/**
 * Agentic loop: model → tool calls → MCP results → model → … until the model
 * returns a plain text answer (or we hit the iteration cap).
 */
import type { McpManager } from "./mcpClient.js";
import type { AgentEvent, ChatMessage, Provider, ToolDef } from "./types.js";

const MAX_ITERATIONS = Number(process.env.MAX_AGENT_ITERATIONS || 16);

export interface RunAgentOpts {
  provider: Provider;
  model: string;
  apiKey?: string;
  baseUrl?: string;
  system?: string;
  messages: ChatMessage[];
  tools: ToolDef[];
  mcp: McpManager;
  emit: (ev: AgentEvent) => void;
  signal?: AbortSignal;
}

export async function runAgent(opts: RunAgentOpts): Promise<ChatMessage[]> {
  const messages = [...opts.messages];
  const { emit } = opts;

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    if (opts.signal?.aborted) throw new Error("aborted");

    const { message, finishReason } = await opts.provider.complete({
      model: opts.model,
      apiKey: opts.apiKey,
      baseUrl: opts.baseUrl,
      system: opts.system,
      messages,
      tools: opts.tools,
      signal: opts.signal,
      onToken: (text) => emit({ type: "token", text }),
    });

    messages.push(message);
    emit({ type: "append", message });

    if (!message.toolCalls?.length) {
      if (!message.content) {
        emit({
          type: "error",
          error: `Model returned an empty response${finishReason ? ` (finish reason: ${finishReason})` : ""}. Try again, a different model, or fewer tools.`,
        });
      }
      emit({ type: "done" });
      return messages;
    }

    for (const call of message.toolCalls) {
      if (opts.signal?.aborted) throw new Error("aborted");
      emit({ type: "tool_call", id: call.id, name: call.name, args: call.args });

      let resultText: string;
      let isError = false;
      try {
        const res = await opts.mcp.callTool(call.name, call.args);
        resultText = res.text;
        isError = res.isError;
      } catch (err) {
        resultText = `Error: ${err instanceof Error ? err.message : String(err)}`;
        isError = true;
      }

      const toolMessage: ChatMessage = {
        role: "tool",
        toolCallId: call.id,
        name: call.name,
        content: resultText,
      };
      messages.push(toolMessage);
      emit({
        type: "tool_result",
        id: call.id,
        name: call.name,
        isError,
        preview: resultText.slice(0, 2_000),
      });
      emit({ type: "append", message: toolMessage });
    }
  }

  emit({ type: "error", error: `Stopped after ${MAX_ITERATIONS} tool iterations.` });
  return messages;
}
