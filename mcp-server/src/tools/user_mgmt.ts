import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerUserMgmtTools(server: McpServer, ctx: Ctx) {
  // ---- User Management ----
  endpoint(
    server,
    ctx,
    "get_user_management_overview",
    "Get user management overview (users count, roles, 2FA status).",
    "GET",
    "/api/v1/user-management/overview",
    { all: z.boolean().optional() },
  );
  endpoint(
    server,
    ctx,
    "get_user_activity_logs",
    "Get user activity logs.",
    "GET",
    "/api/v1/user-management/activity-logs",
    { page: zPage, per_page: zPerPage, user_id: zUuid.optional() },
  );
  endpoint(server, ctx, "get_2fa_status", "Check two-factor authentication status for current account.", "GET", "/api/v1/user-management/2fa/status");
  endpoint(server, ctx, "setup_2fa", "Initiate 2FA setup (returns QR code URI and secret).", "POST", "/api/v1/user-management/2fa/setup");
  endpoint(
    server,
    ctx,
    "enable_2fa",
    "Confirm and enable 2FA with 6-digit TOTP code.",
    "POST",
    "/api/v1/user-management/2fa/enable",
    { code: z.string().describe("6-digit TOTP code") },
  );
  endpoint(
    server,
    ctx,
    "disable_2fa",
    "Disable two-factor authentication for current account.",
    "POST",
    "/api/v1/user-management/2fa/disable",
    { password: z.string().describe("Current account password") },
  );

  // ---- Account Profile & Password ----
  endpoint(
    server,
    ctx,
    "set_account_password",
    "Change account password.",
    "POST",
    "/api/v1/auth/set-password",
    {
      current_password: z.string(),
      new_password: z.string().min(6),
    },
  );
  endpoint(
    server,
    ctx,
    "update_profile",
    "Update authenticated user's name, email, or phone.",
    "PUT",
    "/api/v1/auth/profile",
    {
      name: z.string().optional(),
      email: z.string().email().optional(),
      phone: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "report_app_version",
    "Report client app version to backend.",
    "POST",
    "/api/v1/auth/app-version",
    {
      version: z.string(),
      platform: z.string().optional(),
    },
  );

  // ---- Page Features ----
  endpoint(server, ctx, "get_page_features", "Get module and menu page feature flags.", "GET", "/api/v1/page-features");
  endpoint(
    server,
    ctx,
    "update_page_features",
    "Update module and menu feature toggles (super admin).",
    "PUT",
    "/api/v1/page-features",
    {
      features: z.record(z.boolean()).describe("Feature flag key-value map"),
    },
  );
}
