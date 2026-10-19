#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { TrueRPClient, loadConfigFromEnv } from "./client.js";
import { registerAllTools } from "./tools/index.js";
import { startHttpServer } from "./server-http.js";

async function main() {
  const config = loadConfigFromEnv();
  const args = process.argv.slice(2);

  // Parse transport flags
  let transportMode = process.env.MCP_TRANSPORT || "stdio";
  let port = parseInt(process.env.MCP_PORT || "8089", 10);
  let host = process.env.MCP_HOST || "0.0.0.0";

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === "--transport" && args[i + 1]) {
      transportMode = args[i + 1].toLowerCase();
      i++;
    } else if (arg.startsWith("--transport=")) {
      transportMode = arg.split("=")[1].toLowerCase();
    } else if (arg === "--port" && args[i + 1]) {
      port = parseInt(args[i + 1], 10);
      i++;
    } else if (arg.startsWith("--port=")) {
      port = parseInt(arg.split("=")[1], 10);
    } else if (arg === "--host" && args[i + 1]) {
      host = args[i + 1];
      i++;
    } else if (arg.startsWith("--host=")) {
      host = arg.split("=")[1];
    } else if (arg === "--sse") {
      transportMode = "sse";
    } else if (arg === "--stdio") {
      transportMode = "stdio";
    }
  }

  if (transportMode === "sse" || transportMode === "http") {
    startHttpServer({ port, host, config });
    return;
  }

  // Stdio transport (default)
  const api = new TrueRPClient(config);
  const server = new McpServer({
    name: "truerp-mcp-server",
    version: "1.0.0",
  });

  registerAllTools(server, { api });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Keep stdout clean for stdio JSON-RPC protocol
  console.error(`truerp-mcp-server running (stdio) — API: ${config.baseUrl}`);
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
