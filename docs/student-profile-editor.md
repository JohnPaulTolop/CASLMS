# Student profile editor

The former Personal Information, Account Details, photo and Refresh Profile
menu is replaced by one responsive **Edit Profile** form:

- Display name and a required year level (1st–4th Year).
- Visible, read-only Student ID: existing campus-login identity remains intact.
- Email / Gmail address, with password reauthentication and Firebase's
  verify-before-update email link.
- Check email verification, Reset Password, and Save Changes controls.

Photo controls remain beside the avatar. Existing reset-email and logout flows
remain available. Department/program are no longer editable from this form.

## Data and identity

Saving the basic form updates the current `users/{uid}` document's `name`,
`displayName`, `yearLevel` (integer 1–4) and `updatedAt`. Firebase Auth's display
name is updated on a best-effort basis; the app uses Firestore as its name
source. Existing user records need no bulk migration.

An entered new email is never written directly to Firestore. The user supplies
their current password, Firebase reauthenticates, and
`verifyBeforeUpdateEmail` sends the confirmation link. The pending state appears
in the editor. After confirming the email, use Check email verification or sign
in again with the same Student ID and password.

The existing `student-registration` Supabase function now accepts
`sync_verified_email`. It validates App Check, the Firebase ID token, the fresh
Auth record, verified email ownership and an active student profile. The
profile is selected exclusively by authenticated UID, with no client-supplied
destination UID or email. It then synchronizes `email` and `authEmail`, enables
the existing verification requirement, and stamps `emailVerifiedAt`/`updatedAt`.
It cannot activate suspended/pending accounts or change Student ID, role or
status. Repeated synchronization is idempotent. Registration/activation remain
unchanged.

`CampusAuthService` synchronizes a verified changed address only during an
explicit Check email verification action or sign-in. Opening Profile and live
profile listeners do not force token renewal or perform writes. Own-profile reads remain possible
while the old Firestore email awaits synchronization. Reset Password continues
to use the confirmed registered address, never an unsaved form value.

Basic profile saving and email delivery are separate operations. If the basic
profile saves but the email request fails, the UI explicitly reports the partial
success and allows retry. The existing address remains valid until Firebase
applies the verified email change. Firebase may require a fresh sign-in afterward.

No new collection, Firestore rule, index, paid service, API key or secret is
required. The existing Firebase Admin credentials/App Check are reused.

## Rollout

Deploy the updated function before publishing the client:

```powershell
cd C:\caslms-main
& {
    $ErrorActionPreference = 'Stop'
    .\scripts\deploy-student-profile.ps1
    .\scripts\build-vercel.ps1
    npx.cmd vercel deploy --prebuilt
}
```

The function deployment helper targets only `student-registration` in the
existing Supabase project. It retains Firebase Authentication and App Check
validation in the handler; the Supabase JWT check is disabled because this app
uses Firebase bearer tokens.

## Verification

The four changed/new Flutter files passed static analysis. Three backend policy
tests passed, covering existing CAS registration, activation, and the new
verified-email boundary. Full function type checking passed with the existing
local npm dependencies:

```powershell
flutter analyze
deno test --allow-read supabase/functions/student-registration/policy_test.ts
deno check --node-modules-dir=manual supabase/functions/student-registration/index.ts
```

A Flutter build and authenticated browser/email test still need to run locally.
Automated Edge cannot start in the restricted development runtime.

On the new preview, test saving name/year and refreshing; invalid email and
empty-name validation; cancel/wrong-password email requests; unconfirmed email
leaving the registered address unchanged; confirmed email followed by Check
verification or a fresh Student ID login; and reset delivery to the confirmed
address. Verify existing registration/email activation, photo upload/removal,
logout, class enrollment and grade access still work.

## Files

- `lib/screens/student/student_profile_page.dart`
- `lib/screens/student/student_profile_editor.dart`
- `lib/services/student_profile_service.dart`
- `lib/services/campus_auth_service.dart`
- `supabase/functions/student-registration/index.ts`
- `supabase/functions/student-registration/policy.ts`
- `supabase/functions/student-registration/policy_test.ts`
- `scripts/deploy-student-profile.ps1`
- `docs/student-profile-editor.md`

## Session refresh loop repair

Profile initialization previously requested `reload()`/`getIdToken(true)`.
The token event rebuilt SessionGate and recreated its profile stream, briefly
replacing the dashboard with a loading view. The remounted Profile requested
another token, creating a feedback loop even while Profile was an offscreen
child of the dashboard's IndexedStack.

Profile initialization now performs ordinary Firestore reads. Both the Auth
and per-UID profile streams are initialized once in widget state. Same-UID
token events retain the mounted dashboard; changing UID disposes the old
profile listener. Live account status and email-verification checks remain in
place. Profile reads/listeners are read-only; email synchronization happens at
explicit verification or sign-in.

The repair changes `lib/screens/session_gate.dart`,
`lib/services/campus_auth_service.dart`, and
`lib/screens/student/student_profile_page.dart`. Regression tests in
`test/session_gate_refresh_test.dart` exercise repeated token events, parent
rebuilds, live suspension, old-listener cleanup and account switching. Test
execution in the restricted runtime is blocked by the Flutter SDK cache
lockfile; run locally:

```powershell
flutter test --no-pub test/session_gate_refresh_test.dart
```

This repair needs only a rebuilt web client. The supporting email-sync function
does not need redeployment if it was deployed for the previous profile update.
