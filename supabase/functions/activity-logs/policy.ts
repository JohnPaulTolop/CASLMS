export const eventTypes = [
  "login",
  "logout",
  "course_created",
  "material_uploaded",
] as const;

export type EventType = typeof eventTypes[number];

export function eventType(value: unknown): EventType | null {
  const clean = String(value ?? "").trim();
  return eventTypes.includes(clean as EventType) ? clean as EventType : null;
}

export function targetId(value: unknown): string | null {
  const clean = String(value ?? "").trim();
  return clean.length > 0 && clean.length <= 200 &&
      /^[A-Za-z0-9_-]+$/.test(clean)
    ? clean
    : null;
}

export function isoTimestamp(value: unknown): string | null {
  if (value && typeof value === "object" && "toDate" in value) {
    const date = (value as { toDate(): Date }).toDate();
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  }
  if (typeof value === "string") {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date.toISOString();
  }
  return null;
}
