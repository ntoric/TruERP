import type { ModelInfo, Provider } from "../types.js";
import { geminiProvider } from "./gemini.js";
import { openAiCompatProvider } from "./openaiCompat.js";

const OLLAMA_DEFAULT_BASE = process.env.OLLAMA_BASE_URL || "http://localhost:11434";

/** Ollama's model list lives at /api/tags (its /v1 endpoint is OpenAI-shaped). */
async function listOllamaModels(baseUrl: string): Promise<ModelInfo[]> {
  const native = baseUrl.replace(/\/v1\/?$/, "");
  const res = await fetch(`${native}/api/tags`, { signal: AbortSignal.timeout(10_000) });
  if (!res.ok) throw new Error(`Ollama /api/tags → ${res.status} ${res.statusText}`);
  const data = (await res.json()) as { models?: Array<{ name: string }> };
  return (data.models ?? []).map((m) => ({ id: m.name }));
}

export const providers: Record<string, Provider> = {
  gemini: geminiProvider,

  openrouter: openAiCompatProvider({
    id: "openrouter",
    label: "OpenRouter",
    needsKey: true,
    envKey: "OPENROUTER_API_KEY",
    defaultModel: "openai/gpt-4o-mini",
    baseUrl: "https://openrouter.ai/api/v1",
    headers: { "X-Title": "TruERP Chat" },
  }),

  ollama: openAiCompatProvider({
    id: "ollama",
    label: "Ollama (local)",
    needsKey: false,
    defaultModel: "llama3.1",
    baseUrl: `${OLLAMA_DEFAULT_BASE}/v1`,
    listModels: (baseUrl) => listOllamaModels(baseUrl),
  }),
};

export function getProvider(id: string): Provider | undefined {
  return providers[id];
}
