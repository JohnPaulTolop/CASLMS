import assert from "node:assert/strict";
import {
  activeAccount,
  compute,
  numericGrade,
  ownReveal,
  postedMetadata,
  taskDefinitions,
  weights,
} from "./engine.ts";
import type { ComputeOptions, Row, Task } from "./engine.ts";
const config: ComputeOptions = {
  weights: { activity: 0, quiz: 100, assignment: 0, unit_test: 0, exam: 0 },
  missing: "incomplete",
  acceptLegacyQuizScores: false,
};
const task = (id: string, max = 100, kind = "quiz"): Task => ({
  id,
  source: "assessments",
  parentKey: "assessmentId",
  category: kind as Task["category"],
  courseId: "course",
  sectionId: "A",
  max,
  dueMs: 0,
  title: id,
});
const result = (id: string, score: number, rest: Row = {}) => ({
  id: `result-${id}`,
  courseId: "course",
  studentId: "self",
  assessmentId: id,
  score,
  status: "graded",
  submittedAt: 100,
  ...rest,
});

Deno.test("every scale boundary is continuous without rounding up", () => {
  for (
    const [percent, grade] of [
      [100, "1.00"],
      [99, "1.00"],
      [98.999, "1.25"],
      [96, "1.25"],
      [95.999, "1.50"],
      [93, "1.50"],
      [92.999, "1.75"],
      [90, "1.75"],
      [89.999, "2.00"],
      [87, "2.00"],
      [86.999, "2.25"],
      [84, "2.25"],
      [83.999, "2.50"],
      [81, "2.50"],
      [80.999, "2.75"],
      [78, "2.75"],
      [77.999, "3.00"],
      [75, "3.00"],
      [74.999, "5.00"],
      [50, "5.00"],
    ] as const
  ) assert.equal(numericGrade(percent).grade, grade);
  for (const value of [NaN, Infinity, 49, 101]) {
    assert.throws(() => numericGrade(value));
  }
});
Deno.test("zero scores, fractional scores and the requested 50-base formula", () => {
  assert.equal(
    compute([task("q")], [result("q", 0)], "self", config).grade,
    "5.00",
  );
  assert.equal(
    compute([task("q")], [result("q", 50)], "self", config).percentage,
    75,
  );
  assert.equal(
    compute([task("q", 20)], [result("q", 17.5)], "self", config).percentage,
    93.75,
  );
  assert.equal(
    compute([task("q")], [result("q", 100)], "self", config).grade,
    "1.00",
  );
});
Deno.test("pool points within categories, then weight; never average item percentages blindly", () => {
  const policy = {
    ...config,
    weights: { activity: 0, quiz: 40, assignment: 0, unit_test: 0, exam: 60 },
  };
  const computed = compute(
    [task("small", 10), task("large", 90), task("exam", 100, "exam")],
    [result("small", 10), result("large", 45), result("exam", 80)],
    "self",
    policy,
  );
  assert.equal(computed.rawPercentage, 70);
  assert.equal(computed.percentage, 85);
  assert.equal(computed.grade, "2.25");
});
Deno.test("missing, ungraded, invalid and unreviewed legacy scores cannot silently become passing grades", () => {
  assert.equal(compute([task("q")], [], "self", config).grade, "INC");
  assert.equal(
    compute([task("q")], [], "self", { ...config, missing: "zero" }).grade,
    "5.00",
  );
  assert.equal(
    compute([task("q")], [result("q", 0, { status: "submitted" })], "self", {
      ...config,
      missing: "zero",
    }).grade,
    "INC",
  );
  for (const score of [-1, 101, NaN, Infinity]) {
    assert.equal(
      compute([task("q")], [result("q", score)], "self", config).grade,
      "INC",
    );
  }
  assert.equal(
    compute([task("q")], [result("q", 50, { totalPoints: 60 })], "self", config)
      .grade,
    "INC",
  );
  const legacy = { ...task("q"), source: "quizzes", parentKey: "quizId" };
  const attempt = result("q", 90, { quizId: "q", status: "submitted" });
  assert.equal(compute([legacy], [attempt], "self", config).grade, "INC");
  assert.equal(
    compute([legacy], [attempt], "self", {
      ...config,
      acceptLegacyQuizScores: true,
    }).grade,
    "1.50",
  );
  assert.equal(compute([], [], "self", config).grade, "INC");
});
Deno.test("do not include classmates or choose an older grade over a newer pending attempt", () => {
  assert.equal(
    compute(
      [task("q")],
      [result("q", 100, { studentId: "other" })],
      "self",
      config,
    ).grade,
    "INC",
  );
  assert.equal(
    compute(
      [task("q")],
      [
        result("q", 100),
        result("q", 0, { id: "new", submittedAt: 200, status: "submitted" }),
      ],
      "self",
      config,
    ).grade,
    "INC",
  );
});
Deno.test("course-wide and own-section work count once; summative maps to exam", () => {
  const definitions = {
    assessments: [{
      id: "a",
      courseId: "course",
      status: "published",
      assessmentType: "summative",
      totalPoints: 10,
      sectionId: "",
    }, {
      id: "b",
      courseId: "course",
      status: "published",
      assessmentType: "quiz",
      totalPoints: 20,
      sectionId: "A",
    }, {
      id: "other",
      courseId: "course",
      status: "published",
      assessmentType: "quiz",
      totalPoints: 20,
      sectionId: "B",
    }],
    quizzes: [{
      id: "legacy",
      assessmentId: "b",
      courseId: "course",
      status: "published",
      totalPoints: 20,
    }],
  };
  const tasks = taskDefinitions(definitions, "course", "A");
  assert.equal(tasks.length, 2);
  assert.equal(tasks[0].category, "exam");
  assert.throws(() =>
    taskDefinitions(
      {
        assessments: [{
          id: "broken",
          courseId: "course",
          status: "published",
          assessmentType: "quiz",
          totalPoints: 0,
        }],
      },
      "course",
      "A",
    )
  );
});
Deno.test("weights and special dispositions are explicit and validated", () => {
  assert.deepEqual(weights(config.weights), config.weights);
  assert.throws(() => weights({ ...config.weights, quiz: 99 }));
  assert.throws(() => weights({ ...config.weights, exam: NaN }));
  const dropped = compute([task("q")], [], "self", config, {
    code: "DRP",
    reason: "Approved withdrawal",
  });
  assert.equal(dropped.grade, "DRP");
  assert.equal(dropped.percentage, null);
  assert.equal(
    compute([task("q")], [], "self", config, {
      code: "INC",
      reason: "Pending requirement",
    }).grade,
    "INC",
  );
  assert.throws(() =>
    compute([task("q")], [], "self", config, { code: "DRP", reason: "" })
  );
});
Deno.test("posted metadata never contains grade values, ciphertext, classmates or raw percentages", () => {
  const subject = {
    courseId: "course",
    courseTitle: "IT",
    courseCode: "IT101",
    termId: "2026|1st",
    termLabel: "2026 1st",
  };
  const meta = postedMetadata(subject, {
    posted: true,
    revision: 2,
    grade: "1.75",
    percentage: 92.5,
    encrypted: { ciphertext: "secret" },
    studentId: "self",
  });
  assert.equal(meta.posted, true);
  for (
    const key of [
      "grade",
      "percentage",
      "encrypted",
      "studentId",
      "rawPercentage",
    ]
  ) assert.equal(key in meta, false);
  assert.equal(JSON.stringify(meta).includes("1.75"), false);
});
Deno.test("reveal is bound to caller UID and own Student ID; active verified profile required", () => {
  const profile = {
    role: "student",
    status: "active",
    universityId: "12345",
    email: "s@example.com",
    emailVerificationRequired: true,
  };
  assert.equal(
    activeAccount(profile, { email_verified: false, email: profile.email }),
    false,
  );
  assert.equal(
    activeAccount(profile, { email_verified: true, email: profile.email }),
    true,
  );
  assert.equal(
    activeAccount({ ...profile, status: "suspended" }, {
      email_verified: true,
      email: profile.email,
    }),
    false,
  );
  assert.equal(
    ownReveal(profile, "self", "12345", { studentId: "other", posted: true }),
    false,
  );
  assert.equal(
    ownReveal(profile, "self", "99999", { studentId: "self", posted: true }),
    false,
  );
  assert.equal(
    ownReveal(profile, "self", "12345", { studentId: "self", posted: false }),
    false,
  );
  assert.equal(
    ownReveal(profile, "self", "12345", { studentId: "self", posted: true }),
    true,
  );
});

Deno.test("Unit Tests have their own weight, points pool, and missing-work checks", () => {
  const unitTasks = taskDefinitions(
    {
      assessments: [{
        id: "unit-1",
        courseId: "course",
        sectionId: "A",
        status: "published",
        assessmentType: "unit_test",
        totalPoints: 100,
      }],
    },
    "course",
    "A",
  );
  assert.equal(unitTasks[0].category, "unit_test");
  const options: ComputeOptions = {
    ...config,
    weights: weights({
      activity: 0,
      quiz: 25,
      unit_test: 75,
      assignment: 0,
      exam: 0,
    }),
  };
  const tasks = [task("quiz-1"), ...unitTasks];
  const scores = [result("quiz-1", 50), result("unit-1", 100)];
  const grade = compute(tasks, scores, "self", options);
  assert.equal(grade.rawPercentage, 87.5);
  assert.equal(grade.percentage, 93.75);
  assert.equal(grade.grade, "1.50");
  assert.equal(
    grade.components.find((row) => row.category === "unit_test")?.earned,
    100,
  );
  assert.equal(compute(tasks, [scores[0]], "self", options).grade, "INC");
  assert.equal(
    compute(tasks, [scores[0]], "self", { ...options, missing: "zero" })
      .rawPercentage,
    12.5,
  );
  assert.throws(() => weights({ ...options.weights, unit_test: -1 }));
  assert.throws(() => weights({ ...options.weights, unit_test: NaN }));
  assert.throws(() => weights({ ...options.weights, unit_test: 80 }));
});

Deno.test("older four-category clients allocate zero to Unit Tests", () => {
  const legacy = { activity: 0, quiz: 100, assignment: 0, exam: 0 };
  assert.equal(weights(legacy).unit_test, 0);
  assert.equal(
    compute(
      [task("q"), task("unit", 100, "unit_test")],
      [result("q", 100)],
      "self",
      { ...config, weights: weights(legacy) },
    ).grade,
    "1.00",
  );
});
