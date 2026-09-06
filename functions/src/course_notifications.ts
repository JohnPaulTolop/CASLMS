/* eslint-disable require-jsdoc */

import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

type DataMap = Record<string, unknown>;

interface CourseContext {
  code: string;
  title: string;
  instructorId: string;
  instructorName: string;
}

interface CourseNotification {
  courseId: string;
  moduleId?: string;
  sourceId: string;
  sourceType: string;
  notificationType: string;
  itemTitle: string;
  action: string;
  activityType?: string;
  actorId?: string;
}

interface GradeNotification {
  courseId: string;
  moduleId?: string;
  sourceId: string;
  sourceType: string;
  studentId: string;
  itemTitle: string;
  score: unknown;
  totalPoints?: unknown;
  actorId?: string;
}

const functionOptions = {
  region: "asia-southeast1",
  maxInstances: 10,
};

function text(value: unknown): string {
  return String(value ?? "").trim();
}

function normalized(value: unknown): string {
  return text(value).toLowerCase();
}

function dataMap(value: unknown): DataMap | undefined {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return undefined;
  }

  return value as DataMap;
}

function becamePublished(
  before: DataMap | undefined,
  after: DataMap,
): boolean {
  return normalized(after.status) === "published" &&
    normalized(before?.status) !== "published";
}

function safeIdPart(value: string): string {
  return value.replace(/[^A-Za-z0-9_-]/g, "_");
}

function displayType(value: unknown, fallback: string): string {
  const cleanValue = text(value).replace(/_/g, " ");

  if (!cleanValue) {
    return fallback;
  }

  return cleanValue.charAt(0).toUpperCase() + cleanValue.slice(1);
}

async function getCourseContext(courseId: string): Promise<CourseContext> {
  const database = getFirestore();
  const document = await database.collection("courses").doc(courseId).get();
  const course = dataMap(document.data()) ?? {};

  return {
    code: text(course.code),
    title: text(course.title) || "Course",
    instructorId: text(course.instructorId),
    instructorName: text(course.instructorName) || "Instructor",
  };
}

async function getActorName(
  actorId: string,
  fallback: string,
): Promise<string> {
  if (!actorId) {
    return fallback;
  }

  const database = getFirestore();
  const document = await database.collection("users").doc(actorId).get();
  const user = dataMap(document.data());

  if (!user) {
    return fallback;
  }

  return text(user.name) ||
    text(user.displayName) ||
    text(user.fullName) ||
    fallback;
}

async function getActiveStudentIds(courseId: string): Promise<string[]> {
  const database = getFirestore();
  const snapshot = await database
    .collection("enrollments")
    .where("courseId", "==", courseId)
    .get();
  const ids = snapshot.docs
    .map((document) => dataMap(document.data()))
    .filter((enrollment) => normalized(enrollment?.status) === "active")
    .map((enrollment) => text(enrollment?.studentId))
    .filter((studentId) => studentId.length > 0);

  return [...new Set(ids)];
}

async function notifyCourseStudents(
  input: CourseNotification,
): Promise<void> {
  const studentIds = await getActiveStudentIds(input.courseId);

  if (studentIds.length === 0) {
    return;
  }

  const database = getFirestore();
  const course = await getCourseContext(input.courseId);
  const actorId = text(input.actorId) || course.instructorId;
  const actorName = await getActorName(actorId, course.instructorName);
  const courseLabel = course.code || course.title;

  for (let start = 0; start < studentIds.length; start += 400) {
    const batch = database.batch();

    for (const studentId of studentIds.slice(start, start + 400)) {
      const notificationId = [
        input.notificationType,
        input.sourceType,
        input.sourceId,
        studentId,
      ].map(safeIdPart).join("_");
      const reference = database
        .collection("notifications")
        .doc(notificationId);

      batch.set(reference, {
        userId: studentId,
        type: input.notificationType,
        sourceType: input.sourceType,
        sourceId: input.sourceId,
        title: input.itemTitle,
        message: `${actorName} ${input.action} in ${courseLabel}.`,
        courseId: input.courseId,
        courseCode: course.code,
        courseTitle: course.title,
        moduleId: input.moduleId ?? null,
        activityType: input.activityType ?? null,
        actorId,
        actorName,
        priority: "normal",
        isUrgent: false,
        isRead: false,
        readAt: null,
        createdAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    }

    await batch.commit();
  }
}

async function notifyStudentOfGrade(
  input: GradeNotification,
): Promise<void> {
  if (!input.studentId) {
    return;
  }

  const database = getFirestore();
  const course = await getCourseContext(input.courseId);
  const actorId = text(input.actorId) || course.instructorId;
  const actorName = await getActorName(actorId, course.instructorName);
  const score = text(input.score);
  const totalPoints = text(input.totalPoints);
  const scoreLabel = score ?
    totalPoints ? ` Score: ${score}/${totalPoints}.` : ` Score: ${score}.` :
    "";
  const notificationId = [
    "grade",
    input.sourceType,
    input.sourceId,
    input.studentId,
  ].map(safeIdPart).join("_");

  await database.collection("notifications").doc(notificationId).set({
    userId: input.studentId,
    type: "grade",
    sourceType: input.sourceType,
    sourceId: input.sourceId,
    title: `Graded: ${input.itemTitle}`,
    message: `${actorName} graded your work.${scoreLabel}`,
    courseId: input.courseId,
    courseCode: course.code,
    courseTitle: course.title,
    moduleId: input.moduleId ?? null,
    actorId,
    actorName,
    priority: "normal",
    isUrgent: false,
    isRead: false,
    readAt: null,
    createdAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

function needsManualGradeNotification(
  before: DataMap | undefined,
  after: DataMap,
): boolean {
  const gradedBy = normalized(after.gradedBy);

  if (normalized(after.status) !== "graded" ||
      !gradedBy ||
      gradedBy.startsWith("system:")) {
    return false;
  }

  return normalized(before?.status) !== "graded" ||
    before?.score !== after.score ||
    before?.feedback !== after.feedback;
}

function needsLegacyGradeNotification(
  before: DataMap | undefined,
  after: DataMap,
): boolean {
  return normalized(after.status) === "graded" &&
    (normalized(before?.status) !== "graded" ||
      before?.score !== after.score ||
      before?.feedback !== after.feedback);
}

export const notifyPublishedModule = onDocumentWritten(
  {...functionOptions, document: "modules/{moduleId}"},
  async (event) => {
    const before = dataMap(event.data?.before.data());
    const after = dataMap(event.data?.after.data());

    if (!after || !becamePublished(before, after)) {
      return;
    }

    const courseId = text(after.courseId);

    if (!courseId) {
      return;
    }

    const title = text(after.title) || "New module";
    await notifyCourseStudents({
      courseId,
      moduleId: event.params.moduleId,
      sourceId: event.params.moduleId,
      sourceType: "module",
      notificationType: "module",
      itemTitle: `New module: ${title}`,
      action: `published the module "${title}"`,
      actorId: text(after.createdBy),
    });
  },
);

export const notifyPublishedResource = onDocumentWritten(
  {...functionOptions, document: "moduleResources/{resourceId}"},
  async (event) => {
    const before = dataMap(event.data?.before.data());
    const after = dataMap(event.data?.after.data());

    if (!after || !becamePublished(before, after)) {
      return;
    }

    const courseId = text(after.courseId);

    if (!courseId) {
      return;
    }

    const title = text(after.title) || text(after.fileName) ||
      "Learning material";
    await notifyCourseStudents({
      courseId,
      moduleId: text(after.moduleId),
      sourceId: event.params.resourceId,
      sourceType: "moduleResource",
      notificationType: "resource",
      itemTitle: `New resource: ${title}`,
      action: `added the resource "${title}"`,
      activityType: text(after.resourceType),
      actorId: text(after.createdBy),
    });
  },
);

export const notifyPublishedAssessment = onDocumentWritten(
  {...functionOptions, document: "assessments/{assessmentId}"},
  async (event) => {
    const before = dataMap(event.data?.before.data());
    const after = dataMap(event.data?.after.data());

    if (!after || !becamePublished(before, after)) {
      return;
    }

    const courseId = text(after.courseId);

    if (!courseId) {
      return;
    }

    const assessmentType = displayType(after.assessmentType, "Assessment");
    const title = text(after.title) || assessmentType;
    await notifyCourseStudents({
      courseId,
      moduleId: text(after.moduleId),
      sourceId: event.params.assessmentId,
      sourceType: "assessment",
      notificationType: "assessment",
      itemTitle: `New ${assessmentType}: ${title}`,
      action: `published the ${assessmentType.toLowerCase()} "${title}"`,
      activityType: normalized(after.assessmentType),
      actorId: text(after.createdBy),
    });
  },
);

export const notifyAssessmentGrade = onDocumentWritten(
  {...functionOptions, document: "assessmentSubmissions/{submissionId}"},
  async (event) => {
    const before = dataMap(event.data?.before.data());
    const after = dataMap(event.data?.after.data());

    if (!after || !needsManualGradeNotification(before, after)) {
      return;
    }

    const assessmentId = text(after.assessmentId);
    const courseId = text(after.courseId);
    const studentId = text(after.studentId);

    if (!assessmentId || !courseId || !studentId) {
      return;
    }

    const database = getFirestore();
    const assessmentDocument = await database
      .collection("assessments")
      .doc(assessmentId)
      .get();
    const assessment = dataMap(assessmentDocument.data()) ?? {};

    await notifyStudentOfGrade({
      courseId,
      moduleId: text(after.moduleId),
      sourceId: event.params.submissionId,
      sourceType: "assessmentSubmission",
      studentId,
      itemTitle: text(assessment.title) || "Assessment",
      score: after.score,
      totalPoints: assessment.totalPoints,
      actorId: text(after.gradedBy),
    });
  },
);

export const notifyPublishedLegacyAssignment = onDocumentWritten(
  {...functionOptions, document: "assignments/{assignmentId}"},
  async (event) => {
    const before = dataMap(event.data?.before.data());
    const after = dataMap(event.data?.after.data());

    if (!after || !becamePublished(before, after)) {
      return;
    }

    const courseId = text(after.courseId);

    if (!courseId) {
      return;
    }

    const title = text(after.title) || "Assignment";
    await notifyCourseStudents({
      courseId,
      moduleId: text(after.moduleId),
      sourceId: event.params.assignmentId,
      sourceType: "assignment",
      notificationType: "assignment",
      itemTitle: `New assignment: ${title}`,
      action: `published the assignment "${title}"`,
      activityType: "assignment",
      actorId: text(after.createdBy),
    });
  },
);

export const notifyLegacyAssignmentGrade = onDocumentWritten(
  {...functionOptions, document: "submissions/{submissionId}"},
  async (event) => {
    const before = dataMap(event.data?.before.data());
    const after = dataMap(event.data?.after.data());

    if (!after || !needsLegacyGradeNotification(before, after)) {
      return;
    }

    const assignmentId = text(after.assignmentId);
    const studentId = text(after.studentId);

    if (!assignmentId || !studentId) {
      return;
    }

    const database = getFirestore();
    const assignmentDocument = await database
      .collection("assignments")
      .doc(assignmentId)
      .get();
    const assignment = dataMap(assignmentDocument.data()) ?? {};
    const courseId = text(after.courseId) || text(assignment.courseId);

    if (!courseId) {
      return;
    }

    await notifyStudentOfGrade({
      courseId,
      moduleId: text(after.moduleId) || text(assignment.moduleId),
      sourceId: event.params.submissionId,
      sourceType: "submission",
      studentId,
      itemTitle: text(assignment.title) || "Assignment",
      score: after.score,
      totalPoints: assignment.points,
      actorId: text(after.gradedBy),
    });
  },
);
