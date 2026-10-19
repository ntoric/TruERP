import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { URL, fileURLToPath } from "node:url";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { registerAllTools } from "./tools/index.js";
import { TrueRPClient, type ClientConfig, loadConfigFromEnv } from "./client.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

interface ActiveSession {
  transport: SSEServerTransport;
  server: McpServer;
  client: TrueRPClient;
  token?: string;
  user?: Record<string, unknown>;
}

export interface HttpOptions {
  port: number;
  host: string;
  config: ClientConfig;
}

export function startHttpServer(options: HttpOptions): http.Server {
  const { port, host, config } = options;
  const sessions = new Map<string, ActiveSession>();

  const server = http.createServer(async (req, res) => {
    // CORS headers for web/IDE clients
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE");
    res.setHeader(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization, X-Store-ID, Accept, Cache-Control, Last-Event-ID",
    );

    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    const parsedUrl = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);
    const pathname = parsedUrl.pathname;

    // -------------------------------------------------------------
    // 1. Health check
    // -------------------------------------------------------------
    if (pathname === "/health" && req.method === "GET") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(
        JSON.stringify({
          status: "ok",
          transport: "sse",
          apiBaseUrl: config.baseUrl,
          activeSessions: sessions.size,
        }),
      );
      return;
    }

    // -------------------------------------------------------------
    // OpenAPI Schema for ChatGPT Actions (GET /openapi.json)
    // -------------------------------------------------------------
    if (pathname === "/openapi.json" && req.method === "GET") {
      const proto = req.headers["x-forwarded-proto"] || "http";
      const publicBase = `${proto}://${req.headers.host || `${host}:${port}`}`;
      try {
        const filePath = path.resolve(__dirname, "../../chatgpt-actions-openapi.json");
        const altFilePath = path.resolve(__dirname, "../chatgpt-actions-openapi.json");
        const targetPath = fs.existsSync(filePath) ? filePath : altFilePath;
        const raw = fs.readFileSync(targetPath, "utf-8");
        const replaced = raw.replaceAll("https://YOUR_DOMAIN", publicBase);
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(replaced);
      } catch (err) {
        res.writeHead(500, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Failed to load openapi.json", detail: String(err) }));
      }
      return;
    }

    // -------------------------------------------------------------
    // 2. OAuth 2.0 Discovery (RFC 8414)
    // -------------------------------------------------------------
    if (
      (pathname === "/.well-known/oauth-authorization-server" ||
        pathname === "/.well-known/openid-configuration" ||
        pathname === "/oauth/.well-known/oauth-authorization-server") &&
      req.method === "GET"
    ) {
      const publicBase = `http://${req.headers.host || `${host}:${port}`}`;
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(
        JSON.stringify({
          issuer: publicBase,
          authorization_endpoint: `${publicBase}/oauth/authorize`,
          token_endpoint: `${publicBase}/oauth/token`,
          userinfo_endpoint: `${publicBase}/oauth/userinfo`,
          response_types_supported: ["code"],
          grant_types_supported: ["authorization_code", "client_credentials", "refresh_token", "password"],
          token_endpoint_auth_methods_supported: ["client_secret_basic", "client_secret_post", "none"],
          code_challenge_methods_supported: ["S256", "plain"],
          scopes_supported: ["read", "write", "admin", "erp"],
        }),
      );
      return;
    }

    // -------------------------------------------------------------
    // 3. OAuth 2.0 Proxy Endpoints (Authorize, Token, UserInfo)
    // -------------------------------------------------------------
    if (pathname === "/oauth/authorize") {
      // Forward to backend authorization endpoint
      const targetUrl = new URL(`${config.baseUrl}/api/v1/oauth/authorize`);
      parsedUrl.searchParams.forEach((v, k) => targetUrl.searchParams.set(k, v));

      if (req.method === "GET") {
        try {
          const beRes = await fetch(targetUrl.toString());
          const html = await beRes.text();
          res.writeHead(beRes.status, { "Content-Type": beRes.headers.get("content-type") || "text/html" });
          res.end(html);
        } catch (err) {
          res.writeHead(502, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "Failed to connect to TruERP OAuth backend", detail: String(err) }));
        }
        return;
      }

      if (req.method === "POST") {
        const bodyBuf = await readBody(req);
        try {
          const beRes = await fetch(targetUrl.toString(), {
            method: "POST",
            headers: {
              "Content-Type": req.headers["content-type"] || "application/x-www-form-urlencoded",
              Accept: req.headers.accept || "*/*",
            },
            body: bodyBuf,
            redirect: "manual",
          });

          // If backend responded with 302 redirect
          const location = beRes.headers.get("location");
          if (location) {
            res.writeHead(beRes.status, { Location: location });
            res.end();
            return;
          }

          const respBody = await beRes.text();
          res.writeHead(beRes.status, { "Content-Type": beRes.headers.get("content-type") || "application/json" });
          res.end(respBody);
        } catch (err) {
          res.writeHead(502, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: "OAuth authorization failed", detail: String(err) }));
        }
        return;
      }
    }

    if (pathname === "/oauth/token" && req.method === "POST") {
      const bodyBuf = await readBody(req);
      try {
        const beRes = await fetch(`${config.baseUrl}/api/v1/oauth/token`, {
          method: "POST",
          headers: {
            "Content-Type": req.headers["content-type"] || "application/x-www-form-urlencoded",
            Accept: "application/json",
            Authorization: req.headers.authorization || "",
          },
          body: bodyBuf,
        });
        const respBody = await beRes.text();
        res.writeHead(beRes.status, { "Content-Type": "application/json" });
        res.end(respBody);
      } catch (err) {
        res.writeHead(502, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Token exchange failed", detail: String(err) }));
      }
      return;
    }

    if (pathname === "/oauth/userinfo" && req.method === "GET") {
      try {
        const beRes = await fetch(`${config.baseUrl}/api/v1/oauth/userinfo`, {
          headers: {
            Authorization: req.headers.authorization || "",
            Accept: "application/json",
          },
        });
        const respBody = await beRes.text();
        res.writeHead(beRes.status, { "Content-Type": "application/json" });
        res.end(respBody);
      } catch (err) {
        res.writeHead(502, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "UserInfo failed", detail: String(err) }));
      }
      return;
    }

    // -------------------------------------------------------------
    // 4. MCP SSE Transport (GET /sse)
    // -------------------------------------------------------------
    if (pathname === "/sse" && req.method === "GET") {
      // Validate OAuth 2.0 Bearer Token
      const token = extractBearerToken(req, parsedUrl);
      let sessionConfig = { ...config };
      let userInfo: Record<string, unknown> | undefined;

      if (token) {
        // Validate with TruERP backend
        const user = await validateOAuthToken(config.baseUrl, token);
        if (!user) {
          res.writeHead(401, {
            "Content-Type": "application/json",
            "WWW-Authenticate": 'Bearer realm="truerp-mcp", error="invalid_token", error_description="Token expired or invalid"',
          });
          res.end(JSON.stringify({ error: "Unauthorized: Invalid OAuth 2.0 Bearer token" }));
          return;
        }
        userInfo = user;
        sessionConfig.token = token;
        sessionConfig.oauthToken = token;
        const storeIdHeader = req.headers["x-store-id"];
        if (typeof storeIdHeader === "string") {
          sessionConfig.storeId = storeIdHeader;
        } else if (typeof user.store_id === "string") {
          sessionConfig.storeId = user.store_id;
        }
      } else if (!config.token && !config.email && !config.oauthClientId) {
        // No server default configured, and client didn't supply token
        res.writeHead(401, {
          "Content-Type": "application/json",
          "WWW-Authenticate": 'Bearer realm="truerp-mcp", error="unauthorized", error_description="OAuth 2.0 Bearer token is required to establish MCP SSE connection"',
        });
        res.end(JSON.stringify({ error: "OAuth 2.0 authentication required. Supply 'Authorization: Bearer <token>' or authenticate via /oauth/authorize" }));
        return;
      }

      const client = new TrueRPClient(sessionConfig);
      const mcpServer = new McpServer({
        name: "truerp-mcp-server",
        version: "1.0.0",
      });

      registerAllTools(mcpServer, { api: client });

      const transport = new SSEServerTransport("/messages", res);
      const sessionId = transport.sessionId;

      sessions.set(sessionId, {
        transport,
        server: mcpServer,
        client,
        token: sessionConfig.token,
        user: userInfo,
      });

      transport.onclose = () => {
        sessions.delete(sessionId);
      };

      await mcpServer.connect(transport);
      return;
    }

    // -------------------------------------------------------------
    // 5. MCP Post Messages (POST /messages)
    // -------------------------------------------------------------
    if (pathname === "/messages" && req.method === "POST") {
      const sessionId = parsedUrl.searchParams.get("sessionId");
      if (!sessionId) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Missing sessionId parameter" }));
        return;
      }

      const session = sessions.get(sessionId);
      if (!session) {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Session not found or expired" }));
        return;
      }

      await session.transport.handlePostMessage(req, res);
      return;
    }

    // Default 404
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found", path: pathname }));
  });

  server.listen(port, host, () => {
    console.error(`TruERP MCP Server running (HTTP/SSE) at http://${host}:${port}`);
    console.error(`  - SSE Endpoint:   http://${host}:${port}/sse`);
    console.error(`  - OAuth Discovery: http://${host}:${port}/.well-known/oauth-authorization-server`);
    console.error(`  - OAuth Authorize: http://${host}:${port}/oauth/authorize`);
    console.error(`  - OAuth Token:     http://${host}:${port}/oauth/token`);
    console.error(`  - TruERP API:      ${config.baseUrl}`);
  });

  return server;
}

function extractBearerToken(req: http.IncomingMessage, url: URL): string | undefined {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.toLowerCase().startsWith("bearer ")) {
    return authHeader.slice(7).trim();
  }
  const tokenQuery = url.searchParams.get("access_token");
  if (tokenQuery) return tokenQuery;
  return undefined;
}

async function validateOAuthToken(baseUrl: string, token: string): Promise<Record<string, unknown> | null> {
  try {
    const res = await fetch(`${baseUrl}/api/v1/oauth/userinfo`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/json",
      },
    });
    if (!res.ok) {
      // Fallback to /api/v1/auth/profile
      const resProfile = await fetch(`${baseUrl}/api/v1/auth/profile`, {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: "application/json",
        },
      });
      if (!resProfile.ok) return null;
      return (await resProfile.json()) as Record<string, unknown>;
    }
    return (await res.json()) as Record<string, unknown>;
  } catch {
    return null;
  }
}

function readBody(req: http.IncomingMessage): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", (chunk) => chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)));
    req.on("end", () => resolve(Buffer.concat(chunks)));
    req.on("error", reject);
  });
}
