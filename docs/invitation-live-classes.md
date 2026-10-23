# Invitation-only classes and live dashboards

## What changed

Students join through an instructor invitation. Instructors open **My Courses →
course → section → Students → Invite student**, enter the student's registered
Campus ID, and send the invitation. Pending invitations appear in that section
with a Cancel action. Course tools also offer invitations, with an explicit
section selector.

Students open **Home → Course invitations → Accept**. Their dashboard and
**My Classes** list update through Firestore snapshots, without signing out.
The newest enrollment is first, using `enrolledAt`, not the date the course was
created. Clicking a dashboard class opens that course directly.

The instructor dashboard puts courses and search above summaries and secondary
tools. Repeated create-course banners and grading shortcuts were removed.
Course counts, section rosters, pending invitations, and the modern assessment
grading count update live. The existing legacy assignment grading summary still
refreshes when loading or refreshing the dashboard.

## Why joining failed or appeared stale

- Dashboard and class pages previously loaded memberships only once. Cached tabs
  retained that old list until the user logged in again.
- Invitations previously enrolled every student into the original section,
  regardless of which section the instructor intended.
- A notification write was included in the enrollment transaction. If that
  optional write failed, it could reject an otherwise valid enrollment.

## Data and authorization

The existing collections and canonical IDs remain in use:

| Record | ID and relevant fields |
| --- | --- |
| `courseInvitations` | `${courseId}_${studentUid}`; adds `sectionId` and `sectionName` |
| `enrollments` | `${courseId}_${studentUid}`; `sectionId`, `status`, `enrolledAt`, `acceptedAt`, invitation identity |
| `courseSections` | Existing section document IDs |
| `notifications` | Existing stable enrollment receipt ID |

Acceptance atomically updates invitation status and membership. An existing
inactive membership is replaced with the validated enrollment fields, so stale
metadata does not break the allowed-field checks. An already-active membership
in the same section retains its original join timestamp. Repeating an already
successful acceptance returns success without creating another enrollment.

The enrollment notification is sent separately, best effort, after acceptance.
Its stable ID prevents duplicates, and a notification failure cannot roll back
membership.

Rules require an instructor-issued pending invitation that becomes accepted in
the same operation, the exact student, the exact course and section, and active
course/section status. Students cannot retarget invitations, replay used
invitations, or transfer themselves between active sections. Instructor transfers
remain available.

Older invitations without section metadata resolve to the original section.
Existing enrollments remain intact. No bulk migration or collection is added.
The old internal `classCode` values remain as legacy identifiers, but students
cannot enroll by code through the UI, service, or Firestore rules. Admin account
management remains unchanged.

`LiveCoursesService` shares membership/course listeners between Home and
My Classes, and between the instructor dashboard and courses page. Listeners
are cancelled when consumers are disposed; per-course listeners are removed
when membership or course ownership changes. No polling, paid Firebase service,
or Supabase backend change is introduced. Normal Firestore read quotas apply.

The student dashboard renders its classes independently from assessment-summary
loading, so a failed secondary summary cannot hide newly joined classes.

## Files changed for this fix

| File | Purpose |
| --- | --- |
| `firestore.rules` | Exact-section invitation acceptance; disable self-enrollment by code; prevent replay/self-transfer |
| `lib/models/course_order.dart` | Enrollment-date ordering with legacy timestamp fallbacks |
| `lib/services/live_courses_service.dart` | Shared live class feeds and roster counts |
| `lib/services/course_invitation_service.dart` | Section metadata, pending-invitation stream, acceptance repair, independent receipt |
| `lib/services/enrollment_service.dart` | Disable code joining; live student courses; newest-joined ordering |
| `lib/services/instructor_course_service.dart` | Live instructor course API |
| `lib/screens/student/student_dashboard_page.dart` | Live memberships/invitation count; class-first layout; direct course opening; remove code sheet |
| `lib/screens/student/modules_page.dart` | Live My Classes with progress enrichment and stale-load protection |
| `lib/screens/student/student_course_invitations_page.dart` | Live pending invitations and visible destination section |
| `lib/screens/instructor/invite_student_dialog.dart` | Shared invitation form with section selection and validation |
| `lib/screens/instructor/instructor_dashboard_page.dart` | Live courses/counts and assessment summary; simplified actions/layout |
| `lib/screens/instructor/instructor_classes_page.dart` | Live instructor courses/counts |
| `lib/screens/instructor/instructor_course_sections_page.dart` | Avoid missing the initial membership snapshot |
| `lib/screens/instructor/instructor_section_details_page.dart` | Invite directly into the section; live pending list/cancellation; remove code chip |
| `lib/screens/instructor/instructor_class_details_page.dart` | Live roster/invitations; shared section-aware dialog; remove public code labels |
| `lib/screens/instructor/instructor_create_course_page.dart` | Invitation-only enrollment instructions |
| `lib/screens/instructor/instructor_main_page.dart` | Preserve the live courses page instead of recreating it on every tab selection |
| `lib/screens/shared/role_navigation_bar.dart` | Student Modules destination renamed My Classes |
| `lib/screens/shared/caslms_help_page.dart` | Updated invitation-only help steps |
| `test/invitation_enrollment_rules_check.mjs` | 29 local-emulator invitation/membership checks |
| `test/firestore_school_rules.mjs` | Existing regression checks now expect code joining to be denied |
| `test/course_order_check.dart` | 8 enrollment-order/timestamp checks |
| `docs/notification-navigation.md` | Correct enrollment-receipt and invitation documentation |
| `docs/invitation-live-classes.md` | This implementation and rollout guide |

## Validation performed

- 29 invitation/enrollment rule checks passed against a disposable local emulator.
- 26 existing school authorization checks passed, including grade privacy.
- 21 existing notification ownership/deduplication checks passed.
- 8 course-order checks passed.
- Dart analysis of all `lib` source reported no errors. The 14 remaining findings
  are in other files (2 unused-field warnings and 12 lint/deprecation notices).
- A full Flutter web build/browser session was not run here: the execution
  environment cannot write the Flutter SDK's cache lockfile. Run the commands
  below in your normal PowerShell session.

## Local testing in VS Code

```powershell
cd C:\caslms-main
flutter analyze
dart run test/course_order_check.dart
flutter run -d edge --dart-define-from-file=config/local.json
```

Use your existing local build configuration. Do not create an empty config or
replace production App Check settings. If `config/local.json` is absent, restore
your local configuration first.

For emulator regression tests, start a local Firestore emulator with the updated
rules. The suites only accept localhost and use the disposable
`demo-caslms-school-check` database, which they clear. Run sequentially:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180'
node test/invitation_enrollment_rules_check.mjs
node test/firestore_school_rules.mjs
node test/notification_rules_check.mjs
```

## Rollout

Deploy rules **before** publishing the client. The updated invitation documents
include fields that the old rules reject. This fix needs rules and a web build;
there is no Supabase function redeployment for this change.

Run the following block in your normal PowerShell terminal. The guards prevent
deploying an old prebuilt output if a required step fails:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    Set-Location -LiteralPath C:\caslms-main
    npx.cmd firebase-tools deploy --only firestore:rules --project soloapp-52a6b
    if ($LASTEXITCODE -ne 0) { throw 'Rules deployment failed.' }
    .\scripts\build-vercel.ps1 -EnableAiGateway
    npx.cmd vercel deploy --prebuilt
    if ($LASTEXITCODE -ne 0) { throw 'Preview deployment failed.' }
}
```

`-EnableAiGateway` retains the AI router used in the current application. Keep
your existing production configuration file and App Check setup.

Test the preview using two separate browser profiles, one instructor and one
student. Once it passes, promote that **new** preview:

```powershell
npx.cmd vercel promote https://YOUR-NEW-PREVIEW.vercel.app
```

## Two-account browser acceptance checks

1. Instructor opens a non-original section and sends an invitation to a student's
   Campus ID. The section shows the pending invitation.
2. Without refreshing, the student sees the dashboard invitation count increase
   and the invitation appear in the invitations screen with the correct section.
3. Student accepts. Without logging out or reloading, return to Home: the course
   is first in My Classes, also appears in My Classes navigation, and opens the
   correct course when clicked.
4. Instructor keeps the section open: pending invitation disappears, roster gains
   the student, and section/course counts update automatically.
5. Instructor cancels a second invitation while the student's invitations screen
   is open: it disappears automatically. A stale acceptance cannot enroll.
6. Attempt to accept a stale/deleted/archived invitation: show an error without
   creating a membership. Verify other student accounts do not receive it.
7. Instructor transfers the student between sections: both section rosters update;
   the student's enrollment remains one course and retains its join date.
8. There is no Join Section with Code action. Previously enrolled students remain
   enrolled, including those whose older membership used a code.
9. Navigate away and back to courses, use mobile widths, and verify the dashboard
   has one create-course entry, clear section invitations, and no duplicate
   grading banners. Submit/grade a modern assessment to confirm its dashboard
   To Grade count updates live.

These browser checks still need to be run against the new build with real test
accounts; emulator authorization tests do not substitute for UI testing.
