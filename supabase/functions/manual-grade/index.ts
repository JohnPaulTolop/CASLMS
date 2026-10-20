import { FieldValue } from "npm:firebase-admin@13.4.0/firestore";
import {
  caller,
  cors,
  db,
  failure,
  json,
  RequestError,
} from "../_shared/firebase.ts";
import { canGradeEnrollment, validScore } from "./policy.ts";

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
    const assessmentId = String(body?.assessmentId ?? "").trim();
    const studentId = String(body?.studentId ?? "").trim();
    const feedback = String(body?.feedback ?? "").trim();
    if (
      !assessmentId || !studentId || assessmentId.includes("/") ||
      studentId.includes("/") || feedback.length > 5000
    ) {
      throw new RequestError(
        "Valid assessment, student and feedback are required.",
      );
    }
    const ref = db.collection("assessmentSubmissions").doc(
      `${assessmentId}_${studentId}`,
    );
    const notice = db.collection("notifications").doc();
    const audit = ref.collection("gradeHistory").doc();
    await db.runTransaction(async (tx) => {
      const instructor = (await tx.get(db.collection("users").doc(actor.uid)))
        .data();
      const assessment =
        (await tx.get(db.collection("assessments").doc(assessmentId))).data();
      if (
        !instructor || instructor.role !== "instructor" ||
        instructor.status !== "active"
      ) {
        throw new RequestError("Active instructor account required.", 403);
      }
      if (
        !assessment || assessment.deliveryType !== "external_link" ||
        !["published", "closed"].includes(assessment.status)
      ) {
        throw new RequestError(
          "Manual grades are available for published or closed external assessments only.",
        );
      }
      const total = assessment.totalPoints;
      if (!validScore(body.score, total)) {
        throw new RequestError(
          "Score must be between zero and the assessment's total points.",
        );
      }
      const course =
        (await tx.get(db.collection("courses").doc(assessment.courseId)))
          .data();
      const enrollment = (await tx.get(
        db.collection("enrollments").doc(
          `${assessment.courseId}_${studentId}`,
        ),
      )).data();
      const student = (await tx.get(db.collection("users").doc(studentId)))
        .data();
      const existing = (await tx.get(ref)).data();
      if (!course || course.instructorId !== actor.uid) {
        throw new RequestError("You do not own this course.", 403);
      }
      if (
        !student ||
        !canGradeEnrollment(
          actor.uid,
          assessment,
          course,
          enrollment,
          student,
          studentId,
        )
      ) {
        throw new RequestError(
          "This student is not actively enrolled in the assessment's course and section.",
          403,
        );
      }
      if (
        existing &&
        (existing.assessmentId !== assessmentId ||
          existing.studentId !== studentId ||
          existing.courseId !== assessment.courseId)
      ) {
        throw new RequestError("Submission identity does not match.", 409);
      }
      if (
        existing?.gradingMode === "manual" && existing.score === body.score &&
        existing.totalPoints === total && existing.feedback === feedback
      ) return;
      const google = assessment.submissionMethod === "google_form" ||
        /^(https:\/\/)?(forms\.gle\/|docs\.google\.com\/forms\/)/i.test(
          String(assessment.externalUrl ?? ""),
        );
      tx.set(ref, {
        assessmentId,
        courseId: assessment.courseId,
        moduleId: assessment.moduleId,
        studentId,
        studentName: student.name ?? "Student",
        studentEmail: student.email ?? "",
        submissionType: google ? "google_form" : "external_link",
        ...(google
          ? {
            complianceStatus: "complied",
            submissionSource: "instructor_verification",
            verifiedBy: actor.uid,
            verifiedAt: FieldValue.serverTimestamp(),
          }
          : { submissionSource: "instructor_manual" }),
        status: "graded",
        gradingMode: "manual",
        gradeSource: "instructor_manual",
        score: body.score,
        totalPoints: total,
        percentage: body.score / total * 100,
        feedback,
        gradedBy: actor.uid,
        gradedAt: FieldValue.serverTimestamp(),
        manualGradeVersion: Number(existing?.manualGradeVersion ?? 0) + 1,
        submittedAt: existing?.submittedAt ?? FieldValue.serverTimestamp(),
        createdAt: existing?.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.set(audit, {
        previousScore: existing?.score ?? null,
        score: body.score,
        totalPoints: total,
        feedback,
        gradedBy: actor.uid,
        gradedAt: FieldValue.serverTimestamp(),
      });
      tx.set(notice, {
        userId: studentId,
        type: "grade",
        sourceType: "manualAssessmentGrade",
        sourceId: ref.id,
        actorId: actor.uid,
        actorName: instructor.name ?? "Instructor",
        title: `Grade: ${assessment.title}`,
        message: `Your score is ${body.score} / ${total}.`,
        courseId: assessment.courseId,
        moduleId: assessment.moduleId,
        isRead: false,
        readAt: null,
        createdAt: FieldValue.serverTimestamp(),
      });
    });
    return json({ success: true, submissionId: ref.id });
  } catch (error) {
    return failure(error);
  }
});
