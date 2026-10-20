import { FieldValue } from "npm:firebase-admin@13.4.0/firestore";
import {
  auth,
  caller,
  cors,
  db,
  failure,
  json,
  RequestError,
} from "../_shared/firebase.ts";
import { mayActivate, validProgram } from "./policy.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }
  try {
    const token = await caller(request);
    const user = await auth.getUser(token.uid);
    const email = (user.email ?? "").trim().toLowerCase();
    if (user.disabled || !email || email.endsWith("@caslms.app")) {
      throw new RequestError(
        "A real email address is required for student registration.",
      );
    }
    const body = await request.json().catch(() => {
      throw new RequestError("Invalid request body.");
    });
    const ref = db.collection("users").doc(user.uid);
    if (body?.action === "activate") {
      await db.runTransaction(async (tx) => {
        const profile = (await tx.get(ref)).data();
        // Check both the fresh Auth record and the verified ID token. Never
        // reactivate a suspended/denied account through email confirmation.
        if (
          !profile ||
          !mayActivate(
            profile,
            email,
            user.emailVerified && token.email_verified === true,
          )
        ) {
          throw new RequestError(
            "Verify your email first, then check again. Contact the administrator if the account is suspended.",
            403,
          );
        }
        if (profile.status === "active") return;
        tx.update(ref, {
          status: "active",
          emailVerifiedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      return json({ success: true });
    }
    if (body?.action !== "register") {
      throw new RequestError("Invalid registration action.");
    }
    const campusId = String(body.campusId ?? "").replace(/\s+/g, "");
    const name = String(body.fullName ?? "").trim();
    const department = String(body.department ?? "").trim();
    const course = String(body.course ?? "").trim();
    if (
      !/^\d{5,12}$/.test(campusId) || name.length < 2 || name.length > 150 ||
      !validProgram(department, course)
    ) {
      throw new RequestError(
        "Enter a valid name, campus ID, department and program.",
      );
    }
    // Older accounts still authenticate using a synthetic email. Reserve those
    // IDs too; do not create a second student with the same ID and a real email.
    try {
      const legacy = await auth.getUserByEmail(`${campusId}@caslms.app`);
      if (legacy.uid !== user.uid) {
        throw new RequestError("This campus ID is already registered.", 409);
      }
    } catch (error) {
      if (
        !(typeof error === "object" && error !== null && "code" in error &&
          error.code === "auth/user-not-found")
      ) throw error;
    }
    const reservation = db.collection("campusLoginIds").doc(campusId);
    await db.runTransaction(async (tx) => {
      const existing = (await tx.get(ref)).data();
      const reserved = (await tx.get(reservation)).data();
      const sameId = await tx.get(
        db.collection("users").where("universityId", "==", campusId).limit(2),
      );
      if (
        reserved && reserved.uid !== user.uid ||
        sameId.docs.some((doc) => doc.id !== user.uid)
      ) {
        throw new RequestError("This campus ID is already registered.", 409);
      }
      if (existing) {
        if (
          existing.role !== "student" || existing.universityId !== campusId ||
          existing.email !== email ||
          existing.emailVerificationRequired !== true ||
          !["pending_verification", "active"].includes(existing.status)
        ) {
          throw new RequestError(
            "This account is already registered. Please sign in.",
            409,
          );
        }
        return; // A retry must not reset an existing account's status/profile.
      }
      tx.set(reservation, {
        uid: user.uid,
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(ref, {
        uid: user.uid,
        name,
        email,
        authEmail: email,
        universityId: campusId,
        department,
        course,
        role: "student",
        status: "pending_verification",
        approvalStatus: "not_required",
        emailVerificationRequired: true,
        emailVerifiedAt: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return json({ success: true });
  } catch (error) {
    return failure(error);
  }
});
