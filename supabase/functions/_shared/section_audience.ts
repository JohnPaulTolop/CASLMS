/** Section audiences are intersections: a child can narrow, never widen, its module. */
export function audience(value: unknown): string[] {
  if (
    !Array.isArray(value) || value.length === 0 || value.length > 50 ||
    value.some((id) =>
      typeof id !== "string" || !id.trim() || id !== id.trim() ||
      id.includes("/")
    ) ||
    new Set(value).size !== value.length ||
    (value.includes("*") && value.length !== 1)
  ) {
    throw new Error("Invalid section audience.");
  }
  return [...value] as string[];
}

export function storedAudience(record: Record<string, unknown>): string[] {
  // Only missing fields are legacy. Malformed or empty stored fields fail closed.
  return Object.hasOwn(record, "sectionIds")
    ? audience(record.sectionIds)
    : ["*"];
}

export function allowsSection(ids: string[], section: string): boolean {
  return !!section && (ids.includes("*") || ids.includes(section));
}

export function assertChildAudience(parent: string[], child: string[]): void {
  if (
    !parent.includes("*") &&
    (child.includes("*") || child.some((id) => !parent.includes(id)))
  ) {
    throw new Error("Content cannot be shared outside its module sections.");
  }
}

export function assertActiveSections(
  ids: string[],
  courseId: string,
  sections: Array<{ id: string; courseId: string; status: string }>,
): void {
  if (ids.includes("*")) return;
  if (
    ids.some((id) =>
      !sections.some((s) =>
        s.id === id && s.courseId === courseId && s.status === "active"
      )
    )
  ) {
    throw new Error("Choose active sections belonging to this course.");
  }
}

export function canAccessSectionContent(input: {
  studentId: string;
  courseId: string;
  moduleId: string;
  enrollment: Record<string, unknown>;
  module: Record<string, unknown>;
  child?: Record<string, unknown>;
}): boolean {
  try {
    const { studentId, courseId, moduleId, enrollment, module, child } = input;
    const section = typeof enrollment.sectionId === "string"
      ? enrollment.sectionId
      : "";
    if (
      !studentId || !courseId || !moduleId ||
      enrollment.studentId !== studentId || enrollment.courseId !== courseId ||
      enrollment.status !== "active" || module.courseId !== courseId ||
      module.status !== "published" ||
      !allowsSection(storedAudience(module), section)
    ) return false;
    if (!child) return true;
    if (
      child.courseId !== courseId || child.moduleId !== moduleId ||
      !["published", "closed"].includes(String(child.status)) ||
      !allowsSection(storedAudience(child), section)
    ) return false;
    // Preserve the existing AI quiz single-section restriction as an additional intersection.
    return !child.sectionId || child.sectionId === section;
  } catch (_) {
    return false;
  }
}
