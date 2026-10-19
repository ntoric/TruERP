import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerAuditTools(server: McpServer, ctx: Ctx) {
  endpoint(
    server,
    ctx,
    "list_audit_logs",
    "List security and system audit logs with filters (super admin).",
    "GET",
    "/api/v1/audit/logs",
    {
      action: z.string().optional(),
      entity_type: z.string().optional(),
      user_id: zUuid.optional(),
      from_date: z.string().optional(),
      to_date: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_audit_log", "Get an audit log by ID (super admin).", "GET", "/api/v1/audit/logs/:id", { id: zUuid });
  endpoint(server, ctx, "get_audit_stats", "Get audit log statistical aggregations (super admin).", "GET", "/api/v1/audit/stats");
  endpoint(
    server,
    ctx,
    "export_audit_logs",
    "Export audit log records to CSV/JSON format (super admin).",
    "GET",
    "/api/v1/audit/logs/export",
    {
      action: z.string().optional(),
      from_date: z.string().optional(),
      to_date: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_audit_logs", "Delete audit log records matching criteria (super admin).", "DELETE", "/api/v1/audit/logs", { before_date: z.string().optional() }, { destructive: true });
  endpoint(server, ctx, "get_audit_retention_settings", "Get audit log retention policies (super admin).", "GET", "/api/v1/audit/retention");
  endpoint(
    server,
    ctx,
    "update_audit_retention_settings",
    "Update audit log retention policies (super admin).",
    "PUT",
    "/api/v1/audit/retention",
    {
      retention_days: z.number().int().optional(),
      auto_archive: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "archive_audit_logs", "Archive older audit logs to storage (super admin).", "POST", "/api/v1/audit/archive", { before_date: z.string().optional() });
  endpoint(server, ctx, "list_archived_audit_logs", "List archived audit log snapshots (super admin).", "GET", "/api/v1/audit/archives");
}
