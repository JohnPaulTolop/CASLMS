import { cert, getApps, initializeApp } from "npm:firebase-admin@13.4.0/app";
import { getAuth } from "npm:firebase-admin@13.4.0/auth";
import { getAppCheck } from "npm:firebase-admin@13.4.0/app-check";
import { getFirestore } from "npm:firebase-admin@13.4.0/firestore";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info, x-firebase-appcheck",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
export function secret(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing secret: ${name}`);
  return value;
}
const account = JSON.parse(secret("FIREBASE_SERVICE_ACCOUNT_JSON"));
account.private_key = account.private_key.replace(/\\n/g, "\n");
const app = getApps()[0] ?? initializeApp({ credential: cert(account) });
export const auth = getAuth(app);
export const db = getFirestore(app);
db.settings({ preferRest: true });
export function json(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
export class RequestError extends Error {
  constructor(message: string, public status = 400) {
    super(message);
  }
}
export async function caller(request: Request) {
  try {
    await getAppCheck(app).verifyToken(
      request.headers.get("X-Firebase-AppCheck") ?? "",
    );
    const bearer = request.headers.get("Authorization") ?? "";
    if (!bearer.startsWith("Bearer ")) throw new Error();
    return await auth.verifyIdToken(bearer.slice(7), true);
  } catch {
    throw new RequestError("Please sign in again and retry.", 401);
  }
}
export function failure(error: unknown): Response {
  if (error instanceof RequestError) {
    return json({ error: error.message }, error.status);
  }
  const code = typeof error === "object" && error !== null && "code" in error
    ? String(error.code)
    : "internal";
  console.error("School service request failed:", code);
  return json({
    error: "The request could not be completed. Please try again.",
  }, 500);
}
