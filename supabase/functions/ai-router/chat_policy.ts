import { AiError, route } from "./engine.ts";
import type { Event, Health, Input, Provider, Task } from "./engine.ts";

export const topicLimitMessage =
  "I'm limited to CAS LMS and schoolwork. Please ask a question about your classes, assignments, lessons, or using the LMS.";
export const clarifyTopicMessage =
  "I can help with CAS LMS and schoolwork. Which subject, assignment, or LMS task is this question for?";

export function isChat(input: Input): boolean {
  return ["teaching_chat", "study_chat", "records_summary"].includes(
    input.task,
  );
}

export function taskAllowed(role: unknown, task: Input["task"]): boolean {
  return ["admin", "instructor"].includes(String(role))
    ? task !== "scope_check"
    : role === "student" && ["study_chat", "records_summary"].includes(task);
}

// Extract only the user's question for classification; never send a record
// snapshot or course metadata to the classifier as supposed policy/context.
export function questionText(
  content: string,
  task: Task = "records_summary",
): string {
  // A study question is already plain text; do not let a user-supplied JSON
  // envelope hide part of that question from the classifier.
  if (task === "study_chat") return content;
  try {
    const parsed = JSON.parse(content);
    if (parsed && typeof parsed.question === "string") {
      return parsed.question;
    }
  } catch { /* Older teaching clients use a labelled plain-text envelope. */ }
  const marker = "\nInstructor request:\n";
  const offset = content.indexOf(marker);
  return offset >= 0 ? content.slice(offset + marker.length) : content;
}

export function verdict(text: string, truncated = false): string | null {
  if (truncated) return clarifyTopicMessage;
  try {
    const value = JSON.parse(text);
    if (value?.scope === "lms" || value?.scope === "schoolwork") return null;
    if (value?.scope === "unrelated") return topicLimitMessage;
  } catch {
    /* Invalid or missing classification must not authorize an answer. */
  }
  return clarifyTopicMessage;
}

export async function checkChatTopic(
  input: Input,
  available: Provider[],
  health: Health,
  signal: AbortSignal,
  fetcher: typeof fetch = fetch,
): Promise<string | null> {
  if (!isChat(input)) return null;
  const questions = input.messages.filter((message) => message.role === "user")
    .map((message) => questionText(message.content, input.task));
  // Never classify a prefix and then answer a longer, unchecked question.
  if (!questions.at(-1)?.trim() || questions.at(-1)!.length > 3000) {
    return clarifyTopicMessage;
  }
  const check: Input = {
    task: "scope_check",
    messages: [{
      role: "user",
      content: JSON.stringify({
        latestQuestion: questions.at(-1),
        previousQuestions: questions.slice(-3, -1).map((q) => q.slice(0, 3000)),
      }),
    }],
  };
  let output = "", complete = false, truncated = false;
  for await (
    const event of route(check, available, health, signal, fetcher, {
      first: 7000,
      total: 12000,
    })
  ) {
    if (event.type === "delta") output += event.text;
    else {
      complete = true;
      truncated = event.truncated;
    }
  }
  if (!complete) throw new AiError("scope_check_unavailable");
  return verdict(output, truncated);
}

// This is the only chat entry point used by the HTTP handler. A rejection never
// starts normal generation; classifier output itself is never sent to clients.
export async function* guardedRoute(
  input: Input,
  available: Provider[],
  health: Health,
  signal: AbortSignal,
  fetcher: typeof fetch = fetch,
): AsyncGenerator<Event> {
  const limitation = await checkChatTopic(
    input,
    available,
    health,
    signal,
    fetcher,
  );
  if (limitation) {
    yield { type: "delta", text: limitation };
    yield {
      type: "done",
      provider: "policy",
      model: "school-scope",
      truncated: false,
    };
    return;
  }
  yield* route(input, available, health, signal, fetcher);
}
