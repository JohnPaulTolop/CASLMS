import { verifyCampusPassword } from "./verify_password.ts";

function mock(body: unknown, status = 200): typeof fetch {
  return (() =>
    Promise.resolve(
      new Response(JSON.stringify(body), { status }),
    )) as typeof fetch;
}
async function verify(send: typeof fetch) {
  return await verifyCampusPassword(
    "original-uid",
    "contact@example.com",
    "test-password",
    "test-key",
    "test-appcheck",
    send,
  );
}
Deno.test("reject incorrect password, different UID, and incomplete MFA", async () => {
  for (
    const send of [
      mock({ error: {} }, 400),
      mock({ localId: "wrong-uid" }),
      mock({ localId: "original-uid", mfaPendingCredential: "pending" }),
      mock({}),
    ]
  ) {
    if (await verify(send)) {
      throw new Error("An unverified identity was accepted");
    }
  }
});
Deno.test("verify against Firebase with the real email and forward App Check", async () => {
  const send = ((url, options) => {
    const endpoint = new URL(String(url));
    const headers = new Headers(options?.headers);
    const body = JSON.parse(String(options?.body));
    if (
      endpoint.hostname !== "identitytoolkit.googleapis.com" ||
      headers.get("X-Firebase-AppCheck") !== "test-appcheck" ||
      body.email !== "contact@example.com" || body.password !== "test-password"
    ) {
      throw new Error("Incorrect Firebase credential request");
    }
    return Promise.resolve(
      new Response(JSON.stringify({ localId: "original-uid" })),
    );
  }) as typeof fetch;
  if (!(await verify(send))) throw new Error("Valid identity was rejected");
});
