import {
  cert,
  getApps,
  initializeApp,
} from "npm:firebase-admin@13.4.0/app";

import {
  getAuth,
} from "npm:firebase-admin@13.4.0/auth";

import {
  FieldValue,
  getFirestore,
} from "npm:firebase-admin@13.4.0/firestore";

import {
  createClient,
} from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

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

function requiredSecret(name: string): string {
  const value = Deno.env.get(name);

  if (!value) {
    throw new Error(
      `Missing environment secret: ${name}`,
    );
  }

  return value;
}

function bearerToken(request: Request): string {
  const authorization =
    request.headers.get("Authorization") ?? "";

  if (!authorization.startsWith("Bearer ")) {
    throw new Error(
      "Firebase authorization token is missing.",
    );
  }

  return authorization
    .substring("Bearer ".length)
    .trim();
}

function cleanText(value: unknown): string {
  return String(value ?? "").trim();
}

function validEmail(email: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email);
}

function validCampusId(campusId: string): boolean {
  return /^\d{5,12}$/.test(campusId);
}

function extensionForMimeType(
  mimeType: string,
): string | null {
  switch (mimeType.toLowerCase()) {
    case "image/jpeg":
      return "jpg";

    case "image/png":
      return "png";

    case "image/webp":
      return "webp";

    case "application/pdf":
      return "pdf";

    default:
      return null;
  }
}

function decodeBase64(encoded: string): Uint8Array {
  const binary = atob(encoded);

  return Uint8Array.from(
    binary,
    (character) => character.charCodeAt(0),
  );
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

const serviceAccount = JSON.parse(
  requiredSecret(
    "FIREBASE_SERVICE_ACCOUNT_JSON",
  ),
);

if (
  typeof serviceAccount.private_key === "string"
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
const firestore = getFirestore(firebaseApp);

const supabase = createClient(
  requiredSecret("SUPABASE_URL"),
  requiredSecret(
    "SUPABASE_SERVICE_ROLE_KEY",
  ),
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);

const bucketName = "caslms-faculty-ids";

async function requireFirebaseUser(
  request: Request,
) {
  const token = bearerToken(request);

  return await firebaseAuth.verifyIdToken(
    token,
    true,
  );
}

async function requireAdmin(
  request: Request,
) {
  const decoded =
    await requireFirebaseUser(request);

  const document = await firestore
    .collection("users")
    .doc(decoded.uid)
    .get();

  const profile = document.data();

  if (
    !document.exists ||
    profile?.role !== "admin" ||
    profile?.status !== "active"
  ) {
    throw new Error(
      "Active administrator access is required.",
    );
  }

  return {
    decoded,
    profile,
  };
}

async function submitApplication(
  request: Request,
  body: Record<string, unknown>,
): Promise<Response> {
  const decoded =
    await requireFirebaseUser(request);

  const fullName =
    cleanText(body.fullName);

  const contactEmail =
    cleanText(body.email).toLowerCase();

  const campusId =
    cleanText(body.campusId);

  const department =
    cleanText(body.department);

  const course =
    cleanText(body.course);

  const fileName =
    cleanText(body.facultyIdFileName);

  const mimeType =
    cleanText(
      body.facultyIdMimeType,
    ).toLowerCase();

  const encodedFile =
    cleanText(body.facultyIdBase64);

  if (fullName.length < 2) {
    return response(
      {
        error:
          "Enter your complete name.",
      },
      400,
    );
  }

  if (!validEmail(contactEmail)) {
    return response(
      {
        error:
          "Enter a valid email address.",
      },
      400,
    );
  }

  if (!validCampusId(campusId)) {
    return response(
      {
        error:
          "Enter a valid faculty ID.",
      },
      400,
    );
  }

  if (
    department.length === 0 ||
    course.length === 0
  ) {
    return response(
      {
        error:
          "Department and position are required.",
      },
      400,
    );
  }

  if (
    fileName.length === 0 ||
    encodedFile.length === 0
  ) {
    return response(
      {
        error:
          "A faculty ID image or PDF is required.",
      },
      400,
    );
  }

  const extension =
    extensionForMimeType(mimeType);

  if (!extension) {
    return response(
      {
        error:
          "Faculty ID must be a JPG, PNG, WEBP, or PDF file.",
      },
      400,
    );
  }

  const expectedAuthEmail =
    `${campusId}@caslms.app`.toLowerCase();

  if (
    cleanText(decoded.email).toLowerCase() !==
    expectedAuthEmail
  ) {
    return response(
      {
        error:
          "The faculty ID does not match the authenticated account.",
      },
      403,
    );
  }

  let bytes: Uint8Array;

  try {
    bytes = decodeBase64(encodedFile);
  } catch (_) {
    return response(
      {
        error:
          "The faculty ID file is invalid.",
      },
      400,
    );
  }

  const maximumBytes =
    5 * 1024 * 1024;

  if (
    bytes.length === 0 ||
    bytes.length > maximumBytes
  ) {
    return response(
      {
        error:
          "Faculty ID must be 5 MB or smaller.",
      },
      400,
    );
  }

  const userReference = firestore
    .collection("users")
    .doc(decoded.uid);

  const existingUser =
    await userReference.get();

  if (
    existingUser.exists &&
    existingUser.data()?.status === "active"
  ) {
    return response(
      {
        error:
          "This account is already active.",
      },
      409,
    );
  }

  const applicationReference =
    firestore
      .collection(
        "instructorApplications",
      )
      .doc(decoded.uid);

  const existingApplication =
    await applicationReference.get();

  if (
    existingApplication.exists &&
    existingApplication.data()?.status ===
      "pending"
  ) {
    return response(
      {
        error:
          "Your instructor application is already pending.",
      },
      409,
    );
  }

  const storagePath =
    `applications/${decoded.uid}/` +
    `faculty-id-${Date.now()}.${extension}`;

  const uploadResult =
    await supabase.storage
      .from(bucketName)
      .upload(
        storagePath,
        bytes,
        {
          contentType: mimeType,
          upsert: false,
        },
      );

  if (uploadResult.error) {
    console.error(uploadResult.error);

    return response(
      {
        error:
          "Unable to upload the faculty ID.",
      },
      500,
    );
  }

  try {
    const batch = firestore.batch();

    batch.set(
      userReference,
      {
        uid: decoded.uid,
        name: fullName,
        email: contactEmail,
        universityId: campusId,
        authEmail: expectedAuthEmail,
        department,
        course,
        role: "instructor",
        status: "pending",
        approvalStatus: "pending",
        instructorApplicationId:
          decoded.uid,
        createdAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
        lastLoginAt: null,
      },
    );

    batch.set(
      applicationReference,
      {
        applicantId: decoded.uid,
        name: fullName,
        email: contactEmail,
        universityId: campusId,
        department,
        course,
        facultyIdPath: storagePath,
        facultyIdFileName: fileName,
        facultyIdMimeType: mimeType,
        status: "pending",
        submittedAt:
          FieldValue.serverTimestamp(),
        updatedAt:
          FieldValue.serverTimestamp(),
        reviewedAt: null,
        reviewedBy: null,
        denialReason: null,
        emailStatus: "not_sent",
      },
    );

    await batch.commit();
  } catch (error) {
    await supabase.storage
      .from(bucketName)
      .remove([storagePath]);

    console.error(error);

    return response(
      {
        error:
          "Unable to save the instructor application.",
      },
      500,
    );
  }

  return response({
    success: true,
    status: "pending",
    message:
      "Your instructor application was submitted for administrator review.",
  });
}

async function getFacultyId(
  request: Request,
  body: Record<string, unknown>,
): Promise<Response> {
  await requireAdmin(request);

  const applicantId =
    cleanText(body.applicantId);

  if (applicantId.length === 0) {
    return response(
      {
        error:
          "Applicant ID is required.",
      },
      400,
    );
  }

  const application =
    await firestore
      .collection(
        "instructorApplications",
      )
      .doc(applicantId)
      .get();

  const data = application.data();

  if (
    !application.exists ||
    !data
  ) {
    return response(
      {
        error:
          "Instructor application was not found.",
      },
      404,
    );
  }

  const storagePath =
    cleanText(data.facultyIdPath);

  if (storagePath.length === 0) {
    return response(
      {
        error:
          "Faculty ID file was not found.",
      },
      404,
    );
  }

  const signedUrlResult =
    await supabase.storage
      .from(bucketName)
      .createSignedUrl(
        storagePath,
        300,
      );

  if (
    signedUrlResult.error ||
    !signedUrlResult.data?.signedUrl
  ) {
    console.error(
      signedUrlResult.error,
    );

    return response(
      {
        error:
          "Unable to open the faculty ID.",
      },
      500,
    );
  }

  return response({
    success: true,
    url:
      signedUrlResult.data.signedUrl,
    expiresInSeconds: 300,
  });
}

async function sendDecisionEmail(
  email: string,
  name: string,
  approved: boolean,
  reason: string,
) {
  const resendKey =
    requiredSecret("RESEND_API_KEY");

  const fromEmail =
    Deno.env.get(
      "APPROVAL_FROM_EMAIL",
    ) ??
    "CASLMS <onboarding@resend.dev>";

  const safeName =
    escapeHtml(name);

  const safeReason =
    escapeHtml(reason);

  const subject = approved
    ? "Your CASLMS instructor account was approved"
    : "Your CASLMS instructor application was denied";

  const html = approved
    ? `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#10182f">
        <h2>Instructor account approved</h2>
        <p>Hello ${safeName},</p>
        <p>Your CASLMS instructor account has been verified and approved.</p>
        <p>You can now log in using your faculty ID and open the instructor dashboard.</p>
        <p>CASLMS Administration</p>
      </div>
    `
    : `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#10182f">
        <h2>Instructor application denied</h2>
        <p>Hello ${safeName},</p>
        <p>Your CASLMS instructor application was not approved.</p>
        ${
          safeReason.length > 0
            ? `<p><strong>Reason:</strong> ${safeReason}</p>`
            : ""
        }
        <p>Please contact the CASLMS administrator if you believe this decision is incorrect.</p>
        <p>CASLMS Administration</p>
      </div>
    `;

  const emailResponse =
    await fetch(
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
          subject,
          html,
        }),
      },
    );

  const result =
    await emailResponse.json();

  if (!emailResponse.ok) {
    console.error(result);

    throw new Error(
      "Unable to send the decision email.",
    );
  }

  return result;
}

async function reviewApplication(
  request: Request,
  body: Record<string, unknown>,
): Promise<Response> {
  const admin =
    await requireAdmin(request);

  const applicantId =
    cleanText(body.applicantId);

  const decision =
    cleanText(body.decision)
      .toLowerCase();

  const denialReason =
    cleanText(body.reason);

  if (applicantId.length === 0) {
    return response(
      {
        error:
          "Applicant ID is required.",
      },
      400,
    );
  }

  if (
    decision !== "approved" &&
    decision !== "denied"
  ) {
    return response(
      {
        error:
          "Decision must be approved or denied.",
      },
      400,
    );
  }

  if (
    decision === "denied" &&
    denialReason.length === 0
  ) {
    return response(
      {
        error:
          "Enter a reason for denying the application.",
      },
      400,
    );
  }

  const applicationReference =
    firestore
      .collection(
        "instructorApplications",
      )
      .doc(applicantId);

  const userReference =
    firestore
      .collection("users")
      .doc(applicantId);

  const [
    applicationDocument,
    userDocument,
  ] = await Promise.all([
    applicationReference.get(),
    userReference.get(),
  ]);

  const application =
    applicationDocument.data();

  const user =
    userDocument.data();

  if (
    !applicationDocument.exists ||
    !application ||
    !userDocument.exists ||
    !user
  ) {
    return response(
      {
        error:
          "Instructor application was not found.",
      },
      404,
    );
  }

  if (
    application.status !== "pending" ||
    user.status !== "pending"
  ) {
    return response(
      {
        error:
          "This application has already been reviewed.",
      },
      409,
    );
  }

  const approved =
    decision === "approved";

  const batch = firestore.batch();

  batch.update(
    applicationReference,
    {
      status: decision,
      reviewedBy:
        admin.decoded.uid,
      reviewedAt:
        FieldValue.serverTimestamp(),
      denialReason:
        approved
          ? null
          : denialReason,
      updatedAt:
        FieldValue.serverTimestamp(),
      emailStatus: "sending",
    },
  );

  batch.update(
    userReference,
    {
      status:
        approved
          ? "active"
          : "denied",
      approvalStatus: decision,
      reviewedBy:
        admin.decoded.uid,
      reviewedAt:
        FieldValue.serverTimestamp(),
      denialReason:
        approved
          ? null
          : denialReason,
      updatedAt:
        FieldValue.serverTimestamp(),
    },
  );

  await batch.commit();

  if (approved) {
    await firebaseAuth.updateUser(
      applicantId,
      {
        disabled: false,
      },
    );
  } else {
    await firebaseAuth.updateUser(
      applicantId,
      {
        disabled: true,
      },
    );

    await firebaseAuth.revokeRefreshTokens(
      applicantId,
    );
  }

  let emailSent = false;

  try {
    await sendDecisionEmail(
      cleanText(user.email),
      cleanText(user.name),
      approved,
      denialReason,
    );

    emailSent = true;

    await applicationReference.update({
      emailStatus: "sent",
      emailSentAt:
        FieldValue.serverTimestamp(),
      updatedAt:
        FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(error);

    await applicationReference.update({
      emailStatus: "failed",
      emailError: cleanText(error),
      updatedAt:
        FieldValue.serverTimestamp(),
    });
  }

  return response({
    success: true,
    decision,
    emailSent,
    message: approved
      ? "Instructor approved."
      : "Instructor application denied.",
  });
}

Deno.serve(
  async (request: Request) => {
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
          error:
            "Method not allowed.",
        },
        405,
      );
    }

    try {
      const body =
        await request.json() as
          Record<string, unknown>;

      const action =
        cleanText(body.action)
          .toLowerCase();

      switch (action) {
        case "submit":
          return await submitApplication(
            request,
            body,
          );

        case "get_faculty_id":
          return await getFacultyId(
            request,
            body,
          );

        case "review":
          return await reviewApplication(
            request,
            body,
          );

        default:
          return response(
            {
              error:
                "Invalid instructor approval action.",
            },
            400,
          );
      }
    } catch (error) {
      console.error(error);

      const message =
        error instanceof Error
          ? error.message
          : "Unable to process the request.";

      const lowerMessage =
        message.toLowerCase();

      const unauthorized =
        lowerMessage.includes("token") ||
        lowerMessage.includes(
          "administrator",
        );

      return response(
        {
          error: message,
        },
        unauthorized ? 403 : 500,
      );
    }
  },
);