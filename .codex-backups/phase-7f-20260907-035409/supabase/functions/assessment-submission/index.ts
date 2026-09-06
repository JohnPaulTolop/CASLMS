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
  "Access-Control-Allow-Methods":
    "POST, OPTIONS",
};

const bucketName =
  "caslms-assessment-submissions";

const maximumFileBytes =
  20 * 1024 * 1024;

class RequestError extends Error {
  constructor(
    message: string,
    readonly status = 400,
  ) {
    super(message);
  }
}

function json(
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
  const value =
    Deno.env.get(name);

  if (!value) {
    throw new Error(
      `Missing environment secret: ${name}`,
    );
  }

  return value;
}

function clean(
  value: unknown,
): string {
  return String(
    value ?? "",
  ).trim();
}

function bearerToken(
  request: Request,
): string {
  const authorization =
    request.headers.get(
      "Authorization",
    ) ?? "";

  if (
    !authorization.startsWith(
      "Bearer ",
    )
  ) {
    throw new RequestError(
      "Firebase authorization token is missing.",
      401,
    );
  }

  const token =
    authorization
      .substring(
        "Bearer ".length,
      )
      .trim();

  if (!token) {
    throw new RequestError(
      "Firebase authorization token is missing.",
      401,
    );
  }

  return token;
}

function decodeBase64(
  encoded: string,
): Uint8Array {
  try {
    const binary =
      atob(encoded);

    return Uint8Array.from(
      binary,
      (character) =>
        character.charCodeAt(0),
    );
  } catch (_) {
    throw new RequestError(
      "The uploaded file is invalid.",
    );
  }
}

function fileExtension(
  fileName: string,
): string {
  const parts =
    fileName
      .toLowerCase()
      .split(".");

  if (parts.length < 2) {
    return "";
  }

  return parts.pop() ?? "";
}

function safeFileName(
  value: string,
): string {
  let result =
    value
      .replaceAll("\\", "_")
      .replaceAll("/", "_")
      .replace(
        /[^a-zA-Z0-9._-]/g,
        "_",
      )
      .replace(
        /_+/g,
        "_",
      );

  if (result.length > 120) {
    result =
      result.substring(
        result.length - 120,
      );
  }

  return result;
}

function validateGitHubUrl(
  value: string,
): string {
  let url: URL;

  try {
    url = new URL(value);
  } catch (_) {
    throw new RequestError(
      "Enter a valid GitHub repository link.",
    );
  }

  const pathParts =
    url.pathname
      .split("/")
      .filter(
        (part) =>
          part.length > 0,
      );

  if (
    url.protocol !== "https:" ||
    url.hostname.toLowerCase() !==
      "github.com" ||
    pathParts.length < 2
  ) {
    throw new RequestError(
      "Use a valid https://github.com/owner/repository link.",
    );
  }

  url.search = "";
  url.hash = "";

  return url
    .toString()
    .replace(
      /\/$/,
      "",
    );
}

const allowedFiles: Record<
  string,
  {
    extensions: string[];
    mimeTypes: string[];
  }
> = {
  zip_file: {
    extensions: [
      "zip",
    ],
    mimeTypes: [
      "application/zip",
      "application/x-zip-compressed",
      "application/octet-stream",
    ],
  },

  technical_document: {
    extensions: [
      "pdf",
      "doc",
      "docx",
      "txt",
    ],
    mimeTypes: [
      "application/pdf",
      "application/msword",
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      "text/plain",
      "application/octet-stream",
    ],
  },
};

const serviceAccount =
  JSON.parse(
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
        credential:
          cert(
            serviceAccount,
          ),
      });

const firebaseAuth =
  getAuth(firebaseApp);

const firestore =
  getFirestore(firebaseApp);

firestore.settings({
  preferRest: true,
});

const supabase =
  createClient(
    requiredSecret(
      "SUPABASE_URL",
    ),
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

async function requireActiveUser(
  request: Request,
) {
  const decoded =
    await firebaseAuth
      .verifyIdToken(
        bearerToken(request),
        true,
      );

  const userDocument =
    await firestore
      .collection("users")
      .doc(decoded.uid)
      .get();

  const profile =
    userDocument.data();

  if (
    !userDocument.exists ||
    !profile ||
    clean(
        profile.status,
      ).toLowerCase() !==
      "active"
  ) {
    throw new RequestError(
      "An active CASLMS account is required.",
      403,
    );
  }

  return {
    uid: decoded.uid,
    profile,
  };
}

async function requireStudentAssessment(
  request: Request,
  assessmentId: string,
) {
  const user =
    await requireActiveUser(
      request,
    );

  if (
    clean(
      user.profile.role,
    ).toLowerCase() !==
      "student"
  ) {
    throw new RequestError(
      "A student account is required.",
      403,
    );
  }

  const assessmentDocument =
    await firestore
      .collection(
        "assessments",
      )
      .doc(
        assessmentId,
      )
      .get();

  const assessment =
    assessmentDocument.data();

  if (
    !assessmentDocument.exists ||
    !assessment
  ) {
    throw new RequestError(
      "Assessment could not be found.",
      404,
    );
  }

  if (
    clean(
      assessment.status,
    ).toLowerCase() !==
      "published"
  ) {
    throw new RequestError(
      "This assessment is not currently available.",
      403,
    );
  }

  const deliveryType =
    clean(
      assessment.deliveryType,
    ).toLowerCase();

  const assessmentType =
    clean(
      assessment.assessmentType,
    ).toLowerCase();

  if (
    deliveryType ===
      "ai_generated" &&
    assessmentType ===
      "quiz"
  ) {
    throw new RequestError(
      "AI quizzes must be answered inside CASLMS.",
    );
  }

  const courseId =
    clean(
      assessment.courseId,
    );

  const moduleId =
    clean(
      assessment.moduleId,
    );

  if (
    !courseId ||
    !moduleId
  ) {
    throw new RequestError(
      "Assessment information is incomplete.",
    );
  }

  const enrollmentId =
    `${courseId}_${user.uid}`;

  const enrollmentDocument =
    await firestore
      .collection(
        "enrollments",
      )
      .doc(
        enrollmentId,
      )
      .get();

  const enrollment =
    enrollmentDocument.data();

  if (
    !enrollmentDocument.exists ||
    !enrollment ||
    enrollment.studentId !==
      user.uid ||
    enrollment.courseId !==
      courseId ||
    clean(
      enrollment.status,
    ).toLowerCase() !==
      "active"
  ) {
    throw new RequestError(
      "You are not actively enrolled in this course.",
      403,
    );
  }

  const dueAt =
    assessment.dueAt;

  if (
    dueAt &&
    typeof dueAt.toDate ===
      "function" &&
    dueAt.toDate().getTime() <
      Date.now()
  ) {
    throw new RequestError(
      "The deadline for this assessment has passed.",
      403,
    );
  }

  return {
    uid: user.uid,
    profile: user.profile,
    assessment,
    courseId,
    moduleId,
  };
}

async function submitAssessment(
  request: Request,
  body: Record<
    string,
    unknown
  >,
): Promise<Response> {
  const assessmentId =
    clean(
      body.assessmentId,
    );

  const submissionType =
    clean(
      body.submissionType,
    ).toLowerCase();

  if (!assessmentId) {
    throw new RequestError(
      "Assessment ID is required.",
    );
  }

  const allowedSubmissionTypes = [
    "github_repository",
    "zip_file",
    "technical_document",
  ];

  if (
    !allowedSubmissionTypes
      .includes(
        submissionType,
      )
  ) {
    throw new RequestError(
      "Select a valid submission type.",
    );
  }

  const context =
    await requireStudentAssessment(
      request,
      assessmentId,
    );

  const submissionId =
    `${assessmentId}_${context.uid}`;

  const submissionReference =
    firestore
      .collection(
        "assessmentSubmissions",
      )
      .doc(
        submissionId,
      );

  const existingDocument =
    await submissionReference
      .get();

  const existingStatus =
    clean(
      existingDocument
        .data()
        ?.status,
    ).toLowerCase();

  if (
    existingDocument.exists &&
    [
      "submitted",
      "graded",
    ].includes(
      existingStatus,
    )
  ) {
    throw new RequestError(
      "This assessment has already been submitted.",
      409,
    );
  }

  let repositoryUrl:
    string | null = null;

  let storagePath:
    string | null = null;

  let fileName:
    string | null = null;

  let mimeType:
    string | null = null;

  let sizeBytes:
    number | null = null;

  if (
    submissionType ===
      "github_repository"
  ) {
    repositoryUrl =
      validateGitHubUrl(
        clean(
          body.repositoryUrl,
        ),
      );
  } else {
    fileName =
      clean(
        body.fileName,
      );

    mimeType =
      clean(
        body.mimeType,
      ).toLowerCase();

    const fileBase64 =
      clean(
        body.fileBase64,
      );

    const fileRule =
      allowedFiles[
        submissionType
      ];

    if (
      !fileName ||
      !fileBase64
    ) {
      throw new RequestError(
        "Choose a file to upload.",
      );
    }

    if (
      !fileRule.extensions
        .includes(
          fileExtension(
            fileName,
          ),
        ) ||
      !fileRule.mimeTypes
        .includes(
          mimeType,
        )
    ) {
      throw new RequestError(
        submissionType ===
            "zip_file"
          ? "Only ZIP files are accepted."
          : "Technical documents must be PDF, DOC, DOCX, or TXT files.",
      );
    }

    const fileBytes =
      decodeBase64(
        fileBase64,
      );

    if (
      fileBytes.length === 0
    ) {
      throw new RequestError(
        "The selected file is empty.",
      );
    }

    if (
      fileBytes.length >
      maximumFileBytes
    ) {
      throw new RequestError(
        "The file must not exceed 20 MB.",
      );
    }

    sizeBytes =
      fileBytes.length;

    storagePath =
      `courses/${context.courseId}/` +
      `modules/${context.moduleId}/` +
      `assessments/${assessmentId}/` +
      `students/${context.uid}/` +
      `${Date.now()}_` +
      safeFileName(
        fileName,
      );

    const uploadResult =
      await supabase
        .storage
        .from(
          bucketName,
        )
        .upload(
          storagePath,
          fileBytes,
          {
            contentType:
              mimeType,
            cacheControl:
              "3600",
            upsert:
              false,
          },
        );

    if (
      uploadResult.error
    ) {
      throw new RequestError(
        `Unable to upload the file: ${uploadResult.error.message}`,
        500,
      );
    }
  }

  const studentName =
    clean(
      context.profile.name ??
        context.profile
          .displayName,
    ) || "Student";

  const submissionData = {
    assessmentId,
    courseId:
      context.courseId,
    moduleId:
      context.moduleId,

    studentId:
      context.uid,
    studentName,

    submissionType,
    repositoryUrl,

    storageProvider:
      storagePath
        ? "supabase"
        : null,

    storageBucket:
      storagePath
        ? bucketName
        : null,

    storagePath,
    fileName,
    mimeType,
    sizeBytes,

    status:
      "submitted",

    score:
      null,

    feedback:
      null,

    gradedAt:
      null,

    gradedBy:
      null,

    submittedAt:
      FieldValue
        .serverTimestamp(),

    createdAt:
      FieldValue
        .serverTimestamp(),

    updatedAt:
      FieldValue
        .serverTimestamp(),
  };

  try {
    await submissionReference
      .set(
        submissionData,
      );
  } catch (error) {
    if (storagePath) {
      await supabase
        .storage
        .from(
          bucketName,
        )
        .remove([
          storagePath,
        ]);
    }

    throw error;
  }

  return json({
    success: true,
    submissionId,
    message:
      "Assessment submitted successfully.",
  });
}

async function openSubmissionFile(
  request: Request,
  body: Record<
    string,
    unknown
  >,
): Promise<Response> {
  const submissionId =
    clean(
      body.submissionId,
    );

  if (!submissionId) {
    throw new RequestError(
      "Submission ID is required.",
    );
  }

  const user =
    await requireActiveUser(
      request,
    );

  const submissionDocument =
    await firestore
      .collection(
        "assessmentSubmissions",
      )
      .doc(
        submissionId,
      )
      .get();

  const submission =
    submissionDocument.data();

  if (
    !submissionDocument.exists ||
    !submission
  ) {
    throw new RequestError(
      "Submission could not be found.",
      404,
    );
  }

  const role =
    clean(
      user.profile.role,
    ).toLowerCase();

  let isAllowed =
    role === "admin" ||
    (
      role === "student" &&
      submission.studentId ===
        user.uid
    );

  if (
    !isAllowed &&
    role === "instructor"
  ) {
    const courseId =
      clean(
        submission.courseId,
      );

    if (courseId) {
      const courseDocument =
        await firestore
          .collection(
            "courses",
          )
          .doc(
            courseId,
          )
          .get();

      isAllowed =
        courseDocument
          .data()
          ?.instructorId ===
        user.uid;
    }
  }

  if (!isAllowed) {
    throw new RequestError(
      "You cannot open this submission.",
      403,
    );
  }

  const storagePath =
    clean(
      submission.storagePath,
    );

  if (!storagePath) {
    throw new RequestError(
      "This submission has no uploaded file.",
    );
  }

  const downloadFileName =
    clean(
      submission.fileName,
    );

  const signedResult =
    await supabase
      .storage
      .from(
        bucketName,
      )
      .createSignedUrl(
        storagePath,
        600,
        {
          download:
            downloadFileName ||
            true,
        },
      );

  if (
    signedResult.error ||
    !signedResult
      .data
      ?.signedUrl
  ) {
    throw new RequestError(
      "Unable to create a secure file link.",
      500,
    );
  }

  return json({
    success: true,
    url:
      signedResult
        .data
        .signedUrl,
    fileName:
      downloadFileName,
  });
}

Deno.serve(
  async (
    request: Request,
  ) => {
    if (
      request.method ===
        "OPTIONS"
    ) {
      return new Response(
        "ok",
        {
          headers:
            corsHeaders,
        },
      );
    }

    if (
      request.method !==
        "POST"
    ) {
      return json(
        {
          success: false,
          error:
            "Method not allowed.",
        },
        405,
      );
    }

    try {
      const body =
        await request
          .json() as Record<
            string,
            unknown
          >;

      const action =
        clean(
          body.action,
        ).toLowerCase();

      switch (action) {
        case "submit":
          return await submitAssessment(
            request,
            body,
          );

        case "open_file":
          return await openSubmissionFile(
            request,
            body,
          );

        default:
          throw new RequestError(
            "Invalid assessment submission action.",
          );
      }
    } catch (error) {
      console.error(
        error,
      );

      const status =
        error instanceof
            RequestError
          ? error.status
          : 500;

      const message =
        error instanceof Error
          ? error.message
          : "Unable to process the assessment submission.";

      return json(
        {
          success: false,
          error:
            message,
        },
        status,
      );
    }
  },
);