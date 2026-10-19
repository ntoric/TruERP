# TruERP Chat

A standalone AI chat interface for the TruERP MCP server. It runs an agentic
loop — the model streams a reply, calls MCP tools against the live ERP API,
and continues until it produces a final answer.

## Providers

| Provider   | Notes                                                            |
| ---------- | ---------------------------------------------------------------- |
| Gemini     | `@google/genai`, needs `GEMINI_API_KEY` (or key entered in the UI) |
| OpenRouter | OpenAI-compatible, needs `OPENROUTER_API_KEY`                      |
| Ollama     | Local models via `http://localhost:11434` (no key required)        |

The chat server spawns `mcp-server/dist/index.js` as a stdio MCP child
process — the same way Claude Desktop / Cursor launch it — and exposes all
~390 TruERP tools to the model.

## Requirements

- Node.js ≥ 18 (built-in `fetch` + `.env` loading used)
- Built MCP server: `cd ../mcp-server && npm run build`
- Running TruERP backend (default `http://localhost:8088`)

## Setup

```bash
cd chat
npm install
cp .env.example .env   # fill in TRUERP_* credentials (+ API keys if desired)
npm run build
npm start
```

Open http://localhost:8788

## Configuration

| Env var                 | Default                          | Description                                    |
| ----------------------- | -------------------------------- | ---------------------------------------------- |
| `PORT`                  | `8788`                           | HTTP port for the chat UI                      |
| `TRUERP_API_URL`        | `http://localhost:8088`          | Backend URL handed to the MCP server           |
| `TRUERP_TOKEN`          | —                                | Pre-issued JWT (alt. to email/password)        |
| `TRUERP_EMAIL/PASSWORD` | —                                | TruERP login                                   |
| `TRUERP_STORE_ID`       | —                                | `X-Store-ID` header (super-admin scoping)      |
| `GEMINI_API_KEY`        | —                                | Fallback if no key entered in UI               |
| `OPENROUTER_API_KEY`    | —                                | Fallback if no key entered in UI               |
| `OLLAMA_BASE_URL`       | `http://localhost:11434`         | Ollama daemon URL                              |
| `MCP_SERVER_PATH`       | `../mcp-server/dist/index.js`    | Path to the MCP server entrypoint              |
| `MCP_SERVER_COMMAND`    | `node`                           | Full command override (`MCP_SERVER_ARGS` too)  |
| `MAX_TOOL_RESULT_CHARS` | `40000`                          | Per-call truncation before feeding the model   |
| `MAX_AGENT_ITERATIONS`  | `16`                             | Tool-loop safety cap                           |

## Tool selection

With ~390 tools registered, sending every schema on each request is heavy —
especially for small-context Ollama models. Use the **Tools** panel in the
sidebar to enable only the domains you need (e.g. just `list_invoices`,
`get_invoice`, `create_invoice` for billing questions). Selections persist
in `localStorage`.

## How it works

```
browser ──SSE──▶ chat server ──spawn stdio──▶ mcp-server ──REST──▶ TruERP backend
                     │
                     └─▶ Gemini / OpenRouter / Ollama (streaming, tool calls)
```

- `GET /api/health` — MCP connection status + tool count
- `GET /api/providers` — provider metadata
- `GET /api/models?provider=…` — dynamic model list
- `GET /api/tools` — MCP tool catalogue for the picker
- `POST /api/chat` — SSE stream (`token`, `tool_call`, `tool_result`,
  `append`, `done`, `error` events)

Binary tool results (invoice PDFs, exports) are saved to `chat/downloads/`
instead of being fed back to the model.

## Development

```bash
npm run dev        # tsc --watch
npm run typecheck
```

Layout:

```
src/
  index.ts               express bootstrap + SSE endpoint
  agent.ts               model ↔ tool-call loop
  mcpClient.ts           stdio MCP client manager
  providers/
    index.ts             provider registry
    gemini.ts            @google/genai adapter
    openaiCompat.ts      shared OpenAI-compatible adapter (OpenRouter + Ollama)
public/                  zero-build chat UI
```
