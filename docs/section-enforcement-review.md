# Section enforcement review - implementation complete, deployment pending

## Integrated enforcement

- `sectionIds: ['*']` means every active section; otherwise records contain one
  or more unique section IDs. Missing fields are supported only as legacy shared
  data. Empty, malformed, duplicate, oversized, and mixed wildcard audiences
  fail closed.
- Modules, learning materials, and assessments persist their validated audience
  during creation. A child can narrow but cannot expand its module audience.
  The existing assessment `sectionId` remains an additional restriction.
- Student module, resource, assessment, progress, calendar, roster, notification,
  AI attachment, and submission paths now intersect active enrollment with the
  stored module and child audiences. Admin SDK request handlers perform the same
  checks explicitly instead of relying on Firestore rules.
- Instructor creation screens require an explicit section audience and show the
  assigned audience separately from the section currently being viewed.
- Published parent audiences cannot be changed in place. This avoids an
  intermediate state where existing children, submissions, or cached links gain
  broader access.

## Protected learning-material storage

The `caslms-learning-materials` bucket is migrated to private storage by
`202611090001_private_learning_materials.sql`. The migration backs up matching
storage policies before removing direct client access, and a reviewed rollback
script restores the captured definitions.

- Upload authorization verifies Firebase Auth, App Check, active instructor
  status, course ownership, module ownership, active sections, and the parent
  audience before issuing a one-minute signed upload token.
- Material metadata stores the canonical bucket and path with `fileUrl: null`.
- Downloads use a five-minute signed URL issued only after role, enrollment,
  publication, and audience checks.
- Deletion is performed by the verified Edge Function; Flutter clients no longer
  remove protected material objects directly.
- Student viewers and AI attachment readers request authorized URLs instead of
  using public object URLs.

Previously downloaded copies cannot be revoked. Existing public bucket URLs stop
working only after the private-bucket migration is applied.

## Local validation completed

- Full Dart analysis: no issues.
- Shared section policy: 10 Deno tests passed.
- `assessment-submission` Edge Function: Deno type-check passed.
- Firebase notification functions: TypeScript build and ESLint passed.
- Firestore indexes: valid JSON.
- Migration and Firestore rule check scripts: Node syntax checks passed.

## Required pre-deployment gates

The implementation has not been deployed. Before production, complete the
ordered maintenance-window procedure in `section-isolation-rollout.md`, including:

1. Run the Firestore emulator rule suite and Flutter widget/regression tests in
   an environment that permits local loopback sockets and Flutter SDK cache
   writes.
2. Review the legacy audience migration report and resolve every error before
   applying it.
3. Verify signed upload, download, delete, and expiry behavior in staging.
4. Deploy indexes and wait until they are ready before deploying rules.
5. Apply the private-storage migration only after the compatible Edge Function
   and Flutter viewers are available.
6. Use dedicated 4C and 4D accounts to verify direct-ID denial, cross-section
   query denial, notification isolation, AI attachment isolation, submissions,
   and copied public URL denial.

No Firebase rules, functions, indexes, Supabase policies, bucket settings,
content records, or frontend release were changed in production by this work.
