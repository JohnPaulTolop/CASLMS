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
