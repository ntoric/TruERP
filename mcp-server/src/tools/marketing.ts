import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerMarketingTools(server: McpServer, ctx: Ctx) {
  // ---- SMS Marketing ----
  endpoint(
    server,
    ctx,
    "list_sms_campaigns",
    "List SMS marketing campaigns with optional status and date filters.",
    "GET",
    "/api/v1/sms-marketing",
    {
      status: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_sms_marketing_stats", "Get SMS marketing statistics (total sent, delivered, failed).", "GET", "/api/v1/sms-marketing/stats");
  endpoint(
    server,
    ctx,
    "create_sms_campaign",
    "Create a new SMS marketing campaign.",
    "POST",
    "/api/v1/sms-marketing",
    {
      title: z.string(),
      message: z.string(),
      recipient_type: z.string().describe("e.g. all, customers, vendors, custom"),
      recipient_phone_numbers: z.array(z.string()).optional(),
      scheduled_at: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_sms_campaign", "Get an SMS marketing campaign by ID.", "GET", "/api/v1/sms-marketing/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_sms_campaign",
    "Update an SMS marketing campaign.",
    "PUT",
    "/api/v1/sms-marketing/:id",
    {
      id: zUuid,
      title: z.string().optional(),
      message: z.string().optional(),
      recipient_type: z.string().optional(),
      recipient_phone_numbers: z.array(z.string()).optional(),
      scheduled_at: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_sms_campaign", "Delete an SMS marketing campaign.", "DELETE", "/api/v1/sms-marketing/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "send_sms_campaign", "Send an SMS marketing campaign immediately.", "POST", "/api/v1/sms-marketing/:id/send", { id: zUuid });
  endpoint(
    server,
    ctx,
    "schedule_sms_campaign",
    "Schedule an SMS marketing campaign for later delivery.",
    "POST",
    "/api/v1/sms-marketing/:id/schedule",
    { id: zUuid, scheduled_at: z.string().describe("ISO timestamp") },
  );

  // ---- Email Marketing ----
  endpoint(
    server,
    ctx,
    "list_email_campaigns",
    "List email marketing campaigns.",
    "GET",
    "/api/v1/email-marketing",
    {
      status: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_email_marketing_stats", "Get email marketing statistics.", "GET", "/api/v1/email-marketing/stats");
  endpoint(
    server,
    ctx,
    "create_email_campaign",
    "Create a new email marketing campaign.",
    "POST",
    "/api/v1/email-marketing",
    {
      title: z.string(),
      subject: z.string(),
      body: z.string().describe("HTML or text body"),
      recipient_type: z.string().describe("all, customers, vendors, custom"),
      recipient_emails: z.array(z.string()).optional(),
      scheduled_at: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_email_campaign", "Get an email marketing campaign by ID.", "GET", "/api/v1/email-marketing/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_email_campaign",
    "Update an email marketing campaign.",
    "PUT",
    "/api/v1/email-marketing/:id",
    {
      id: zUuid,
      title: z.string().optional(),
      subject: z.string().optional(),
      body: z.string().optional(),
      recipient_type: z.string().optional(),
      recipient_emails: z.array(z.string()).optional(),
      scheduled_at: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_email_campaign", "Delete an email marketing campaign.", "DELETE", "/api/v1/email-marketing/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "send_email_campaign", "Send an email marketing campaign immediately.", "POST", "/api/v1/email-marketing/:id/send", { id: zUuid });
  endpoint(server, ctx, "resend_email_campaign", "Resend failed messages in an email marketing campaign.", "POST", "/api/v1/email-marketing/:id/resend", { id: zUuid });
  endpoint(
    server,
    ctx,
    "schedule_email_campaign",
    "Schedule an email marketing campaign.",
    "POST",
    "/api/v1/email-marketing/:id/schedule",
    { id: zUuid, scheduled_at: z.string().describe("ISO timestamp") },
  );

  // ---- WhatsApp Marketing ----
  endpoint(
    server,
    ctx,
    "list_whatsapp_campaigns",
    "List WhatsApp marketing campaigns.",
    "GET",
    "/api/v1/whatsapp-marketing",
    {
      status: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_whatsapp_marketing_stats", "Get WhatsApp marketing statistics.", "GET", "/api/v1/whatsapp-marketing/stats");
  endpoint(
    server,
    ctx,
    "create_whatsapp_campaign",
    "Create a new WhatsApp marketing campaign.",
    "POST",
    "/api/v1/whatsapp-marketing",
    {
      title: z.string(),
      message: z.string(),
      recipient_type: z.string().describe("all, customers, vendors, custom"),
      recipient_phone_numbers: z.array(z.string()).optional(),
      scheduled_at: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_whatsapp_campaign", "Get a WhatsApp marketing campaign by ID.", "GET", "/api/v1/whatsapp-marketing/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_whatsapp_campaign",
    "Update a WhatsApp marketing campaign.",
    "PUT",
    "/api/v1/whatsapp-marketing/:id",
    {
      id: zUuid,
      title: z.string().optional(),
      message: z.string().optional(),
      recipient_type: z.string().optional(),
      recipient_phone_numbers: z.array(z.string()).optional(),
      scheduled_at: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_whatsapp_campaign", "Delete a WhatsApp marketing campaign.", "DELETE", "/api/v1/whatsapp-marketing/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "send_whatsapp_campaign", "Send a WhatsApp marketing campaign immediately.", "POST", "/api/v1/whatsapp-marketing/:id/send", { id: zUuid });
  endpoint(
    server,
    ctx,
    "schedule_whatsapp_campaign",
    "Schedule a WhatsApp marketing campaign.",
    "POST",
    "/api/v1/whatsapp-marketing/:id/schedule",
    { id: zUuid, scheduled_at: z.string().describe("ISO timestamp") },
  );
}
