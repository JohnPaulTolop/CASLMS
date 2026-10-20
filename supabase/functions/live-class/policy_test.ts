import assert from "node:assert/strict";
import {
  admitStudent,
  allowedAccount,
  canAttend,
  ROOM_LIMIT,
  STUDENT_LIMIT,
} from "./policy.ts";

const course = {
  instructorId: "teacher",
  status: "active",
  classCode: "ORIGINAL",
};
const student = { role: "student", status: "active" };
const enrollment = {
  courseId: "course",
  studentId: "student",
  status: "active",
  sectionId: "A",
};

Deno.test("30 students plus one instructor; repeated joins retain one seat", () => {
  let ids: string[] = [];
  for (let i = 0; i < STUDENT_LIMIT; i++) ids = admitStudent(ids, `s${i}`);
  assert.equal(ids.length, 30);
  assert.equal(ROOM_LIMIT, 31);
  assert.throws(() => admitStudent(ids, "student31"), /CLASS_FULL/);
  assert.deepEqual(admitStudent(ids, "s0"), ids);
  assert.deepEqual(admitStudent(["s0", "s0"], "s0"), ["s0"]);
});
Deno.test("only enrolled students in the correct section and course owner can attend", () => {
  assert.equal(
    canAttend("student", student, {}, "course", course, enrollment, "A"),
    true,
  );
  assert.equal(
    canAttend("student", student, {}, "course", course, enrollment, "B"),
    false,
  );
  assert.equal(
    canAttend("student", student, {}, "different", course, enrollment, "A"),
    false,
  );
  assert.equal(
    canAttend("stranger", student, {}, "course", course, enrollment, "A"),
    false,
  );
  assert.equal(
    canAttend("student", student, {}, "course", course, undefined, "A"),
    false,
  );
  assert.equal(
    canAttend("student", student, {}, "course", course, {
      ...enrollment,
      status: "inactive",
    }, "A"),
    false,
  );
  assert.equal(
    canAttend(
      "teacher",
      { role: "instructor", status: "active" },
      {},
      "course",
      course,
      undefined,
      "A",
    ),
    true,
  );
  assert.equal(
    canAttend(
      "other",
      { role: "instructor", status: "active" },
      {},
      "course",
      course,
      undefined,
      "A",
    ),
    false,
  );
});
Deno.test("legacy membership falls back to original section, and verification cannot be bypassed", () => {
  assert.equal(
    canAttend("student", student, {}, "course", course, {
      ...enrollment,
      sectionId: "",
    }, "ORIGINAL"),
    true,
  );
  assert.equal(
    canAttend("student", student, {}, "course", course, {
      ...enrollment,
      sectionId: "",
    }, "A"),
    false,
  );
  assert.equal(
    allowedAccount({ ...student, status: "pending_verification" }, {}),
    false,
  );
  assert.equal(allowedAccount({ ...student, status: "suspended" }, {}), false);
  const verified = {
    ...student,
    emailVerificationRequired: true,
    email: "student@example.com",
  };
  assert.equal(
    allowedAccount(verified, { email_verified: false, email: verified.email }),
    false,
  );
  assert.equal(
    allowedAccount(verified, {
      email_verified: true,
      email: "other@example.com",
    }),
    false,
  );
  assert.equal(
    allowedAccount(verified, { email_verified: true, email: verified.email }),
    true,
  );
});
