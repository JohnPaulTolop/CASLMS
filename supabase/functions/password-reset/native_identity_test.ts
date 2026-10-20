import { type ResetIdentity, resetIdentityAction } from "./native_identity.ts";

const legacy: ResetIdentity = {
  uid: "same-uid",
  email: "12345@caslms.app",
  disabled: false,
};
function equal(actual: unknown, expected: unknown) {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, received ${actual}`);
  }
}
Deno.test("only the campus ID's existing synthetic identity can migrate", () => {
  equal(
    resetIdentityAction(legacy, "12345", "student@example.com", legacy.email),
    "migrate",
  );
  equal(
    resetIdentityAction(legacy, "99999", "student@example.com", legacy.email),
    "skip",
  );
  equal(
    resetIdentityAction(
      legacy,
      "12345",
      "student@example.com",
      "other@caslms.app",
    ),
    "skip",
  );
});
Deno.test("retry after migration sends without rewriting the Auth identity", () => {
  equal(
    resetIdentityAction(
      { ...legacy, email: "Student@Example.com" },
      "12345",
      "student@example.com",
      legacy.email,
    ),
    "send",
  );
});
Deno.test("disabled, missing and unrelated identities cannot migrate", () => {
  equal(
    resetIdentityAction(
      { ...legacy, disabled: true },
      "12345",
      "student@example.com",
      legacy.email,
    ),
    "skip",
  );
  equal(
    resetIdentityAction(
      { ...legacy, email: undefined },
      "12345",
      "student@example.com",
      legacy.email,
    ),
    "skip",
  );
  equal(
    resetIdentityAction(
      { ...legacy, email: "another@example.com" },
      "12345",
      "student@example.com",
      legacy.email,
    ),
    "skip",
  );
});
Deno.test("never send to an internal campus alias", () => {
  equal(
    resetIdentityAction(legacy, "12345", legacy.email!, legacy.email),
    "skip",
  );
});
