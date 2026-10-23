// Pure payload builder. Call only after authoritative submission authorization.
export function submissionNotice(
  submissionId: string,
  submission: Record<string, unknown>,
  instructorId: string,
  createdAt: unknown,
) {
  return {
    userId: instructorId,
    type: "submission",
    sourceType: "assessmentReceived",
    sourceId: submissionId,
    courseId: submission.courseId,
    moduleId: submission.moduleId,
    actorId: submission.studentId,
    title: "New assessment submission",
    message: "A student submitted work. Open this notification to review it.",
    isRead: false,
    readAt: null,
    createdAt,
  };
}
