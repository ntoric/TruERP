import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerAdminNotificationTools(server: McpServer, ctx: Ctx) {
  // ---- Notification Events ----
  endpoint(server, ctx, "list_notification_events", "List backoffice notification events (super admin).", "GET", "/api/v1/admin/notifications/events");
  endpoint(
    server,
    ctx,
    "create_notification_event",
    "Register a new backoffice notification event (super admin).",
    "POST",
    "/api/v1/admin/notifications/events",
    {
      code: z.string().describe("e.g. invoice_created, payment_received"),
      name: z.string(),
      description: z.string().optional(),
      channels: z.array(z.string()).optional(),
      template: z.string().optional(),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "get_notification_event", "Get a notification event by ID (super admin).", "GET", "/api/v1/admin/notifications/events/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_notification_event",
    "Update a notification event (super admin).",
    "PUT",
    "/api/v1/admin/notifications/events/:id",
    {
      id: zUuid,
      name: z.string().optional(),
      description: z.string().optional(),
      channels: z.array(z.string()).optional(),
      template: z.string().optional(),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "delete_notification_event", "Delete a notification event (super admin).", "DELETE", "/api/v1/admin/notifications/events/:id", { id: zUuid }, { destructive: true });
  endpoint(
    server,
    ctx,
    "trigger_notification_event",
    "Manually trigger a notification event test (super admin).",
    "POST",
    "/api/v1/admin/notifications/events/:id/trigger",
    {
      id: zUuid,
      payload: z.record(z.any()).optional().describe("Event parameters"),
    },
  );

  // ---- External Channels ----
  endpoint(server, ctx, "list_notification_channels", "List configured notification channels (email, sms, whatsapp, telegram, push).", "GET", "/api/v1/admin/notifications/channels");
  endpoint(
    server,
    ctx,
    "update_notification_channel",
    "Configure a notification delivery channel (super admin).",
    "PUT",
    "/api/v1/admin/notifications/channels/:channel",
    {
      channel: z.string().describe("smtp, telegram, whatsapp, sms, push"),
      config: z.record(z.any()).describe("Channel credentials and endpoint config"),
      is_enabled: z.boolean().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "test_notification_channel",
    "Send a test dispatch on a notification channel (super admin).",
    "POST",
    "/api/v1/admin/notifications/channels/:channel/test",
    {
      channel: z.string(),
      recipient: z.string().describe("Target email, phone or chat ID"),
    },
  );

  // ---- Broadcast & Deliveries ----
  endpoint(
    server,
    ctx,
    "broadcast_notification",
    "Broadcast a system notification to users (super admin).",
    "POST",
    "/api/v1/admin/notifications/broadcast",
    {
      title: z.string(),
      message: z.string(),
      type: z.string().optional().describe("info, warning, success, alert"),
      target_role: z.string().optional().describe("all, admin, staff, owner"),
    },
  );
  endpoint(
    server,
    ctx,
    "list_notification_deliveries",
    "List external notification delivery history logs (super admin).",
    "GET",
    "/api/v1/admin/notifications/deliveries",
    {
      channel: z.string().optional(),
      status: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "clear_notification_deliveries", "Clear notification delivery history logs (super admin).", "DELETE", "/api/v1/admin/notifications/deliveries", {}, { destructive: true });

  // ---- Announcements Admin ----
  endpoint(server, ctx, "list_admin_announcements", "List all platform announcements (super admin).", "GET", "/api/v1/admin/announcements");
  endpoint(
    server,
    ctx,
    "create_admin_announcement",
    "Create a new in-app announcement banner/modal (super admin).",
    "POST",
    "/api/v1/admin/announcements",
    {
      title: z.string(),
      content: z.string(),
      type: z.string().optional().describe("info, banner, update, promo"),
      is_active: z.boolean().optional(),
      start_date: z.string().optional(),
      end_date: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_admin_announcement", "Get an announcement by ID (super admin).", "GET", "/api/v1/admin/announcements/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_admin_announcement",
    "Update an announcement (super admin).",
    "PUT",
    "/api/v1/admin/announcements/:id",
    {
      id: zUuid,
      title: z.string().optional(),
      content: z.string().optional(),
      type: z.string().optional(),
      is_active: z.boolean().optional(),
      start_date: z.string().optional(),
      end_date: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_admin_announcement", "Delete an announcement (super admin).", "DELETE", "/api/v1/admin/announcements/:id", { id: zUuid }, { destructive: true });
}
