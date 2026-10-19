/**
 * TruERP Chat — standalone AI chat interface.
 *
 * Serves a static chat UI and an SSE-backed /api/chat endpoint that runs an
 * agent loop across Gemini / OpenRouter / Ollama, with tool calls executed
 * against the TruERP MCP server (spawned as a stdio child process).
 */
import express from "express";
import { execSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { runAgent } from "./agent.js";
import { McpManager } from "./mcpClient.js";
import { getProvider, providers } from "./providers/index.js";
import type { AgentEvent, ChatMessage } from "./types.js";

// Load .env when present (Node ≥20.6). Absence is fine.
try {
  process.loadEnvFile(path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../.env"));
} catch {
  /* no .env */
}

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = path.resolve(HERE, "../public");
const PORT = Number(process.env.PORT || 8788);

const DEFAULT_SYSTEM = `You are an expert accountant and business analyst embedded in TruERP,
a billing/ERP application. You have tools to query and modify the live ERP
data (parties, products, inventory, sales invoices, purchases, payments,
expenses, cash & bank, reports, GST/tax, HR/payroll, accounting).

How to work:
- Prefer calling tools over guessing; never invent IDs, numbers, or totals.
- After every tool call, ALWAYS produce a complete natural-language answer
  built from the tool results — never reply with empty text, and never dump
  raw JSON or internal IDs at the user.
- For list endpoints, prefer page/per_page filters instead of dumping full lists.

Write operations (create / update / delete):
- For create requests (sales or purchase invoice, quotation, payment in/out,
  credit/debit note, product, party, expense, stock adjustment, etc.), first
  check the target tool's REQUIRED fields (and any data the user already gave).
- If any required field is missing, ask the user for ALL of it in ONE clear
  numbered list — do not call the create tool, and do not ask one question
  per turn.
- Ask briefly for sensible optional fields only when they'd obviously matter
  (e.g. date defaults to today; payment mode for payments).
- Datetime fields on create/update endpoints require RFC 3339 — send
  'YYYY-MM-DDTHH:mm:ssZ' (or with timezone offset), never bare 'YYYY-MM-DD'.
  Date-range list filters accept 'YYYY-MM-DD'.
- Once the user supplies everything, call the create tool exactly ONCE, then
  confirm what was created with its identifier — name, document number, or
  ID — plus a one-line summary of the key values.
- If creation fails, report the error plainly and ask for the corrected value.

How to communicate (accountant/analyst style):
- Lead with the headline number or finding, then the supporting detail —
  pull the related figures from the tool result that add context (counts,
  outstanding amounts, comparisons, top items) rather than answering with
  a single number.
- Format tabular data as markdown tables; short enumerations as bullets.
- Present amounts with the currency symbol (₹ by default) and thousands
  separators, e.g. ₹12,34,560.
- Add brief analyst commentary where useful: totals vs. expectations,
  anomalies, overdue/outstanding exposure, low-stock risks, tax notes.
- Keep it concise and businesslike — no filler, no restating the question.
- If a tool returns an error, explain it plainly and suggest a fix.

Today's date is ${new Date().toISOString().slice(0, 10)}.`;

const mcp = new McpManager();
const app = express();
app.use(express.json({ limit: "10mb" }));
app.use(express.static(PUBLIC_DIR));

function resolveApiKey(providerId: string, given?: string): string | undefined {
  if (given) return given;
  const envKey = getProvider(providerId)?.envKey;
  return envKey ? process.env[envKey] : undefined;
}

app.get("/api/health", async (_req, res) => {
  try {
    await mcp.ensureConnected();
    res.json({ ok: true, mcp: mcp.status, toolCount: (await mcp.listTools()).length });
  } catch (err) {
    res.status(503).json({
      ok: false,
      mcp: mcp.status,
      error: err instanceof Error ? err.message : String(err),
    });
  }
});

app.get("/api/providers", (_req, res) => {
  res.json(
    Object.values(providers).map((p) => ({
      id: p.id,
      label: p.label,
      needsKey: p.needsKey,
      envKey: p.envKey,
      defaultModel: p.defaultModel,
      defaultBaseUrl: p.defaultBaseUrl,
    })),
  );
});

app.get("/api/models", async (req, res) => {
  const provider = getProvider(String(req.query.provider ?? ""));
  if (!provider) {
    res.status(400).json({ error: `Unknown provider: ${String(req.query.provider)}` });
    return;
  }
  try {
    const apiKey = resolveApiKey(provider.id, req.header("x-api-key") || undefined);
    if (provider.needsKey && !apiKey) {
      res.status(400).json({ error: `API key required (sidebar or ${provider.envKey}).` });
      return;
    }
    const models = await provider.listModels({
      apiKey,
      baseUrl: typeof req.query.baseUrl === "string" ? req.query.baseUrl : undefined,
    });
    res.json(models);
  } catch (err) {
    res.status(502).json({ error: err instanceof Error ? err.message : String(err) });
  }
});

app.get("/api/tools", async (_req, res) => {
  try {
    const tools = await mcp.listTools();
    res.json(
      tools.map((t) => ({
        name: t.name,
        description: t.description,
        annotations: t.annotations,
      })),
    );
  } catch (err) {
    res.status(503).json({ error: err instanceof Error ? err.message : String(err) });
  }
});

interface ChatBody {
  provider?: string;
  model?: string;
  apiKey?: string;
  baseUrl?: string;
  system?: string;
  messages?: ChatMessage[];
  /** If present, whitelist of enabled tool names. Absent = all tools. */
  tools?: string[];
}

app.post("/api/chat", async (req, res) => {
  const body = req.body as ChatBody;
  const provider = getProvider(String(body.provider ?? ""));
  if (!provider) {
    res.status(400).json({ error: `Unknown provider: ${String(body.provider)}` });
    return;
  }
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    res.status(400).json({ error: "messages must be a non-empty array" });
    return;
  }
  const apiKey = resolveApiKey(provider.id, body.apiKey || req.header("x-api-key") || undefined);
  if (provider.needsKey && !apiKey) {
    res
      .status(400)
      .json({ error: `API key required — enter it in the sidebar or set ${provider.envKey}.` });
    return;
  }

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no",
  });
  res.flushHeaders();

  const emit = (ev: AgentEvent) => {
    if (!res.writableEnded) res.write(`data: ${JSON.stringify(ev)}\n\n`);
  };

  const abort = new AbortController();
  res.on("close", () => abort.abort());

  try {
    const allTools = await mcp.listTools();
    const enabled = Array.isArray(body.tools) ? new Set(body.tools) : undefined;
    const tools = enabled ? allTools.filter((t) => enabled.has(t.name)) : allTools;

    await runAgent({
      provider,
      model: body.model || provider.defaultModel,
      apiKey,
      baseUrl: body.baseUrl,
      system: body.system ?? DEFAULT_SYSTEM,
      messages: body.messages,
      tools,
      mcp,
      emit,
      signal: abort.signal,
    });
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    emit({ type: "error", error: msg === "aborted" ? "Request cancelled." : msg });
  } finally {
    res.end();
  }
});

// Warm up the MCP connection in the background so the first chat isn't slow.
mcp.ensureConnected().catch((err) => {
  console.error(`[mcp] initial connect failed: ${err instanceof Error ? err.message : err}`);
});

/**
 * If the port is held by a stale truerp-chat instance (e.g. orphaned when a
 * parent process was killed, or a previous shutdown hung on open SSE
 * connections), kill it and return true so the caller can retry the listen.
 * Foreign processes are never touched.
 */
function killStaleInstance(port: number): boolean {
  try {
    const out = execSync(`lsof -nP -tiTCP:${port} -sTCP:LISTEN`, { encoding: "utf8" });
    let killed = false;
    for (const pidStr of out.trim().split("\n").filter(Boolean)) {
      const pid = Number(pidStr);
      if (pid === process.pid) continue;
      let cmd = "";
      try {
        cmd = execSync(`ps -p ${pid} -o command=`, { encoding: "utf8" });
      } catch {
        continue;
      }
      if (/node\b.*\bdist[/\\]index\.js\b/.test(cmd)) {
        console.error(`[start] killing stale truerp-chat instance (pid ${pid}): ${cmd.trim()}`);
        try {
          process.kill(pid, "SIGKILL");
          killed = true;
        } catch {
          /* already gone */
        }
      }
    }
    return killed;
  } catch {
    return false; // lsof unavailable / nothing listening
  }
}

function listen(port: number, retries = 1): ReturnType<typeof app.listen> {
  const server = app.listen(port);
  server.on("listening", () => {
    console.log(`TruERP Chat → http://localhost:${port}`);
  });
  server.on("error", (err: NodeJS.ErrnoException) => {
    if (err.code === "EADDRINUSE" && retries > 0 && killStaleInstance(port)) {
      setTimeout(() => listen(port, retries - 1), 400);
      return;
    }
    if (err.code === "EADDRINUSE") {
      console.error(`Port ${port} is already in use — kill the other process or set PORT=<other>.`);
    } else {
      console.error(err);
    }
    process.exit(1);
  });
  return server;
}

const server = listen(PORT);

let shuttingDown = false;
for (const sig of ["SIGINT", "SIGTERM"] as const) {
  process.on(sig, async () => {
    if (shuttingDown) process.exit(1); // second signal → force
    shuttingDown = true;
    server.closeAllConnections?.(); // drop SSE/keep-alive sockets so close() can't hang
    server.close();
    await Promise.race([mcp.close(), new Promise((r) => setTimeout(r, 3_000))]);
    process.exit(0);
  });
}
