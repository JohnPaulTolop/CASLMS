export type Row = Record<string, any>;
export const CATEGORIES = ["activity", "quiz", "assignment", "exam"] as const;
export type Category = typeof CATEGORIES[number];
export type Weights = Record<Category, number>;
export const POLICY_VERSION = "ssu-configured-50-base-v1";
export function text(value: unknown) {
  return String(value ?? "").trim();
}
export function category(value: unknown): Category {
  const type = text(value).toLowerCase();
  if (type === "summative") return "exam";
  if (!CATEGORIES.includes(type as Category)) {
    throw new Error(
      "Unknown activity type. Correct it before computing grades.",
    );
  }
  return type as Category;
}
export function weights(value: unknown): Weights {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Enter category weights totaling 100%.");
  }
  const input = value as Row;
  if (Object.keys(input).some((key) => !CATEGORIES.includes(key as Category))) {
    throw new Error("Unknown grading category.");
  }
  const result = {} as Weights;
  for (const key of CATEGORIES) {
    if (
      typeof input[key] !== "number" || !Number.isFinite(input[key]) ||
      input[key] < 0 || input[key] > 100
    ) throw new Error("Each category weight must be between 0 and 100.");
    result[key] = input[key];
  }
  if (
    Math.abs(Object.values(result).reduce((sum, n) => sum + n, 0) - 100) >
      0.000001
  ) throw new Error("Category weights must total 100%.");
  return result;
}
export function numericGrade(percentage: number) {
  if (!Number.isFinite(percentage) || percentage < 50 || percentage > 100) {
    throw new Error("Invalid transmuted percentage.");
  }
  for (
    const [threshold, grade, description] of [
      [99, "1.00", "Excellent"],
      [96, "1.25", ""],
      [93, "1.50", "Very Good"],
      [90, "1.75", ""],
      [87, "2.00", "Good"],
      [84, "2.25", ""],
      [81, "2.50", "Satisfactory"],
      [78, "2.75", ""],
      [75, "3.00", "Passed"],
    ] as const
  ) {
    if (percentage >= threshold) {
      return { grade, description, result: "Passed" };
    }
  }
  return { grade: "5.00", description: "Failed", result: "Failed" };
}
export interface Task {
  id: string;
  source: string;
  parentKey: string;
  category: Category;
  title: string;
  courseId: string;
  sectionId: string;
  max: number;
  dueMs: number;
}
export function time(value: any): number {
  if (value?.toMillis) return value.toMillis();
  if (typeof value === "number") return value;
  const parsed = Date.parse(value ?? "");
  return Number.isFinite(parsed) ? parsed : 0;
}
export function taskDefinitions(
  definitions: Record<string, Row[]>,
  courseId: string,
  sectionId?: string,
): Task[] {
  const modern = new Set(
    (definitions.assessments ?? []).filter((row) => row.courseId === courseId)
      .map((row) => row.id),
  );
  const tasks: Task[] = [];
  for (
    const [source, parentKey, fallback] of [
      ["assessments", "assessmentId", "activity"],
      ["assignments", "assignmentId", "assignment"],
      ["quizzes", "quizId", "quiz"],
    ]
  ) {
    for (const row of definitions[source] ?? []) {
      if (
        row.courseId !== courseId ||
        !["published", "closed"].includes(row.status)
      ) continue;
      if (
        source !== "assessments" && modern.has(text(row.assessmentId))
      ) continue;
      const assigned = text(row.sectionId);
      if (
        sectionId !== undefined && assigned && assigned !== sectionId
      ) continue;
      const max = row.totalPoints ?? row.points;
      if (typeof max !== "number" || !Number.isFinite(max) || max <= 0) {
        throw new Error(
          `Set positive total points for ${text(row.title) || row.id}.`,
        );
      }
      tasks.push({
        id: row.id,
        source,
        parentKey,
        category: category(row.assessmentType || fallback),
        title: text(row.title) || "Untitled activity",
        courseId,
        sectionId: assigned,
        max,
        dueMs: time(row.dueDate ?? row.deadline),
      });
    }
  }
  return tasks.sort((a, b) =>
    `${a.source}/${a.id}`.localeCompare(`${b.source}/${b.id}`)
  );
}
export function latestResult(
  task: Task,
  results: Row[],
  studentId: string,
): Row | undefined {
  return results.filter((row) =>
    row.studentId === studentId && row.courseId === task.courseId &&
    row[task.parentKey] === task.id &&
    !["in_progress", "draft", "not_complied"].includes(text(row.status))
  )
    .sort((a, b) =>
      time(b.submittedAt ?? b.gradedAt) - time(a.submittedAt ?? a.gradedAt) ||
      text(a.id).localeCompare(text(b.id))
    )[0];
}
export function scored(
  task: Task,
  row: Row | undefined,
  acceptLegacyQuizScores: boolean,
): boolean {
  if (
    !row ||
    (row.status !== "graded" &&
      !(task.source === "quizzes" && row.status === "submitted" &&
        acceptLegacyQuizScores))
  ) return false;
  if (row.totalPoints != null && row.totalPoints !== task.max) return false;
  return typeof row.score === "number" && Number.isFinite(row.score) &&
    row.score >= 0 && row.score <= task.max;
}
export interface ComputeOptions {
  weights: Weights;
  missing: "incomplete" | "zero";
  acceptLegacyQuizScores: boolean;
}
export function compute(
  tasks: Task[],
  results: Row[],
  studentId: string,
  options: ComputeOptions,
  disposition?: Row,
) {
  if (disposition && !["INC", "DRP"].includes(disposition.code)) {
    throw new Error("Invalid student disposition.");
  }
  if (
    disposition &&
    (typeof disposition.reason !== "string" || !disposition.reason.trim() ||
      disposition.reason.length > 500)
  ) throw new Error("Enter a reason for INC or DRP.");
  const components = CATEGORIES.map((key) => ({
    category: key,
    weight: options.weights[key],
    earned: 0,
    max: 0,
    graded: 0,
    required: 0,
  }));
  const issues: string[] = [];
  for (const task of tasks) {
    const component = components.find((row) => row.category === task.category)!;
    if (!component.weight) continue;
    component.required++;
    component.max += task.max;
    const result = latestResult(task, results, studentId);
    if (scored(task, result, options.acceptLegacyQuizScores)) {
      component.earned += result!.score;
      component.graded++;
    } else if (result || options.missing === "incomplete") {
      issues.push(
        `${task.title}: ${
          result ? "pending grade or instructor review" : "no submission"
        }`,
      );
    }
  }
  for (const row of components) {
    if (row.weight > 0 && row.max === 0) {
      issues.push(
        `${row.category}: no graded-work definitions; set its weight to zero or add work`,
      );
    }
  }
  if (disposition || issues.length) {
    return {
      grade: disposition?.code ?? "INC",
      result: disposition?.code === "DRP" ? "Dropped" : "Incomplete",
      description: disposition?.reason ?? "Unfinished grading requirements",
      percentage: null,
      rawPercentage: null,
      components,
      issues,
    };
  }
  const raw = components.reduce(
    (sum, row) =>
      sum + (row.weight > 0 ? row.earned / row.max * row.weight : 0),
    0,
  );
  const percentage = Math.max(50, Math.min(100, raw * 0.5 + 50));
  return {
    ...numericGrade(percentage),
    percentage,
    rawPercentage: raw,
    components,
    issues,
  };
}
export function term(course: Row) {
  const academicYear = text(course.academicYear);
  const semester = text(course.semester);
  return {
    academicYear,
    semester,
    termId: `${academicYear}|${semester}`,
    termLabel: `${academicYear} · ${semester}`,
  };
}
export function activeAccount(profile: Row, token: Row) {
  return profile.status === "active" &&
    (profile.emailVerificationRequired !== true ||
      (token.email_verified === true && token.email === profile.email));
}
export function ownReveal(
  profile: Row,
  actorUid: string,
  requestedCampusId: string,
  grade: Row,
) {
  return profile.role === "student" &&
    text(profile.universityId) === requestedCampusId.replace(/\s+/g, "") &&
    grade.studentId === actorUid && grade.posted === true;
}

export function postedMetadata(subject: Row, grade: Row | undefined) {
  return {
    courseId: subject.courseId,
    courseTitle: subject.courseTitle,
    courseCode: subject.courseCode,
    termId: subject.termId,
    termLabel: subject.termLabel,
    posted: grade?.posted === true,
    revision: Number(grade?.revision ?? 0),
    postedAt: grade?.postedAt?.toDate?.().toISOString() ?? null,
  };
}
