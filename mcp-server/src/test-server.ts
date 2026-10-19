import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerAllTools } from "./tools/index.js";
import { TrueRPClient, loadConfigFromEnv } from "./client.js";
import { startHttpServer } from "./server-http.js";

async function runTests() {
  console.log("=== Testing TruERP MCP Server ===");

  // 1. Tool registration test
  const dummyClient = new TrueRPClient({
    baseUrl: "http://localhost:8088",
    token: "mock-token",
  });

  const server = new McpServer({
    name: "test-server",
    version: "1.0.0",
  });

  registerAllTools(server, { api: dummyClient });

  // @ts-expect-error accessing internal tools map for verification
  const tools = server._registeredTools || server._tools;
  const toolCount = tools ? Object.keys(tools).length : 0;
  console.log(`✓ Tools registered: ${toolCount} total tools across all modules`);
  if (toolCount < 50) {
    throw new Error(`Expected at least 50 tools, got ${toolCount}`);
  }

  // 2. HTTP/SSE Server & OAuth endpoints test
  const testPort = 18099;
  const httpServer = startHttpServer({
    port: testPort,
    host: "127.0.0.1",
    config: {
      baseUrl: "http://localhost:8088",
    },
  });

  await new Promise((resolve) => setTimeout(resolve, 500));

  try {
    // Test Health
    const resHealth = await fetch(`http://127.0.0.1:${testPort}/health`);
    const healthJson = (await resHealth.json()) as { status?: string; transport?: string };
    console.log("✓ Health endpoint response:", healthJson);
    if (healthJson.status !== "ok" || healthJson.transport !== "sse") {
      throw new Error("Health check failed");
    }

    // Test OAuth Discovery
    const resOauth = await fetch(`http://127.0.0.1:${testPort}/.well-known/oauth-authorization-server`);
    const oauthJson = (await resOauth.json()) as { token_endpoint?: string };
    console.log("✓ OAuth Discovery response:", oauthJson.token_endpoint);
    if (!oauthJson.token_endpoint || !oauthJson.token_endpoint.includes("/oauth/token")) {
      throw new Error("OAuth discovery failed");
    }

    // Test OpenAPI Endpoint for ChatGPT
    const resOpenApi = await fetch(`http://127.0.0.1:${testPort}/openapi.json`);
    const openApiJson = (await resOpenApi.json()) as { openapi?: string; paths?: Record<string, unknown> };
    console.log("✓ OpenAPI endpoint loaded paths count:", Object.keys(openApiJson.paths || {}).length);
    if (!openApiJson.openapi || !openApiJson.paths) {
      throw new Error("OpenAPI schema endpoint failed");
    }

    // Test SSE endpoint rejects without token
    const resSse = await fetch(`http://127.0.0.1:${testPort}/sse`);
    console.log("✓ SSE without token correctly rejected with status:", resSse.status);
    if (resSse.status !== 401) {
      throw new Error(`Expected 401, got ${resSse.status}`);
    }

    console.log("=== ALL MCP SERVER & OAUTH TESTS PASSED! ===");
  } finally {
    httpServer.close();
  }
}

runTests().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});
