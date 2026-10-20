# School updates: sections, external grades and verified student registration

## Enrollment and section counts

`enrollments/{courseId}_{studentId}` is the membership record. New section-code
joins already store `sectionId`; new invitation acceptances now store the course's
original `classCode` as `sectionId`. Older rows without a section are interpreted
as Original Section without bulk-writing live data. They are not assigned to an
arbitrary new section. Use **Section > Transfer enrolled student** to move them.

Course counts, section counts and section lists deduplicate active memberships by
student UID, preferring the deterministic enrollment document when duplicates
exist. The roster retains section fields. Section views listen for enrollment
changes and refresh their lists/counts after joins and transfers.

```dart
await CourseSectionService().assignStudent(
  courseId: courseId, sectionId: sectionId, studentId: studentUid,
);
```

| Collection/document | Relevant fields |
| --- | --- |
| `courses/{courseId}` | `instructorId`, `classCode`, `status` |
| `courseSections/{sectionId}` | `courseId`, `instructorId`, `classCode`, `name`, `identifier`, `status` |
| `enrollments/{courseId}_{studentId}` | `courseId`, `studentId`, `sectionId`, `status`, `studentName`, `studentCampusId`, `enrolledAt` |

The displayed student count is derived from memberships; no separate counter can
drift out of sync. No new composite index is needed by the added queries.

## Manual Google Forms grades

Open **Instructor > Grades & Feedback > Manual Grade Input**, select the external
assessment, find the student, and enter a score and optional feedback. The roster
is available even when no Forms webhook/submission exists. The score must be
between zero and the assessment's configured `totalPoints`; zero and fractional
scores are supported. Saving a Google Forms grade also marks that student's
response Complied. Correct a saved score through the same manual grading action.

```dart
await AssessmentSubmissionService().saveManualGrade(
  assessmentId: assessmentId, studentId: studentUid,
  score: 17.5, feedback: 'Reviewed against the Google Forms response.',
);
```

The `manual-grade` function requires Firebase Auth, App Check, an active
instructor who owns the course, and an active student enrollment in the correct
section. It accepts published/closed external assessments only. It does not
override AI-generated quiz or artifact grading. Clients cannot directly write
scores. The Google Forms webhook now preserves manual grades, including when
the webhook and manual save race.

| Collection/document | Fields written |
| --- | --- |
| `assessmentSubmissions/{assessmentId}_{studentId}` | Existing identity fields plus `score`, `totalPoints`, `percentage`, `status: graded`, `gradingMode: manual`, `gradeSource: instructor_manual`, `feedback`, `gradedBy`, `gradedAt`, `updatedAt`, `manualGradeVersion` |
| Google Forms submission fields | `submissionType: google_form`, `submissionSource: instructor_verification`, `complianceStatus: complied`, `verifiedBy`, `verifiedAt` |
| `assessmentSubmissions/{id}/gradeHistory/{revisionId}` | `previousScore`, `score`, `totalPoints`, `feedback`, `gradedBy`, `gradedAt` (server-only audit trail) |
| `notifications/{id}` | Student grade notice, committed atomically with the grade |

The existing student progress calculator reads these same graded submissions.
The student progress and module screens now listen for score updates. No second
gradebook collection or migration is required.

## Department and program dropdowns

Student registration uses the exact mapping supplied in the request. The program
selector stays disabled until a college is selected and resets when the college
changes. Instructor position/program entry remains unchanged.

Catalogs are in `lib/config/academic_catalog.dart` and
`supabase/functions/_shared/academic_catalog.json`. Client/server parity is
checked by `test/school_domain_check.dart`. The backend rejects invalid pairings.

## Email verification

New self-registered students use their real email in Firebase Authentication.
Campus-ID login is preserved by the existing `campus-login` lookup; no password
or UID migration is required for new accounts. Existing active users are not
forced through a new verification process.

1. Firebase creates the email/password identity.
2. `student-registration` atomically reserves the campus ID and writes its
   profile as `pending_verification`. It rejects duplicate campus IDs, including
   older synthetic-email identities.
3. Firebase sends its native email confirmation link. If delivery fails, the
   verification screen provides Resend. A retry of an interrupted registration
   can resume using the same email and password without deleting the account.
4. Pending users may authenticate only to their verification screen. Firestore
   denies course/grade/dashboard data until verification and activation.
5. The verification screen reloads Firebase Auth, refreshes the ID token, and
   calls the activation endpoint. It checks immediately, on return to the app,
   every 10 seconds while open, or when **I have verified my email** is clicked.
6. The backend requires both the Auth record and ID token to verify the same
   real email before changing `pending_verification` to `active`. Suspended or
   denied profiles cannot be reactivated by this flow.

| Document | Added/changed fields |
| --- | --- |
| `users/{uid}` for new students | `authEmail` and `email` contain the real email; `status: pending_verification`; `emailVerificationRequired: true`; `emailVerifiedAt: null`, later a server timestamp |
| `campusLoginIds/{campusId}` | `uid`, `updatedAt`; reserved transactionally, accessible to trusted backend only |

The rules prohibit client profile creation/self-activation, protect verification
fields, and require `email_verified` plus a matching token email for these new
students. Profile reads for the pending user's own verification screen remain
allowed. The legacy `/student_dashboard` URL also passes through SessionGate.

This implements email ownership verification at registration, not a second
authentication factor on every login. It uses Firebase-native email, not SMS MFA
or another email provider. No new server secrets are needed; the functions use
the existing `FIREBASE_SERVICE_ACCOUNT_JSON` secret.

## Deployment

No production deployment was performed as part of the local implementation.
From the project root in PowerShell:

```powershell
.\scripts\deploy-school-updates.ps1
.\scripts\build-vercel.ps1
npx.cmd vercel deploy --prebuilt
```

The default backend script deploys the two new functions and updates the webhook.
It stops on failure and defers the rules so the old production signup flow keeps
working while you test the preview. After preview acceptance tests, run:

```powershell
.\scripts\deploy-school-updates.ps1 -RulesOnly
npx.cmd vercel promote YOUR_TESTED_PREVIEW_URL
```

Coordinate those final commands: older self-registration code cannot create
active student profiles after the tightened rules are deployed. The rules enforce
verification against direct API attempts; the preview's verification UI/backend
can be tested before that final rules change.

Allow the new preview hostname on the production reCAPTCHA key as before. After
testing, promote the tested preview with `npx.cmd vercel promote PREVIEW_URL`.

Acceptance checks:

- Join a new section, accept an original-section invitation, and transfer a
  student. Compare course counts, section counts and the section roster.
- Enter a Google Forms grade before any webhook, then correct it. Confirm that
  the student sees the new score, totals and grade notification.
- Change a selected college and ensure a previously selected program clears.
- Register with a real test inbox. Before confirmation, verify that direct
  dashboard URLs and course reads are blocked. Confirm the link, return to the
  app, and check that the same UID becomes active and campus-ID login works.
- Check duplicate campus IDs and that a suspended account cannot self-activate.

Focused checks included in the repository:

```powershell
dart test/school_domain_check.dart
deno test --no-config supabase/functions/manual-grade/policy_test.ts supabase/functions/student-registration/policy_test.ts
# With a local emulator running with firestore.rules on port 8189:
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8189'
node test/firestore_school_rules.mjs
```

The rules suite refuses non-local hosts and uses only the disposable
`demo-caslms-school-check` project. It never targets production data.
