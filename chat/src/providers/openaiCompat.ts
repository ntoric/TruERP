/**
 * OpenAI-compatible chat completions provider.
 *
 * Used for both OpenRouter (https://openrouter.ai/api/v1) and Ollama
 * (http://localhost:11434/v1) — both expose the OpenAI API shape with
 * streaming + function/tool calling.
 */
import OpenAI from "openai";
import type {
  ChatMessage,
  ModelInfo,
  Provider,
  ProviderRequest,
  ProviderResult,
  ToolCall,
} from "../types.js";

type OaiMessage = OpenAI.Chat.ChatCompletionMessageParam;

function toOpenAiMessages(system: string | undefined, messages: ChatMessage[]): OaiMessage[] {
  const out: OaiMessage[] = [];
  if (system) out.push({ role: "system", content: system });
  for (const m of messages) {
    if (m.role === "user") {
      out.push({ role: "user", content: m.content });
    } else if (m.role === "assistant") {
      out.push({
        role: "assistant",
        content: m.content || null,
        tool_calls: (m.toolCalls ?? []).map((c) => ({
          id: c.id,
          type: "function" as const,
          function: { name: c.name, arguments: JSON.stringify(c.args ?? {}) },
        })),
      });
    } else if (m.role === "tool") {
      out.push({ role: "tool", tool_call_id: m.toolCallId ?? "", content: m.content });
    }
  }
  return out;
}

interface OpenAiCompatOpts {
  id: string;
  label: string;
  needsKey: boolean;
  envKey?: string;
  defaultModel: string;
  baseUrl: string;
  /** Extra HTTP headers (OpenRouter recommends referer/title). */
  headers?: Record<string, string>;
  /** Custom model listing (Ollama uses /api/tags, not /models). */
  listModels?: (baseUrl: string, apiKey?: string) => Promise<ModelInfo[]>;
}

export function openAiCompatProvider(opts: OpenAiCompatOpts): Provider {
  function makeClient(apiKey?: string, baseUrlOverride?: string): { client: OpenAI; base: string } {
    const base = (baseUrlOverride || opts.baseUrl).replace(/\/+$/, "");
    return {
      base,
      client: new OpenAI({
        apiKey: apiKey || "not-needed",
        baseURL: base,
        defaultHeaders: opts.headers,
      }),
    };
  }

  return {
    id: opts.id,
    label: opts.label,
    needsKey: opts.needsKey,
    envKey: opts.envKey,
    defaultModel: opts.defaultModel,
    defaultBaseUrl: opts.baseUrl,

    async complete(req: ProviderRequest): Promise<ProviderResult> {
      const { client } = makeClient(req.apiKey, req.baseUrl);
      const stream = await client.chat.completions.create(
        {
          model: req.model,
          messages: toOpenAiMessages(req.system, req.messages),
          tools: req.tools.length
            ? req.tools.map((t) => ({
                type: "function" as const,
                function: {
                  name: t.name,
                  description: t.description,
                  parameters: t.inputSchema,
                },
              }))
            : undefined,
          stream: true,
        },
        { signal: req.signal },
      );

      let text = "";
      let finishReason: string | undefined;
      const pending = new Map<number, ToolCall & { raw: string }>();
      for await (const chunk of stream) {
        const choice = chunk.choices?.[0];
        if (choice?.finish_reason) finishReason = choice.finish_reason;
        const delta = choice?.delta;
        if (!delta) continue;
        if (delta.content) {
          text += delta.content;
          req.onToken?.(delta.content);
        }
        const refusal = (delta as { refusal?: string }).refusal;
        if (refusal) {
          text += refusal;
          req.onToken?.(refusal);
        }
        for (const tc of delta.tool_calls ?? []) {
          const slot =
            pending.get(tc.index) ??
            ({ id: "", name: "", args: {}, raw: "" } as ToolCall & { raw: string });
          if (tc.id) slot.id = tc.id;
          if (tc.function?.name) slot.name += tc.function.name;
          if (tc.function?.arguments) slot.raw += tc.function.arguments;
          pending.set(tc.index, slot);
        }
      }

      const toolCalls: ToolCall[] = [...pending.entries()]
        .sort(([a], [b]) => a - b)
        .map(([i, slot]) => {
          let args: Record<string, unknown> = {};
          try {
            args = slot.raw ? (JSON.parse(slot.raw) as Record<string, unknown>) : {};
          } catch {
            /* leave empty — malformed JSON args */
          }
          return { id: slot.id || `call_${i}`, name: slot.name, args };
        });

      return { message: { role: "assistant", content: text, toolCalls }, finishReason };
    },

    async listModels({ apiKey, baseUrl }) {
      if (opts.listModels) return opts.listModels(baseUrl || opts.baseUrl, apiKey);
      const { client } = makeClient(apiKey, baseUrl);
      const res = await client.models.list();
      return res.data.map((m) => ({ id: m.id })).sort((a, b) => a.id.localeCompare(b.id));
    },
  };
}
