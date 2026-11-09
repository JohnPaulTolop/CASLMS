# Calendar handoff

The app currently uses **temporary, in-memory events** by default. Sample events are labeled. Staff can add/edit/delete temporary events, with no event writes to Firestore. These changes are only visible in the current app instance and reset on browser/app reload. Existing authorized assessment due dates remain read-only, and Philippine national holiday dates for 2026–2027 are bundled with declaration links.

## Enable shared events later

1. Review and merge `calendar-events.rules` into the project's Firestore rules, before the catch-all deny rule. It uses the existing `isActive`, `isAdmin`, `isStudent`, `isInstructor`, `courseExists`, `ownsCourse`, and `currentUser` helpers. Publish permissions only after checking the project's deployed rules.
2. Run `test/calendar_rules_check.mjs` against a **local Firestore emulator**; it must never point at production. It merges the proposed fragment for testing and checks course ownership, enrollment, restricted student access, admin scope, updates, deletion, and field validation.
3. Build Flutter with `--dart-define=CASLMS_LIVE_CALENDAR_EVENTS=true` **only after** the rules are deployed. The normal production build keeps temporary events enabled. Do not migrate the sample events into production.

Collection: `calendarEvents`. Fields:

| Field | Type / meaning |
| --- | --- |
| title | String, 1–120 characters |
| description | String, up to 1,000 characters |
| courseId | Course ID; empty string for admin-created schoolwide events |
| startAt, endAt | Firestore timestamps, stored as UTC; displayed as Philippine time (UTC+8) |
| allDay | Boolean; inclusive end of the final day |
| ownerId | Authenticated creator UID; immutable |
| creatorRole | `admin` or `instructor`; immutable |
| createdAt | Server timestamp; immutable |
| updatedAt | Server timestamp on every write |

Events can span up to 31 days. Instructors create events only for their active owned courses. Students read schoolwide events and their actively enrolled courses' events, and cannot write. Admins can moderate all events. Queries use `courseId` equality, so no new composite index is required.

The service retains the live implementation behind the build flag. If event loading fails in live mode, coursework deadlines and holidays remain available, and event publishing is disabled until access recovers.
