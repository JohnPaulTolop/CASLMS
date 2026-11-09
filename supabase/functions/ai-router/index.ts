import { createHash, randomUUID } from "node:crypto";
import { caller, cors, db, RequestError } from "../_shared/firebase.ts";
import { AiError, parseInput, providers } from "./engine.ts";
import type { Provider, ProviderObservation } from "./engine.ts";
import { guardedRoute, isChat, taskAllowed } from "./chat_policy.ts";
const env = (key: string) => Deno.env.get(key)?.trim();
const number = (key: string, fallback: number, maximum: number) => {
  const value = Number(env(key) || fallback);
  return Number.isInteger(value) && value >= 1 && value <= maximum
    ? value
    : fallback;
};
const optionalNumber = (key: string, minimum: number, maximum: number) => {
  const raw = env(key);
  if (!raw) return undefined;
  const value = Number(raw);
  return Number.isInteger(value) && value >= minimum && value <= maximum
    ? value
    : undefined;
};
const decimal = (key: string, maximum = 100000) => {
  const value = Number(env(key) || 0);
  return Number.isFinite(value) && value >= 0 && value <= maximum ? value : 0;
};
const headers = {
  ...cors,
  "Cache-Control": "no-store, private",
  "X-Content-Type-Options": "nosniff",
};
const reply = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
const healthKey = (p: Provider) =>
  createHash("sha256").update(`${p.id}/${p.model}`).digest("hex");
const estimatedCost = (
  provider: Provider,
  observation: ProviderObservation,
) => {
  const prefix = `AI_${provider.id.toUpperCase()}`;
  return observation.approximateInputTokens / 1000000 *
      decimal(`${prefix}_INPUT_USD_PER_MILLION`) +
    observation.approximateOutputTokens / 1000000 *
      decimal(`${prefix}_OUTPUT_USD_PER_MILLION`);
};
const logObservation = (
  provider: Provider,
  outcome: "success" | "failure",
  observation: ProviderObservation,
) => {
  console.info(JSON.stringify({
    event: "ai_provider_attempt",
    provider: provider.id,
    model: provider.model,
    outcome,
    code: observation.code,
    task: observation.task,
    latencyMs: observation.latencyMs,
    failover: observation.failover,
    approximateInputTokens: observation.approximateInputTokens,
    approximateOutputTokens: observation.approximateOutputTokens,
  }));
};
const health = {
  async until(provider: Provider) {
    return Number(
      (await db.collection("aiProviderState").doc(healthKey(provider)).get())
        .data()?.until || 0,
    );
  },
  async success(provider: Provider, observation: ProviderObservation) {
    const ref = db.collection("aiProviderState").doc(healthKey(provider));
    const day = new Date().toISOString().slice(0, 10);
    const usage = db.collection("aiUsage").doc(`project_${day}`);
    const cost = estimatedCost(provider, observation);
    try {
      await db.runTransaction(async (tx) => {
        const [providerDoc, usageDoc] = await Promise.all([
          tx.get(ref),
          tx.get(usage),
        ]);
        const before = providerDoc.data() || {};
        const daily = usageDoc.data() || {};
        tx.set(ref, {
          provider: provider.id,
          model: provider.model,
          until: 0,
          successCount: Number(before.successCount || 0) + 1,
          failureCount: Number(before.failureCount || 0),
          rateLimitCount: Number(before.rateLimitCount || 0),
          failoverCount: Number(before.failoverCount || 0) +
            (observation.failover ? 1 : 0),
          consecutiveFailures: 0,
          totalLatencyMs: Number(before.totalLatencyMs || 0) +
            observation.latencyMs,
          approximateInputTokens: Number(before.approximateInputTokens || 0) +
            observation.approximateInputTokens,
          approximateOutputTokens: Number(before.approximateOutputTokens || 0) +
            observation.approximateOutputTokens,
          estimatedCostUsd: Number(before.estimatedCostUsd || 0) + cost,
          lastTask: observation.task,
          lastOutcome: "success",
          lastErrorCode: "",
          lastSuccessAt: new Date(),
          updatedAt: new Date(),
          expiresAt: new Date(Date.now() + 30 * 86400000),
        });
        tx.set(usage, {
          estimatedCostUsd: Number(daily.estimatedCostUsd || 0) + cost,
          approximateInputTokens: Number(daily.approximateInputTokens || 0) +
            observation.approximateInputTokens,
          approximateOutputTokens: Number(daily.approximateOutputTokens || 0) +
            observation.approximateOutputTokens,
        }, { merge: true });
      });
    } finally {
      logObservation(provider, "success", observation);
    }
  },
  async failure(provider: Provider, observation: ProviderObservation) {
    const ref = db.collection("aiProviderState").doc(healthKey(provider));
    try {
      await db.runTransaction(async (tx) => {
        const before = (await tx.get(ref)).data() || {};
        const cooldownMs = Math.max(0, Number(observation.cooldownMs || 0));
        tx.set(ref, {
          provider: provider.id,
          model: provider.model,
          until: cooldownMs > 0
            ? Math.max(Number(before.until || 0), Date.now() + cooldownMs)
            : Number(before.until || 0),
          successCount: Number(before.successCount || 0),
          failureCount: Number(before.failureCount || 0) + 1,
          rateLimitCount: Number(before.rateLimitCount || 0) +
            (observation.code === "provider_quota" ? 1 : 0),
          failoverCount: Number(before.failoverCount || 0),
          consecutiveFailures: Number(before.consecutiveFailures || 0) + 1,
          totalLatencyMs: Number(before.totalLatencyMs || 0) +
            observation.latencyMs,
          approximateInputTokens: Number(before.approximateInputTokens || 0) +
            observation.approximateInputTokens,
          approximateOutputTokens: Number(before.approximateOutputTokens || 0) +
            observation.approximateOutputTokens,
          estimatedCostUsd: Number(before.estimatedCostUsd || 0),
          lastTask: observation.task,
          lastOutcome: "failure",
          lastErrorCode: observation.code || "provider_unavailable",
          lastFailureAt: new Date(),
          updatedAt: new Date(),
          expiresAt: new Date(Date.now() + 30 * 86400000),
        });
      });
    } finally {
      logObservation(provider, "failure", observation);
    }
  },
};
async function boundedBody(request: Request) {
  if (!request.headers.get("content-type")?.includes("application/json")) {
    throw new RequestError("Use a JSON request.", 415);
  }
  if (Number(request.headers.get("content-length")) > 150000) {
    throw new RequestError("AI request is too large.", 413);
  }
  const reader = request.body?.getReader();
  if (!reader) throw new RequestError("Missing request.");
  const decoder = new TextDecoder();
  let size = 0, text = "";
  try {
    while (true) {
      const item = await reader.read();
      if (item.done) break;
      size += item.value.length;
      if (size > 150000) {
        throw new RequestError("AI request is too large.", 413);
      }
      text += decoder.decode(item.value, { stream: true });
    }
    text += decoder.decode();
    return JSON.parse(text);
  } catch (error) {
    if (error instanceof RequestError) throw error;
    throw new RequestError("Invalid JSON request.");
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
async function reserve(uid: string, requestId: string) {
  const now = Date.now(),
    day = new Date(now).toISOString().slice(0, 10),
    minute = Math.floor(now / 60000);
  const user = db.collection("aiUsage").doc(
      `user_${createHash("sha256").update(uid).digest("hex")}_${day}`,
    ),
    global = db.collection("aiUsage").doc(`project_${day}`);
  await db.runTransaction(async (tx) => {
    const [userDoc, globalDoc] = await Promise.all([
      tx.get(user),
      tx.get(global),
    ]);
    const u = userDoc.data() || {}, g = globalDoc.data() || {};
    if (Number(u.leaseUntil || 0) > now) {
      throw new RequestError(
        "An AI request is already running. Wait for it to finish.",
        429,
      );
    }
    for (
      const [record, perMinute, perDay] of [[
        u,
        number("AI_USER_RPM", 6, 60),
        number("AI_USER_DAILY", 40, 1000),
      ], [
        g,
        number("AI_PROJECT_RPM", 30, 300),
        number("AI_PROJECT_DAILY", 500, 10000),
      ]] as const
    ) {
      if (
        Number(record.daily || 0) >= perDay ||
        (record.minute === minute && Number(record.count || 0) >= perMinute)
      ) {
        throw new RequestError(
          "AI usage limit reached. Please try again later.",
          429,
        );
      }
    }
    const dailyCostLimit = decimal("AI_PROJECT_DAILY_COST_USD");
    if (
      dailyCostLimit > 0 &&
      Number(g.estimatedCostUsd || 0) >= dailyCostLimit
    ) {
      throw new RequestError(
        "AI usage limit reached. Please try again later.",
        429,
      );
    }
    const update = (record: Record<string, unknown>) => ({
      minute,
      count: record.minute === minute ? Number(record.count || 0) + 1 : 1,
      daily: Number(record.daily || 0) + 1,
      expiresAt: new Date(now + 172800000),
    });
    tx.set(user, {
      ...update(u),
      leaseId: requestId,
      leaseUntil: now + 120000,
    }, { merge: true });
    tx.set(global, update(g), { merge: true });
  });
  return async () => {
    await db.runTransaction(async (tx) => {
      const record = (await tx.get(user)).data();
      if (record?.leaseId === requestId) {
        tx.update(user, { leaseUntil: 0, leaseId: "" });
      }
    });
  };
}
const messages: Record<string, string> = {
  safety_blocked:
    "The AI could not answer this request. Try a different educational question.",
  provider_authentication_failed:
    "The AI provider configuration needs administrator attention.",
  stream_interrupted:
    "The answer was interrupted. Please retry; the displayed response is incomplete.",
  incomplete_quiz:
    "The quiz exceeded its response budget. Generate fewer questions.",
  invalid_quiz: "The AI did not return a complete valid quiz. Please retry.",
  providers_unavailable:
    "The AI Assistant is temporarily unavailable. Please try again later.",
};
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers });
  if (request.method !== "POST") return reply({ error: "Use POST." }, 405);
  let release: (() => Promise<void>) | undefined;
  try {
    if (env("AI_ROUTER_ENABLED") !== "true") {
      return reply({ error: "The AI router has not been enabled." }, 503);
    }
    const actor = await caller(request);
    const profile = (await db.collection("users").doc(actor.uid).get()).data();
    if (
      !profile || profile.status !== "active" ||
      !["student", "instructor", "admin"].includes(profile.role) ||
      profile.emailVerificationRequired === true &&
        (actor.email_verified !== true || actor.email !== profile.email)
    ) throw new RequestError("Only verified active accounts may use AI.", 403);
    const input = parseInput(await boundedBody(request));
    const routeTiming = {
      first: optionalNumber("AI_FIRST_TOKEN_TIMEOUT_MS", 1000, 60000),
      total: optionalNumber("AI_TOTAL_TIMEOUT_MS", 5000, 120000),
      backoff: optionalNumber("AI_FAILOVER_BACKOFF_MS", 0, 5000),
    };
    if (!taskAllowed(profile.role, input.task)) {
      throw new RequestError(
        "This AI action is unavailable for your role.",
        403,
      );
    }
    let available = providers(env, input.task);
    if (env("AI_NVIDIA_USAGE") === "prototype") {
      const testers = (env("AI_PROTOTYPE_UIDS") || "").split(",").map((value) =>
        value.trim()
      ).filter(Boolean);
      if (!testers.includes(actor.uid)) {
        available = available.filter((provider) => provider.id !== "nvidia");
      }
    }
    if (!available.length) {
      console.error(JSON.stringify({
        event: "ai_router_configuration_error",
        message: "No eligible provider is configured for the requested task.",
        task: input.task,
      }));
      return reply({ error: "AI providers have not been configured." }, 503);
    }
    const requestId = randomUUID();
    release = await reserve(actor.uid, requestId);
    const abort = new AbortController();
    const onAbort = () => abort.abort();
    request.signal.addEventListener("abort", onAbort, { once: true });
    if (request.signal.aborted) abort.abort();
    const cleanup = release;
    const encoder = new TextEncoder();
    const body = new ReadableStream<Uint8Array>({
      async start(controller) {
        const send = (value: unknown) => {
          if (!abort.signal.aborted) {
            controller.enqueue(
              encoder.encode(`data: ${JSON.stringify(value)}\n\n`),
            );
          }
        };
        const heartbeat = setInterval(() => {
          if (!abort.signal.aborted) {
            controller.enqueue(encoder.encode(": keep-alive\n\n"));
          }
        }, 8000);
        try {
          if (isChat(input)) send({ type: "status", stage: "checking_topic" });
          for await (
            const event of guardedRoute(
              input,
              available,
              health,
              abort.signal,
              fetch,
              routeTiming,
            )
          ) send(event);
        } catch (error) {
          if (!abort.signal.aborted) {
            send({
              type: "error",
              code: error instanceof AiError ? error.code : "unavailable",
              message: error instanceof AiError
                ? messages[error.code] ||
                  "AI could not complete this request. Please retry."
                : "AI could not complete this request. Please retry.",
            });
          }
        } finally {
          clearInterval(heartbeat);
          request.signal.removeEventListener("abort", onAbort);
          await cleanup().catch(() => {});
          if (!abort.signal.aborted) controller.close();
        }
      },
      cancel() {
        abort.abort();
      },
    });
    return new Response(body, {
      headers: {
        ...headers,
        "Content-Type": "text/event-stream",
        "X-Accel-Buffering": "no",
      },
    });
  } catch (error) {
    await release?.().catch(() => {});
    if (error instanceof RequestError) {
      return reply({ error: error.message }, error.status);
    }
    if (error instanceof AiError) {
      return reply(
        { error: "Invalid AI request.", code: error.code },
        error.status,
      );
    }
    console.error("AI gateway failed to authorize or reserve request.");
    return reply(
      { error: "AI is temporarily unavailable. Please retry." },
      503,
    );
  }
});
