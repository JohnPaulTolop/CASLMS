import assert from "node:assert/strict";
import { admitStudent } from "./policy.ts";

// Opt-in integration test. Never uses live credentials or a production project.
const host = Deno.env.get("FIRESTORE_EMULATOR_HOST");
Deno.test({
  name: "concurrent admissions cannot take a 31st student place",
  ignore: !host,
  async fn() {
    assert.match(host!, /^(127\.0\.0\.1|localhost):\d+$/);
    const database = "projects/demo-caslms-school-check/databases/(default)";
    const root = `http://${host}/v1/${database}/documents`;
    const documentId = `capacity-${crypto.randomUUID()}`;
    const name = `${database}/documents/liveClasses/${documentId}`;
    const documentUrl = `${root}/liveClasses/${documentId}`;
    const headers = {
      Authorization: "Bearer owner",
      "Content-Type": "application/json",
    };
    const fields = (ids: string[]) => ({
      studentIds: {
        arrayValue: { values: ids.map((id) => ({ stringValue: id })) },
      },
    });
    const post = async (suffix: string, body: unknown) =>
      await fetch(root + suffix, {
        method: "POST",
        headers,
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(10000),
      });
    try {
      // Two concurrent callers race for the final place, while an existing
      // student also reconnects. Optimistic transactional commits exercise the
      // same read/admit/retry decision used by the backend SDK transaction.
      const seeded = await fetch(documentUrl, {
        method: "PATCH",
        headers,
        body: JSON.stringify({
          fields: fields(Array.from({ length: 29 }, (_, i) => `s${i}`)),
        }),
      });
      assert.equal(seeded.status, 200);
      await seeded.text();
      async function join(uid: string) {
        for (let attempt = 0; attempt < 10; attempt++) {
          const read = await fetch(
            documentUrl,
            { headers, signal: AbortSignal.timeout(10000) },
          );
          const state = await read.json();
          let ids: string[];
          try {
            ids = admitStudent(
              state.fields.studentIds.arrayValue.values.map((
                entry: { stringValue: string },
              ) => entry.stringValue),
              uid,
            );
          } catch (error) {
            throw error;
          }
          const result = await post(":commit", {
            writes: [{
              update: { name, fields: fields(ids) },
              currentDocument: { updateTime: state.updateTime },
            }],
          });
          const details = await result.text();
          if (result.ok) return;
          if (![409, 400].includes(result.status)) throw new Error(details);
        }
        throw new Error("Transaction retries exhausted");
      }
      const results = await Promise.allSettled([
        join("new-a"),
        join("new-b"),
        join("s0"),
      ]);
      assert.equal(
        results.filter((result) => result.status === "fulfilled").length,
        2,
      );
      const failed = results.find((result) =>
        result.status === "rejected"
      ) as PromiseRejectedResult;
      assert.match(String(failed.reason), /CLASS_FULL/);
      const saved = await (await fetch(documentUrl, { headers }))
        .json();
      const ids = saved.fields.studentIds.arrayValue.values.map((
        entry: { stringValue: string },
      ) => entry.stringValue);
      assert.equal(ids.length, 30);
      assert.equal(new Set(ids).size, 30);
    } finally {
      const removed = await fetch(documentUrl, {
        method: "DELETE",
        headers,
      });
      await removed.text();
    }
  },
});
