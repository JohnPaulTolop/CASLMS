import programs from "../_shared/academic_catalog.json" with { type: "json" };
export function validProgram(department: string, program: string): boolean {
  return (programs as Record<string, string[]>)[department]?.includes(
    program,
  ) ?? false;
}
export function mayActivate(
  profile: Record<string, unknown>,
  email: string,
  verified: boolean,
): boolean {
  return profile.role === "student" &&
    profile.emailVerificationRequired === true &&
    ["pending_verification", "active"].includes(String(profile.status)) &&
    profile.email === email && profile.authEmail === email && verified;
}

// The document is loaded by the verified caller UID, never by a submitted ID.
// A changed contact address must come from fresh Firebase Auth ownership proof.
export function maySyncVerifiedEmail(
  profile: Record<string, unknown>,
  uid: string,
  email: string,
  authVerified: boolean,
  tokenEmail: unknown,
  tokenVerified: boolean,
): boolean {
  return profile.role === "student" && profile.status === "active" &&
    (!profile.uid || profile.uid === uid) &&
    /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) &&
    !email.endsWith("@caslms.app") &&
    authVerified && tokenVerified && tokenEmail === email;
}
