# Section isolation rollout

## Stored data

New `modules`, `moduleResources`, and `assessments` documents always contain:

```json
{ "sectionIds": ["*"] }
```

for every active section, or an explicit one/many list such as
`["SECTION_4C"]` or `["SECTION_4C", "SECTION_4D"]`. Missing fields are
legacy shared records only. Empty, duplicate, malformed, over-sized, and mixed
wildcard lists are invalid. A material or assessment can narrow but cannot
expand its module audience. The existing assessment `sectionId` remains an
additional restriction.

Material metadata stores a private `storageBucket` and canonical `storagePath`.
`fileUrl` is `null`; a verified Edge Function returns a five-minute download
URL. Uploads use a verified one-minute signed upload token.

## Pre-deployment review and backup

1. Put content publishing in a maintenance window. Export Firestore using the
   project administrator session and record the export location outside this
   repository.
2. Export the `storage.buckets` row and all `pg_policies` rows for
   `storage.objects` whose `qual` or `with_check` contains
   `caslms-learning-materials`.
3. Inventory public learning-material URLs. Previously downloaded files and
   copied public objects cannot be revoked; only future access is controlled.
4. Run the migration in dry-run mode. It never guesses a legacy section:

   ```powershell
   node functions/scripts/section_audience_migration.mjs --report section-audience-report.json
   ```

5. Review every `error` and `warning`. Missing legacy module audiences become
   `['*']`. A missing child audience becomes its parent module audience, which
   preserves the legacy effective intersection. Malformed, orphaned, inactive,
   foreign, and expanding records are reported and not silently repaired.

## Deployment order

Use a maintenance window so the selector is never exposed ahead of enforcement.

1. Configure the named Edge Function secrets and deploy
   `assessment-submission`. Verify signed upload/download/delete and submission
   authorization in the staging project.
2. Deploy Firebase notification functions. Verify recipient counts for one,
   multiple, and all-section audiences.
3. Apply the reviewed legacy backfill with a new backup file:

   ```powershell
   node functions/scripts/section_audience_migration.mjs --apply --allow-production --backup section-audience-backup.json
   ```

   The script uses document update-time preconditions and stops on concurrent
   changes. Keep the backup outside source control.
4. Deploy `firestore.indexes.json` and wait until every index is `READY`.
5. Deploy `firestore.rules`, then run the production smoke checks with dedicated
   4C and 4D test accounts. Old clients fail closed once these rules are live.
6. Apply `202611090001_private_learning_materials.sql`. Review its policy backup
   table before continuing. Verify public URLs fail and authorized signed links
   expire.
7. Release the compatible Flutter web application. Verify the six instructor
   destinations, mobile/desktop layouts, creation prompts, assignment labels,
   student lists, progress, calendar, AI attachments, and submissions.
8. End the maintenance window only after cross-section direct-ID and file-URL
   denial tests pass. Monitor denied requests and notification delivery.

Commands should target the authorized project explicitly. Do not use a default
project inferred from an unrelated local session.

## Required configuration names

Edge Function secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GOOGLE_FORM_WEBHOOK_SECRET`

Migration/administrator environment names:

- `GOOGLE_APPLICATION_CREDENTIALS`
- `GCLOUD_PROJECT`
- `FIRESTORE_EMULATOR_HOST` (local validation only)

No new application secret is introduced. Firebase App Check must remain enabled
for the registered web/application clients.

## Required indexes

- `modules`: `sectionIds ARRAY`, `courseId ASC`, `status ASC`
- `moduleResources`: `sectionIds ARRAY`, `moduleId ASC`, `status ASC`
- `assessments`: `sectionIds ARRAY`, `courseId ASC`, `sectionId ASC`, `status ASC`

## Rollback

1. Re-enter maintenance mode and stop section-targeted publishing.
2. Roll back the Flutter release to the preceding compatible build.
3. Restore private-storage configuration using
   `rollback_202611090001_private_learning_materials.sql`; review the captured
   policy rows before execution. Making the bucket public again is a security
   regression and should be temporary.
4. Restore Firestore audiences only if records have not changed since the
   migration:

   ```powershell
   node functions/scripts/section_audience_migration.mjs --rollback --allow-production --backup section-audience-backup.json
   ```

   Rollback refuses any document whose current audience differs from the value
   applied by the migration.
5. Redeploy the prior Firestore rules, indexes only if required by that release,
   prior Firebase functions, and prior Edge Function.
6. If concurrent production writes prevent reversible rollback, restore the
   reviewed Firestore export into a separate recovery project first; do not
   overwrite live data blindly.
