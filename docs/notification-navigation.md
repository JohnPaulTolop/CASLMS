# Clickable notification implementation

Notifications now act as named shortcuts to existing course/module, assessment,
grading, conversation and approval screens. This change uses the existing
`notifications` collection and `userId`, `sourceType`, `sourceId`, `courseId`,
`authorizationCourseId` and `moduleId` conventions. No new collection, paid
Firebase service or Firebase Cloud Function is required.

## Behavior

- Admin, Instructor and Student dashboard bells show live unread counts and a
  six-item dropdown; View all opens a searchable, shared notification history.
- The dropdown and history use accessible Material menu items/InkWell controls
  with hover, keyboard activation and unread highlighting. Opening a menu does
  not mark any notification read. Mark all read remains available in history.
- Clicks push `/notification?id=<notification document ID>` through the existing
  MaterialApp Navigator. SessionGate authenticates the role before showing that
  role's shell. A loading view resolves the target and selects the matching tab.
  Browser refresh uses the platform route, restoring a signed-in destination.
- Returning via browser/back navigation restores the previous route. Selecting a
  different role navigation tab displays that normal tab. The named notification
  URL remains a bookmark to its destination if refreshed after selecting a tab.
- Source records are loaded from the server. Checks cover recipient ownership,
  active role, course ownership/enrollment, section membership, source-to-course
  relationships and published student content. Firestore rules still apply.
- Only a successfully resolved destination is marked read. Missing or restricted
  records show a recoverable message, retaining the notification in history.
  Existing rules may conceal a deleted document as permission-denied; the UI
  cannot safely distinguish that case and shows the permission message.
- An old notice is actionable only if its IDs identify a reliable target. Titles
  and names are never used to search/guess a target.
- Stable notification IDs prevent duplicate delivery. Retrying a publication
  keeps existing read state. New message notices are atomic with their messages;
  enrollment receipts are best effort after successful invitation acceptance; submission/approval notices are
  committed with their source writes. Grade publication keeps its existing
  revision semantics.

## Destinations and producers

| Source | Destination / safeguards |
| --- | --- |
| course, enrollment | Exact student course or instructor course/sections screen |
| module | Exact published module |
| assessment | Exact assessment card in module Tasks; existing quiz start, deadline, attempt and anti-cheating logic is reused |
| moduleResource | Exact material in module Files, or filtered instructor material list |
| assignment | Existing legacy assignment detail screen |
| assessmentReceived | Instructor grading view filtered to that submission |
| submissionReceived | Exact legacy submission review, using existing grading service |
| assessmentSubmission, automaticAssessmentGrade, manualAssessmentGrade, assessmentFeedback, googleFormCompliance | Student module Grades, filtered to the assessment |
| submission | Existing assignment detail and own grade |
| semesterGrade | Correct subject/term in Posted Grades, still locked behind existing credential reveal; navigation never downloads/decrypts grades |
| announcement | Exact authoritative announcement, including all-class announcements with their existing authorization course |
| instructorApplication | Admin approvals filtered to the applicant |
| instructorStatus | Existing account gate/status; denied accounts remain disabled and cannot enter dashboards |
| conversation | Exact student/instructor conversation |
| liveClass | Specific live session through the existing authenticated live-class API; ended/replaced sessions are unavailable |

Publication producers retain their exact source IDs. Assessment delivery now
respects section-scoped activities as well as AI quizzes. New course delivery
targets only its current enrolled audience: a newly created, empty course does
not broadcast to unenrolled students. Accepting an invitation
creates the student's course shortcut. Live-start notices go to active members
of that section. Existing courses and notices are not backfilled or duplicated.
There is no standalone schedule-update notification producer in the current
project; live-class navigation is implemented for its actual start event.

Chat notices contain a generic message preview to avoid copying private message
text into an additional record. Live-class notification delivery failures are
logged without aborting a successfully started room. The existing publication
retry path can retry module notices; there is no new background queue.

## Files changed for this feature

| Area | Files |
| --- | --- |
| Target mapping and access | `lib/models/notification_target.dart`, `lib/services/notification_navigation_service.dart` |
| Shared UI | `lib/screens/shared/notification_inbox.dart`, `lib/screens/shared/notification_destination_page.dart`, `lib/screens/shared/legacy_submission_review_page.dart` |
| Routing and role shells | `lib/main.dart`, `lib/screens/session_gate.dart`, `lib/screens/admin/admin_main_page.dart`, `lib/screens/instructor/instructor_main_page.dart`, `lib/screens/student/student_main_page.dart` |
| Bell entry points | `lib/screens/admin/admin_dashboard_page.dart`, `lib/screens/instructor/instructor_dashboard_page.dart`, `lib/screens/student/student_dashboard_page.dart` |
| Shared history compatibility | `lib/screens/student/notifications_page.dart`, `lib/screens/instructor/notifications_page.dart` |
| Exact-content focus | `lib/screens/admin/admin_instructor_approvals_page.dart`, `lib/screens/instructor/instructor_assessment_grading_page.dart`, `lib/screens/instructor/instructor_module_detail_page.dart`, `lib/screens/student/student_module_detail_page.dart`, `lib/screens/student/posted_grades_page.dart` |
| Client event producers | `lib/services/notification_service.dart`, `lib/services/chat_service.dart`, `lib/services/enrollment_service.dart`, `lib/services/course_invitation_service.dart`, `lib/services/instructor_course_service.dart`, `lib/services/assignment_service.dart` |
| Server event producers | `supabase/functions/_shared/notification_payload.ts`, `supabase/functions/assessment-submission/index.ts`, `supabase/functions/instructor-approval/index.ts`, `supabase/functions/semester-grades/index.ts`, `supabase/functions/live-class/index.ts` |
| Authorization | `firestore.rules` |
| Checks and deployment | `test/notification_target_check.dart`, `test/notification_rules_check.mjs`, `scripts/deploy-notifications.ps1`, `docs/notification-navigation.md` |

Earlier AI-provider and CAS-registration changes remain separate from this list.

## Verification completed locally

- 27 source mapping, legacy fallback and invalid-ID checks passed.
- 21 notification Firestore checks passed against a local disposable emulator.
- 26 existing school Firestore access/membership checks passed afterward.
- Dart analysis of all notification-related changed files reported no issues.
- Type checks passed for assessment-submission, instructor-approval,
  semester-grades and live-class handlers. Deployment script parsing and
  whitespace checks passed.
- No live deployment or authenticated browser acceptance session was performed.

## Deploy in PowerShell

Rules must be deployed before the client, because messages now write notifications atomically and invitations carry section identifiers. The script stops immediately on failure. It uses
Firebase and Supabase CLI authentication already configured on your machine.
Supabase handlers continue verifying Firebase Auth/App Check internally.

```powershell
cd C:\caslms-main
.\scripts\deploy-notifications.ps1
```

After successful backend deployment:

```powershell
flutter analyze
.\scripts\build-vercel.ps1 -EnableAiGateway
if ($?) { npx.cmd vercel deploy --prebuilt }
```

Local browser test:

```powershell
flutter run -d edge --dart-define-from-file=config/local.json --dart-define=CASLMS_AI_GATEWAY_ENABLED=true
```

Pure ID mapping check (no Firebase credentials):

```powershell
dart run test/notification_target_check.dart
```

With the Firestore emulator listening on localhost:8180, run the existing school
access regression followed by notification authorization checks:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180'
node test/firestore_school_rules.mjs
node test/notification_rules_check.mjs
```

These scripts explicitly target a disposable demo project. Each suite clears
that demo database. The notification suite also loads current rules into the
demo project and seeds test-only IDs. Run the suites sequentially.

## Browser acceptance checklist

Use two students from different sections, one instructor and one administrator.
Use only a preview after deploying rules/functions. Real browser verification
requires account access and is not replaced by the automated model/rules checks.

1. Accept a student invitation, click the enrollment notice and verify the course ID.
2. Publish a section activity and AI quiz; only the correct section receives
   each. Click and verify the exact activity, then confirm deadline/attempt
   restrictions still run through the existing quiz controls.
3. Publish a resource and announcement; click and verify exact content.
4. Submit artifact work, a legacy assignment and an AI quiz. Verify instructor
   inbox notices open the right student's exact submission.
5. Grade work and add feedback. Verify the student's notice selects the module
   Grades tab and the right assessment. Post semester grades; click and verify
   the subject remains hidden until credential reauthentication.
6. Register an instructor, open the admin approval notice and verify only that
   applicant is shown. Review the application and verify the account gate.
7. Send a text message and attachment both ways; verify exact conversation and
   live notification badges. Start a class; verify section audience and session.
8. Open the dropdown without clicking: unread count stays unchanged. Open one
   notice: only its badge count decreases. Verify Mark all read separately.
9. Delete content, remove enrollment or change section, then try old notices.
   Verify informative failure with history preserved. Attempt another user's
   notification ID and verify denied access.
10. Refresh an opened notification URL and use browser Back. Verify the role
    shell, selected content tab and original quiz/grade restrictions persist.
