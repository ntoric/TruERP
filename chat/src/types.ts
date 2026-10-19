/** Shared chat/provider types. */

export interface ToolCall {
  id: string;
  name: string;
  args: Record<string, unknown>;
  /** Provider-specific data that must be echoed back in history (e.g. Gemini thoughtSignature). */
  meta?: Record<string, unknown>;
}

export type Role = "user" | "assistant" | "tool";

export interface ChatMessage {
  role: Role;
  content: string;
  /** Assistant messages: tool calls the model requested. */
  toolCalls?: ToolCall[];
  /** Tool messages: id of the call this result answers. */
  toolCallId?: string;
  /** Tool messages: name of the tool that produced the result. */
  name?: string;
}

export interface ToolDef {
  name: string;
  description?: string;
  inputSchema: Record<string, unknown>;
  annotations?: Record<string, unknown>;
}

export interface ModelInfo {
  id: string;
  label?: string;
}

export interface ProviderRequest {
  model: string;
  apiKey?: string;
  /** Optional endpoint override (used by Ollama). */
  baseUrl?: string;
  system?: string;
  messages: ChatMessage[];
  tools: ToolDef[];
  signal?: AbortSignal;
  onToken?: (text: string) => void;
}

export interface ProviderResult {
  message: ChatMessage;
  /** Provider-reported stop reason (e.g. STOP, SAFETY, MAX_TOKENS) when known. */
  finishReason?: string;
}

export interface Provider {
  id: string;
  label: string;
  /** Whether an API key is required (UI hint only). */
  needsKey: boolean;
  envKey?: string;
  defaultModel: string;
  defaultBaseUrl?: string;
  complete(req: ProviderRequest): Promise<ProviderResult>;
  listModels(opts: { apiKey?: string; baseUrl?: string }): Promise<ModelInfo[]>;
}

/** SSE events emitted to the browser during a chat run. */
export type AgentEvent =
  | { type: "token"; text: string }
  | { type: "tool_call"; id: string; name: string; args: Record<string, unknown> }
  | { type: "tool_result"; id: string; name: string; isError: boolean; preview: string }
  | { type: "append"; message: ChatMessage }
  | { type: "done" }
  | { type: "error"; error: string };
