import { mayActivate, maySyncVerifiedEmail, validProgram } from "./policy.ts";
import catalog from "../_shared/academic_catalog.json" with { type: "json" };
function check(value: boolean, message: string) {
  if (!value) throw new Error(message);
}
Deno.test("email sync requires matching verified Auth and token ownership for an active student", () => {
  const profile = {
    uid: "student",
    role: "student",
    status: "active",
    email: "old@example.com",
  };
  const allowed = (
    patch = {},
    email = "new@example.com",
    verified = true,
    tokenEmail: unknown = email,
    tokenVerified = true,
  ) =>
    maySyncVerifiedEmail(
      { ...profile, ...patch },
      "student",
      email,
      verified,
      tokenEmail,
      tokenVerified,
    );
  check(allowed(), "Verified new email rejected");
  check(
    !allowed({}, "new@example.com", false),
    "Unverified Auth email accepted",
  );
  check(
    !allowed({}, "new@example.com", true, "old@example.com"),
    "Stale token accepted",
  );
  check(
    !allowed({}, "new@example.com", true, "new@example.com", false),
    "Unverified token accepted",
  );
  check(!allowed({ uid: "other" }), "Other account accepted");
  check(!allowed({ role: "instructor" }), "Instructor accepted");
  for (
    const status of ["pending_verification", "suspended", "denied", "inactive"]
  ) {
    check(!allowed({ status }), `Forbidden account state accepted: ${status}`);
  }
  check(!allowed({}, "12345@caslms.app"), "Synthetic login alias accepted");
  check(!allowed({}, "broken"), "Malformed email accepted");
});
Deno.test("every supplied department/program pairing is accepted, cross-department values are rejected", () => {
  for (const [department, programs] of Object.entries(catalog)) {
    for (const program of programs) {
      check(validProgram(department, program), "Missing valid mapping");
    }
  }
  check(
    !validProgram("College of Arts and Sciences (CAS)", "BSN"),
    "Wrong department accepted",
  );
  check(
    !validProgram("", "BSIT") && !validProgram("Unknown", "BSIT"),
    "Unknown college accepted",
  );
  check(
    Object.keys(catalog).length === 1 &&
      catalog["College of Arts and Sciences (CAS)"].length === 4,
    "Registration must offer only the four CAS programs",
  );
  for (
    const [department, program] of [
      ["College of Education (COED)", "BEEd"],
      ["College of Engineering (COENG)", "BSCE"],
      ["College of Nursing and Health Sciences (CONHS)", "BSN"],
      ["College of Industrial Technology (CIT)", "BS in Architecture"],
    ]
  ) {
    check(!validProgram(department, program), "Non-CAS registration accepted");
  }
});
Deno.test("activation requires real email ownership and the dedicated pending student state", () => {
  const profile = {
    role: "student",
    status: "pending_verification",
    emailVerificationRequired: true,
    email: "student@example.com",
    authEmail: "student@example.com",
  };
  check(
    mayActivate(profile, "student@example.com", true),
    "Verified student rejected",
  );
  check(
    !mayActivate(profile, "student@example.com", false),
    "Unverified student activated",
  );
  check(
    !mayActivate(profile, "attacker@example.com", true),
    "Mismatched email activated",
  );
  for (const status of ["suspended", "denied", "inactive"]) {
    check(
      !mayActivate({ ...profile, status }, "student@example.com", true),
      "Disabled state reactivated",
    );
  }
  check(
    !mayActivate(
      { ...profile, role: "instructor" },
      "student@example.com",
      true,
    ),
    "Instructor self-approved",
  );
  check(
    !mayActivate(
      { ...profile, emailVerificationRequired: false },
      "student@example.com",
      true,
    ),
    "Legacy account modified",
  );
  check(
    !mayActivate(
      { ...profile, authEmail: "12345@caslms.app" },
      "student@example.com",
      true,
    ),
    "Alias treated as verified contact",
  );
});
