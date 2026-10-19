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
  zFromTo,
  zLineItem,
  zPaymentMode,
  zPaymentSplits,
  zAdditionalChargeItems,
  type Ctx,
} from "./helpers.js";

export function registerSalesTools(server: McpServer, ctx: Ctx) {
  // ---------- Invoices ----------
  endpoint(
    server,
    ctx,
    "list_invoices",
    "List sales invoices with status/party/search/date filters and sorting.",
    "GET",
    "/api/v1/invoices",
    {
      status: z.string().optional().describe("draft|sent|paid|overdue|cancelled"),
      party_id: zUuid.optional(),
      search: zSearch,
      ...zFromTo,
      sort: z.string().optional().describe("date|number|amount"),
      order: z.string().optional().describe("asc|desc"),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_invoice", "Get an invoice with items, party, and payment info.", "GET", "/api/v1/invoices/:id", { id: zUuid });
  endpoint(server, ctx, "get_invoice_stats", "Invoice stats for a period (count, totals, paid vs due).", "GET", "/api/v1/invoices/stats", { ...zFromTo, status: z.string().optional() });
  endpoint(server, ctx, "get_next_invoice_number", "Preview the next invoice number.", "GET", "/api/v1/invoices/next-number");
  endpoint(
    server,
    ctx,
    "create_invoice",
    "Create a sales invoice. Computes totals/tax server-side; records payment and stock movements per payload.",
    "POST",
    "/api/v1/invoices",
    {
      party_id: zUuid.describe("Customer party ID"),
      invoice_number: z.string().optional().describe("Auto-generated when omitted"),
      invoice_type: z.string().optional().describe("tax_invoice|bill_of_supply|export"),
      date: zDate,
      due_date: zDate.optional(),
      payment_terms: z.number().int().optional().describe("Credit days"),
      status: z.string().optional().describe("draft|sent|paid"),
      payment_mode: zPaymentMode,
      amount_paid: z.number().optional(),
      received_amount: z.number().optional().describe("Alias for amount_paid"),
      payment_splits: zPaymentSplits,
      bank_account_id: zUuid.optional(),
      is_inter_state: z.boolean().optional().describe("IGST instead of CGST+SGST"),
      invoice_discount: z.number().optional(),
      additional_charges: z.number().optional(),
      additional_charge_items: zAdditionalChargeItems,
      loyalty_points_redeemed: z.number().int().optional(),
      eway_bill_required: z.boolean().optional(),
      is_pos: z.boolean().optional(),
      pos_session_id: zUuid.optional(),
      notes: z.string().optional(),
      terms: z.string().optional(),
      pdf_template: z.string().optional().describe("classic|modern|minimal"),
      custom_fields: z.record(z.any()).optional(),
      client_sale_id: zUuid.optional().describe("Idempotency key — retries return the existing invoice"),
      items: z.array(zLineItem).min(1),
    },
  );
  endpoint(
    server,
    ctx,
    "update_invoice",
    "Update an invoice (typically drafts or editable fields).",
    "PUT",
    "/api/v1/invoices/:id",
    {
      id: zUuid,
      invoice_number: z.string().optional(),
      invoice_type: z.string().optional(),
      date: zDate.optional(),
      due_date: zDate.optional(),
      payment_terms: z.number().int().optional(),
      status: z.string().optional(),
      payment_mode: zPaymentMode,
      amount_paid: z.number().optional(),
      payment_splits: zPaymentSplits,
      bank_account_id: zUuid.optional(),
      is_inter_state: z.boolean().optional(),
      invoice_discount: z.number().optional(),
      additional_charges: z.number().optional(),
      additional_charge_items: zAdditionalChargeItems,
      notes: z.string().optional(),
      terms: z.string().optional(),
      pdf_template: z.string().optional(),
      custom_fields: z.record(z.any()).optional(),
      items: z.array(zLineItem).optional(),
    },
  );
  endpoint(server, ctx, "delete_invoice", "Delete an invoice (soft delete).", "DELETE", "/api/v1/invoices/:id", { id: zUuid }, { destructive: true });
  endpoint(
    server,
    ctx,
    "update_invoice_status",
    "Change an invoice's lifecycle status.",
    "PATCH",
    "/api/v1/invoices/:id/status",
    { id: zUuid, status: z.string().describe("draft|sent|paid|overdue|cancelled"), note: z.string().optional(), amount_paid: z.number().optional() },
  );
  endpoint(server, ctx, "get_invoice_status_history", "Get the audit trail of status changes for an invoice.", "GET", "/api/v1/invoices/:id/status-history", { id: zUuid });
  endpoint(server, ctx, "list_invoice_attachments", "List files attached to an invoice.", "GET", "/api/v1/invoices/:id/attachments", { id: zUuid });
  downloadEndpoint(server, ctx, "get_invoice_pdf", "Download an invoice PDF (base64 blob).", "/api/v1/invoices/:id/pdf", { id: zUuid }, "invoice.pdf");

  // ---------- Quotations ----------
  endpoint(
    server,
    ctx,
    "list_quotations",
    "List quotations/estimates.",
    "GET",
    "/api/v1/quotations",
    { party_id: zUuid.optional(), status: z.string().optional(), search: zSearch, from: zDate.optional(), to: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_quotation", "Get a quotation with items.", "GET", "/api/v1/quotations/:id", { id: zUuid });
  endpoint(server, ctx, "get_next_quotation_number", "Preview the next quotation number.", "GET", "/api/v1/quotations/next-number");
  endpoint(
    server,
    ctx,
    "create_quotation",
    "Create a quotation/estimate for a customer.",
    "POST",
    "/api/v1/quotations",
    {
      party_id: zUuid,
      quotation_number: z.string().optional(),
      date: zDate,
      valid_until: zDate.optional(),
      payment_terms: z.number().int().optional(),
      is_inter_state: z.boolean().optional(),
      place_of_supply: z.string().optional(),
      reverse_charge: z.boolean().optional(),
      quotation_discount: z.number().optional(),
      additional_charges: z.number().optional(),
      additional_charge_items: zAdditionalChargeItems,
      notes: z.string().optional(),
      terms: z.string().optional(),
      items: z.array(zLineItem).min(1),
    },
  );
  endpoint(
    server,
    ctx,
    "update_quotation",
    "Update a quotation.",
    "PUT",
    "/api/v1/quotations/:id",
    {
      id: zUuid,
      quotation_number: z.string().optional(),
      date: zDate.optional(),
      valid_until: zDate.optional(),
      payment_terms: z.number().int().optional(),
      is_inter_state: z.boolean().optional(),
      place_of_supply: z.string().optional(),
      reverse_charge: z.boolean().optional(),
      quotation_discount: z.number().optional(),
      additional_charges: z.number().optional(),
      additional_charge_items: zAdditionalChargeItems,
      notes: z.string().optional(),
      terms: z.string().optional(),
      items: z.array(zLineItem).optional(),
    },
  );
  endpoint(server, ctx, "delete_quotation", "Delete a quotation.", "DELETE", "/api/v1/quotations/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "approve_quotation", "Approve a quotation internally.", "POST", "/api/v1/quotations/:id/approve", { id: zUuid });
  endpoint(server, ctx, "accept_quotation", "Mark a quotation as accepted by the customer.", "POST", "/api/v1/quotations/:id/accept", { id: zUuid });
  endpoint(server, ctx, "reject_quotation", "Mark a quotation as rejected.", "POST", "/api/v1/quotations/:id/reject", { id: zUuid });
  endpoint(server, ctx, "convert_quotation_to_invoice", "Convert an approved/accepted quotation into a sales invoice.", "POST", "/api/v1/quotations/:id/convert", { id: zUuid });
  endpoint(server, ctx, "get_quotation_versions", "List version history of a quotation.", "GET", "/api/v1/quotations/:id/versions", { id: zUuid });
  endpoint(
    server,
    ctx,
    "send_quotation",
    "Send a quotation to the customer (marks it sent; delivery channel per server config).",
    "POST",
    "/api/v1/quotations/:id/send",
    { id: zUuid },
  );
  downloadEndpoint(server, ctx, "get_quotation_pdf", "Download a quotation PDF (base64 blob).", "/api/v1/quotations/:id/pdf", { id: zUuid }, "quotation.pdf");

  // ---------- Sales returns ----------
  endpoint(
    server,
    ctx,
    "list_sales_returns",
    "List sales returns (customer returns).",
    "GET",
    "/api/v1/sales-returns",
    { party_id: zUuid.optional(), status: z.string().optional(), from_date: zDate.optional(), to_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_sales_return",
    "Create a sales return against an invoice.",
    "POST",
    "/api/v1/sales-returns",
    {
      party_id: zUuid,
      invoice_id: zUuid.optional(),
      settle_invoice_id: zUuid.optional().describe("Apply credit refund to a different invoice (exchange flow)"),
      date: zDate,
      reason: z.string().optional(),
      refund_mode: z.string().optional().describe("cash|original_payment|credit_note"),
      notes: z.string().optional(),
      deduction_items: zAdditionalChargeItems.describe("Amounts withheld from refund, e.g. restocking fee"),
      items: z
        .array(
          z.object({
            invoice_item_id: zUuid.optional(),
            product_id: zUuid.optional(),
            description: z.string().optional(),
            quantity: z.number().positive(),
            unit_price: z.number(),
            tax_rate: z.number().optional(),
            reason: z.string().optional(),
          }),
        )
        .min(1),
    },
  );
  endpoint(server, ctx, "get_sales_return", "Get a sales return with items.", "GET", "/api/v1/sales-returns/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_sales_return",
    "Update a draft sales return.",
    "PUT",
    "/api/v1/sales-returns/:id",
    {
      id: zUuid,
      date: zDate.optional(),
      reason: z.string().optional(),
      refund_mode: z.string().optional(),
      notes: z.string().optional(),
      deduction_items: zAdditionalChargeItems,
      settle_invoice_id: zUuid.optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "process_sales_return",
    "Process a draft sales return — restocks items and issues refund/credit note per refund_mode.",
    "POST",
    "/api/v1/sales-returns/:id/process",
    { id: zUuid },
  );
  endpoint(server, ctx, "delete_sales_return", "Delete a sales return.", "DELETE", "/api/v1/sales-returns/:id", { id: zUuid }, { destructive: true });

  // ---------- Delivery challans ----------
  endpoint(
    server,
    ctx,
    "list_delivery_challans",
    "List delivery challans.",
    "GET",
    "/api/v1/delivery-challans",
    { party_id: zUuid.optional(), status: z.string().optional(), from: zDate.optional(), to: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_delivery_challan", "Get a delivery challan with items.", "GET", "/api/v1/delivery-challans/:id", { id: zUuid });
  endpoint(server, ctx, "get_next_challan_number", "Preview the next delivery challan number.", "GET", "/api/v1/delivery-challans/next-number");
  endpoint(
    server,
    ctx,
    "create_delivery_challan",
    "Create a delivery challan (goods dispatch note, optionally linked to an invoice).",
    "POST",
    "/api/v1/delivery-challans",
    {
      party_id: zUuid,
      challan_number: z.string().optional().describe("Auto-generated when omitted"),
      invoice_id: zUuid.optional(),
      date: zDate,
      due_date: zDate.optional(),
      status: z.string().optional().describe("draft|delivered|cancelled"),
      vehicle_number: z.string().optional(),
      transport_mode: z.string().optional().describe("road|rail|air|sea"),
      notes: z.string().optional(),
      terms: z.string().optional(),
      items: z
        .array(
          z.object({
            description: z.string(),
            quantity: z.number(),
            unit: z.string().optional(),
            unit_price: z.number().optional(),
            batch_no: z.string().optional(),
          }),
        )
        .min(1),
    },
  );
  endpoint(
    server,
    ctx,
    "update_delivery_challan",
    "Update a delivery challan.",
    "PUT",
    "/api/v1/delivery-challans/:id",
    {
      id: zUuid,
      status: z.string().optional(),
      due_date: zDate.optional(),
      vehicle_number: z.string().optional(),
      transport_mode: z.string().optional(),
      notes: z.string().optional(),
      terms: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_delivery_challan", "Delete a delivery challan.", "DELETE", "/api/v1/delivery-challans/:id", { id: zUuid }, { destructive: true });
}
