import { createClient } from "npm:@supabase/supabase-js@2";
import { FieldPath } from "npm:firebase-admin@13.4.0/firestore";

import {
  caller,
  cors,
  db,
  failure,
  json,
  RequestError,
  secret,
} from "../_shared/firebase.ts";
import { eventType, isoTimestamp, targetId } from "./policy.ts";

const supabase = createClient(
  secret("SUPABASE_URL"),
  secret("SUPABASE_SERVICE_ROLE_KEY"),
  { auth: { persistSession: false, autoRefreshToken: false } },
);

function clean(value: unknown): string {
  return String(value ?? "").trim();
}

function normalizedRole(value: unknown): "student" | "instructor" | "admin" | null {
  const role = clean(value).toLowerCase();
  return role === "student" || role === "instructor" || role === "admin"
    ? role
    : null;
}

async function activeProfile(uid: string) {
  const snapshot = await db.collection("users").doc(uid).get();
  const profile = snapshot.data();
  const role = normalizedRole(profile?.role);
  if (!profile || clean(profile.status).toLowerCase() !== "active" || !role) {
    throw new RequestError("An active CASLMS account is required.", 403);
  }
  return { ...profile, role };
}

async function requireAdmin(uid: string) {
  const profile = await activeProfile(uid);
  if (profile.role !== "admin") {
    throw new RequestError("Administrator access is required.", 403);
  }
  return profile;
}

async function insertLog(row: Record<string, unknown>) {
  const { error } = await supabase.from("activity_logs").upsert(row, {
    onConflict: "id",
    ignoreDuplicates: true,
  });
  if (error) throw error;
}

async function recordSession(
  actor: Awaited<ReturnType<typeof caller>>,
  body: Record<string, unknown>,
) {
  const type = eventType(body.type);
  if (type !== "login" && type !== "logout") {
    throw new RequestError("Invalid session event.");
  }
  const authTime = Number(actor.auth_time);
  if (!Number.isSafeInteger(authTime) || authTime <= 0) {
    throw new RequestError("The authenticated session is incomplete.", 409);
  }
  const profile = await activeProfile(actor.uid);
  const id = `${type}_${authTime}_${actor.uid}`;
  await insertLog({
    id,
    event_type: type,
    actor_id: actor.uid,
    actor_name: clean(profile.name),
    actor_role: profile.role,
    session_auth_time: authTime,
    created_at: new Date().toISOString(),
  });
  return json({ success: true, id });
}

async function recordSource(
  actor: Awaited<ReturnType<typeof caller>>,
  body: Record<string, unknown>,
) {
  const type = eventType(body.type);
  if (type !== "course_created" && type !== "material_uploaded") {
    throw new RequestError("Invalid source event.");
  }
  const sourceId = targetId(body.targetId);
  if (!sourceId) throw new RequestError("A valid source ID is required.");

  const profile = await activeProfile(actor.uid);
  if (profile.role !== "instructor" && profile.role !== "admin") {
    throw new RequestError("Staff access is required.", 403);
  }

  const collection = type === "course_created" ? "courses" : "moduleResources";
  const source = (await db.collection(collection).doc(sourceId).get()).data();
  if (!source) throw new RequestError("The source record no longer exists.", 404);

  const courseId = type === "course_created"
    ? sourceId
    : clean(source.courseId);
  const course = (await db.collection("courses").doc(courseId).get()).data();
  if (!course) throw new RequestError("The related course was not found.", 404);

  if (profile.role !== "admin") {
    if (clean(course.instructorId) !== actor.uid) {
      throw new RequestError("You do not own this course.", 403);
    }
    if (type === "material_uploaded" && clean(source.createdBy) !== actor.uid) {
      throw new RequestError("You did not upload this material.", 403);
    }
  }

  const id = `${type}_${sourceId}`;
  await insertLog({
    id,
    event_type: type,
    actor_id: actor.uid,
    actor_name: clean(profile.name),
    actor_role: profile.role,
    target_id: sourceId,
    course_id: courseId,
    title: clean(source.title),
    occurred_at: isoTimestamp(source.createdAt),
    created_at: new Date().toISOString(),
  });
  return json({ success: true, id });
}

function clientRow(row: Record<string, unknown>) {
  return {
    id: row.id,
    sequenceId: row.sequence_id,
    type: row.event_type,
    actorId: row.actor_id,
    actorName: row.actor_name,
    actorRole: row.actor_role,
    sessionAuthTime: row.session_auth_time,
    targetId: row.target_id,
    courseId: row.course_id,
    title: row.title,
    occurredAt: row.occurred_at,
    createdAt: row.created_at,
  };
}

async function listLogs(
  actor: Awaited<ReturnType<typeof caller>>,
  body: Record<string, unknown>,
) {
  await requireAdmin(actor.uid);
  const requestedLimit = Number(body.limit ?? 50);
  const limit = Number.isSafeInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 50;
  const category = clean(body.category).toLowerCase();
  const allowedCategory = category === "all" || eventType(category) !== null;
  if (!allowedCategory) throw new RequestError("Invalid log category.");

  let query = supabase.from("activity_logs").select("*")
    .order("sequence_id", { ascending: false })
    .limit(limit + 1);
  if (category !== "all") query = query.eq("event_type", category);

  const since = isoTimestamp(body.since);
  if (body.since != null && !since) throw new RequestError("Invalid date filter.");
  if (since) query = query.gte("created_at", since);

  if (body.cursor != null) {
    const cursor = Number(body.cursor);
    if (!Number.isSafeInteger(cursor) || cursor <= 0) {
      throw new RequestError("Invalid page cursor.");
    }
    query = query.lt("sequence_id", cursor);
  }

  const { data, error } = await query;
  if (error) throw error;
  const rows = (data ?? []) as Record<string, unknown>[];
  const page = rows.slice(0, limit);
  const nextCursor = rows.length > limit && page.length > 0
    ? page[page.length - 1].sequence_id
    : null;
  return json({
    success: true,
    rows: page.map(clientRow),
    nextCursor,
  });
}

async function migrateLogs(
  actor: Awaited<ReturnType<typeof caller>>,
  body: Record<string, unknown>,
) {
  await requireAdmin(actor.uid);
  const requestedLimit = Number(body.limit ?? 100);
  const limit = Number.isSafeInteger(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 200)
    : 100;
  const cursor = clean(body.cursor);

  let query = db.collection("activityLogs")
    .orderBy(FieldPath.documentId())
    .limit(limit);
  if (cursor) query = query.startAfter(cursor);
  const snapshot = await query.get();

  const rows = snapshot.docs.flatMap((document) => {
    const data = document.data();
    const type = eventType(data.type);
    const role = normalizedRole(data.actorRole);
    if (!type || !role || !clean(data.actorId)) return [];
    return [{
      id: document.id,
      event_type: type,
      actor_id: clean(data.actorId),
      actor_name: clean(data.actorName),
      actor_role: role,
      session_auth_time: Number.isSafeInteger(Number(data.sessionAuthTime))
        ? Number(data.sessionAuthTime)
        : null,
      target_id: clean(data.targetId) || null,
      course_id: clean(data.courseId) || null,
      title: clean(data.title) || null,
      occurred_at: isoTimestamp(data.occurredAt),
      created_at: isoTimestamp(data.createdAt) ??
        isoTimestamp(data.occurredAt) ?? new Date().toISOString(),
    }];
  });

  if (rows.length > 0) {
    const { error } = await supabase.from("activity_logs").upsert(rows, {
      onConflict: "id",
      ignoreDuplicates: true,
    });
    if (error) throw error;
  }

  const last = snapshot.docs.at(-1)?.id ?? null;
  return json({
    success: true,
    copied: rows.length,
    scanned: snapshot.size,
    nextCursor: snapshot.size === limit ? last : null,
    done: snapshot.size < limit,
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }
  try {
    const actor = await caller(request);
    const body = await request.json().catch(() => {
      throw new RequestError("Invalid request body.");
    }) as Record<string, unknown>;
    const action = clean(body.action);
    if (action === "session") return await recordSession(actor, body);
    if (action === "source") return await recordSource(actor, body);
    if (action === "list") return await listLogs(actor, body);
    if (action === "migrate") return await migrateLogs(actor, body);
    throw new RequestError("Unsupported activity-log action.");
  } catch (error) {
    return failure(error);
  }
});
