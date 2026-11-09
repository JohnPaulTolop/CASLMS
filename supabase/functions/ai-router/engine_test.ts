import assert from "node:assert/strict";
import {
  AiError,
  outputLimit,
  parseInput,
  providers,
  route,
  sse,
  validateQuiz,
} from "./engine.ts";
import type { Health, Input, Provider } from "./engine.ts";
const input: Input = {
  task: "teaching_chat",
  messages: [{ role: "user", content: "Explain networks" }],
};
const nvidia: Provider = { id: "nvidia", model: "test/model", key: "test-key" },
  gemini: Provider = { id: "gemini", model: "test-gemini", key: "test-key" };
function state() {
  const times = new Map<string, number>();
  const observations: Array<{ provider: string; outcome: string }> = [];
  return {
    times,
    observations,
    async until(p: Provider) {
      return times.get(p.id) || 0;
    },
    async success(p: Provider) {
      observations.push({ provider: p.id, outcome: "success" });
    },
    async failure(p: Provider, observation) {
      observations.push({ provider: p.id, outcome: "failure" });
      if (observation.cooldownMs) {
        times.set(p.id, Date.now() + observation.cooldownMs);
      }
    },
  } satisfies Health & {
    times: Map<string, number>;
    observations: Array<{ provider: string; outcome: string }>;
  };
}
function stream(events: unknown[]) {
  return new Response(
    events.map((value) =>
      "data: " + (typeof value === "string" ? value : JSON.stringify(value)) +
      "\r\n\r\n"
    ).join(""),
    { headers: { "content-type": "text/event-stream" } },
  );
}
const goodNvidia = () =>
  stream([{ choices: [{ delta: { content: "Hello " } }] }, {
    choices: [{ delta: { content: "world" }, finish_reason: "stop" }],
  }, "[DONE]"]);
const goodGemini = () =>
  stream([{
    candidates: [{
      content: { parts: [{ text: "Backup" }] },
      finishReason: "STOP",
    }],
  }]);
const groq: Provider = {
  id: "groq",
  model: "openai/gpt-oss-20b",
  key: "test-key",
  thinking: "low",
};
Deno.test("three configured providers are ordered while private records stay on Gemini", () => {
  const config: Record<string, string> = {
    GROQ_API_KEY: "test",
    GEMINI_API_KEY: "test",
    AI_GROQ_CHAT_MODEL: "openai/gpt-oss-20b",
    AI_GROQ_QUIZ_MODEL: "openai/gpt-oss-120b",
    AI_GEMINI_MODEL: "test-gemini",
    AI_GROQ_ENABLED: "true",
    NVIDIA_API_KEY: "test",
    AI_NVIDIA_ENABLED: "true",
    AI_NVIDIA_USAGE: "prototype",
    AI_NVIDIA_MODEL: "test/model",
  };
  const env = (key: string) => config[key];
  assert.deepEqual(providers(env, "teaching_chat").map((p) => p.id), [
    "groq",
    "gemini",
    "nvidia",
  ]);
  assert.equal(providers(env, "teaching_chat")[0].model, "openai/gpt-oss-20b");
  assert.equal(providers(env, "quiz")[0].model, "openai/gpt-oss-120b");
  assert.deepEqual(providers(env, "records_summary").map((p) => p.id), [
    "gemini",
  ]);
  config.AI_PRIMARY_PROVIDER = "gemini";
  assert.deepEqual(providers(env, "quiz").map((p) => p.id), [
    "gemini",
    "groq",
    "nvidia",
  ]);
  delete config.AI_GROQ_ENABLED;
  assert.ok(providers(env, "quiz").every((p) => p.id !== "groq"));
});
Deno.test("explicit primary, secondary and tertiary provider slots control priority", () => {
  const config: Record<string, string> = {
    GROQ_API_KEY: "test",
    AI_GROQ_ENABLED: "true",
    GEMINI_API_KEY: "test",
    AI_GROQ_CHAT_MODEL: "openai/gpt-oss-20b",
    AI_GROQ_QUIZ_MODEL: "openai/gpt-oss-120b",
    AI_GEMINI_MODEL: "test-gemini",
    NVIDIA_API_KEY: "test",
    AI_NVIDIA_ENABLED: "true",
    AI_NVIDIA_USAGE: "prototype",
    AI_NVIDIA_MODEL: "test/model",
    AI_PRIMARY_PROVIDER: "gemini",
    AI_SECONDARY_PROVIDER: "nvidia",
    AI_TERTIARY_PROVIDER: "groq",
  };
  const env = (key: string) => config[key];
  assert.deepEqual(providers(env, "study_chat").map((p) => p.id), [
    "gemini",
    "nvidia",
    "groq",
  ]);
  config.AI_GEMINI_ENABLED = "false";
  assert.deepEqual(providers(env, "study_chat").map((p) => p.id), [
    "nvidia",
    "groq",
  ]);
});
Deno.test("Groq streams through fixed endpoint with bounded output and hidden reasoning", async () => {
  const fetcher: typeof fetch = async (url, init) => {
    assert.equal(
      String(url),
      "https://api.groq.com/openai/v1/chat/completions",
    );
    const body = JSON.parse(String(init?.body));
    assert.equal(body.max_tokens, 600);
    assert.equal(body.reasoning_effort, "low");
    assert.equal(body.include_reasoning, false);
    assert.equal(body.stream, true);
    assert.equal(
      (init?.headers as Record<string, string>).Authorization,
      "Bearer test-key",
    );
    return goodNvidia();
  };
  const events = await collect(fetcher, [groq]);
  assert.equal(events.at(-1)?.type, "done");
  assert.equal((events.at(-1) as { provider: string }).provider, "groq");
});
Deno.test("Groq quota automatically falls back to Gemini and establishes cooldown", async () => {
  const health = state();
  let calls = 0;
  const fetcher: typeof fetch = async () =>
    ++calls === 1
      ? new Response(null, { status: 429, headers: { "retry-after": "90" } })
      : goodGemini();
  const events = await collect(fetcher, [groq, gemini], health);
  assert.equal(calls, 2);
  assert.ok(health.times.get("groq")! > Date.now() + 80000);
  assert.equal((events.at(-1) as { provider: string }).provider, "gemini");
});
Deno.test("Groq quiz uses JSON mode and validates before publishing", async () => {
  const quiz = {
    title: "Quiz",
    instructions: "Choose one",
    questions: [{
      question: "Which?",
      options: ["A", "B", "C", "D"],
      correctAnswerIndex: 0,
      explanation: "A is correct",
    }],
  };
  const fetcher: typeof fetch = async (_url, init) => {
    const body = JSON.parse(String(init?.body));
    assert.equal(body.model, "openai/gpt-oss-120b");
    assert.deepEqual(body.response_format, { type: "json_object" });
    return stream([{
      choices: [{
        delta: { content: JSON.stringify(quiz) },
        finish_reason: "stop",
      }],
    }]);
  };
  const events = await Array.fromAsync(route(
    { ...input, task: "quiz", questionCount: 1 },
    [{ ...groq, model: "openai/gpt-oss-120b" }],
    state(),
    new AbortController().signal,
    fetcher,
  ));
  assert.deepEqual(events[0], { type: "delta", text: JSON.stringify(quiz) });
});
const collect = async (
  fetcher: typeof fetch,
  available = [nvidia, gemini],
  health = state(),
) =>
  Array.fromAsync(
    route(input, available, health, new AbortController().signal, fetcher, {
      first: 12000,
      total: 35000,
      backoff: 0,
    }),
  );
Deno.test("task, input, role, history and output budgets are enforced", () => {
  assert.equal(outputLimit(input), 600);
  assert.equal(outputLimit({ ...input, task: "material_summary" }), 1200);
  assert.equal(
    outputLimit({ ...input, task: "quiz", questionCount: 15 }),
    5000,
  );
  assert.deepEqual(
    parseInput({ ...input, model: "evil", max_tokens: 999999 }),
    input,
  );
  for (
    const body of [
      { ...input, task: "delete_database" },
      { ...input, messages: [{ role: "system", content: "x" }] },
      { ...input, messages: [{ role: "assistant", content: "x" }] },
      { ...input, messages: [{ role: "user", content: "x".repeat(18001) }] },
      { ...input, task: "quiz", questionCount: 100 },
      {
        ...input,
        messages: [{ role: "user", content: "x" }, {
          role: "user",
          content: "y",
        }],
      },
    ]
  ) assert.throws(() => parseInput(body), AiError);
});
Deno.test("NVIDIA requires explicit enablement and usage setting; records stay on Gemini", () => {
  const config: Record<string, string> = {
    NVIDIA_API_KEY: "secret",
    AI_NVIDIA_MODEL: "test/model",
    GEMINI_API_KEY: "secret",
    AI_GEMINI_MODEL: "test-gemini",
  };
  const env = (key: string) => config[key];
  assert.deepEqual(providers(env, "teaching_chat").map((p) => p.id), [
    "gemini",
  ]);
  config.AI_NVIDIA_ENABLED = "true";
  config.AI_NVIDIA_USAGE = "prototype";
  assert.deepEqual(providers(env, "teaching_chat").map((p) => p.id), [
    "nvidia",
    "gemini",
  ]);
  assert.deepEqual(providers(env, "records_summary").map((p) => p.id), [
    "gemini",
  ]);
});
Deno.test("one NVIDIA request streams with server-controlled output limits", async () => {
  let calls = 0;
  const fetcher: typeof fetch = async (_url, init) => {
    calls++;
    const body = JSON.parse(init!.body as string);
    assert.equal(body.max_tokens, 600);
    assert.equal(body.stream, true);
    assert.equal(body.messages[0].role, "system");
    return goodNvidia();
  };
  const events = await collect(fetcher);
  assert.equal(calls, 1);
  assert.equal(
    events.filter((e) => e.type === "delta").map((e) =>
      e.type === "delta" ? e.text : ""
    ).join(""),
    "Hello world",
  );
  assert.equal(events.at(-1)?.type, "done");
});
Deno.test("quota, timeout HTTP and server failures fall back once and cool the failed provider", async () => {
  for (const status of [429, 408, 500, 503]) {
    const health = state();
    let calls = 0;
    const events = await collect(
      async () =>
        ++calls === 1
          ? new Response("", { status, headers: { "retry-after": "120" } })
          : goodGemini(),
      [nvidia, gemini],
      health,
    );
    assert.equal(calls, 2);
    assert(health.times.get("nvidia")! > Date.now() + 119000);
    assert.deepEqual(events.at(-1), {
      type: "done",
      provider: "gemini",
      model: "test-gemini",
      truncated: false,
    });
  }
});
Deno.test("network failure before text falls back; cooled provider is skipped", async () => {
  let calls = 0;
  await collect(async () => {
    if (++calls === 1) throw new TypeError("offline");
    return goodGemini();
  });
  assert.equal(calls, 2);
  const health = state();
  await health.failure(nvidia, {
    task: "teaching_chat",
    code: "provider_quota",
    latencyMs: 1,
    approximateInputTokens: 1,
    approximateOutputTokens: 0,
    failover: false,
    cooldownMs: 60000,
  });
  calls = 0;
  await collect(
    async () => {
      calls++;
      return goodGemini();
    },
    [nvidia, gemini],
    health,
  );
  assert.equal(calls, 1);
});
Deno.test("provider authentication failures fail over and establish a long cooldown", async () => {
  for (const status of [401, 403]) {
    const health = state();
    let calls = 0;
    const events = await collect(
      async () => ++calls === 1 ? new Response("", { status }) : goodGemini(),
      [nvidia, gemini],
      health,
    );
    assert.equal(calls, 2);
    assert.ok(health.times.get("nvidia")! > Date.now() + 21000000);
    assert.equal((events.at(-1) as { provider: string }).provider, "gemini");
  }
});
Deno.test("invalid requests and safety refusals never fall back", async () => {
  for (
    const response of [
      new Response("", { status: 400 }),
      stream([{
        choices: [{ delta: { refusal: "Cannot help" }, finish_reason: "stop" }],
      }]),
    ]
  ) {
    let calls = 0;
    await assert.rejects(() =>
      collect(async () => {
        calls++;
        return response;
      }), AiError);
    assert.equal(calls, 1);
  }
});
Deno.test("mid-stream failure preserves the partial answer without invoking a second model", async () => {
  let calls = 0;
  const seen = [];
  try {
    for await (
      const event of route(
        input,
        [nvidia, gemini],
        state(),
        new AbortController().signal,
        async () => {
          calls++;
          return stream([{ choices: [{ delta: { content: "Partial" } }] }]);
        },
      )
    ) seen.push(event);
  } catch (error) {
    assert.equal((error as AiError).code, "stream_interrupted");
  }
  assert.equal(calls, 1);
  assert.deepEqual(seen, [{ type: "delta", text: "Partial" }]);
});
Deno.test("thoughts are not emitted as answer text and token truncation is explicit", async () => {
  const events = await collect(
    async () =>
      stream([{
        candidates: [{
          content: {
            parts: [{ text: "secret reasoning", thought: true }, {
              text: "Answer",
            }],
          },
          finishReason: "MAX_TOKENS",
        }],
      }]),
    [gemini],
  );
  assert.deepEqual(events, [{ type: "delta", text: "Answer" }, {
    type: "done",
    provider: "gemini",
    model: "test-gemini",
    truncated: true,
  }]);
});
Deno.test("caller cancellation makes no provider calls", async () => {
  const controller = new AbortController();
  controller.abort();
  let calls = 0;
  await assert.rejects(
    () =>
      Array.fromAsync(
        route(input, [nvidia, gemini], state(), controller.signal, async () => {
          calls++;
          return goodNvidia();
        }),
      ),
    AiError,
  );
  assert.equal(calls, 0);
});
Deno.test("both failed providers result in one bounded error", async () => {
  let calls = 0;
  await assert.rejects(() =>
    collect(async () => {
      calls++;
      return new Response("", { status: 503 });
    }), (error) => (error as AiError).code === "providers_unavailable");
  assert.equal(calls, 2);
});
Deno.test("primary and secondary failures automatically use the tertiary provider", async () => {
  let calls = 0;
  const continuityInput: Input = {
    task: "teaching_chat",
    messages: [
      { role: "user", content: "Explain normalization" },
      { role: "assistant", content: "Which normal form?" },
      { role: "user", content: "Explain the first three forms" },
    ],
  };
  const events = await Array.fromAsync(route(
    continuityInput,
    [nvidia, groq, gemini],
    state(),
    new AbortController().signal,
    async (_url, init) => {
      calls++;
      const payload = String(init?.body);
      assert.ok(payload.includes("Explain normalization"));
      assert.ok(payload.includes("Explain the first three forms"));
      return calls < 3 ? new Response("", { status: 503 }) : goodGemini();
    },
    { first: 12000, total: 35000, backoff: 0 },
  ));
  assert.equal(calls, 3);
  assert.equal((events.at(-1) as { provider: string }).provider, "gemini");
});
Deno.test("three unavailable providers return one controlled error", async () => {
  let calls = 0;
  await assert.rejects(
    () =>
      collect(async () => {
        calls++;
        return new Response("", { status: 503 });
      }, [nvidia, groq, gemini]),
    (error) => (error as AiError).code === "providers_unavailable",
  );
  assert.equal(calls, 3);
});
Deno.test("a compatible tertiary provider can recover quiz and material requests", async () => {
  const quiz = JSON.stringify({
    title: "Quiz",
    instructions: "Choose one",
    questions: [{
      question: "Which normal form removes partial dependencies?",
      options: ["1NF", "2NF", "3NF", "BCNF"],
      correctAnswerIndex: 1,
      explanation: "2NF removes partial dependencies.",
    }],
  });
  for (
    const request of [
      { ...input, task: "material_summary" as const },
      { ...input, task: "quiz" as const, questionCount: 1 },
    ]
  ) {
    let calls = 0;
    const events = await Array.fromAsync(route(
      request,
      [nvidia, groq, gemini],
      state(),
      new AbortController().signal,
      async () => {
        calls++;
        if (calls < 3) return new Response("", { status: 429 });
        return stream([{
          candidates: [{
            content: {
              parts: [{
                text: request.task === "quiz" ? quiz : "Material summary",
              }],
            },
            finishReason: "STOP",
          }],
        }]);
      },
      { first: 12000, total: 55000, backoff: 0 },
    ));
    assert.equal(calls, 3);
    assert.equal((events.at(-1) as { provider: string }).provider, "gemini");
  }
});
Deno.test("an expired cooldown makes the recovered primary eligible again", async () => {
  const health = state();
  health.times.set("nvidia", Date.now() - 1);
  let calls = 0;
  const events = await collect(
    async () => {
      calls++;
      return goodNvidia();
    },
    [nvidia, gemini],
    health,
  );
  assert.equal(calls, 1);
  assert.equal((events.at(-1) as { provider: string }).provider, "nvidia");
});
Deno.test("quiz JSON is withheld until complete and validated against requested count", async () => {
  const quiz = {
    title: "Quiz",
    instructions: "Choose one",
    questions: [{
      question: "Which?",
      options: ["A", "B", "C", "D"],
      correctAnswerIndex: 0,
      explanation: "A",
    }],
  };
  validateQuiz(JSON.stringify(quiz), 1);
  assert.throws(() => validateQuiz(JSON.stringify(quiz), 2));
  assert.throws(() => validateQuiz('{"title":', 1));
  const quizInput: Input = {
    task: "quiz",
    questionCount: 1,
    messages: input.messages,
  };
  const events = await Array.fromAsync(
    route(
      quizInput,
      [nvidia],
      state(),
      new AbortController().signal,
      async () =>
        stream([{
          choices: [{
            delta: { content: JSON.stringify(quiz) },
            finish_reason: "stop",
          }],
        }, "[DONE]"]),
    ),
  );
  assert.equal(events.length, 2);
  let leaked = false;
  await assert.rejects(async () => {
    for await (
      const event of route(
        quizInput,
        [nvidia, gemini],
        state(),
        new AbortController().signal,
        async () =>
          stream([{
            choices: [{
              delta: { content: JSON.stringify(quiz) },
              finish_reason: "length",
            }],
          }, "[DONE]"]),
      )
    ) if (event.type === "delta") leaked = true;
  }, AiError);
  assert.equal(leaked, false);
});
Deno.test("SSE decoder handles split UTF-8, CRLF and multiple data lines", async () => {
  const encoded = new TextEncoder().encode(
    'data: {"text":"é"}\r\n\r\ndata: one\ndata: two\n\n',
  );
  const body = new ReadableStream<Uint8Array>({
    start(c) {
      for (const byte of encoded) c.enqueue(new Uint8Array([byte]));
      c.close();
    },
  });
  assert.deepEqual(await Array.fromAsync(sse(body)), [
    '{"text":"é"}',
    "one\ntwo",
  ]);
});

Deno.test("a first-token deadline aborts a stalled primary and uses the backup", async () => {
  let calls = 0, aborted = false;
  const fetcher: typeof fetch = (_url, init) => {
    if (++calls === 2) return Promise.resolve(goodGemini());
    return new Promise((_resolve, reject) =>
      init!.signal!.addEventListener("abort", () => {
        aborted = true;
        reject(new DOMException("aborted", "AbortError"));
      }, { once: true })
    );
  };
  const events = await Array.fromAsync(
    route(
      input,
      [nvidia, gemini],
      state(),
      new AbortController().signal,
      fetcher,
      { first: 10, total: 1000 },
    ),
  );
  assert.equal(calls, 2);
  assert.equal(aborted, true);
  assert.equal(events.at(-1)?.type, "done");
});
Deno.test("authentication failures inside an SSE stream fail over before text", async () => {
  let calls = 0;
  const events = await collect(async () => {
    calls++;
    return calls === 1
      ? stream([{ error: { code: 403, message: "private detail" } }])
      : goodGemini();
  });
  assert.equal(calls, 2);
  assert.equal((events.at(-1) as { provider: string }).provider, "gemini");
});
Deno.test("an EOF marker without a completion reason is not accepted as a completed answer", async () => {
  let calls = 0;
  await assert.rejects(() =>
    collect(async () => {
      calls++;
      return stream([
        { choices: [{ delta: { content: "Unfinished" } }] },
        "[DONE]",
      ]);
    }), (error) => (error as AiError).code === "stream_interrupted");
  assert.equal(calls, 1);
});

Deno.test("production NVIDIA calls require an explicitly configured service endpoint", () => {
  const config: Record<string, string> = {
    NVIDIA_API_KEY: "secret",
    GEMINI_API_KEY: "secret",
    AI_GEMINI_MODEL: "test-gemini",
    AI_NVIDIA_MODEL: "instruct",
    AI_NVIDIA_ENABLED: "true",
    AI_NVIDIA_USAGE: "production",
  };
  const env = (name: string) => config[name];
  assert.deepEqual(providers(env, "teaching_chat").map((p) => p.id), [
    "gemini",
  ]);
  config.AI_NVIDIA_BASE_URL = "https://nim.example/v1";
  assert.equal(
    providers(env, "teaching_chat")[0].baseUrl,
    config.AI_NVIDIA_BASE_URL,
  );
  assert.deepEqual(providers(env, "records_summary").map((p) => p.id), [
    "gemini",
  ]);
});
Deno.test("a configured NIM endpoint is used without allowing insecure URLs or embedded credentials", async () => {
  let called = "";
  await collect(async (url) => {
    called = String(url);
    return goodNvidia();
  }, [{ ...nvidia, baseUrl: "https://nim.example/v1/" }]);
  assert.equal(called, "https://nim.example/v1/chat/completions");
  for (
    const baseUrl of [
      "http://nim.example/v1",
      "https://user:password@nim.example/v1",
      "https://nim.example/v1?secret=x",
      "not-a-url",
    ]
  ) {
    let calls = 0;
    const events = await collect(async () => {
      calls++;
      return goodGemini();
    }, [{ ...nvidia, baseUrl }, gemini]);
    assert.equal(calls, 1);
    assert.equal((events.at(-1) as { provider: string }).provider, "gemini");
  }
});
