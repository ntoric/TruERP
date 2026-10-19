import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zDate, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerMiscTools(server: McpServer, ctx: Ctx) {
  // ---------- POS sessions ----------
  endpoint(server, ctx, "list_pos_sessions", "List POS register sessions.", "GET", "/api/v1/pos/sessions", { status: z.string().optional(), from_date: zDate.optional(), to_date: zDate.optional(), page: zPage, per_page: zPerPage });
  endpoint(
    server,
    ctx,
    "open_pos_session",
    "Open a POS register session with opening cash.",
    "POST",
    "/api/v1/pos/sessions",
    { opening_cash: z.number(), outlet_id: zUuid.optional(), notes: z.string().optional() },
  );
  endpoint(server, ctx, "get_active_pos_session", "Get the currently open POS session, if any.", "GET", "/api/v1/pos/sessions/active");
  endpoint(server, ctx, "get_pos_session", "Get a POS session by ID.", "GET", "/api/v1/pos/sessions/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "close_pos_session",
    "Close a POS session with the counted closing cash.",
    "POST",
    "/api/v1/pos/sessions/:id/close",
    { id: zUuid, closing_cash: z.number().optional(), notes: z.string().optional() },
  );
  endpoint(server, ctx, "get_pos_session_summary", "Sales/cash summary for a POS session.", "GET", "/api/v1/pos/sessions/:id/summary", { id: zUuid });
  endpoint(server, ctx, "list_pos_cash_movements", "Cash in/out movements within a POS session.", "GET", "/api/v1/pos/sessions/:id/cash-movements", { id: zUuid });
  endpoint(
    server,
    ctx,
    "add_pos_cash_movement",
    "Record a cash-in or cash-out within a POS session.",
    "POST",
    "/api/v1/pos/sessions/:id/cash-movements",
    { id: zUuid, type: z.enum(["cash_in", "cash_out"]), amount: z.number().positive(), reason: z.string().optional() },
  );

  // ---------- Reminders ----------
  endpoint(server, ctx, "list_reminders", "List reminders.", "GET", "/api/v1/settings/reminders");
  endpoint(
    server,
    ctx,
    "create_reminder",
    "Create a reminder.",
    "POST",
    "/api/v1/settings/reminders",
    {
      title: z.string(),
      description: z.string().optional(),
      remind_at: zDate.optional().describe("When to remind"),
      party_id: zUuid.optional(),
      invoice_id: zUuid.optional(),
    },
  );
  endpoint(server, ctx, "update_reminder", "Update a reminder.", "PUT", "/api/v1/settings/reminders/:id", { id: zUuid, title: z.string().optional(), description: z.string().optional(), remind_at: zDate.optional(), is_done: z.boolean().optional() });
  endpoint(server, ctx, "delete_reminder", "Delete a reminder.", "DELETE", "/api/v1/settings/reminders/:id", { id: zUuid }, { destructive: true });

  // ---------- Invoice settings & templates ----------
  endpoint(server, ctx, "get_invoice_settings", "Get invoice numbering/template settings.", "GET", "/api/v1/settings/invoice");
  endpoint(
    server,
    ctx,
    "update_invoice_settings",
    "Update invoice settings (template, colors, numbering prefix, terms, etc.).",
    "PUT",
    "/api/v1/settings/invoice",
    {
      template: z.string().optional().describe("classic|modern|minimal"),
      primary_color: z.string().optional(),
      secondary_color: z.string().optional(),
      prefix: z.string().optional(),
      next_number: z.number().int().optional(),
      terms: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "list_invoice_templates", "List saved invoice templates.", "GET", "/api/v1/invoice-templates");
  endpoint(server, ctx, "get_print_settings", "Get print settings.", "GET", "/api/v1/settings/print");
  endpoint(
    server,
    ctx,
    "update_print_settings",
    "Update print settings.",
    "PUT",
    "/api/v1/settings/print",
    {
      paper_size: z.string().optional(),
      copies: z.number().int().optional(),
      show_logo: z.boolean().optional(),
      show_signature: z.boolean().optional(),
    },
  );

  // ---------- Notification automation ----------
  endpoint(server, ctx, "send_invoice_due_reminders", "Trigger invoice due-date reminder notifications.", "POST", "/api/v1/notifications/send-invoice-due-reminders");
  endpoint(server, ctx, "send_payment_reminders", "Trigger payment reminder notifications.", "POST", "/api/v1/notifications/send-payment-reminders");
  endpoint(server, ctx, "send_overdue_notifications", "Trigger overdue invoice notifications.", "POST", "/api/v1/notifications/send-overdue-notifications");

  // ---------- Offline sync status ----------
  endpoint(server, ctx, "get_sync_status", "Offline sync queue status.", "GET", "/api/v1/sync/status");
  endpoint(server, ctx, "list_pending_syncs", "List pending offline sync operations.", "GET", "/api/v1/sync/pending");

  // ---------- Support requests ----------
  endpoint(server, ctx, "list_my_support_requests", "List support tickets raised by this account.", "GET", "/api/v1/support-requests");
  endpoint(
    server,
    ctx,
    "create_support_request",
    "Raise a support request to the platform admin.",
    "POST",
    "/api/v1/support-requests",
    { subject: z.string(), message: z.string(), category: z.string().optional(), priority: z.string().optional() },
  );
}
