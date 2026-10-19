import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, custom, zUuid, type Ctx } from "./helpers.js";

export function registerOAuthTools(server: McpServer, ctx: Ctx) {
  endpoint(
    server,
    ctx,
    "list_oauth_clients",
    "List registered OAuth 2.0 client applications (super admin).",
    "GET",
    "/api/v1/oauth/clients",
  );
  endpoint(
    server,
    ctx,
    "create_oauth_client",
    "Register a new OAuth 2.0 client application (super admin).",
    "POST",
    "/api/v1/oauth/clients",
    {
      client_name: z.string(),
      redirect_uris: z.string().describe("Comma-separated redirect URIs"),
      client_id: z.string().optional(),
      client_secret: z.string().optional(),
      grant_types: z.string().optional().describe("authorization_code,client_credentials,refresh_token,password"),
      scopes: z.string().optional().describe("read write admin erp"),
      is_public: z.boolean().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "delete_oauth_client",
    "Delete an OAuth 2.0 client application (super admin).",
    "DELETE",
    "/api/v1/oauth/clients/:id",
    { id: z.string() },
    { destructive: true },
  );
  endpoint(
    server,
    ctx,
    "get_oauth_userinfo",
    "Get authenticated OpenID/OAuth 2.0 user profile claims.",
    "GET",
    "/api/v1/oauth/userinfo",
  );
  endpoint(
    server,
    ctx,
    "revoke_oauth_token",
    "Revoke an OAuth 2.0 access or refresh token.",
    "POST",
    "/api/v1/oauth/revoke",
    { token: z.string() },
  );

  custom(
    server,
    "get_oauth_server_metadata",
    "Get RFC 8414 OAuth 2.0 Authorization Server Metadata and discovery endpoints.",
    {},
    async () => {
      const data = await ctx.api.get("/.well-known/oauth-authorization-server");
      return data;
    },
    { readOnly: true },
  );
}
