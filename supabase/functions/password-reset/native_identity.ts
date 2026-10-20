// Pure policy kept separate from Firebase so migration behavior can be tested.
export interface ResetIdentity {
  uid: string;
  email?: string;
  disabled: boolean;
}

export function resetIdentityAction(
  user: ResetIdentity,
  campusId: string,
  contactEmail: string,
  storedAuthEmail: unknown,
): "send" | "migrate" | "skip" {
  const actual = (user.email ?? "").trim().toLowerCase();
  const contact = contactEmail.trim().toLowerCase();
  if (user.disabled || !actual || !contact || contact.endsWith("@caslms.app")) {
    return "skip";
  }
  if (actual === contact) return "send";
  const legacy = `${campusId}@caslms.app`;
  // Only the expected legacy identity may be migrated. Never overwrite an
  // unrelated Auth email, even if the profile email has been edited.
  return actual === legacy &&
      String(storedAuthEmail ?? "").trim().toLowerCase() === legacy
    ? "migrate"
    : "skip";
}
