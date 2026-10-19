import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, custom, zUuid, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerSupportPortalTools(server: McpServer, ctx: Ctx) {
  // ---- User Support Requests ----
  endpoint(server, ctx, "list_my_support_requests", "List support tickets created by the current user.", "GET", "/api/v1/support-requests");
  endpoint(
    server,
    ctx,
    "create_support_request",
    "Open a support request ticket to the platform administrators.",
    "POST",
    "/api/v1/support-requests",
    {
      subject: z.string(),
      category: z.string().optional().describe("e.g. billing, feature, bug, general"),
      message: z.string(),
      priority: z.string().optional().describe("low, normal, high, urgent"),
    },
  );
  endpoint(server, ctx, "get_support_request", "Get a support request details with discussion thread.", "GET", "/api/v1/support-requests/:id", { id: zUuid });
  endpoint(server, ctx, "close_support_request", "Close a support request.", "PUT", "/api/v1/support-requests/:id/close", { id: zUuid });
  endpoint(
    server,
    ctx,
    "reply_support_request",
    "Post a reply message to a support request thread.",
    "POST",
    "/api/v1/support-requests/:id/replies",
    { id: zUuid, message: z.string() },
  );

  // ---- Admin Support Requests ----
  endpoint(
    server,
    ctx,
    "admin_list_support_requests",
    "List all support requests across all users/stores (super admin).",
    "GET",
    "/api/v1/admin/support-requests",
    {
      status: z.string().optional(),
      category: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "admin_get_support_request", "Get support request details with thread (super admin).", "GET", "/api/v1/admin/support-requests/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "admin_update_support_request",
    "Update support request status or priority (super admin).",
    "PUT",
    "/api/v1/admin/support-requests/:id",
    {
      id: zUuid,
      status: z.string().optional().describe("open, pending, resolved, closed"),
      priority: z.string().optional(),
    },
  );

  // ---- Support Contact Settings ----
  endpoint(server, ctx, "get_support_contact_settings", "Get business support contact channels (phone, email, WhatsApp, hours).", "GET", "/api/v1/support-settings");
  endpoint(
    server,
    ctx,
    "update_support_contact_settings",
    "Update business support contact channels.",
    "PUT",
    "/api/v1/support-settings",
    {
      support_email: z.string().optional(),
      support_phone: z.string().optional(),
      whatsapp_number: z.string().optional(),
      working_hours: z.string().optional(),
    },
  );

  // ---- Customer Portal (Super Admin) ----
  endpoint(server, ctx, "get_customer_portal_settings", "Get customer portal settings (branding, features, slug).", "GET", "/api/v1/customer-portal/settings");
  endpoint(
    server,
    ctx,
    "update_customer_portal_settings",
    "Update customer portal settings.",
    "PUT",
    "/api/v1/customer-portal/settings",
    {
      portal_enabled: z.boolean().optional(),
      portal_slug: z.string().optional(),
      portal_name: z.string().optional(),
      allow_invoice_downloads: z.boolean().optional(),
      allow_online_payments: z.boolean().optional(),
      allow_tickets: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "list_customer_portal_access", "List customer access credentials for the portal.", "GET", "/api/v1/customer-portal/access");
  endpoint(
    server,
    ctx,
    "upsert_customer_portal_access",
    "Grant or update customer portal login access for a party.",
    "PUT",
    "/api/v1/customer-portal/access/:party_id",
    {
      party_id: zUuid,
      is_enabled: z.boolean().optional(),
      pin: z.string().optional().describe("Access PIN/password"),
    },
  );
  endpoint(server, ctx, "admin_list_portal_tickets", "List customer portal support tickets (super admin).", "GET", "/api/v1/customer-portal/tickets");
  endpoint(
    server,
    ctx,
    "admin_update_portal_ticket",
    "Update a customer portal support ticket status/reply.",
    "PUT",
    "/api/v1/customer-portal/tickets/:id",
    {
      id: zUuid,
      status: z.string().optional(),
      reply: z.string().optional(),
    },
  );

  // ---- Customer Portal (Client Endpoints) ----
  endpoint(server, ctx, "get_portal_public_info", "Get public customer portal info by business slug.", "GET", "/api/v1/portal/public/:slug", { slug: z.string() });
  endpoint(
    server,
    ctx,
    "portal_login",
    "Log in a customer to their portal using phone/email and PIN.",
    "POST",
    "/api/v1/portal/login",
    {
      slug: z.string(),
      phone: z.string(),
      pin: z.string(),
    },
  );
  endpoint(server, ctx, "portal_get_profile", "Get logged-in customer's profile in portal.", "GET", "/api/v1/portal/me");
  endpoint(server, ctx, "portal_list_invoices", "List invoices belonging to the logged-in portal customer.", "GET", "/api/v1/portal/invoices");
  endpoint(server, ctx, "portal_get_invoice", "Get invoice details in customer portal.", "GET", "/api/v1/portal/invoices/:id", { id: zUuid });

  custom(
    server,
    "portal_invoice_pdf",
    "Download invoice PDF via customer portal.",
    { id: zUuid },
    async ({ id }) => {
      const { base64, mimeType } = await ctx.api.download(`/api/v1/portal/invoices/${id}/pdf`);
      return { id, mimeType, base64Length: base64.length, base64Data: base64 };
    },
    { readOnly: true },
  );

  endpoint(server, ctx, "portal_list_payments", "List payments made by customer in portal.", "GET", "/api/v1/portal/payments");
  endpoint(server, ctx, "portal_get_loyalty", "Get customer loyalty points balance and history in portal.", "GET", "/api/v1/portal/loyalty");
  endpoint(server, ctx, "portal_list_statements", "List account statements in portal.", "GET", "/api/v1/portal/statements");

  custom(
    server,
    "portal_statement_pdf",
    "Download account statement PDF via customer portal.",
    { id: zUuid },
    async ({ id }) => {
      const { base64, mimeType } = await ctx.api.download(`/api/v1/portal/statements/${id}/pdf`);
      return { id, mimeType, base64Length: base64.length, base64Data: base64 };
    },
    { readOnly: true },
  );

  endpoint(server, ctx, "portal_list_tickets", "List customer support tickets in portal.", "GET", "/api/v1/portal/tickets");
  endpoint(
    server,
    ctx,
    "portal_create_ticket",
    "Create a new support ticket in customer portal.",
    "POST",
    "/api/v1/portal/tickets",
    {
      subject: z.string(),
      message: z.string(),
    },
  );
}
