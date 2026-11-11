import { eventType, isoTimestamp, targetId } from "./policy.ts";

function assertEquals(actual: unknown, expected: unknown) {
  if (!Object.is(actual, expected)) {
    throw new Error(`Expected ${String(expected)}, received ${String(actual)}`);
  }
}

Deno.test("event types are allow-listed", () => {
  assertEquals(eventType("login"), "login");
  assertEquals(eventType("material_uploaded"), "material_uploaded");
  assertEquals(eventType("delete_user"), null);
});

Deno.test("target IDs reject paths and unsafe values", () => {
  assertEquals(targetId("course_123-A"), "course_123-A");
  assertEquals(targetId("courses/123"), null);
  assertEquals(targetId(""), null);
});

Deno.test("timestamps serialize consistently", () => {
  assertEquals(
    isoTimestamp(new Date("2026-11-11T00:00:00.000Z")),
    "2026-11-11T00:00:00.000Z",
  );
  assertEquals(isoTimestamp("not-a-date"), null);
});
