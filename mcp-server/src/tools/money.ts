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
  zPaymentMode,
  type Ctx,
} from "./helpers.js";

const zNoteItem = (billItemKey: string) =>
  z
    .object({
      [billItemKey]: zUuid.optional().describe("Line ID on the source bill/invoice"),
      description: z.string(),
      quantity: z.number().positive(),
      unit_price: z.number(),
      tax_rate: z.number().optional(),
      reason: z.string().optional(),
    })
    .passthrough();

export function registerMoneyTools(server: McpServer, ctx: Ctx) {
  // ---------- Payments In ----------
  endpoint(
    server,
    ctx,
    "list_payments_in",
    "List payments received (payment-in) with invoice/party/mode/date filters.",
    "GET",
    "/api/v1/payments",
    {
      search: zSearch,
      invoice_id: zUuid.optional(),
      party_id: zUuid.optional(),
      mode: z.string().optional(),
      ...zFromTo,
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_next_payment_in_number", "Preview the next payment-in number.", "GET", "/api/v1/payments/next-number");
  endpoint(
    server,
    ctx,
    "create_payment_in",
    "Record a payment received from a customer (optionally against an invoice).",
    "POST",
    "/api/v1/payments",
    {
      party_id: zUuid,
      invoice_id: zUuid.optional().describe("Settle this invoice when provided"),
      amount_received: z.number().positive(),
      payment_in_discount: z.number().optional().describe("Settlement discount given"),
      payment_in_number: z.string().optional(),
      mode: z.string().describe("cash|upi|bank_transfer|cheque|card"),
      date: zDate,
      reference: z.string().optional().describe("Cheque/UTR/reference number"),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_payment_in", "Delete a payment-in (reverses settlement).", "DELETE", "/api/v1/payments/:id", { id: zUuid }, { destructive: true });
  downloadEndpoint(server, ctx, "get_payment_receipt_pdf", "Download a payment receipt PDF (base64 blob).", "/api/v1/payments/:id/pdf", { id: zUuid }, "receipt.pdf");

  // ---------- Payments Out ----------
  endpoint(
    server,
    ctx,
    "list_payments_out",
    "List payments made to vendors (payment-out).",
    "GET",
    "/api/v1/payment-outs",
    { search: zSearch, party_id: zUuid.optional(), purchase_bill_id: zUuid.optional(), invoice_id: zUuid.optional(), mode: z.string().optional(), ...zFromTo, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_payment_out",
    "Record a payment made to a vendor — against a purchase bill, or a refund for a sales return / credit note / invoice.",
    "POST",
    "/api/v1/payment-outs",
    {
      party_id: zUuid,
      purchase_bill_id: zUuid.optional(),
      sales_return_id: zUuid.optional().describe("Refund a processed sales return in money"),
      credit_note_id: zUuid.optional().describe("Pay off an issued credit note in money"),
      invoice_id: zUuid.optional().describe("Refund against a sales invoice"),
      amount_paid: z.number().positive(),
      payment_out_discount: z.number().optional().describe("Settlement discount received"),
      payment_out_number: z.string().optional(),
      mode: z.string().describe("cash|upi|bank_transfer|cheque|card"),
      date: zDate,
      reference: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_payment_out", "Delete a payment-out.", "DELETE", "/api/v1/payment-outs/:id", { id: zUuid }, { destructive: true });

  // ---------- Credit notes ----------
  endpoint(
    server,
    ctx,
    "list_credit_notes",
    "List credit notes issued to customers.",
    "GET",
    "/api/v1/credit-notes",
    { party_id: zUuid.optional(), invoice_id: zUuid.optional(), status: z.string().optional(), from_date: zDate.optional(), to_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_credit_note", "Get a credit note with items.", "GET", "/api/v1/credit-notes/:id", { id: zUuid });
  endpoint(server, ctx, "get_next_credit_note_number", "Preview the next credit note number.", "GET", "/api/v1/credit-notes/next-number");
  endpoint(
    server,
    ctx,
    "create_credit_note",
    "Create a credit note against a sales invoice.",
    "POST",
    "/api/v1/credit-notes",
    {
      invoice_id: zUuid,
      date: zDate,
      reason: z.string().optional(),
      refund_mode: z.string().optional().describe("cash|original_payment|credit_note"),
      items: z.array(zNoteItem("invoice_item_id")).min(1),
    },
  );
  endpoint(
    server,
    ctx,
    "update_credit_note",
    "Update a draft credit note.",
    "PUT",
    "/api/v1/credit-notes/:id",
    { id: zUuid, date: zDate.optional(), reason: z.string().optional(), refund_mode: z.string().optional() },
  );
  endpoint(server, ctx, "issue_credit_note", "Issue a draft credit note (applies credit to the party/invoice).", "POST", "/api/v1/credit-notes/:id/issue", { id: zUuid });
  endpoint(server, ctx, "delete_credit_note", "Delete a credit note.", "DELETE", "/api/v1/credit-notes/:id", { id: zUuid }, { destructive: true });

  // ---------- Debit notes ----------
  endpoint(
    server,
    ctx,
    "list_debit_notes",
    "List debit notes issued to vendors.",
    "GET",
    "/api/v1/debit-notes",
    { party_id: zUuid.optional(), purchase_bill_id: zUuid.optional(), status: z.string().optional(), from_date: zDate.optional(), to_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_debit_note", "Get a debit note with items.", "GET", "/api/v1/debit-notes/:id", { id: zUuid });
  endpoint(server, ctx, "get_next_debit_note_number", "Preview the next debit note number.", "GET", "/api/v1/debit-notes/next-number");
  endpoint(
    server,
    ctx,
    "create_debit_note",
    "Create a debit note against a purchase bill.",
    "POST",
    "/api/v1/debit-notes",
    {
      purchase_bill_id: zUuid,
      date: zDate,
      reason: z.string().optional(),
      refund_mode: z.string().optional().describe("cash|original_payment|debit_note"),
      items: z.array(zNoteItem("purchase_bill_item_id")).min(1),
    },
  );
  endpoint(
    server,
    ctx,
    "update_debit_note",
    "Update a draft debit note.",
    "PUT",
    "/api/v1/debit-notes/:id",
    { id: zUuid, date: zDate.optional(), reason: z.string().optional(), refund_mode: z.string().optional() },
  );
  endpoint(server, ctx, "issue_debit_note", "Issue a draft debit note (applies debit to the vendor/bill).", "POST", "/api/v1/debit-notes/:id/issue", { id: zUuid });
  endpoint(server, ctx, "delete_debit_note", "Delete a debit note.", "DELETE", "/api/v1/debit-notes/:id", { id: zUuid }, { destructive: true });

  // ---------- Expenses ----------
  endpoint(
    server,
    ctx,
    "list_expenses",
    "List expenses with category/date filters.",
    "GET",
    "/api/v1/expenses",
    { search: zSearch, category: z.string().optional(), ...zFromTo, page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_expense", "Get an expense with line items.", "GET", "/api/v1/expenses/:id", { id: zUuid });
  endpoint(server, ctx, "get_next_expense_number", "Preview the next expense number.", "GET", "/api/v1/expenses/next-number");
  endpoint(
    server,
    ctx,
    "create_expense",
    "Record an expense. Provide either a flat amount or itemized lines; with_gst+tax_rate splits GST.",
    "POST",
    "/api/v1/expenses",
    {
      category: z.string().describe("Expense category name (see list_expense_categories)"),
      amount: z.number().optional().describe("Total amount — required when items are not given"),
      description: z.string().optional(),
      original_invoice_num: z.string().optional(),
      date: zDate,
      vendor: z.string().optional(),
      payment_mode: zPaymentMode,
      bank_account_id: zUuid.optional(),
      with_gst: z.boolean().optional(),
      tax_rate: z.number().optional(),
      notes: z.string().optional(),
      items: z
        .array(
          z.object({
            description: z.string(),
            quantity: z.number().optional(),
            unit_price: z.number(),
            tax_rate: z.number().optional(),
          }),
        )
        .optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_expense",
    "Update an expense.",
    "PUT",
    "/api/v1/expenses/:id",
    {
      id: zUuid,
      category: z.string().optional(),
      amount: z.number().optional(),
      description: z.string().optional(),
      original_invoice_num: z.string().optional(),
      date: zDate.optional(),
      vendor: z.string().optional(),
      payment_mode: zPaymentMode,
      bank_account_id: zUuid.optional(),
      with_gst: z.boolean().optional(),
      tax_rate: z.number().optional(),
      notes: z.string().optional(),
      items: z
        .array(
          z.object({
            description: z.string(),
            quantity: z.number().optional(),
            unit_price: z.number(),
            tax_rate: z.number().optional(),
          }),
        )
        .optional(),
    },
  );
  endpoint(server, ctx, "delete_expense", "Delete an expense.", "DELETE", "/api/v1/expenses/:id", { id: zUuid }, { destructive: true });
}
