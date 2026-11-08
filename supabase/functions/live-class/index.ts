import { FieldValue } from "npm:firebase-admin@13.4.0/firestore";
import type { Transaction } from "npm:firebase-admin@13.4.0/firestore";
import {
  caller,
  cors,
  db,
  failure,
  json,
  RequestError,
  secret,
} from "../_shared/firebase.ts";
import { admitStudent, canAttend, STUDENT_LIMIT } from "./policy.ts";
import { LiveKitRooms, participantGrant, signToken } from "./livekit.ts";

type Data = Record<string, any>;
function id(value: unknown): string {
  if (
    typeof value !== "string" || !value.trim() || value.length > 200 ||
    value.includes("/")
  ) {
    throw new RequestError("A valid course and section are required.");
  }
  return value.trim();
}
function provider() {
  const url = secret("LIVEKIT_URL");
  if (!/^wss:\/\/[^/]+\.livekit\.cloud\/?$/.test(url)) {
    throw new RequestError(
      "Configure a LiveKit Cloud project URL before starting a class.",
      503,
    );
  }
  const key = secret("LIVEKIT_API_KEY");
  const apiSecret = secret("LIVEKIT_API_SECRET");
  return { url, key, apiSecret, rooms: new LiveKitRooms(url, key, apiSecret) };
}
function configured() {
  return ["LIVEKIT_URL", "LIVEKIT_API_KEY", "LIVEKIT_API_SECRET"].every((key) =>
    Deno.env.get(key)?.trim()
  );
}
function publicState(data: Data | undefined) {
  if (!data) return null;
  return {
    sessionId: data.sessionId,
    title: data.title,
    status: data.status,
    studentCount: (data.studentIds ?? []).length,
    studentLimit: STUDENT_LIMIT,
    startedAt: data.startedAt?.toDate?.().toISOString() ?? null,
  };
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
    });
    const courseId = id(body?.courseId);
    const action = body?.action;
    if (!["state", "start", "join", "end"].includes(action)) {
      throw new RequestError("Invalid classroom action.");
    }
    let lockedSection: string | undefined;
    async function access(tx?: Transaction) {
      const read = async (collection: string, key: string) => {
        const ref = db.collection(collection).doc(key);
        return (tx ? await tx.get(ref) : await ref.get()).data();
      };
      const profile = await read("users", actor.uid);
      const course = await read("courses", courseId);
      if (!profile || !course) {
        throw new RequestError("Course access is unavailable.", 403);
      }
      const instructor = profile.role === "instructor" &&
        course.instructorId === actor.uid;
      const enrollment = instructor
        ? undefined
        : await read("enrollments", `${courseId}_${actor.uid}`);
      const sectionId = id(
        instructor
          ? body.sectionId
          : String(enrollment?.sectionId ?? "").trim() || course.classCode,
      );
      if (lockedSection && sectionId !== lockedSection) {
        throw new RequestError(
          "Your section changed. Reopen Live Classes.",
          409,
        );
      }
      // Students never select another section through a request parameter.
      if (
        !canAttend(
          actor.uid,
          profile,
          actor,
          courseId,
          course,
          enrollment,
          sectionId,
        )
      ) {
        throw new RequestError(
          "Only the course instructor and active students in this section can enter.",
          403,
        );
      }
      const section = await read("courseSections", sectionId);
      if (
        (section &&
          (section.courseId !== courseId || section.status !== "active")) ||
        (!section && sectionId !== course.classCode)
      ) {
        throw new RequestError("This section is unavailable.", 403);
      }
      return {
        profile,
        course,
        sectionId,
        instructor,
        sectionName: section?.name ?? course.legacySectionName ??
          "Original Section",
      };
    }
    const initial = await access();
    lockedSection = initial.sectionId;
    const digest = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(JSON.stringify([courseId, initial.sectionId])),
    );
    const key = Array.from(
      new Uint8Array(digest),
      (byte) => byte.toString(16).padStart(2, "0"),
    ).join("");
    const ref = db.collection("liveClasses").doc(key);
    if (action === "state") {
      return json({
        success: true,
        configured: !!configured(),
        instructor: initial.instructor,
        courseTitle: initial.course.title ?? "Course",
        sectionName: initial.sectionName,
        sectionId: initial.sectionId,
        session: publicState((await ref.get()).data()),
      });
    }
    if (!configured()) {
      throw new RequestError(
        "Live classes are not configured yet. Ask the administrator to complete LiveKit setup.",
        503,
      );
    }
    const livekit = provider();
    if (action === "start") {
      if (!initial.instructor) {
        throw new RequestError(
          "Only the course instructor can start a class.",
          403,
        );
      }
      const title = String(body.title ?? "Live class").trim();
      if (!title || title.length > 100) {
        throw new RequestError("Enter a class title of up to 100 characters.");
      }
      const sessionId = crypto.randomUUID();
      const roomName = `cas-${sessionId}`;
      let created = false;
      await db.runTransaction(async (tx) => {
        created = false;
        const permission = await access(tx);
        if (!permission.instructor) {
          throw new RequestError("Instructor access required.", 403);
        }
        const existing = (await tx.get(ref)).data();
        if (
          existing?.status === "live" || existing?.status === "ending" ||
          (existing?.status === "starting" &&
            existing.updatedAt?.toMillis() > Date.now() - 180000)
        ) return;
        tx.set(ref, {
          courseId,
          sectionId: initial.sectionId,
          instructorId: actor.uid,
          title,
          sessionId,
          roomName,
          status: "starting",
          studentIds: [],
          startedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        created = true;
      });
      if (created) {
        try {
          await livekit.rooms.createRoom(
            roomName,
            JSON.stringify({
              courseId,
              sectionId: initial.sectionId,
              sessionId,
            }),
          );
          await db.runTransaction(async (tx) => {
            const current = (await tx.get(ref)).data();
            if (
              current?.sessionId !== sessionId || current.status !== "starting"
            ) {
              throw new RequestError(
                "Class start was interrupted. Refresh and retry.",
                409,
              );
            }
            tx.update(ref, {
              status: "live",
              updatedAt: FieldValue.serverTimestamp(),
            });
          });
        } catch (error) {
          await db.runTransaction(async (tx) => {
            const current = (await tx.get(ref)).data();
            if (
              current?.sessionId === sessionId && current.status === "starting"
            ) {
              tx.update(ref, {
                status: "failed",
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          });
          throw error;
        }
      }
      return json({
        success: true,
        session: publicState((await ref.get()).data()),
      });
    }
    const sessionId = id(body.sessionId);
    if (action === "end") {
      if (!initial.instructor) {
        throw new RequestError(
          "Only the course instructor can end a class.",
          403,
        );
      }
      const session = await db.runTransaction(async (tx) => {
        const permission = await access(tx);
        const current = (await tx.get(ref)).data();
        if (
          !permission.instructor || !current || current.sessionId !== sessionId
        ) throw new RequestError("Refresh the class before ending it.", 409);
        if (current.status === "ended") return current;
        if (!["live", "ending"].includes(current.status)) {
          throw new RequestError("Wait for the class to finish starting.", 409);
        }
        tx.update(ref, {
          status: "ending",
          updatedAt: FieldValue.serverTimestamp(),
        });
        return current;
      });
      if (session.status !== "ended") {
        // Cloud revocation also covers issued-but-not-connected tokens. The
        // future boundary covers a concurrent join response already in flight.
        const revokeTokenTs = Math.floor(Date.now() / 1000) + 30;
        await Promise.all(
          [session.instructorId, ...(session.studentIds ?? [])].map((uid) =>
            livekit.rooms.removeParticipant(
              session.roomName,
              uid,
              revokeTokenTs,
            )
          ),
        );
        const rooms = await livekit.rooms.listRooms(session.roomName);
        if (rooms.length) await livekit.rooms.deleteRoom(session.roomName);
        await db.runTransaction(async (tx) => {
          const current = (await tx.get(ref)).data();
          if (current?.sessionId === sessionId && current.status === "ending") {
            tx.update(ref, {
              status: "ended",
              endedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        });
      }
      return json({ success: true });
    }
    const session = await db.runTransaction(async (tx) => {
      const permission = await access(tx);
      const current = (await tx.get(ref)).data();
      if (
        !current || current.sessionId !== sessionId || current.status !== "live"
      ) {
        throw new RequestError(
          "This class is not live. Refresh the page.",
          409,
        );
      }
      if (!permission.instructor) {
        let students: string[];
        try {
          students = admitStudent(current.studentIds ?? [], actor.uid);
        } catch {
          throw new RequestError(
            "This class has reached its 30-student limit.",
            409,
          );
        }
        if (students.length !== (current.studentIds ?? []).length) {
          tx.update(ref, {
            studentIds: students,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      return {
        roomName: String(current.roomName),
        title: String(current.title),
        instructor: permission.instructor,
        displayName: String(permission.profile.name ?? "Participant").slice(
          0,
          100,
        ),
      };
    });
    const rooms = await livekit.rooms.listRooms(session.roomName);
    if (!rooms.length) {
      throw new RequestError(
        "This room expired while empty. Ask the instructor to end it and start a new class.",
        409,
      );
    }
    const jwt = await signToken(livekit.key, livekit.apiSecret, {
      sub: actor.uid,
      name: session.displayName,
      video: participantGrant(session.roomName, session.instructor),
      roomConfig: {
        maxParticipants: 31,
        emptyTimeout: 600,
        departureTimeout: 600,
      },
      metadata: JSON.stringify({
        role: session.instructor ? "instructor" : "student",
      }),
    });
    const latest = (await ref.get()).data();
    if (latest?.status !== "live" || latest.sessionId !== sessionId) {
      throw new RequestError("This class has ended.", 409);
    }
    return json({
      success: true,
      url: livekit.url,
      token: jwt,
      instructor: session.instructor,
      sessionId,
      title: session.title,
    });
  } catch (error) {
    return failure(error);
  }
});
