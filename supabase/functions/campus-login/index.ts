import { cert, getApps, initializeApp } from "npm:firebase-admin@13.4.0/app";
import { getAppCheck } from "npm:firebase-admin@13.4.0/app-check";
import { getAuth } from "npm:firebase-admin@13.4.0/auth";
import { getFirestore } from "npm:firebase-admin@13.4.0/firestore";
import { verifyCampusPassword } from "./verify_password.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info, x-firebase-appcheck",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const failure = "Incorrect ID number or password.";
function reply(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
function secret(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing environment secret: ${name}`);
  return value;
}
const account = JSON.parse(secret("FIREBASE_SERVICE_ACCOUNT_JSON"));
account.private_key = account.private_key.replace(/\\n/g, "\n");
const app = getApps()[0] ?? initializeApp({ credential: cert(account) });
const auth = getAuth(app);
const db = getFirestore(app);
db.settings({ preferRest: true });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return reply({ error: "Method not allowed." }, 405);
  }
  const appCheckToken = request.headers.get("X-Firebase-AppCheck") ?? "";
  try {
    await getAppCheck(app).verifyToken(appCheckToken);
  } catch {
    return reply({ error: "CASLMS could not verify this application." }, 401);
  }
  let body: Record<string, unknown>;
  try {
    body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new Error();
    }
  } catch {
    return reply({ error: "Invalid request body." }, 400);
  }
  const campusId = String(body.campusId ?? "").replace(/\s+/g, "");
  const password = body.password;
  if (
    !/^\d{5,12}$/.test(campusId) || typeof password !== "string" ||
    !password || password.length > 4096
  ) return reply({ error: failure }, 400);

  try {
    // The lookup is server-only. Do not return the contact email to the client.
    const attemptRef = db.collection("campusLoginAttempts").doc(campusId);
    const allowed = await db.runTransaction(async (transaction) => {
      const data = (await transaction.get(attemptRef)).data();
      const now = Date.now();
      const inWindow = Number(data?.expiresAtMs ?? 0) > now;
      const count = inWindow ? Number(data?.count ?? 0) : 0;
      if (count >= 10) return false;
      transaction.set(attemptRef, {
        count: count + 1,
        expiresAtMs: inWindow ? data!.expiresAtMs : now + 600_000,
      });
      return true;
    });
    if (!allowed) {
      return reply({ error: "Too many login attempts. Try again later." }, 429);
    }

    const profiles = await db.collection("users")
      .where("universityId", "==", campusId).limit(2).get();
    if (profiles.size !== 1) return reply({ error: failure }, 400);
    const profile = profiles.docs[0];
    const user = await auth.getUser(profile.id);
    if (user.disabled || !user.email) return reply({ error: failure }, 400);

    // Verify the supplied password with Firebase before minting a session.
    if (
      !(await verifyCampusPassword(
        profile.id,
        user.email,
        password,
        secret("FIREBASE_WEB_API_KEY"),
        appCheckToken,
      ))
    ) {
      return reply({ error: failure }, 400);
    }
    const customToken = await auth.createCustomToken(profile.id);
    await attemptRef.delete();
    return reply({ customToken });
  } catch (error) {
    // Never log passwords, emails, tokens, or raw Firebase error responses.
    const code = typeof error === "object" && error !== null && "code" in error
      ? String(error.code)
      : "internal";
    console.error("Campus login failed:", code);
    return reply(
      { error: "Unable to sign in right now. Please try again." },
      503,
    );
  }
});
