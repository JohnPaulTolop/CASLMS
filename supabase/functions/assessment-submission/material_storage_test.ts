import {
  learningMaterialsBucket,
  legacyMaterialStoragePath,
  validMaterialStoragePath,
} from "./material_storage.ts";

function assertEquals(actual: unknown, expected: unknown, label: string) {
  if (actual !== expected) {
    throw new Error(
      `${label}: expected ${String(expected)}, got ${String(actual)}`,
    );
  }
}

const projectUrl = "https://example-project.supabase.co";
const objectPath = "courses/course-1/modules/module-1/resource-1/lesson.pdf";

Deno.test("extracts a legacy public learning-material path", () => {
  assertEquals(
    legacyMaterialStoragePath(
      `${projectUrl}/storage/v1/object/public/${learningMaterialsBucket}/${objectPath}`,
      projectUrl,
    ),
    objectPath,
    "public URL",
  );
});

Deno.test("extracts a legacy signed learning-material path", () => {
  assertEquals(
    legacyMaterialStoragePath(
      `${projectUrl}/storage/v1/object/sign/${learningMaterialsBucket}/${objectPath}?token=temporary`,
      projectUrl,
    ),
    objectPath,
    "signed URL",
  );
});

Deno.test("rejects URLs outside the configured project or bucket", () => {
  assertEquals(
    legacyMaterialStoragePath(
      `https://attacker.example/storage/v1/object/public/${learningMaterialsBucket}/${objectPath}`,
      projectUrl,
    ),
    null,
    "foreign origin",
  );
  assertEquals(
    legacyMaterialStoragePath(
      `${projectUrl}/storage/v1/object/public/another-bucket/${objectPath}`,
      projectUrl,
    ),
    null,
    "wrong bucket",
  );
});

Deno.test("rejects traversal and validates the record-owned object prefix", () => {
  assertEquals(
    legacyMaterialStoragePath(
      `${projectUrl}/storage/v1/object/public/${learningMaterialsBucket}/courses/course-1/%2E%2E/private.pdf`,
      projectUrl,
    ),
    null,
    "path traversal",
  );
  assertEquals(
    validMaterialStoragePath(
      objectPath,
      "course-1",
      "module-1",
      "resource-1",
    ),
    true,
    "owned path",
  );
  assertEquals(
    validMaterialStoragePath(
      objectPath,
      "course-2",
      "module-1",
      "resource-1",
    ),
    false,
    "another course",
  );
});
