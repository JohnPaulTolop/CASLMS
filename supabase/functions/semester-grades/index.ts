import { FieldValue } from "npm:firebase-admin@13.4.0/firestore";
import type { Transaction } from "npm:firebase-admin@13.4.0/firestore";
import {
  auth,
  caller,
  cors,
  db,
  json,
  RequestError,
  secret,
} from "../_shared/firebase.ts";
import { verifyCampusPassword } from "../campus-login/verify_password.ts";
import {
  activeAccount,
  category,
  compute,
  ownReveal,
  POLICY_VERSION,
  postedMetadata,
  taskDefinitions,
  term,
  text,
  time,
  weights,
} from "./engine.ts";
import type { ComputeOptions, Row } from "./engine.ts";
import { decryptGrade, encryptGrade } from "./crypto.ts";

const resultCollections = [
  "assessmentSubmissions",
  "submissions",
  "quiz_attempts",
];
const definitionsCollections = ["assessments", "assignments", "quizzes"];
function response(body: Row, status = 200) {
  const result = json(body, status);
  result.headers.set("Cache-Control", "no-store, private");
  result.headers.set("Pragma", "no-cache");
  return result;
}
function identifier(value: unknown) {
  const result = text(value);
  if (!result || result.length > 200 || result.includes("/")) {
    throw new RequestError("A valid course and section are required.");
  }
  return result;
}
async function hash(value: unknown) {
  const stable = (item: any): any =>
    Array.isArray(item)
      ? item.map(stable)
      : item && typeof item === "object"
      ? Object.fromEntries(
        Object.keys(item).sort().map((key) => [key, stable(item[key])]),
      )
      : item;
  const bytes = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify(stable(value))),
  );
  return Array.from(
    new Uint8Array(bytes),
    (n) => n.toString(16).padStart(2, "0"),
  ).join("");
}
async function readOne(collection: string, id: string, tx?: Transaction) {
  const ref = db.collection(collection).doc(id);
  return (tx ? await tx.get(ref) : await ref.get()).data();
}
async function rows(
  collection: string,
  field: string,
  value: string,
  tx?: Transaction,
): Promise<Row[]> {
  const query = db.collection(collection).where(field, "==", value);
  const snapshot = tx ? await tx.get(query) : await query.get();
  return snapshot.docs.map((doc) => ({ ...doc.data(), id: doc.id }));
}
function options(body: Row): ComputeOptions {
  if (!["incomplete", "zero"].includes(body.missing)) {
    throw new RequestError("Choose how to handle missing submissions.");
  }
  try {
    return {
      weights: weights(body.weights),
      missing: body.missing,
      acceptLegacyQuizScores: body.acceptLegacyQuizScores === true,
    };
  } catch (error) {
    throw new RequestError((error as Error).message);
  }
}
async function instructorSnapshot(
  actor: Row,
  courseId: string,
  sectionId: string,
  config: ComputeOptions,
  overrides: Row,
  tx?: Transaction,
) {
  const profile = await readOne("users", actor.uid, tx);
  const course = await readOne("courses", courseId, tx);
  if (
    !profile || !activeAccount(profile, actor) ||
    profile.role !== "instructor" || !course ||
    course.instructorId !== actor.uid
  ) {
    throw new RequestError(
      "Only the active course instructor can finalize these grades.",
      403,
    );
  }
  const semester = term(course);
  if (!semester.academicYear || !semester.semester) {
    throw new RequestError("Set the course academic year and semester first.");
  }
  const section = await readOne("courseSections", sectionId, tx);
  if (
    section
      ? section.courseId !== courseId || section.status !== "active"
      : sectionId !== course.classCode
  ) {
    throw new RequestError(
      "Select an active section belonging to this course.",
      403,
    );
  }
  const memberships = await rows("enrollments", "courseId", courseId, tx);
  const byStudent = new Map<string, Row>();
  for (const row of memberships) {
    if (row.status === "active" && text(row.studentId)) {
      if (
        !byStudent.has(row.studentId) ||
        row.id === `${courseId}_${row.studentId}`
      ) byStudent.set(row.studentId, row);
    }
  }
  const students = [...byStudent.values()].filter((row) =>
    (text(row.sectionId) || course.classCode) === sectionId
  ).sort((a, b) => text(a.studentId).localeCompare(text(b.studentId)));
  if (!students.length) {
    throw new RequestError("This section has no enrolled students.");
  }
  if (students.length > 100) {
    throw new RequestError(
      "Finalize sections of up to 100 students at a time.",
    );
  }
  if (
    Object.keys(overrides).some((uid) =>
      !students.some((row) => row.studentId === uid)
    )
  ) {
    throw new RequestError(
      "A disposition refers to a student outside this section.",
    );
  }
  const definitions: Record<string, Row[]> = {};
  const results: Row[] = [];
  for (const collection of definitionsCollections) {
    definitions[collection] = await rows(collection, "courseId", courseId, tx);
  }
  for (const collection of resultCollections) {
    results.push(...await rows(collection, "courseId", courseId, tx));
  }
  let tasks;
  try {
    tasks = taskDefinitions(definitions, courseId, sectionId);
  } catch (error) {
    throw new RequestError((error as Error).message);
  }
  const grades: Row[] = [];
  for (const student of students) {
    try {
      grades.push({
        studentId: student.studentId,
        studentName: text(student.studentName) || "Student",
        campusId: text(student.studentCampusId),
        ...compute(
          tasks,
          results,
          student.studentId,
          config,
          overrides[student.studentId],
        ),
      });
    } catch (error) {
      throw new RequestError((error as Error).message);
    }
  }
  const source = {
    tasks,
    results: results.filter((row) =>
      students.some((student) => student.studentId === row.studentId)
    ).map((row) => ({
      id: row.id,
      studentId: row.studentId,
      assessmentId: row.assessmentId ?? null,
      assignmentId: row.assignmentId ?? null,
      quizId: row.quizId ?? null,
      score: row.score ?? null,
      status: row.status ?? null,
      submittedAt: time(row.submittedAt),
      updatedAt: time(row.updatedAt),
    })).sort((a, b) => a.id.localeCompare(b.id)),
  };
  const fingerprint = await hash({
    courseId,
    sectionId,
    semester,
    config,
    overrides,
    grades,
    source,
  });
  return {
    semester,
    course,
    sectionName: text(section?.name) || "Original Section",
    grades,
    fingerprint,
  };
}
async function studentSubjects(uid: string) {
  const memberships = await rows("enrollments", "studentId", uid);
  const ids = [
    ...new Set(
      memberships.filter((row) =>
        ["active", "completed", "dropped"].includes(row.status)
      ).map((row) => text(row.courseId)),
    ),
  ].filter(Boolean);
  const subjects: Row[] = [];
  for (const id of ids) {
    const course = await readOne("courses", id);
    if (course) {
      subjects.push({
        courseId: id,
        courseTitle: text(course.title),
        courseCode: text(course.code),
        ...term(course),
      });
    }
  }
  return subjects;
}
// Metadata is explicitly projected. Never spread an encrypted grade record into
// the unauthenticated-to-reveal response, even when its owner is requesting it.

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return response({ error: "Method not allowed." }, 405);
  }
  try {
    const actor = await caller(request);
    const profile = await readOne("users", actor.uid);
    if (!profile || !activeAccount(profile, actor)) {
      throw new RequestError("An active verified account is required.", 403);
    }
    const body = await request.json().catch(() => {
      throw new RequestError("Invalid request body.");
    });
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new RequestError("Invalid request body.");
    }
    if (["preview", "finalize"].includes(body.action)) {
      const courseId = identifier(body.courseId);
      const sectionId = identifier(body.sectionId);
      const config = options(body);
      const overrides = body.dispositions ?? {};
      if (
        !overrides || typeof overrides !== "object" || Array.isArray(overrides)
      ) throw new RequestError("Invalid dispositions.");
      if (body.action === "preview") {
        const snapshot = await instructorSnapshot(
          actor,
          courseId,
          sectionId,
          config,
          overrides,
        );
        return response({
          success: true,
          previewHash: snapshot.fingerprint,
          courseTitle: snapshot.course.title,
          sectionName: snapshot.sectionName,
          termLabel: snapshot.semester.termLabel,
          grades: snapshot.grades,
          policyVersion: POLICY_VERSION,
        });
      }
      // Refuse publication without the exact preview of current source data.
      if (!/^[a-f0-9]{64}$/.test(text(body.previewHash))) {
        throw new RequestError("Preview the grades before finalizing.", 409);
      }
      const encryptionKey = secret("SEMESTER_GRADE_ENCRYPTION_KEY");
      const postedCount = await db.runTransaction(async (tx) => {
        const snapshot = await instructorSnapshot(
          actor,
          courseId,
          sectionId,
          config,
          overrides,
          tx,
        );
        if (snapshot.fingerprint !== body.previewHash) {
          throw new RequestError(
            "Scores, enrollment or settings changed. Preview again before posting.",
            409,
          );
        }
        const refs = await Promise.all(
          snapshot.grades.map(async (grade) =>
            db.collection("semesterGrades").doc(
              await hash([courseId, snapshot.semester.termId, grade.studentId]),
            )
          ),
        );
        const existing = await tx.getAll(...refs);
        const policyRef = db.collection("semesterGradePolicies").doc(
          await hash([courseId, sectionId, snapshot.semester.termId]),
        );
        const oldPolicy = (await tx.get(policyRef)).data();
        if (oldPolicy?.sourceHash === snapshot.fingerprint) return 0; // Retry is idempotent.
        const prepared = await Promise.all(
          snapshot.grades.map(async (grade, index) => {
            const revision = Number(existing[index].data()?.revision ?? 0) + 1;
            const encrypted = await encryptGrade(
              { ...grade, policyVersion: POLICY_VERSION, config },
              encryptionKey,
              JSON.stringify([
                refs[index].id,
                grade.studentId,
                snapshot.semester.termId,
                revision,
              ]),
            );
            return {
              ref: refs[index],
              revision,
              encrypted,
              studentId: grade.studentId,
            };
          }),
        );
        for (const item of prepared) {
          const record = {
            courseId,
            sectionId,
            studentId: item.studentId,
            instructorId: actor.uid,
            ...snapshot.semester,
            posted: true,
            revision: item.revision,
            encrypted: item.encrypted,
            sourceHash: snapshot.fingerprint,
            postedAt: FieldValue.serverTimestamp(),
          };
          tx.set(item.ref, record);
          tx.set(
            item.ref.collection("revisions").doc(String(item.revision)),
            record,
          );
          tx.set(db.collection("notifications").doc(), {
            userId: item.studentId,
            type: "grade",
            title: "Semester grade posted",
            message: `Your semester grade for ${
              text(snapshot.course.code) || text(snapshot.course.title)
            } is available in Posted Grades.`,
            courseId,
            sourceType: "semesterGrade",
            sourceId: item.ref.id,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
        tx.set(policyRef, {
          courseId,
          sectionId,
          instructorId: actor.uid,
          ...snapshot.semester,
          ...config,
          policyVersion: POLICY_VERSION,
          sourceHash: snapshot.fingerprint,
          postedAt: FieldValue.serverTimestamp(),
        });
        return prepared.length;
      });
      return response({ success: true, postedCount });
    }
    if (profile.role !== "student") {
      throw new RequestError("This view is only available to students.", 403);
    }
    if (body.action === "posted") {
      const subjects = await studentSubjects(actor.uid);
      const terms = [
        ...new Map(
          subjects.map((
            subject,
          ) => [subject.termId, {
            id: subject.termId,
            label: subject.termLabel,
          }]),
        ).values(),
      ].sort((a, b) => b.id.localeCompare(a.id));
      const calendar = await readOne("settings", "academicCalendar");
      const selected = text(body.termId) ||
        (terms.some((value) => value.id === calendar?.currentTermId)
          ? calendar!.currentTermId
          : terms[0]?.id ?? "");
      const result = [];
      for (
        const subject of subjects.filter((value) => value.termId === selected)
      ) {
        const grade = await readOne(
          "semesterGrades",
          await hash([subject.courseId, subject.termId, actor.uid]),
        );
        result.push(postedMetadata(subject, grade));
      }
      return response({
        success: true,
        terms,
        termId: selected,
        subjects: result,
      });
    }
    if (body.action === "reveal") {
      const attemptRef = db.collection("gradeRevealAttempts").doc(actor.uid);
      const allowed = await db.runTransaction(async (tx) => {
        const previous = (await tx.get(attemptRef)).data();
        const now = Date.now();
        const current = Number(previous?.expiresAtMs ?? 0) > now;
        const count = current ? Number(previous?.count ?? 0) : 0;
        if (count >= 10) return false;
        tx.set(attemptRef, {
          count: count + 1,
          expiresAtMs: current ? previous!.expiresAtMs : now + 600000,
        });
        return true;
      });
      if (!allowed) {
        throw new RequestError(
          "Too many attempts. Please try again in 10 minutes.",
          429,
        );
      }
      const campusId = text(body.campusId).replace(/\s+/g, "");
      if (
        campusId !== text(profile.universityId) ||
        typeof body.password !== "string" || !body.password ||
        body.password.length > 4096
      ) throw new RequestError("Invalid Student ID or Password", 401);
      const user = await auth.getUser(actor.uid);
      if (
        user.disabled || !user.email ||
        !await verifyCampusPassword(
          actor.uid,
          user.email,
          body.password,
          secret("FIREBASE_WEB_API_KEY"),
          request.headers.get("X-Firebase-AppCheck") ?? "",
        )
      ) throw new RequestError("Invalid Student ID or Password", 401);
      const courseId = identifier(body.courseId);
      const termId = text(body.termId);
      if (!termId || termId.length > 200) {
        throw new RequestError("Select the semester again.");
      }
      const docId = await hash([courseId, termId, actor.uid]);
      const grade = await readOne("semesterGrades", docId);
      if (!grade || !ownReveal(profile, actor.uid, campusId, grade)) {
        throw new RequestError(
          "Your grade for this subject has not been posted.",
          403,
        );
      }
      // Recheck account state after credential verification; no custom token or
      // auth-session replacement is returned by this reveal workflow.
      const fresh = await readOne("users", actor.uid);
      if (!fresh || !activeAccount(fresh, actor)) {
        throw new RequestError("Account access is unavailable.", 403);
      }
      const payload = await decryptGrade(
        grade.encrypted,
        secret("SEMESTER_GRADE_ENCRYPTION_KEY"),
        JSON.stringify([docId, actor.uid, termId, grade.revision]),
      );
      await attemptRef.delete();
      return response({
        success: true,
        grade: payload.grade,
        result: payload.result,
        description: payload.description,
        revision: grade.revision,
      });
    }
    if (body.action === "activities") {
      const summaries: Row[] = [];
      const results: Row[] = [];
      for (const collection of resultCollections) {
        results.push(
          ...(await rows(collection, "studentId", actor.uid)).map((row) => ({
            ...row,
            collection,
          })),
        );
      }
      const cache = new Map<string, Row | undefined>();
      async function get(collection: string, id: string) {
        const key = `${collection}/${id}`;
        if (!cache.has(key)) cache.set(key, await readOne(collection, id));
        return cache.get(key);
      }
      const modernResultIds = new Set(
        results.filter((row) => row.collection === "assessmentSubmissions").map(
          (row) => row.assessmentId,
        ),
      );
      for (const row of results) {
        if (
          ["draft", "in_progress", "not_complied"].includes(row.status) ||
          !row.submittedAt
        ) continue;
        const sourceIndex = resultCollections.indexOf(row.collection);
        const definitionId = text(
          row[["assessmentId", "assignmentId", "quizId"][sourceIndex]],
        );
        if (!definitionId || definitionId.includes("/")) continue;
        const definition = await get(
          definitionsCollections[sourceIndex],
          definitionId,
        );
        if (
          sourceIndex !== 0 && modernResultIds.has(definition?.assessmentId)
        ) continue;
        const courseId = text(row.courseId);
        if (!courseId || courseId.includes("/")) continue;
        const course = await get("courses", courseId);
        let kind;
        try {
          kind = categoryFor(definition, sourceIndex);
        } catch {
          kind = "activity";
        }
        const max = row.totalPoints ?? definition?.totalPoints ??
          definition?.points;
        const validMax = typeof max === "number" && Number.isFinite(max) &&
          max > 0;
        const isGraded = row.status === "graded" &&
          typeof row.score === "number" && Number.isFinite(row.score) &&
          validMax && row.score >= 0 && row.score <= max;
        const reported = sourceIndex === 2 && row.status === "submitted" &&
          typeof row.score === "number" && Number.isFinite(row.score) &&
          validMax && row.score >= 0 && row.score <= max;
        const submittedMs = time(row.submittedAt);
        const due = time(definition?.dueDate ?? definition?.deadline);
        const late = row.isLate === true || (due > 0 && submittedMs > due);
        summaries.push({
          id: `${row.collection}/${row.id}`,
          title: text(definition?.title) || "Submitted activity",
          courseId,
          subject: `${text(course?.code)} ${text(course?.title)}`.trim() ||
            "Subject",
          activityType: kind,
          submittedAt: new Date(submittedMs).toISOString(),
          totalPoints: validMax ? max : null,
          pointsEarned: isGraded || reported ? row.score : null,
          percentage: isGraded || reported ? row.score / max * 100 : null,
          status: isGraded ? "Graded" : reported ? "Reported" : "Pending",
          late,
          needsInstructorReview: sourceIndex === 2 && row.status !== "graded",
        });
      }
      summaries.sort((a, b) => b.submittedAt.localeCompare(a.submittedAt));
      return response({ success: true, activities: summaries });
    }
    throw new RequestError("Invalid grades action.");
  } catch (error) {
    if (error instanceof RequestError) {
      return response({ error: error.message }, error.status);
    }
    const code = typeof error === "object" && error && "code" in error
      ? String(error.code)
      : "internal";
    console.error("Semester grades request failed:", code);
    return response({
      error:
        "Grades are unavailable. Please retry or contact the administrator.",
    }, 500);
  }
});

function categoryFor(definition: Row | undefined, index: number) {
  const type = text(definition?.assessmentType) ||
    ["activity", "assignment", "quiz"][index];
  try {
    return category(type);
  } catch {
    return "activity";
  }
}
