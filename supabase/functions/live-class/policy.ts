export const STUDENT_LIMIT = 30;
export const ROOM_LIMIT = STUDENT_LIMIT + 1;
type Data = Record<string, unknown>;

export function allowedAccount(profile: Data, token: Data): boolean {
  return profile.status === "active" &&
    (profile.emailVerificationRequired !== true ||
      (token.email_verified === true && token.email === profile.email));
}

export function canAttend(
  uid: string,
  profile: Data,
  token: Data,
  courseId: string,
  course: Data,
  enrollment: Data | undefined,
  sectionId: string,
): boolean {
  if (!allowedAccount(profile, token) || course.status !== "active") {
    return false;
  }
  if (profile.role === "instructor") return course.instructorId === uid;
  if (
    profile.role !== "student" || enrollment?.status !== "active" ||
    enrollment.studentId !== uid || enrollment.courseId !== courseId
  ) return false;
  const assigned = String(enrollment.sectionId ?? "").trim() ||
    course.classCode;
  return assigned === sectionId;
}

// Seats last for the session. This avoids concurrent join requests overbooking
// a room and lets the same student reconnect without consuming another place.
export function admitStudent(current: string[], uid: string): string[] {
  const ids = [...new Set(current)];
  if (ids.includes(uid)) return ids;
  if (ids.length >= STUDENT_LIMIT) throw new Error("CLASS_FULL");
  return [...ids, uid];
}
