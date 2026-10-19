/**
 * Google Gemini provider via @google/genai, with streaming + function calling.
 */
import { GoogleGenAI } from "@google/genai";
import type {
  ChatMessage,
  ModelInfo,
  Provider,
  ProviderRequest,
  ProviderResult,
  ToolCall,
} from "../types.js";

type Part = Record<string, unknown>;
interface GeminiContent {
  role: string;
  parts: Part[];
}

/** JSON-Schema keys the Gemini function-declaration schema accepts. */
const SCHEMA_KEYS = new Set([
  "type",
  "format",
  "description",
  "nullable",
  "enum",
  "items",
  "properties",
  "required",
  "anyOf",
  "minItems",
  "maxItems",
  "minimum",
  "maximum",
  "pattern",
]);

function sanitizeSchema(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(sanitizeSchema);
  if (node === null || typeof node !== "object") return node;
  const src = node as Record<string, unknown>;
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(src)) {
    if (!SCHEMA_KEYS.has(k)) continue;
    // `properties` maps names → schemas: keep every name, sanitize each value.
    if (k === "properties" && v !== null && typeof v === "object") {
      out.properties = Object.fromEntries(
        Object.entries(v as Record<string, unknown>).map(([pk, pv]) => [pk, sanitizeSchema(pv)]),
      );
      continue;
    }
    out[k] = sanitizeSchema(v);
  }
  // Normalize "type": ["string","null"] → type:"string", nullable:true
  if (Array.isArray(out.type)) {
    const types = out.type.filter((t) => t !== "null");
    if (out.type.includes("null")) out.nullable = true;
    out.type = types[0] ?? "string";
  }
  return out;
}

function functionResponsePart(name: string, content: string): Part {
  let response: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(content);
    response =
      parsed !== null && typeof parsed === "object"
        ? { result: parsed }
        : { result: parsed };
  } catch {
    response = { result: content };
  }
  return { functionResponse: { name, response } };
}

function toGeminiContents(messages: ChatMessage[]): GeminiContent[] {
  const out: GeminiContent[] = [];
  for (let i = 0; i < messages.length; i++) {
    const m = messages[i];
    if (m.role === "user") {
      out.push({ role: "user", parts: [{ text: m.content }] });
    } else if (m.role === "assistant") {
      const parts: Part[] = [];
      if (m.content) parts.push({ text: m.content });
      for (const c of m.toolCalls ?? []) {
        const part: Part = { functionCall: { name: c.name, args: c.args ?? {} } };
        // Gemini 3.x requires the thought signature echoed back with the call.
        const sig = c.meta?.thoughtSignature;
        if (typeof sig === "string") part.thoughtSignature = sig;
        parts.push(part);
      }
      if (parts.length) out.push({ role: "model", parts });
    } else if (m.role === "tool") {
      // Collapse a run of consecutive tool results into one user content.
      const parts: Part[] = [];
      let j = i;
      while (j < messages.length && messages[j].role === "tool") {
        const tm = messages[j];
        parts.push(functionResponsePart(tm.name ?? "unknown", tm.content));
        j++;
      }
      i = j - 1;
      out.push({ role: "user", parts });
    }
  }
  return out;
}

let counter = 0;

export const geminiProvider: Provider = {
  id: "gemini",
  label: "Gemini",
  needsKey: true,
  envKey: "GEMINI_API_KEY",
  defaultModel: "gemini-2.5-flash",

  async complete(req: ProviderRequest): Promise<ProviderResult> {
    const ai = new GoogleGenAI({ apiKey: req.apiKey ?? "" });
    const stream = await ai.models.generateContentStream({
      model: req.model,
      contents: toGeminiContents(req.messages) as never,
      config: {
        abortSignal: req.signal,
        systemInstruction: req.system,
        tools: req.tools.length
          ? [
              {
                functionDeclarations: req.tools.map((t) => ({
                  name: t.name,
                  description: t.description,
                  parameters: sanitizeSchema(t.inputSchema) as never,
                })),
              },
            ]
          : undefined,
      },
    });

    let text = "";
    let finishReason: string | undefined;
    const toolCalls: ToolCall[] = [];
    for await (const chunk of stream) {
      const cand = chunk.candidates?.[0];
      if (cand?.finishReason) finishReason = String(cand.finishReason);
      const block = (chunk as { promptFeedback?: { blockReason?: string } }).promptFeedback?.blockReason;
      if (block) finishReason = `BLOCKED:${block}`;
      const parts = (cand?.content?.parts ?? []) as Array<Record<string, unknown>>;
      for (const part of parts) {
        if (part.thought === true) continue; // skip thinking traces
        if (typeof part.text === "string" && part.text) {
          text += part.text;
          req.onToken?.(part.text);
        }
        const fc = part.functionCall as { name?: string; args?: Record<string, unknown> } | undefined;
        if (fc?.name) {
          const call: ToolCall = { id: `fc_${Date.now()}_${counter++}`, name: fc.name, args: fc.args ?? {} };
          const sig = part.thoughtSignature;
          if (typeof sig === "string") call.meta = { thoughtSignature: sig };
          toolCalls.push(call);
        }
      }
    }

    return { message: { role: "assistant", content: text, toolCalls }, finishReason };
  },

  async listModels({ apiKey }): Promise<ModelInfo[]> {
    const ai = new GoogleGenAI({ apiKey: apiKey ?? "" });
    // queryBase: true lists base models (the tuned-model view is the other mode).
    const pager = await ai.models.list({ config: { queryBase: true } });
    const out: ModelInfo[] = [];
    for await (const m of pager) {
      const name = (m.name ?? "").replace(/^models\//, "");
      if (!name) continue;
      // Prefer the API's capability list; fall back to a name heuristic when absent.
      if (m.supportedActions?.length) {
        if (!m.supportedActions.includes("generateContent")) continue;
      } else if (/embed|imagen|veo|tts|aqa|image|audio|robotics|computer-use/i.test(name)) {
        continue;
      }
      out.push({ id: name, label: m.displayName || name });
    }
    return out.sort((a, b) => a.id.localeCompare(b.id));
  },
};
