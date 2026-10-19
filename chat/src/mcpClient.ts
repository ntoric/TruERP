/**
 * Owns the connection to the TruERP MCP server.
 *
 * The server is spawned as a stdio child process (same way Claude Desktop /
 * Cursor launch it) via the official SDK's StdioClientTransport. All
 * TRUERP_* env vars are inherited from this process's environment.
 */
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ToolDef } from "./types.js";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = path.resolve(HERE, "..");
const DEFAULT_SERVER = path.resolve(PKG_ROOT, "../mcp-server/dist/index.js");
const DOWNLOADS_DIR = path.join(PKG_ROOT, "downloads");

const MAX_TOOL_RESULT_CHARS = Number(process.env.MAX_TOOL_RESULT_CHARS || 40_000);

export type McpStatus = "disconnected" | "connecting" | "connected" | "error";

export interface ToolCallResult {
  text: string;
  isError: boolean;
}

function extForMime(mime?: string): string {
  switch (mime) {
    case "application/pdf":
      return ".pdf";
    case "image/png":
      return ".png";
    case "image/jpeg":
      return ".jpg";
    case "text/csv":
      return ".csv";
    case "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
      return ".xlsx";
    default:
      return ".bin";
  }
}

async function saveBlob(base64: string, mimeType: string | undefined, hint: string): Promise<string> {
  await mkdir(DOWNLOADS_DIR, { recursive: true });
  const safe = hint.replace(/[^a-zA-Z0-9._-]+/g, "_").slice(-60) || "file";
  const file = path.join(DOWNLOADS_DIR, `${Date.now()}_${safe}${extForMime(mimeType)}`);
  await writeFile(file, Buffer.from(base64, "base64"));
  return file;
}

export class McpManager {
  private client?: Client;
  private transport?: StdioClientTransport;
  private connecting?: Promise<void>;
  private tools: ToolDef[] = [];
  status: McpStatus = "disconnected";
  lastError?: string;

  private serverCommand(): { command: string; args: string[] } {
    const cmd = process.env.MCP_SERVER_COMMAND;
    const rawArgs = process.env.MCP_SERVER_ARGS;
    if (cmd) {
      let args: string[] = [];
      if (rawArgs) {
        try {
          const parsed: unknown = JSON.parse(rawArgs);
          args = Array.isArray(parsed) ? parsed.map(String) : rawArgs.split(" ");
        } catch {
          args = rawArgs.split(" ");
        }
      }
      return { command: cmd, args };
    }
    return { command: process.execPath, args: [process.env.MCP_SERVER_PATH || DEFAULT_SERVER] };
  }

  async ensureConnected(): Promise<void> {
    if (this.client && this.status === "connected") return;
    if (this.connecting) return this.connecting;

    this.status = "connecting";
    this.connecting = (async () => {
      const { command, args } = this.serverCommand();
      const transport = new StdioClientTransport({
        command,
        args,
        env: { ...process.env } as Record<string, string>,
        stderr: "inherit",
      });
      const client = new Client(
        { name: "truerp-chat", version: "1.0.0" },
        { capabilities: {} },
      );
      transport.onclose = () => {
        this.status = "disconnected";
        this.client = undefined;
        this.transport = undefined;
      };
      await client.connect(transport);
      this.client = client;
      this.transport = transport;
      this.status = "connected";
      this.lastError = undefined;
      this.tools = await this.fetchAllTools();
      console.error(`[mcp] connected — ${this.tools.length} tools`);
    })();

    try {
      await this.connecting;
    } catch (err) {
      this.status = "error";
      this.lastError = err instanceof Error ? err.message : String(err);
      this.connecting = undefined;
      throw err;
    }
    this.connecting = undefined;
  }

  private async fetchAllTools(): Promise<ToolDef[]> {
    if (!this.client) return [];
    const out: ToolDef[] = [];
    let cursor: string | undefined;
    do {
      const res = await this.client.listTools(cursor ? { cursor } : undefined);
      for (const t of res.tools) {
        out.push({
          name: t.name,
          description: t.description,
          inputSchema: (t.inputSchema ?? { type: "object" }) as Record<string, unknown>,
          annotations: t.annotations as Record<string, unknown> | undefined,
        });
      }
      cursor = res.nextCursor;
    } while (cursor);
    return out;
  }

  async listTools(): Promise<ToolDef[]> {
    await this.ensureConnected();
    return this.tools;
  }

  async callTool(name: string, args: Record<string, unknown>): Promise<ToolCallResult> {
    await this.ensureConnected();
    if (!this.client) throw new Error("MCP client not connected");

    const res = await this.client.callTool({ name, arguments: args });
    const content = (res.content ?? []) as Array<Record<string, unknown>>;
    const texts: string[] = [];

    for (const part of content) {
      if (part.type === "text" && typeof part.text === "string") {
        texts.push(part.text);
      } else if (part.type === "resource") {
        const r = part.resource as Record<string, unknown> | undefined;
        if (r && typeof r.blob === "string" && r.blob) {
          const file = await saveBlob(r.blob, r.mimeType as string | undefined, String(r.uri ?? name));
          texts.push(`[binary ${r.mimeType ?? "data"} saved to ${file}]`);
        } else if (r && typeof r.text === "string") {
          texts.push(r.text);
        }
      } else if (part.type === "image" && typeof part.data === "string") {
        const file = await saveBlob(part.data, part.mimeType as string | undefined, name);
        texts.push(`[image saved to ${file}]`);
      }
    }

    let text = texts.join("\n") || "(empty result)";
    if (text.length > MAX_TOOL_RESULT_CHARS) {
      text = text.slice(0, MAX_TOOL_RESULT_CHARS) + "\n…[truncated]";
    }
    return { text, isError: res.isError === true };
  }

  async close(): Promise<void> {
    try {
      await this.transport?.close();
    } catch {
      /* ignore */
    }
    this.client = undefined;
    this.transport = undefined;
    this.status = "disconnected";
  }
}
