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
  zFromToDate,
  zPaymentMode,
  zPaymentSplits,
  zAdditionalChargeItems,
  type Ctx,
} from "./helpers.js";

const zOrderItem = z.object({
  description: z.string(),
  quantity: z.number().positive(),
  unit_price: z.number(),
  tax_rate: z.number().optional(),
});

const zReceiptItem = zOrderItem.extend({
  batch_no: z.string().optional(),
  mfg_date: zDate.optional(),
  exp_date: zDate.optional(),
});

const zBillItem = z
  .object({
    product_id: zUuid.optional(),
    item_code: z.string().optional(),
    description: z.string(),
    quantity: z.number(),
    unit: z.string().optional(),
    unit_price: z.number(),
    discount: z.number().optional(),
    tax_rate: z.number().optional(),
    mrp: z.number().optional(),
    sale_price: z.number().optional(),
    hsn_code: z.string().optional(),
    batch_no: z.string().optional(),
    mfg_date: zDate.optional(),
    exp_date: zDate.optional(),
    is_new_item: z.boolean().optional().describe("Create as new product if not matched"),
    category: z.string().optional(),
  })
  .passthrough();

export function registerPurchaseTools(server: McpServer, ctx: Ctx) {
  // ---------- Purchase orders ----------
  endpoint(
    server,
    ctx,
    "list_purchase_orders",
    "List purchase orders with party/status/date filters.",
    "GET",
    "/api/v1/purchase/orders",
    { party_id: zUuid.optional(), status: z.string().optional(), ...zFromToDate, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_purchase_order",
    "Create a purchase order for a vendor.",
    "POST",
    "/api/v1/purchase/orders",
    {
      party_id: zUuid.describe("Vendor party ID"),
      order_date: zDate,
      expected_date: zDate.optional(),
      notes: z.string().optional(),
      terms: z.string().optional(),
      items: z.array(zOrderItem).min(1),
    },
  );
  endpoint(server, ctx, "get_purchase_order", "Get a purchase order with items.", "GET", "/api/v1/purchase/orders/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_purchase_order",
    "Update a draft purchase order.",
    "PUT",
    "/api/v1/purchase/orders/:id",
    {
      id: zUuid,
      expected_date: zDate.optional(),
      notes: z.string().optional(),
      terms: z.string().optional(),
      items: z.array(zOrderItem).optional(),
    },
  );
  endpoint(server, ctx, "submit_purchase_order", "Submit a draft purchase order to the vendor.", "POST", "/api/v1/purchase/orders/:id/submit", { id: zUuid });
  endpoint(server, ctx, "delete_purchase_order", "Delete a purchase order.", "DELETE", "/api/v1/purchase/orders/:id", { id: zUuid }, { destructive: true });

  // ---------- Purchase receipts (GRN) ----------
  endpoint(
    server,
    ctx,
    "list_purchase_receipts",
    "List goods receipts against purchase orders.",
    "GET",
    "/api/v1/purchase/receipts",
    { party_id: zUuid.optional(), status: z.string().optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_purchase_receipt",
    "Record a goods receipt (optionally against a purchase order).",
    "POST",
    "/api/v1/purchase/receipts",
    {
      party_id: zUuid,
      purchase_order_id: zUuid.optional(),
      receipt_date: zDate,
      notes: z.string().optional(),
      items: z.array(zReceiptItem).min(1),
    },
  );
  endpoint(server, ctx, "get_purchase_receipt", "Get a purchase receipt with items.", "GET", "/api/v1/purchase/receipts/:id", { id: zUuid });
  endpoint(server, ctx, "submit_purchase_receipt", "Submit a draft purchase receipt (posts stock).", "POST", "/api/v1/purchase/receipts/:id/submit", { id: zUuid });

  // ---------- Purchase bills ----------
  endpoint(
    server,
    ctx,
    "list_purchase_bills",
    "List purchase bills (vendor invoices) with search, party/status/date filters. payable=true returns only unpaid/partial.",
    "GET",
    "/api/v1/purchase/bills",
    {
      search: zSearch,
      party_id: zUuid.optional(),
      status: z.string().optional().describe("unpaid|paid|partial"),
      payable: z.boolean().optional().describe("Only bills with balance due"),
      ...zFromToDate,
      sort: z.string().optional(),
      order: z.string().optional().describe("asc|desc"),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_purchase_bill", "Get a purchase bill with items and payment splits.", "GET", "/api/v1/purchase/bills/:id", { id: zUuid });
  endpoint(server, ctx, "get_purchase_bill_stats", "Purchase bill totals: total purchase, paid, unpaid.", "GET", "/api/v1/purchase/bills/stats", { ...zFromToDate });
  endpoint(
    server,
    ctx,
    "create_purchase_bill",
    "Create a purchase bill (vendor invoice). Posts stock entries when warehouse/stock status applies.",
    "POST",
    "/api/v1/purchase/bills",
    {
      party_id: zUuid.describe("Vendor party ID"),
      bill_number: z.string().describe("Vendor's bill/invoice number"),
      bill_date: zDate,
      due_date: zDate.optional(),
      warehouse_id: zUuid.optional().describe("Warehouse stock is posted into"),
      purchase_receipt_id: zUuid.optional(),
      status: z.string().optional().describe("unpaid|paid|partial — derived from paid_amount if omitted"),
      paid_amount: z.number().optional(),
      payment_mode: zPaymentMode,
      bank_account_id: zUuid.optional(),
      payment_splits: zPaymentSplits,
      tax_exempt: z.boolean().optional(),
      invoice_discount: z.number().optional(),
      additional_charges: z.number().optional(),
      additional_charge_items: zAdditionalChargeItems,
      notes: z.string().optional(),
      client_bill_id: zUuid.optional().describe("Idempotency key — retries return the existing bill"),
      items: z.array(zBillItem).min(1),
    },
  );
  endpoint(
    server,
    ctx,
    "update_purchase_bill",
    "Update a purchase bill.",
    "PUT",
    "/api/v1/purchase/bills/:id",
    {
      id: zUuid,
      bill_number: z.string().optional(),
      bill_date: zDate.optional(),
      due_date: zDate.optional(),
      warehouse_id: zUuid.optional(),
      paid_amount: z.number().optional(),
      payment_mode: zPaymentMode,
      bank_account_id: zUuid.optional(),
      payment_splits: zPaymentSplits,
      status: z.string().optional(),
      tax_exempt: z.boolean().optional(),
      invoice_discount: z.number().optional(),
      additional_charges: z.number().optional(),
      additional_charge_items: zAdditionalChargeItems,
      notes: z.string().optional(),
      items: z.array(zBillItem).optional(),
    },
  );
  endpoint(server, ctx, "delete_purchase_bill", "Delete a purchase bill.", "DELETE", "/api/v1/purchase/bills/:id", { id: zUuid }, { destructive: true });
  endpoint(
    server,
    ctx,
    "get_vendor_recent_products",
    "Products recently purchased from a vendor (quick-add list for new bills).",
    "GET",
    "/api/v1/purchase/bills/vendor/:vendorId/recent-products",
    { vendorId: zUuid },
  );
  downloadEndpoint(
    server,
    ctx,
    "get_purchase_bill_pdf",
    "Download a purchase bill PDF (base64 blob).",
    "/api/v1/purchase/bills/:id/pdf",
    { id: zUuid },
    "purchase-bill.pdf",
  );

  // ---------- Purchase returns ----------
  endpoint(
    server,
    ctx,
    "list_purchase_returns",
    "List purchase returns (goods returned to vendors).",
    "GET",
    "/api/v1/purchase-returns",
    { party_id: zUuid.optional(), status: z.string().optional(), from_date: zDate.optional(), to_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_purchase_return",
    "Create a purchase return against a purchase bill.",
    "POST",
    "/api/v1/purchase-returns",
    {
      party_id: zUuid,
      purchase_bill_id: zUuid.optional(),
      date: zDate,
      reason: z.string().optional(),
      refund_mode: z.string().optional().describe("cash|original_payment|debit_note"),
      notes: z.string().optional(),
      items: z
        .array(
          z.object({
            purchase_bill_item_id: zUuid.optional(),
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
  endpoint(server, ctx, "get_purchase_return", "Get a purchase return with items.", "GET", "/api/v1/purchase-returns/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_purchase_return",
    "Update a draft purchase return.",
    "PUT",
    "/api/v1/purchase-returns/:id",
    { id: zUuid, date: zDate.optional(), reason: z.string().optional(), refund_mode: z.string().optional(), notes: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "process_purchase_return",
    "Process a draft purchase return — reverses stock and issues refund/debit note per refund_mode.",
    "POST",
    "/api/v1/purchase-returns/:id/process",
    { id: zUuid },
  );
  endpoint(server, ctx, "delete_purchase_return", "Delete a purchase return.", "DELETE", "/api/v1/purchase-returns/:id", { id: zUuid }, { destructive: true });
}
