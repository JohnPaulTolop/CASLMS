import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

import {setGlobalOptions} from "firebase-functions/v2";

// ============================================================
// FIREBASE ADMIN
// ============================================================

initializeApp();

const db = getFirestore();

// ============================================================
// GLOBAL CLOUD FUNCTION SETTINGS
// ============================================================

setGlobalOptions({
  region: "asia-southeast1",
  maxInstances: 10,
});

// ============================================================
// PREPARE AI MATERIAL
//
// Phase 13A:
// This function DOES NOT call an AI model yet.
//
// Responsibilities:
// 1. Require Firebase Authentication.
// 2. Require an active instructor account.
// 3. Validate the requested learning material.
// 4. Verify the instructor owns the course.
// 5. Verify the material is AI-eligible.
// 6. Mark the material as requested for future processing.
// ============================================================

export const prepareAiMaterial = onCall(
  async (request) => {
    // ========================================================
    // REQUIRE AUTHENTICATION
    // ========================================================

    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be logged in.",
      );
    }

    const uid = request.auth.uid;

    // ========================================================
    // VALIDATE RESOURCE ID
    // ========================================================

    const resourceId =
      typeof request.data?.resourceId === "string" ?
        request.data.resourceId.trim() :
        "";

    if (!resourceId) {
      throw new HttpsError(
        "invalid-argument",
        "Learning material ID is required.",
      );
    }

    // ========================================================
    // LOAD CURRENT USER PROFILE
    // ========================================================

    const userDocument =
      await db
        .collection("users")
        .doc(uid)
        .get();

    if (
      !userDocument.exists ||
      !userDocument.data()
    ) {
      throw new HttpsError(
        "not-found",
        "Your CASLMS profile could not be found.",
      );
    }

    const userData = userDocument.data()!;

    const role =
      String(userData.role ?? "")
        .trim()
        .toLowerCase();

    const accountStatus =
      String(userData.status ?? "")
        .trim()
        .toLowerCase();

    // ========================================================
    // REQUIRE ACTIVE INSTRUCTOR
    // ========================================================

    if (accountStatus !== "active") {
      throw new HttpsError(
        "permission-denied",
        "Your CASLMS account is not active.",
      );
    }

    if (role !== "instructor") {
      throw new HttpsError(
        "permission-denied",
        "Only instructors can process learning materials.",
      );
    }

    // ========================================================
    // LOAD LEARNING MATERIAL
    // ========================================================

    const materialReference =
      db
        .collection("moduleResources")
        .doc(resourceId);

    const materialDocument =
      await materialReference.get();

    if (
      !materialDocument.exists ||
      !materialDocument.data()
    ) {
      throw new HttpsError(
        "not-found",
        "Learning material could not be found.",
      );
    }

    const material =
      materialDocument.data()!;

    // ========================================================
    // COURSE ID
    // ========================================================

    const courseId =
      String(material.courseId ?? "")
        .trim();

    if (!courseId) {
      throw new HttpsError(
        "failed-precondition",
        "Learning material has no course ID.",
      );
    }

    // ========================================================
    // VERIFY COURSE OWNERSHIP
    // ========================================================

    const courseDocument =
      await db
        .collection("courses")
        .doc(courseId)
        .get();

    if (
      !courseDocument.exists ||
      !courseDocument.data()
    ) {
      throw new HttpsError(
        "not-found",
        "Course could not be found.",
      );
    }

    const course =
      courseDocument.data()!;

    const instructorId =
      String(course.instructorId ?? "")
        .trim();

    if (instructorId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "You can only process materials from your own course.",
      );
    }

    // ========================================================
    // CHECK DELIVERY TYPE
    // ========================================================

    const deliveryType =
      String(material.deliveryType ?? "")
        .trim()
        .toLowerCase();

    if (deliveryType !== "uploaded_file") {
      throw new HttpsError(
        "failed-precondition",
        "Only uploaded files can currently be used for AI.",
      );
    }

    // ========================================================
    // CHECK AI ELIGIBILITY
    // ========================================================

    if (material.aiEligible !== true) {
      throw new HttpsError(
        "failed-precondition",
        "This learning material is not AI-eligible.",
      );
    }

    // ========================================================
    // VALIDATE STORAGE INFORMATION
    // ========================================================

    const storagePath =
      String(material.storagePath ?? "")
        .trim();

    const fileName =
      String(material.fileName ?? "")
        .trim();

    if (!storagePath || !fileName) {
      throw new HttpsError(
        "failed-precondition",
        "Learning material storage information is incomplete.",
      );
    }

    // ========================================================
    // MARK AS REQUESTED
    //
    // Actual file downloading, text extraction and AI calls
    // will be added in the next Phase 13 steps.
    // ========================================================

    await materialReference.update({
      aiProcessingStatus: "pending",

      aiError: null,

      aiRequestedBy: uid,

      aiRequestedAt:
        FieldValue.serverTimestamp(),

      updatedAt:
        FieldValue.serverTimestamp(),
    });

    // ========================================================
    // RESPONSE
    // ========================================================

    return {
      success: true,

      resourceId,

      courseId,

      fileName,

      storagePath,

      aiEligible: true,

      aiProcessingStatus: "pending",

      message:
        "Learning material is ready for AI processing.",
    };
  },
);


