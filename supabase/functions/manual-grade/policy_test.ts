import { canGradeEnrollment, matchesSection, validScore } from "./policy.ts";
function check(value: boolean, message: string) {
  if (!value) throw new Error(message);
}
Deno.test("manual grades accept zero/fractions and reject invalid score limits", () => {
  check(
    validScore(0, 20) && validScore(17.5, 20) && validScore(20, 20),
    "Valid score rejected",
  );
  for (const score of [-1, 20.01, NaN, Infinity, "10", null]) {
    check(!validScore(score, 20), "Invalid score accepted");
  }
  check(
    !validScore(0, 0) && !validScore(2, Infinity),
    "Invalid maximum accepted",
  );
});
Deno.test("manual grades require course ownership, active student and matching enrollment/section", () => {
  const assessment = { courseId: "course", sectionId: "A" };
  const course = { instructorId: "teacher", classCode: "ORIGINAL" };
  const enrollment = {
    courseId: "course",
    studentId: "student",
    status: "active",
    sectionId: "A",
  };
  const student = { role: "student", status: "active" };
  check(
    canGradeEnrollment(
      "teacher",
      assessment,
      course,
      enrollment,
      student,
      "student",
    ),
    "Valid teacher rejected",
  );
  check(
    !canGradeEnrollment(
      "other",
      assessment,
      course,
      enrollment,
      student,
      "student",
    ),
    "Other teacher accepted",
  );
  check(
    !canGradeEnrollment(
      "teacher",
      assessment,
      course,
      { ...enrollment, sectionId: "B" },
      student,
      "student",
    ),
    "Wrong section accepted",
  );
  check(
    !canGradeEnrollment(
      "teacher",
      assessment,
      course,
      { ...enrollment, courseId: "other" },
      student,
      "student",
    ),
    "Wrong course accepted",
  );
  check(
    !canGradeEnrollment(
      "teacher",
      assessment,
      course,
      { ...enrollment, status: "inactive" },
      student,
      "student",
    ),
    "Inactive enrollment accepted",
  );
  check(
    !canGradeEnrollment("teacher", assessment, course, enrollment, {
      ...student,
      status: "pending_verification",
    }, "student"),
    "Pending student accepted",
  );
  check(
    !canGradeEnrollment(
      "teacher",
      assessment,
      course,
      enrollment,
      student,
      "someone-else",
    ),
    "Wrong student accepted",
  );
});
Deno.test("course-wide assessments and legacy original sections retain their scope", () => {
  check(matchesSection("", "A", "ORIGINAL"), "Course-wide assessment rejected");
  check(
    matchesSection("ORIGINAL", undefined, "ORIGINAL"),
    "Legacy member rejected",
  );
  check(
    !matchesSection("A", undefined, "ORIGINAL"),
    "Legacy member leaked into new section",
  );
});
