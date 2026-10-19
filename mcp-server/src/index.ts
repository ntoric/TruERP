#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { TrueRPClient, loadConfigFromEnv } from "./client.js";
import { registerAllTools } from "./tools/index.js";

async function main() {
  const config = loadConfigFromEnv();
  const api = new TrueRPClient(config);

  const server = new McpServer({
    name: "truerp-mcp-server",
    version: "1.0.0",
  });

  registerAllTools(server, { api });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  // MCP stdio servers must keep stdout clean for protocol frames.
  console.error(`truerp-mcp-server running — API: ${config.baseUrl}`);
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
