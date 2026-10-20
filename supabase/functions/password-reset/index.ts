import {
  cert,
  getApps,
  initializeApp,
} from "npm:firebase-admin@13.4.0/app";

import {
  getAppCheck,
} from "npm:firebase-admin@13.4.0/app-check";

import {
  getAuth,
} from "npm:firebase-admin@13.4.0/auth";

import {
  FieldValue,
  getFirestore,
} from "npm:firebase-admin@13.4.0/firestore";

import { resetIdentityAction } from "./native_identity.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info, x-firebase-appcheck",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const genericMessage =
  "If the ID number and registered email match an account, " +
  "a password reset link will be sent shortly.";

function response(
  data: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(data),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function requiredSecret(
  name: string,
): string {
  const value = Deno.env.get(name)?.trim();

  if (!value) {
    throw new Error(
      `Missing environment secret: ${name}`,
    );
  }

  return value;
}

function cleanText(
  value: unknown,
): string {
  return String(value ?? "").trim();
}

function normalizeCampusId(
  value: unknown,
): string {
  return cleanText(value).replace(
    /\s+/g,
    "",
  );
}

function normalizeEmail(
  value: unknown,
): string {
  return cleanText(value).toLowerCase();
}

function validCampusId(
  value: string,
): boolean {
  return /^\d{5,12}$/.test(value);
}

function validEmail(
  value: string,
): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(
    value,
  );
}

// ============================================================
// FIREBASE ADMIN
// ============================================================

const serviceAccount = JSON.parse(
  requiredSecret(
    "FIREBASE_SERVICE_ACCOUNT_JSON",
  ),
);

if (
  typeof serviceAccount.private_key ===
    "string"
) {
  serviceAccount.private_key =
    serviceAccount.private_key.replace(
      /\\n/g,
      "\n",
    );
}

const firebaseApp =
  getApps().length > 0
    ? getApps()[0]
    : initializeApp({
        credential: cert(serviceAccount),
      });

const firebaseAuth = getAuth(firebaseApp);

const firebaseAppCheck =
  getAppCheck(firebaseApp);

const firestore =
  getFirestore(firebaseApp);

// Supabase Edge Functions run in a Deno environment.
// Use Firestore REST instead of gRPC.
firestore.settings({
  preferRest: true,
});

// ============================================================
// APP CHECK
// ============================================================

async function requireValidAppCheck(
  request: Request,
): Promise<void> {
  const token = request.headers
    .get("X-Firebase-AppCheck")
    ?.trim();

  if (!token) {
    throw new Error(
      "Firebase App Check token is missing.",
    );
  }

  await firebaseAppCheck.verifyToken(token);
}

// ============================================================
// RATE LIMITING
// ============================================================

async function requestAllowed(
  userId: string,
): Promise<boolean> {
  const reference = firestore
    .collection("passwordResetRateLimits")
    .doc(userId);

  return await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const now = Date.now();
    if (Number(snapshot.data()?.nextAllowedAtMs ?? 0) > now) return false;
    transaction.set(reference, {
      userId,
      nextAllowedAtMs: now + 60_000,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return true;
  });
}

// ============================================================
// EMAIL DELIVERY
// ============================================================

// Firebase Authentication delivers its own password-reset email.
// Requires FIREBASE_WEB_API_KEY in Supabase Edge Function secrets.
async function sendResetEmail(
  email: string,
  appCheckToken: string,
): Promise<void> {
  const apiKey = requiredSecret(
    "FIREBASE_WEB_API_KEY",
  );

  const endpoint = new URL(
    "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode",
  );
  endpoint.searchParams.set(
    "key",
    apiKey,
  );

  const emailResponse = await fetch(
    endpoint.toString(),
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Firebase-AppCheck": appCheckToken,
      },
      body: JSON.stringify({
        requestType: "PASSWORD_RESET",
        email,
      }),
    },
  );

  if (!emailResponse.ok) {
    // Never log the email, API key, or raw Firebase response.
    throw new Error(
      "Firebase rejected the password-reset request " +
        `(HTTP ${emailResponse.status}).`,
    );
  }
}

// ============================================================
// PASSWORD RESET PROCESSING
// ============================================================

async function processResetRequest(
  campusId: string,
  email: string,
  appCheckToken: string,
): Promise<void> {
  const users = await firestore
    .collection("users")
    .where(
      "universityId",
      "==",
      campusId,
    )
    .limit(2)
    .get();

  if (users.empty) {
    console.info("Password reset skipped: no matching campus ID.");
    return;
  }

  const matches = users.docs.filter(
    (document) =>
      normalizeEmail(
        document.data().email,
      ) === email,
  );

  if (users.size !== 1 || matches.length !== 1) {
    console.info("Password reset skipped: ambiguous ID or contact email mismatch.");
    return;
  }

  const document = matches[0];
  const profile = document.data();

  const authUser = await firebaseAuth.getUser(
    document.id,
  );
  const identityAction = resetIdentityAction(
    authUser, campusId, email, profile.authEmail,
  );
  if (identityAction === "skip") {
    console.warn(
      "Password reset skipped: unsupported identity or disabled account.",
    );
    return;
  }

  if (
    !(await requestAllowed(
      document.id,
    ))
  ) {
    console.info("Password reset skipped: rate limited.");
    return;
  }

  // Validate configuration before changing any identity.
  requiredSecret("FIREBASE_WEB_API_KEY");

  // Reserve the campus ID before freeing its synthetic Auth email. Rules and
  // instructor registration reject attempts to register this ID with a new UID.
  const reservation = firestore.collection("campusLoginIds").doc(campusId);
  await firestore.runTransaction(async (transaction) => {
    const existing = await transaction.get(reservation);
    const freshProfile = await transaction.get(document.ref);
    if (existing.exists && existing.data()?.uid !== document.id) {
      throw new Error("Campus login reservation conflict.");
    }
    if (normalizeEmail(freshProfile.data()?.email) !== email ||
      normalizeCampusId(freshProfile.data()?.universityId) !== campusId) {
      throw new Error("Profile changed during password reset.");
    }
    transaction.set(reservation, {
      uid: document.id,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  if (identityAction === "migrate") {
    // Firebase enforces email uniqueness: an address belonging to another UID
    // causes an error. Never merge accounts or change passwords here.
    await firebaseAuth.updateUser(document.id, {
      email,
      emailVerified: false,
    });
    console.info("Password reset: legacy Auth identity migrated.");
  }
  await document.ref.update({
    authEmail: email,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await sendResetEmail(email, appCheckToken);
  console.info("Password reset: Firebase accepted the email request.");
}

// ============================================================
// HTTP HANDLER
// ============================================================

Deno.serve(
  async (
    request: Request,
  ): Promise<Response> => {
    if (request.method === "OPTIONS") {
      return new Response(
        "ok",
        {
          headers: corsHeaders,
        },
      );
    }

    if (request.method !== "POST") {
      return response(
        {
          error: "Method not allowed.",
        },
        405,
      );
    }

    try {
      await requireValidAppCheck(
        request,
      );
    } catch (error) {
      console.error(
        "Password reset App Check " +
          "verification failed:",
        error,
      );

      return response(
        {
          error:
            "CASLMS could not verify this " +
            "application. Please restart it " +
            "and try again.",
        },
        401,
      );
    }

    let body:
      Record<string, unknown>;

    try {
      body = await request.json();
    } catch (_) {
      return response(
        {
          error:
            "Invalid request body.",
        },
        400,
      );
    }

    const campusId =
      normalizeCampusId(
        body.campusId,
      );

    const email =
      normalizeEmail(
        body.email,
      );

    if (!validCampusId(campusId)) {
      return response(
        {
          error:
            "Enter a valid student or " +
            "faculty ID number.",
        },
        400,
      );
    }

    if (!validEmail(email)) {
      return response(
        {
          error:
            "Enter a valid registered " +
            "email address.",
        },
        400,
      );
    }

    try {
      await processResetRequest(
        campusId,
        email,
        request.headers.get("X-Firebase-AppCheck")!.trim(),
      );
    } catch (error) {
      // Never reveal whether the ID or email
      // belongs to an existing account.
      const code = typeof error === "object" && error !== null && "code" in error
        ? String(error.code)
        : error instanceof Error && /^(Missing environment secret:|Firebase rejected)/.test(error.message)
        ? error.message
        : "internal";
      console.error("Password reset processing failed:", code);
    }

    return response({
      success: true,
      message: genericMessage,
    });
  },
);
