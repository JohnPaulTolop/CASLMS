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

function escapeHtml(
  value: string,
): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
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

  const snapshot =
    await reference.get();

  const now = Date.now();

  const nextAllowedAtMs = Number(
    snapshot.data()?.nextAllowedAtMs ?? 0,
  );

  if (nextAllowedAtMs > now) {
    return false;
  }

  await reference.set(
    {
      userId,
      nextAllowedAtMs: now + 60_000,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  return true;
}

// ============================================================
// EMAIL DELIVERY
// ============================================================

async function sendResetEmail({
  email,
  name,
  resetLink,
}: {
  email: string;
  name: string;
  resetLink: string;
}): Promise<void> {
  const resendKey = requiredSecret(
    "RESEND_API_KEY",
  );

  const fromEmail =
    Deno.env.get(
      "PASSWORD_RESET_FROM_EMAIL",
    )?.trim() ||
    Deno.env.get(
      "APPROVAL_FROM_EMAIL",
    )?.trim() ||
    "CASLMS <onboarding@resend.dev>";

  const displayName =
    name.length === 0
      ? "CASLMS user"
      : name;

  const safeName =
    escapeHtml(displayName);

  const safeLink =
    escapeHtml(resetLink);

  const emailResponse = await fetch(
    "https://api.resend.com/emails",
    {
      method: "POST",
      headers: {
        "Authorization":
          `Bearer ${resendKey}`,
        "Content-Type":
          "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [email],
        subject:
          "Reset your CASLMS password",
        html: `
          <div
            style="
              font-family:Arial,sans-serif;
              line-height:1.6;
              color:#10182f;
              max-width:560px;
              margin:auto;
            "
          >
            <h2 style="color:#1769ff">
              Reset your CASLMS password
            </h2>

            <p>Hello ${safeName},</p>

            <p>
              A password reset was requested
              for your CASLMS account.
            </p>

            <p style="margin:28px 0">
              <a
                href="${safeLink}"
                style="
                  background:#1769ff;
                  color:#ffffff;
                  text-decoration:none;
                  padding:13px 20px;
                  border-radius:8px;
                  font-weight:700;
                "
              >
                Reset Password
              </a>
            </p>

            <p>
              This link is temporary and can only
              be used for its intended password-reset
              action.
            </p>

            <p>
              If you did not request this reset,
              you can safely ignore this email.
              Your password will remain unchanged.
            </p>

            <p>CASLMS Administration</p>
          </div>
        `,
        text:
          `Hello ${displayName},\n\n` +
          "A password reset was requested for your " +
          "CASLMS account.\n\n" +
          `Reset your password: ${resetLink}\n\n` +
          "If you did not request this reset, " +
          "ignore this email.",
      }),
    },
  );

  if (!emailResponse.ok) {
    const details =
      await emailResponse.text();

    throw new Error(
      "Resend rejected the password reset " +
        `email: ${details}`,
    );
  }
}

// ============================================================
// PASSWORD RESET PROCESSING
// ============================================================

async function processResetRequest(
  campusId: string,
  email: string,
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
    return;
  }

  const matches = users.docs.filter(
    (document) =>
      normalizeEmail(
        document.data().email,
      ) === email,
  );

  if (matches.length !== 1) {
    return;
  }

  const document = matches[0];
  const profile = document.data();

  if (
    !(await requestAllowed(
      document.id,
    ))
  ) {
    return;
  }

  const authEmail = normalizeEmail(
    profile.authEmail ??
      `${campusId}@caslms.app`,
  );

  const registeredEmail =
    normalizeEmail(
      profile.email,
    );

  const name = cleanText(
    profile.name ??
      profile.fullName,
  );

  const continueUrl =
    Deno.env.get(
      "PASSWORD_RESET_CONTINUE_URL",
    )?.trim() ||
    "https://ssu-caslms.vercel.app/";

  const resetLink =
    await firebaseAuth
      .generatePasswordResetLink(
        authEmail,
        {
          url: continueUrl,
          handleCodeInApp: false,
        },
      );

  await sendResetEmail({
    email: registeredEmail,
    name,
    resetLink,
  });
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
      );
    } catch (error) {
      // Never reveal whether the ID or email
      // belongs to an existing account.
      console.error(
        "Password reset processing failed:",
        error,
      );
    }

    return response({
      success: true,
      message: genericMessage,
    });
  },
);