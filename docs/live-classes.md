# Embedded live classes

## Where to find it

- Instructor: Course > Section > video-camera button (Live Classes).
- Student: Course > video-camera button (Live Classes). The server selects the
  student's enrolled section; request parameters cannot select another section.
- Instructor enters a title, starts the class, then joins. Students can join once
  it is live. The classroom stays embedded in the Flutter page.
- Both roles have camera/mic controls, sound enable, participant list and Leave.
  The instructor can share a screen and end the class for everyone. Students'
  tokens permit camera/mic publishing only; hiding screen-share is not the sole
  enforcement. Recording and data-channel chat are disabled for this version.

## Classroom interface

The lobby shows the course and section, a live/starting/ending state, reserved
student places, and a role-specific start or join action. A short preparation
panel explains microphone/camera defaults, sound, and reconnecting. Its panels
stack on smaller screens.

Inside the room, circular labeled controls show microphone/camera state. The
participant panel supports search, a close button, and Escape with focus returned
to the participant toggle. The active speaker is highlighted; instructor tiles
have a distinct background. Connection badges distinguish connecting,
reconnecting, disconnected, and connected states. Screen sharing gives the
presentation more space. Transitions respect reduced-motion preferences.

Ending a session requires confirmation. The classroom route and any open
confirmation close if the server reports the session has ended. Camera and
microphone still start off; the room remains limited to 30 students plus one
instructor. These interface changes require rebuilding the Flutter web preview;
they do not require changes to the LiveKit backend configuration.
## Capacity and free usage

There are **30 student places + one instructor** per section's live session.
Places are reserved on first admission for the entire session; leaving does not
release a place to a different student. Rejoining with the same Firebase UID
retains that place. Multiple tabs use the same LiveKit identity (they do not
create additional participant identities). End and start a new session to reset
the 30-student roster. Admission is a Firestore transaction, so simultaneous
requests for the last place cannot both succeed. LiveKit also caps the room at
31 participants. Client parameters cannot increase either limit.

The published free Cloud allowance is shared across the project: 100 concurrent
participants, 5,000 participant-minutes/month and 50 GB downstream/month. A
one-hour class with 30 students plus the teacher uses 1,860 participant-minutes;
bandwidth can run out earlier. This implementation does not bypass those limits.
Camera defaults are 360p with adaptive subscriptions/simulcast to reduce use.

## LiveKit setup required before calls work

1. Create a free Build project at https://cloud.livekit.io/.
2. Obtain its project WebSocket URL (`wss://YOUR-PROJECT.livekit.cloud`), API key
   and API secret. This integration targets LiveKit Cloud and its token
   revocation support; it does not silently connect to a public shared room.
3. In https://supabase.com/dashboard/project/jymjlterjhznsxrwpjqz/functions/secrets
   add these **server secrets**:

   | Name | Value |
   | --- | --- |
   | `LIVEKIT_URL` | Project WebSocket URL |
   | `LIVEKIT_API_KEY` | Project API key |
   | `LIVEKIT_API_SECRET` | Project API secret |

   Keep the existing `FIREBASE_SERVICE_ACCOUNT_JSON`. Do not put LiveKit keys in
   Dart defines, public JSON, Flutter source, Vercel frontend variables or chat.
   Avoid passing secrets on the CLI where they enter terminal history.
4. Disable automatic room creation in LiveKit project settings where available.
   The backend explicitly creates each room with capacity 31. Never give browser
   tokens room-create, room-admin, recording or metadata-update grants.
5. Run in PowerShell:

   ```powershell
   cd C:\caslms-main
   flutter pub get
   .\scripts\deploy-live-classes.ps1
   .\scripts\build-vercel.ps1
   npx.cmd vercel deploy --prebuilt
   ```

6. Allow that preview hostname on your existing reCAPTCHA Enterprise key. Test
   from two separate browser profiles/devices, one instructor and one student.
   Use HTTPS for deployed calls; localhost is supported for development with
   your existing App Check debug setup.
7. After testing, promote the preview as usual:

   ```powershell
   npx.cmd vercel promote YOUR_TESTED_PREVIEW_URL
   ```

No Firebase plan upgrade, new Firestore indexes, or changes to existing rules are
required. The `liveClasses` collection has no client access under the existing
default-deny rules. All reads/writes go through the authenticated edge function.
Missing LiveKit configuration displays a setup message instead of fake video.

## Implementation and database

`liveClasses/{sha256([courseId,sectionId])}` stores `courseId`, `sectionId`,
`instructorId`, `title`, `sessionId`, random `roomName`, `status`, `studentIds`,
`startedAt`, `updatedAt`, and `endedAt`. It stores current session state, not a
historical attendance ledger. A reserved seat is not proof of attendance.

`live-class` actions:

- `state`: Firebase ID token + App Check, active/verified profile, owned course
  or active enrollment, valid active section. Returns sanitized session state.
- `start`: owner only, atomically reserves a starting session, explicitly creates
  the provider room (31 max), then makes it live. Retries do not create parallel
  live rooms. A failed/stale start can be retried.
- `join`: repeats account/enrollment checks inside the transaction; reserves a
  student place and issues a 60-second joining token for that exact random room,
  Firebase UID, trusted name and server-selected role. The token's expiration
  controls admission; it is not a 60-second call duration limit.
- `end`: owner only, marks ending first (blocking joins), revokes all admitted
  identities in LiveKit Cloud, deletes the room, then marks ended. Failures keep
  it ending, with a retry action. Leaving alone does not end everyone's call.

Room tokens stay in memory and reach the same-origin classroom iframe through
an origin/source-checked message, never through URLs or persistent browser
storage. The bundled JS SDK is pinned to 2.23.0 with its Apache license. All
participant names are inserted as text. Camera/microphone begin off; the student
must explicitly enable devices. Browser back/dispose unloads the iframe and
stops its media. A room empty for ten minutes expires; the instructor can end
that session and start a new one.

## Validation and remaining live checks

Focused policy tests cover capacity/rejoin, role/ownership, cross-section and
cross-course denial, inactive enrollment, legacy sections, and email ownership.
Run `deno test --no-config supabase/functions/live-class/policy_test.ts`.

Additional checks:

```powershell
deno test --no-config supabase/functions/live-class/livekit_test.ts
# With the local Firestore emulator running on 8189:
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8189'
deno test --no-config --allow-env=FIRESTORE_EMULATOR_HOST --allow-net=127.0.0.1:8189 supabase/functions/live-class/admission_emulator_test.ts
# DOM behavior checks with simulated media; install test dependencies locally:
npm.cmd install --prefix .dart_tool/live-class-validation jsdom@26.1.0 --ignore-scripts --no-audit --no-fund
node test/live_classroom_dom_check.cjs
```

The admission integration check uses optimistic conditional Firestore commits
to race two new students and an existing rejoin for the final place. The SDK
transaction in the endpoint makes the same admission decision on retries.
The optional `test/live_classroom_browser_check.cjs` requires `playwright-core`
and installed Edge; browser launch was blocked by this workspace's environment,
so rendered layout and live devices still require preview verification.

Local validation completed: targeted Dart analysis (no issues), backend type
checking, six policy/provider tests, the concurrent admission emulator check,
19 Firestore access checks, and the simulated-media DOM checks. A release build
was attempted but blocked because this workspace cannot write
`C:\flutter\bin\cache\lockfile`; run the build script in your own terminal.

Before promotion verify a real two-device call with sound, permission rejection,
camera toggling, screen share start/stop, leave/rejoin, End for everyone and a
fresh new session. Also verify unauthorized/other-section users cannot join.
Load-test 30 students before promising performance for a full class. No real
LiveKit call or 30-device load test is claimed without project credentials.
