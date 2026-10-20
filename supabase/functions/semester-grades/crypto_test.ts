import assert from "node:assert/strict";
import { decryptGrade, encryptGrade } from "./crypto.ts";
const secret = btoa(String.fromCharCode(...new Uint8Array(32).fill(42)));
Deno.test("grade ciphertext decrypts only under its authenticated owner/semester/revision context", async () => {
  const context = JSON.stringify(["doc", "self", "2026|1st", 1]);
  const encrypted = await encryptGrade(
    { grade: "1.75", result: "Passed" },
    secret,
    context,
  );
  assert.equal(JSON.stringify(encrypted).includes("1.75"), false);
  assert.deepEqual(await decryptGrade(encrypted, secret, context), {
    grade: "1.75",
    result: "Passed",
  });
  await assert.rejects(() =>
    decryptGrade(
      encrypted,
      secret,
      JSON.stringify(["doc", "other", "2026|1st", 1]),
    )
  );
  await assert.rejects(() =>
    decryptGrade(
      encrypted,
      secret,
      JSON.stringify(["doc", "self", "2026|1st", 2]),
    )
  );
  const tampered = {
    ...encrypted,
    ciphertext: encrypted.ciphertext.slice(0, -4) + "AAAA",
  };
  await assert.rejects(() => decryptGrade(tampered, secret, context));
});
Deno.test("encryption uses unique nonces and rejects invalid keys", async () => {
  const a = await encryptGrade({ grade: "INC" }, secret, "context");
  const b = await encryptGrade({ grade: "INC" }, secret, "context");
  assert.notEqual(a.iv, b.iv);
  assert.notEqual(a.ciphertext, b.ciphertext);
  await assert.rejects(() => encryptGrade({}, btoa("bad-key"), "context"));
});
