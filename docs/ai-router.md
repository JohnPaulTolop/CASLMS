# AI router implementation and rollout

## Decision

Keep the existing Gemini integration for native media. Add one authenticated,
server-side text router for Groq primary + Gemini backup for campus text requests.
NVIDIA remains an optional separately gated integration. Do not assume that a
larger model is faster or better. Measure both using real lesson-plan, summary,
and quiz prompts before enabling NVIDIA for users.

## Request path and scope

- Flutter -> `ai-router` Supabase function -> server-selected model.
- Instructor teaching chat streams text into its existing chat bubble.
- Learner record summaries stream too, but use Gemini only. The existing scoped
  Firestore queries and deterministic record answers remain responsible for
  account isolation. No database tools are exposed to any model.
- Administrative record summaries use Gemini only.
- Extracted TXT/DOCX/PPTX/XLSX text summaries and quizzes use the router when
  enabled. Input over 32,000 characters is rejected with a request to split the
  source; it is not silently truncated.
- Native PDF/image/video inputs continue through Firebase AI Logic. A text-only
  NVIDIA model is never given those native media requests.
- Model-generated rubrics, quiz drafts and feedback remain drafts. Final grades
  still use the deterministic semester engine and instructor posting action.

## Budgets and routing

| Workload | Output budget | First upstream text deadline | Total per-provider deadline |
| --- | --- | --- | --- |
| Teaching chat | 600 tokens | 12 s | 35 s |
| Record summary | 600 tokens | 12 s | 35 s |
| Material summary | 1,200 tokens | 25 s | 45 s |
| Quiz | 500 + 300 per question, max 10,000 | 25 s | 55 s |

Output budgets may include reasoning tokens depending on the model. Gemini uses
LOW thinking; optionally configure a supported NVIDIA reasoning effort. An
output cap does not guarantee wall-clock speed. Reasoning-heavy NVIDIA models
can exhaust a small budget before producing an answer. Test the chosen model.

Teaching history is limited to six previous turns, 1,500 characters each, with
failed/unanswered turns normalized. Total teaching input is capped at 18,000
characters. Other text inputs are capped at 32,000. These are character caps,
not exact token counts; prompt/input tokens are still charged by providers.

Each provider gets at most one attempt. HTTP 408, 429, 5xx, network failure and
deadline expiry can switch to the second configured provider before any answer
text is emitted. Failures establish a cooldown shared through Firestore,
honoring Retry-After seconds/date when present (default 60 s, max 24 h).
Authentication errors, invalid requests and safety blocks do not switch.

Once text is displayed, never splice in another model. Report an interrupted
answer instead. The UI reports output truncation explicitly. Quiz JSON is
buffered and validated for exact question count, four nonempty options, valid
answer indices and required fields; an incomplete draft is never published.

The client does not silently bypass gateway quota/auth errors using the old
Firebase path. Native-media Gemini requests have one attempt, a 75-second
client wait, LOW thinking, and task output caps. The SDK timeout stops waiting;
it does not guarantee upstream work is cancelled or unbilled.

## Server authorization and persistence

Firebase Auth + App Check verification precedes access. Only active accounts
meeting configured email-verification requirements are admitted. Students can
request record summaries only; teaching/material/quiz actions require instructor
or administrator role. Client input cannot set API keys, URLs, models, system
instructions or output limits.

Firestore collections (server Admin SDK only; existing default-deny rules apply):

| Collection | Fields and purpose |
| --- | --- |
| `aiUsage/user_{SHA256(uid)}_{UTC-day}` | `minute`, `count`, `daily`, `leaseId`, `leaseUntil`, `expiresAt` |
| `aiUsage/project_{UTC-day}` | Shared minute/day request counters and `expiresAt` |
| `aiProviderState/{SHA256(provider/model)}` | `until` cooldown timestamp and `expiresAt` |

Defaults: 6 requests/minute and 40/day per user; 30/minute and 500/day across the
project. One in-flight request per user is reserved transactionally, with a
120-second lease for crash recovery. Each admitted logical request counts once,
including failed requests; upstream attempts can be two per logical request.
A model's own provider quota can be lower than these app limits.

Counters and cooldowns store no prompts, answers, passwords or API keys. Responses
use no-store. Day boundaries use UTC. `expiresAt` is a normal field: without a
separately configured TTL policy it does not automatically delete documents.
The collections use a few reads/writes per request; monitor Firestore Spark
usage. Lower project limits if needed. No new Firestore index is required.

## Configuration (server secrets, never Flutter config)

Set these at the Supabase project's Edge Functions -> Secrets page:
https://supabase.com/dashboard/project/jymjlterjhznsxrwpjqz/functions/secrets

| Secret | Value |
| --- | --- |
| `AI_ROUTER_ENABLED` | `true` after configuration |
| `GEMINI_API_KEY` | Server Gemini Developer API key; not a Firebase ID token |
| `AI_GEMINI_MODEL` | Model available to that key; default `gemini-3.7-flash` |
| `AI_GEMINI_THINKING_LEVEL` | Default `LOW`; use a value supported by the selected model |
| `NVIDIA_API_KEY` | NVIDIA hosted API key |
| `AI_NVIDIA_MODEL` | Exact model ID from its NVIDIA catalog API example; no invented default |
| `AI_NVIDIA_ENABLED` | `true` to opt in; otherwise NVIDIA is not called |
| `AI_PRIMARY_PROVIDER` | `nvidia` (default order) or `gemini` |
| `AI_NVIDIA_USAGE` | `prototype` or `production`, matching the actual service entitlement |
| `AI_PROTOTYPE_UIDS` | Comma-separated Firebase UIDs of internal testers; mandatory to admit NVIDIA prototype calls |
| `AI_NVIDIA_BASE_URL` | Production: explicitly configure an HTTPS OpenAI-compatible NIM `/v1` base URL whose service terms permit production. Prototype: defaults to the NVIDIA API catalog endpoint. |
| `AI_NVIDIA_REASONING_EFFORT` | Optional; only set if the NVIDIA model supports it |

Optional limits: `AI_USER_RPM`, `AI_USER_DAILY`, `AI_PROJECT_RPM`,
`AI_PROJECT_DAILY`. Invalid settings revert to bounded defaults. The function
reuses the existing `FIREBASE_SERVICE_ACCOUNT_JSON` secret.

For the NVIDIA free trial, use `prototype` and only internal tester UIDs in a
private preview with non-sensitive sample teaching material. NVIDIA trial access
is not a free production backend. Set `production` only when the selected
endpoint/service terms permit production. Production mode additionally requires an explicit `AI_NVIDIA_BASE_URL`. Neither flag grants an entitlement.
Student/admin record summaries never go to NVIDIA or Groq regardless of these flags.

## Campus Groq configuration

Use a Groq **Free** account and a Gemini **Free** project if zero provider spend
is required. The router cannot detect billing-plan changes or guarantee free
capacity; provider limits are shared across the campus. Do not upgrade billing.
When both providers are at capacity, return a temporary-unavailability message.

| Supabase secret | Value |
| --- | --- |
| `GROQ_API_KEY` | The key generated in Groq Console (not xAI/Grok) |
| `AI_GROQ_ENABLED` | `true` |
| `AI_PRIMARY_PROVIDER` | `groq` |
| `AI_GROQ_CHAT_MODEL` | `openai/gpt-oss-20b` (default for teaching chat and text summaries) |
| `AI_GROQ_QUIZ_MODEL` | `openai/gpt-oss-120b` (default for quizzes) |
| `GEMINI_API_KEY` | Gemini Developer API key for the backup |
| `AI_GEMINI_MODEL` | A model currently available on that project's free tier |
| `AI_ROUTER_ENABLED` | `true` |
| `AI_NVIDIA_ENABLED` | `false` |

No tester UID list is required for Groq; existing active-account, role and App
Check checks still apply. Groq is chosen ahead of Gemini unless primary is
explicitly Gemini. While Groq is configured, NVIDIA is excluded from that route.
No Groq configuration means the older NVIDIA/Gemini configuration still works.

Groq uses a fixed HTTPS endpoint, LOW reasoning effort, bounded output, and
excludes GPT-OSS reasoning from responses. Teaching chat streams. Quizzes use
streaming JSON object mode followed by full server-side quiz validation; this
is not the strict JSON-schema feature (which does not support streaming).
No question draft is delivered until its count, choices and indices validate.
JSON validation does not establish factual correctness. Instructor review is
required. Native PDF/image/video inputs still use the existing Gemini path;
automatic Groq fallback applies to text requests, not native media requests.

429/408/5xx, network failures and deadlines can fall back once, before visible
output. Retry-After establishes a shared provider/model cooldown. Auth failures,
safety rejections and invalid quiz JSON do not trigger provider switching.
An interrupted visible stream is reported as incomplete, never mixed with a
different model. API keys and model settings remain on the server.

Deploy and build using the PowerShell activation steps below, then test an
instructor teaching chat and a short quiz from extracted text in the preview.
Automated tests use simulated providers; they do not verify the saved secret,
live model availability, provider latency or your free-tier account status.

Model selection is a server setting. Start with a non-reasoning instruct model
available in your account, compare it against Gemini, then choose the better
result. This implementation intentionally does not claim an untested NVIDIA
model is faster or more accurate.

## PowerShell activation

1. Configure server secrets above. Do not paste keys into chat or commit them.
2. Deploy the new function (Firebase verification is done inside it):

```powershell
cd C:\caslms-main
.\scripts\deploy-ai-router.ps1
```

3. Build an explicitly enabled preview:

```powershell
flutter pub get
.\scripts\build-vercel.ps1 -EnableAiGateway
if ($?) { npx.cmd vercel deploy --prebuilt }
```

Local development:

```powershell
flutter run -d edge --dart-define-from-file=config/local.json --dart-define=CASLMS_AI_GATEWAY_ENABLED=true
```

The new router is OFF by default in both server and Flutter builds. Builds without
`-EnableAiGateway` keep the existing Firebase provider, with new output caps,
streaming chat and bounded material requests. If your production JSON explicitly
sets `CASLMS_AI_GATEWAY_ENABLED`, remove or change it when reverting.

Rollback: rebuild without `-EnableAiGateway` (and remove a JSON override) before
disabling `AI_ROUTER_ENABLED`; otherwise an already-enabled client will report
unavailability. Disabling only `AI_NVIDIA_ENABLED` immediately routes text to
Gemini when its server key is configured.

## Acceptance checks before production

- Authenticate as an internal instructor tester and see a response arrive in chunks.
- Confirm native media processing, 5/10/15-question drafts, and record views work.
- Test a short-lived primary 429/503 in a test environment: Gemini answers once.
- Verify primary 401/403 or safety rejection does not call the backup.
- Interrupt a stream after some visible text: show an incomplete-answer error.
- Submit an oversized input or exceed per-user limits: show a clear limit message.
- Ask the same representative prompts of both models. Compare time to first text,
  total time, factual accuracy, rubric adherence and quiz validity. These measures
  have not yet been collected against live provider credentials.
- Verify the private prototype configuration never admits non-tester NVIDIA calls.
- Check two accounts cannot read each other's Firestore record scopes.

Automated checks: `deno test supabase/functions/ai-router/engine_test.ts`,
`deno check --node-modules-dir=manual ai-router/index.ts` from `supabase/functions`,
and Dart analysis of updated services/screens. Real provider credentials and
browser integration are required for the final end-to-end acceptance run.

## References checked during implementation

- https://docs.api.nvidia.com/nim/reference/llm-apis
- https://docs.nvidia.com/nim/large-language-models/latest/troubleshooting/requests.html
- https://ai.google.dev/api/generate-content
- https://firebase.google.com/docs/ai-logic/model-parameters
- https://firebase.google.com/docs/ai-logic/thinking
- https://assets.ngc.nvidia.com/products/api-catalog/legal/NVIDIA%20API%20Trial%20Terms%20of%20Service.pdf
