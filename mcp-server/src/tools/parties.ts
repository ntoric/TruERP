import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import {
  endpoint,
  downloadEndpoint,
  zUuid,
  zDate,
  zPage,
  zPerPage,
  zSearch,
  type Ctx,
} from "./helpers.js";

const partyFields = {
  name: z.string().describe("Party display name"),
  phone: z.string().optional(),
  email: z.string().optional(),
  gstin: z.string().optional().describe("15-char GSTIN"),
  address: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  pincode: z.string().optional(),
  state_code: z.string().optional().describe("2-digit GST state code"),
  category: z.string().optional().describe("Free-form grouping/category label"),
  party_type: z.string().describe("customer | vendor | both"),
  opening_balance: z.number().optional().describe("Positive = party owes you (receivable); negative = you owe party"),
  balance: z.number().optional(),
  credit_limit: z.number().optional(),
  tan: z.string().optional(),
  pan: z.string().optional(),
  notes: z.string().optional(),
  is_active: z.boolean().optional(),
};

export function registerPartyTools(server: McpServer, ctx: Ctx) {
  endpoint(
    server,
    ctx,
    "list_parties",
    "List parties (customers/vendors) with search, category/type filters and optional pagination.",
    "GET",
    "/api/v1/parties",
    {
      search: zSearch,
      category: z.string().optional(),
      party_type: z.string().optional().describe("customer | vendor"),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_party", "Get a party by ID.", "GET", "/api/v1/parties/:id", { id: zUuid });
  endpoint(server, ctx, "get_party_stats", "Get aggregate party stats (total parties, to-collect, to-pay).", "GET", "/api/v1/parties/stats");
  endpoint(server, ctx, "create_party", "Create a customer or vendor.", "POST", "/api/v1/parties", partyFields);
  endpoint(
    server,
    ctx,
    "update_party",
    "Update a party.",
    "PUT",
    "/api/v1/parties/:id",
    { id: zUuid, ...Object.fromEntries(Object.entries(partyFields).map(([k, v]) => [k, (v as z.ZodTypeAny).optional()])) },
  );
  endpoint(server, ctx, "delete_party", "Delete a party (soft delete).", "DELETE", "/api/v1/parties/:id", { id: zUuid }, { destructive: true });

  endpoint(
    server,
    ctx,
    "get_party_ledger",
    "Get the full ledger for a party: opening balance, every transaction (invoices, payments, returns, notes) and running balance.",
    "GET",
    "/api/v1/parties/:id/ledger",
    { id: zUuid, from: zDate.optional(), to: zDate.optional() },
  );
  downloadEndpoint(
    server,
    ctx,
    "get_party_ledger_pdf",
    "Download a party ledger as PDF (base64 blob).",
    "/api/v1/parties/:id/ledger/pdf",
    { id: zUuid, from: zDate.optional(), to: zDate.optional() },
    "party-ledger.pdf",
  );
  endpoint(
    server,
    ctx,
    "get_party_aging",
    "Get receivable/payable aging buckets for a party.",
    "GET",
    "/api/v1/customer-statements/parties/:id/aging",
    { id: zUuid },
  );
  endpoint(
    server,
    ctx,
    "get_aging_report",
    "Get aging report across all parties (outstanding bucketed by age).",
    "GET",
    "/api/v1/customer-statements/aging-report",
  );

  endpoint(
    server,
    ctx,
    "bulk_delete_parties",
    "Delete many parties at once. Pass ids, or all_matching+filters to delete by filter.",
    "POST",
    "/api/v1/parties/bulk/delete",
    {
      ids: z.array(zUuid).optional(),
      all_matching: z.boolean().optional(),
      filters: z
        .object({ search: z.string().optional(), category: z.string().optional(), party_type: z.string().optional() })
        .optional(),
    },
    { destructive: true },
  );
  endpoint(
    server,
    ctx,
    "bulk_update_party_category",
    "Assign a category label to many parties at once.",
    "POST",
    "/api/v1/parties/bulk/update-category",
    {
      ids: z.array(zUuid).optional(),
      category: z.string(),
      all_matching: z.boolean().optional(),
      filters: z
        .object({ search: z.string().optional(), category: z.string().optional(), party_type: z.string().optional() })
        .optional(),
    },
  );

  // ---- Loyalty ----
  endpoint(server, ctx, "get_loyalty_settings", "Get loyalty program settings.", "GET", "/api/v1/loyalty/settings");
  endpoint(
    server,
    ctx,
    "update_loyalty_settings",
    "Update loyalty program settings.",
    "PUT",
    "/api/v1/loyalty/settings",
    {
      is_enabled: z.boolean().optional(),
      spend_amount: z.number().optional().describe("Amount spent to earn points_per_spend points"),
      points_per_spend: z.number().int().optional(),
      point_value: z.number().optional().describe("Currency value per redeemed point"),
      min_redeem_points: z.number().int().optional(),
      max_redeem_percent: z.number().optional(),
    },
  );
  endpoint(server, ctx, "get_loyalty_stats", "Get loyalty program stats.", "GET", "/api/v1/loyalty/stats");
  endpoint(
    server,
    ctx,
    "list_loyalty_transactions",
    "List loyalty point transactions (earn/redeem/adjust/expire).",
    "GET",
    "/api/v1/loyalty/transactions",
    { party_id: zUuid.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "list_loyalty_customers",
    "List customers with their loyalty point balances.",
    "GET",
    "/api/v1/loyalty/customers",
    { search: zSearch, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "get_party_loyalty_balance",
    "Get a party's current loyalty point balance.",
    "GET",
    "/api/v1/loyalty/parties/:party_id",
    { party_id: zUuid },
  );
  endpoint(
    server,
    ctx,
    "adjust_party_loyalty",
    "Manually adjust a party's loyalty points (positive or negative).",
    "POST",
    "/api/v1/loyalty/parties/:party_id/adjust",
    { party_id: zUuid, points: z.number().int(), notes: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "calculate_loyalty_redemption",
    "Preview how many points can be redeemed against a bill amount.",
    "POST",
    "/api/v1/loyalty/calculate-redemption",
    { party_id: zUuid, bill_amount: z.number(), points: z.number().int().optional() },
    { paramStyle: "body" },
  );

  // ---- Customer statements ----
  endpoint(
    server,
    ctx,
    "generate_customer_statement",
    "Generate a customer account statement for a date range.",
    "POST",
    "/api/v1/customer-statements",
    {
      party_id: zUuid,
      from_date: zDate,
      to_date: zDate,
    },
  );
  endpoint(
    server,
    ctx,
    "list_customer_statements",
    "List generated customer statements.",
    "GET",
    "/api/v1/customer-statements",
    { party_id: zUuid.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_customer_statement", "Get a customer statement by ID.", "GET", "/api/v1/customer-statements/:id", { id: zUuid });
  endpoint(server, ctx, "delete_customer_statement", "Delete a customer statement.", "DELETE", "/api/v1/customer-statements/:id", { id: zUuid }, { destructive: true });
  downloadEndpoint(
    server,
    ctx,
    "get_customer_statement_pdf",
    "Download a customer statement PDF (base64 blob).",
    "/api/v1/customer-statements/:id/pdf",
    { id: zUuid },
    "customer-statement.pdf",
  );
}
