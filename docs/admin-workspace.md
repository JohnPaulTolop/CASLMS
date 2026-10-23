# CAS LMS admin workspace

## Where to find the features

Desktop uses a left navigation sidebar. On smaller screens, Overview, Users and
Courses remain visible; **More** contains Instructor files, Activity logs,
Instructor approvals, Reports, AI Assistant and Settings. Existing navigation
indexes 0–5 are preserved for notification routing.

| Area | Behavior |
| --- | --- |
| Overview | Live account/course metrics, pending instructor applications, unverified students, courses missing an active instructor, recent uploads and activity, failed AI-processing alerts |
| Instructor files | Live, paginated learning-material library with course/instructor filters, page search, status chips, file details and CSV download |
| File details | Original filename, uploader, course, module, size, dates, publication and AI status; PDF/image preview; open/save the original for other formats |
| Activity logs | Separate All events, Logins, Logouts, Courses created and Files uploaded categories; server date/category filters, pagination and export |
| Users and Courses | Existing management actions remain; lists and enrollment counts now update live through the shared admin directory |
| Reports | Current record metrics and clearly labeled record snapshots; CSV now downloads instead of only copying to the clipboard |

The library lists `moduleResources` records with `deliveryType: uploaded_file`,
using the existing `createdBy`, `courseId`, `moduleId`, `fileName`, `fileUrl`,
`sizeBytes`, `status` and timestamp fields. This includes existing uploads using
the current learning-material service. Private chat attachments and profile
photos are outside this learning-material library.

The preview allows only HTTPS objects from the configured Supabase public
learning-material bucket. Image formats render directly. PDFs use an isolated
browser frame with a fallback Open original / save file action. Office files and
archives open through that action; they are not sent to a third-party conversion
service. Actual PDF embedding and downloads still need a browser smoke test.

## Activity history

The previous report inferred activity from each user's single `lastLoginAt`
value and each course's `updatedAt`. It did not contain a full login/logout
history. That inferred login list was removed from reports.

The new `activityLogs` collection stores future app events. It is necessary for
keeping multiple events instead of repeatedly replacing one timestamp. No bulk
migration or synthetic historical login records are created.

Session records:

```text
ID: login_<Firebase auth_time>_<uid> or logout_<Firebase auth_time>_<uid>
type: login | logout
actorId, actorName, actorRole
sessionAuthTime
createdAt: server timestamp
```

Source records:

```text
ID: course_created_<courseId> or material_uploaded_<resourceId>
type: course_created | material_uploaded
actorId, actorName, actorRole
targetId, courseId, title
occurredAt: original source creation timestamp
createdAt: server timestamp for recording the event
```

Rules restrict reading logs to active admins. Writes must use the authenticated
account's actual profile, role, name, authentication time and a server timestamp.
Course/file events must reference a real source owned by the instructor (or an
authorized admin), with the exact title, course and original creation time.
Clients, including admins, cannot update or delete log records. Deterministic
IDs prevent a retry from overwriting the original event.

These are **client-recorded application activities**, not tamper-proof identity
provider security audit logs. A malicious/old/offline client can omit an event.
Logging failures cannot block sign-in, course creation or uploads. Logout records
are explicitly labeled **Logout requested**, since they are written before the
Firebase session is cleared. Logging waits at most three seconds before allowing
logout to continue. Closing a browser is not an explicit logout and is not
recorded as one. Restoring an existing session or refreshing a token is not
recorded as a new sign-in. No passwords, Firebase tokens or AI keys are logged.

## Queries and performance

- One shared admin catalog listens to users, courses and pending applications.
  Existing Users/Courses pages reuse it instead of repeating directory queries.
- The enrollment listener starts when Courses is opened. Active students are
  deduplicated per course; a student enrolled in two courses counts in each.
- Extra screens start on first use, preserving the existing IndexedStack behavior
  without loading every admin report and AI screen at startup.
- Files use 40 records per page plus one look-ahead record; logs use 50 plus one.
  Pagination cursors include creation time and document ID for stable ordering.
- Course/instructor file filters and event/date log filters apply to the server
  query. Text search and file status chips apply only to the current page and
  are labeled accordingly. Exports contain the visible matches on that page.
- Five composite index definitions are added. Existing cloud indexes must be
  retained. Listeners are cancelled on disposal; retrying the directory cancels
  old subscriptions before attaching replacements.
- No new paid service, Cloud Function, or Supabase secret is required. Normal
  Firebase Spark and Supabase quotas still apply.

## Rollout from VS Code PowerShell

First deploy the updated rules **and indexes**:

```powershell
cd C:\caslms-main
.\scripts\deploy-admin-updates.ps1
```

If Firebase CLI asks to delete cloud indexes that are absent from the local file,
choose **No**. Keep existing indexes used by the rest of the LMS. Wait for the
new indexes to reach Ready/Enabled in Firestore before testing the new library
filters and log categories.

Then analyze and create a fresh preview using the existing production config:

```powershell
flutter analyze
```

```powershell
& {
    $ErrorActionPreference = 'Stop'
    Set-Location -LiteralPath C:\caslms-main
    .\scripts\build-vercel.ps1 -EnableAiGateway
    npx.cmd vercel deploy --prebuilt
    if ($LASTEXITCODE -ne 0) { throw 'Vercel preview deployment failed.' }
}
```

This change needs no Supabase function deployment. After testing the new preview,
promote its actual URL to production:

```powershell
npx.cmd vercel promote https://YOUR-NEW-PREVIEW.vercel.app
```

## Verification

Completed locally: 34 admin authorization/history checks, 29 metadata/export/count checks, and 76 existing enrollment, notification and school-authorization checks passed (139 total). Full source analysis reported no errors; 13 existing warnings/lint notices remain in other files. A Flutter web build and authenticated browser test were not run because this environment cannot write the Flutter SDK cache lockfile.

Automated checks use the local, disposable Firestore emulator, with project
`demo-caslms-school-check`. Each rule suite clears that demo database. Run them
sequentially, never against a real project:

```powershell
dart run test/admin_records_check.dart
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180'
node test/admin_activity_rules_check.mjs
node test/invitation_enrollment_rules_check.mjs
node test/firestore_school_rules.mjs
node test/notification_rules_check.mjs
```

The admin suite covers actor/role/name spoofing, session identity, server times,
unexpected fields, source ownership, missing sources, immutable history,
admin-only reads, category filtering and preservation after source deletion.
Helper checks cover storage URL validation, path traversal, CSV injection,
quoted/newline data, size/date formatting and unique enrollment counts.

Browser checks still required on the preview:

1. Sign in as Admin; check sidebar, mobile More navigation, notification shortcuts,
   Users, Courses, Approvals, Reports, Settings and AI Assistant.
2. In a separate instructor browser, upload a PDF and an image. Keep the admin
   library open; new records should appear with the correct course and uploader.
3. Open each file, test PDF/image preview and original save/open, then test a DOCX
   or PPTX. Change instructor/course filters, browse pages and export the page.
4. Create a course and sign out/in with instructor/student accounts. Confirm
   distinct log categories and account identities. Refreshing an existing session
   must not create duplicate login events.
5. Cancel an invitation, accept a new invitation and transfer a student. Verify
   the admin course count updates and existing student/instructor flows still work.
6. Review a pending instructor application. Confirm the overview updates. A student
   awaiting email verification must still complete verification before activation.
7. Remove a source file/course in a disposable test account and open its old log.
   The log should remain and its source action should report missing content.
8. Confirm student/instructor accounts cannot read the `activityLogs` collection.
   If the current account changes while a pushed admin file view is open, the
   access guard must replace the file view with an access-required screen.
9. Test desktop and mobile widths, keyboard activation, long names/filenames,
   failed file URLs, lost connection and retry buttons.

## Files changed for this admin update

| File | Change |
| --- | --- |
| `lib/models/admin_records.dart` | Metadata formatting, validated file URLs, safe CSV and unique enrollment counts |
| `lib/services/admin_catalog.dart` | Shared live admin directory with role validation and listener cleanup |
| `lib/services/activity_log_service.dart` | Best-effort session/source events and bounded logout logging |
| `lib/screens/admin/admin_main_page.dart` | Responsive sidebar/mobile navigation, lazy tabs, preserved notification indexes |
| `lib/screens/admin/admin_dashboard_page.dart` | Redesigned overview, live metrics, attention panels and recent records |
| `lib/screens/admin/admin_ui.dart` | Shared admin components and live access guard for pushed views |
| `lib/screens/admin/admin_files_page.dart` | Paginated/filterable instructor learning-material library |
| `lib/screens/admin/admin_file_details_page.dart` | File metadata, preview, safe original-file access and missing-file handling |
| `lib/screens/admin/admin_document_frame.dart` | Conditional document preview export |
| `lib/screens/admin/admin_document_frame_web.dart` | Isolated PDF browser frame |
| `lib/screens/admin/admin_document_frame_stub.dart` | Non-web preview fallback |
| `lib/screens/admin/admin_download.dart` | Conditional CSV download export |
| `lib/screens/admin/admin_download_web.dart` | Browser CSV file download and object URL cleanup |
| `lib/screens/admin/admin_download_stub.dart` | Non-web clipboard fallback |
| `lib/screens/admin/admin_users_page.dart` | Shared live directory; preserve management actions |
| `lib/screens/admin/admin_courses_page.dart` | Shared live courses/instructors and deduplicated live enrollment counts |
| `lib/screens/admin/admin_system_reports_page.dart` | Separate snapshot reports from real session history; downloadable safe CSV |
| `lib/screens/admin/admin_settings_page.dart` | Log explicit admin logout requests |
| `lib/screens/admin/admin_instructor_approvals_page.dart` | Formatting only; existing approval workflow retained |
| `lib/screens/instructor/instructor_profile_page.dart` | Log explicit instructor logout requests |
| `lib/screens/student/student_profile_page.dart` | Log explicit student logout requests |
| `lib/services/auth_service.dart` | Login/logout hooks for the legacy authentication path |
| `lib/services/campus_auth_service.dart` | Login/logout hooks for campus-ID authentication |
| `lib/services/instructor_course_service.dart` | Source-bound course-creation event |
| `lib/services/learning_material_service.dart` | Source-bound successful upload event |
| `firestore.rules` | Admin-only log reads and validated append-only events |
| `firestore.indexes.json` | Composite indexes for file filters and log categories |
| `scripts/deploy-admin-updates.ps1` | Rules/index deployment with failure checks |
| `test/admin_records_check.dart` | File/export/enrollment helper regression checks |
| `test/admin_activity_rules_check.mjs` | Local emulator activity-history authorization checks |
| `docs/admin-workspace.md` | This implementation and rollout guide |
