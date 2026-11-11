export const learningMaterialsBucket = "caslms-learning-materials";

export function validMaterialStoragePath(
  path: string,
  courseId: string,
  moduleId: string,
  resourceId: string,
): boolean {
  const expectedPrefix =
    `courses/${courseId}/modules/${moduleId}/${resourceId}/`;
  return path.startsWith(expectedPrefix) &&
    !path.includes("..") &&
    !path.startsWith("/") &&
    !path.endsWith("/");
}

/// Extracts the object path from legacy public/signed Supabase URLs.
///
/// Only URLs belonging to this Supabase project and the configured learning
/// material bucket are accepted. The caller must still validate that the path
/// belongs to the requested course, module and material record.
export function legacyMaterialStoragePath(
  rawUrl: unknown,
  projectUrl: string,
  bucket = learningMaterialsBucket,
): string | null {
  const rawUrlText = String(rawUrl ?? "");
  try {
    const decodedUrlWithoutQuery =
      decodeURIComponent(rawUrlText).split(/[?#]/)[0];
    if (
      decodedUrlWithoutQuery.includes("\\") ||
      decodedUrlWithoutQuery.split("/").some((part) =>
        part === "." || part === ".."
      )
    ) {
      return null;
    }
  } catch (_) {
    return null;
  }

  let materialUrl: URL;
  let project: URL;
  try {
    materialUrl = new URL(rawUrlText);
    project = new URL(projectUrl);
  } catch (_) {
    return null;
  }

  if (materialUrl.origin !== project.origin) return null;

  const prefixes = [
    `/storage/v1/object/public/${bucket}/`,
    `/storage/v1/object/sign/${bucket}/`,
    `/storage/v1/object/${bucket}/`,
  ];
  const prefix = prefixes.find((candidate) =>
    materialUrl.pathname.startsWith(candidate)
  );
  if (!prefix) return null;

  let storagePath: string;
  try {
    storagePath = decodeURIComponent(materialUrl.pathname.slice(prefix.length));
  } catch (_) {
    return null;
  }

  if (
    !storagePath ||
    storagePath.includes("..") ||
    storagePath.startsWith("/") ||
    storagePath.endsWith("/") ||
    storagePath.includes("\\")
  ) {
    return null;
  }
  return storagePath;
}
