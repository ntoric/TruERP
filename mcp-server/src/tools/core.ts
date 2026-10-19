import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, custom, zUuid, type Ctx } from "./helpers.js";

export function registerCoreTools(server: McpServer, ctx: Ctx) {
  custom(
    server,
    "ping",
    "Check connectivity to the TruERP API (calls /health, no auth needed) and report the configured base URL.",
    {},
    async () => {
      const res = await fetch(`${ctx.api.baseUrl}/health`);
      const text = await res.text();
      return { status: res.status, body: text };
    },
    { readOnly: true },
  );

  endpoint(server, ctx, "get_profile", "Get the currently authenticated user's profile.", "GET", "/api/v1/auth/profile");
  endpoint(server, ctx, "list_my_stores", "List stores accessible to the authenticated user.", "GET", "/api/v1/auth/my-stores");

  // ---- Business profile ----
  endpoint(server, ctx, "get_business", "Get the business profile (name, GSTIN, address, bank details, invoice settings flags).", "GET", "/api/v1/business");
  endpoint(
    server,
    ctx,
    "update_business",
    "Update the business profile.",
    "PUT",
    "/api/v1/business",
    {
      name: z.string().optional(),
      gstin: z.string().optional(),
      address: z.string().optional(),
      city: z.string().optional(),
      state: z.string().optional(),
      pincode: z.string().optional(),
      phone: z.string().optional(),
      email: z.string().optional(),
      state_code: z.string().optional(),
      bank_name: z.string().optional(),
      account_number: z.string().optional(),
      ifsc_code: z.string().optional(),
      upi_id: z.string().optional(),
      allow_negative_stock: z.boolean().optional(),
      enable_ai_hsn_search: z.boolean().optional(),
      enable_ai_bill_parsing: z.boolean().optional(),
    },
  );

  // ---- Stores (super admin) ----
  endpoint(server, ctx, "list_stores", "List all stores (super admin).", "GET", "/api/v1/stores");
  endpoint(server, ctx, "get_store", "Get a store by ID (super admin).", "GET", "/api/v1/stores/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "create_store",
    "Create a store with its owner user (super admin).",
    "POST",
    "/api/v1/stores",
    {
      name: z.string(),
      owner_name: z.string().optional().describe("Store owner's display name"),
      owner_email: z.string().optional(),
      owner_password: z.string().optional(),
      owner_phone: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_store",
    "Update a store (super admin).",
    "PUT",
    "/api/v1/stores/:id",
    { id: zUuid, name: z.string().optional(), is_active: z.boolean().optional() },
  );
  endpoint(server, ctx, "reset_store", "Reset all data in a store (super admin). Danger: wipes store data.", "POST", "/api/v1/stores/:id/reset", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "list_store_users", "List users belonging to a store (super admin).", "GET", "/api/v1/stores/:id/users", { id: zUuid });

  // ---- Business users ----
  endpoint(server, ctx, "list_business_users", "List users in the current business.", "GET", "/api/v1/settings/users");
  endpoint(
    server,
    ctx,
    "create_business_user",
    "Create a user in the current business (role-scoped access).",
    "POST",
    "/api/v1/settings/users",
    {
      name: z.string(),
      email: z.string(),
      password: z.string(),
      phone: z.string().optional(),
      role: z.string().optional().describe("Role name, e.g. staff, admin"),
    },
  );
  endpoint(
    server,
    ctx,
    "update_business_user",
    "Update a business user.",
    "PUT",
    "/api/v1/settings/users/:id",
    { id: zUuid, name: z.string().optional(), phone: z.string().optional(), role: z.string().optional(), is_active: z.boolean().optional() },
  );
  endpoint(server, ctx, "delete_business_user", "Delete a business user.", "DELETE", "/api/v1/settings/users/:id", { id: zUuid }, { destructive: true });

  // ---- Announcements / notifications ----
  endpoint(server, ctx, "list_active_announcements", "List currently active announcements.", "GET", "/api/v1/announcements/active");
  endpoint(
    server,
    ctx,
    "list_notifications",
    "List in-app notifications.",
    "GET",
    "/api/v1/notifications",
    { status: z.string().optional(), is_read: z.boolean().optional(), type: z.string().optional(), page: z.number().int().optional(), per_page: z.number().int().optional() },
  );
  endpoint(server, ctx, "mark_notification_read", "Mark a notification as read.", "PUT", "/api/v1/notifications/:id/read", { id: zUuid });
  endpoint(server, ctx, "mark_all_notifications_read", "Mark all notifications as read.", "PUT", "/api/v1/notifications/read-all");

  // ---- Drafts (form drafts) ----
  endpoint(server, ctx, "list_drafts", "List saved form drafts.", "GET", "/api/v1/drafts", { entity_type: z.string().optional() });
  endpoint(
    server,
    ctx,
    "create_draft",
    "Save a form draft (entity_type: product, category, invoice, purchase, sales_return, purchase_return, payment_in, payment_out).",
    "POST",
    "/api/v1/drafts",
    {
      entity_type: z.string(),
      title: z.string(),
      data: z.record(z.any()).describe("Draft payload — arbitrary JSON form data"),
    },
  );
  endpoint(server, ctx, "get_draft", "Get a draft by ID.", "GET", "/api/v1/drafts/:id", { id: zUuid });
  endpoint(server, ctx, "delete_draft", "Delete a draft.", "DELETE", "/api/v1/drafts/:id", { id: zUuid }, { destructive: true });
}
