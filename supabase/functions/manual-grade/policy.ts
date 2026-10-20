export function validScore(score: unknown, total: unknown): score is number {
  return typeof score === "number" && Number.isFinite(score) &&
    typeof total === "number" && Number.isFinite(total) &&
    total > 0 && score >= 0 && score <= total;
}
export function matchesSection(
  assessmentSection: unknown,
  enrollmentSection: unknown,
  originalCode: unknown,
): boolean {
  const section = String(assessmentSection ?? "").trim();
  return !section ||
    section ===
      (String(enrollmentSection ?? "").trim() ||
        String(originalCode ?? "").trim());
}

export function canGradeEnrollment(
  actor: string,
  assessment: Record<string, unknown>,
  course: Record<string, unknown>,
  enrollment: Record<string, unknown> | undefined,
  student: Record<string, unknown> | undefined,
  studentId: string,
): boolean {
  return course.instructorId === actor && enrollment?.status === "active" &&
    enrollment.studentId === studentId &&
    enrollment.courseId === assessment.courseId &&
    student?.role === "student" && student.status === "active" &&
    matchesSection(
      assessment.sectionId,
      enrollment.sectionId,
      course.classCode,
    );
}
