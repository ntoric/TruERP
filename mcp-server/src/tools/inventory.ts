import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zDate, zPage, zPerPage, zSearch, type Ctx } from "./helpers.js";

const zOutlet = zUuid.describe("Warehouse/outlet ID (use list_warehouses)");

const warehouseFields = {
  name: z.string(),
  code: z.string().describe("Unique short code, e.g. WH1"),
  address: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  pincode: z.string().optional(),
  contact_person: z.string().optional(),
  contact_phone: z.string().optional(),
  contact_email: z.string().optional(),
  is_default: z.boolean().optional(),
  is_active: z.boolean().optional(),
  notes: z.string().optional(),
};

export function registerInventoryTools(server: McpServer, ctx: Ctx) {
  // ---------- Warehouses ----------
  endpoint(server, ctx, "list_warehouses", "List warehouses/outlets.", "GET", "/api/v1/warehouses", { is_active: z.boolean().optional(), search: zSearch });
  endpoint(server, ctx, "get_warehouse", "Get a warehouse by ID.", "GET", "/api/v1/warehouses/:id", { id: zUuid });
  endpoint(server, ctx, "create_warehouse", "Create a warehouse/outlet.", "POST", "/api/v1/warehouses", warehouseFields);
  endpoint(
    server,
    ctx,
    "update_warehouse",
    "Update a warehouse.",
    "PUT",
    "/api/v1/warehouses/:id",
    { id: zUuid, ...Object.fromEntries(Object.entries(warehouseFields).map(([k, v]) => [k, v.optional()])) },
  );
  endpoint(server, ctx, "delete_warehouse", "Delete a warehouse.", "DELETE", "/api/v1/warehouses/:id", { id: zUuid }, { destructive: true });
  endpoint(
    server,
    ctx,
    "get_warehouse_stock",
    "Get consolidated stock levels for all items in a warehouse.",
    "GET",
    "/api/v1/warehouses/:id/stock",
    { id: zUuid, search: zSearch },
  );
  endpoint(server, ctx, "bulk_delete_warehouses", "Delete many warehouses at once.", "POST", "/api/v1/warehouses/bulk/delete", { ids: z.array(zUuid) }, { destructive: true });
  endpoint(
    server,
    ctx,
    "bulk_update_warehouse_status",
    "Activate/deactivate many warehouses.",
    "POST",
    "/api/v1/warehouses/bulk/update-status",
    { ids: z.array(zUuid), is_active: z.boolean() },
  );

  // ---------- Stock views ----------
  endpoint(
    server,
    ctx,
    "get_stock_balance",
    "Consolidated stock balance per product+warehouse (quantity, avg cost, value).",
    "GET",
    "/api/v1/inventory/balance",
    { outlet_id: zOutlet.optional(), product_id: zUuid.optional(), search: zSearch },
  );
  endpoint(
    server,
    ctx,
    "get_inventory_valuation",
    "Inventory valuation report (total value, per-product cost valuation).",
    "GET",
    "/api/v1/inventory/valuation",
    { outlet_id: zOutlet.optional(), as_of: zDate.optional() },
  );
  endpoint(server, ctx, "get_inventory_stats", "Inventory summary widgets: stock value, units, product count, low-stock count.", "GET", "/api/v1/inventory/stats");
  endpoint(
    server,
    ctx,
    "get_low_stock_alerts",
    "Products at or below their min-stock threshold, per warehouse.",
    "GET",
    "/api/v1/inventory/alerts/low-stock",
  );
  endpoint(
    server,
    ctx,
    "list_inventory_items",
    "Products formatted for inventory dropdown selection.",
    "GET",
    "/api/v1/inventory/items",
    { search: zSearch },
  );
  endpoint(
    server,
    ctx,
    "list_inventory_stocks",
    "Raw inventory stock rows (per product + warehouse + batch).",
    "GET",
    "/api/v1/inventory/stocks",
    { outlet_id: zOutlet.optional(), product_id: zUuid.optional(), search: zSearch, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "get_product_stock",
    "Stock rows for one product across warehouses/batches.",
    "GET",
    "/api/v1/inventory/stocks/products/:id",
    { id: zUuid.describe("Product ID") },
  );
  endpoint(
    server,
    ctx,
    "search_stock_by_item_code",
    "Look up stock by item code.",
    "GET",
    "/api/v1/inventory/stocks/search",
    { item_code: z.string(), outlet_id: zOutlet.optional() },
  );

  // ---------- Stock entries ----------
  endpoint(
    server,
    ctx,
    "list_stock_entries",
    "List stock ledger entries (purchase/sale/adjustment/transfer/opening).",
    "GET",
    "/api/v1/inventory/entries",
    {
      product_id: zUuid.optional(),
      entry_type: z.string().optional().describe("purchase|sale|adjustment|transfer|opening"),
      outlet_id: zOutlet.optional(),
      approval_status: z.string().optional().describe("pending|approved|rejected"),
      from_date: zDate.optional(),
      to_date: zDate.optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(
    server,
    ctx,
    "create_stock_entry",
    "Record a stock entry (opening stock, manual purchase in, adjustment, etc.).",
    "POST",
    "/api/v1/inventory/entries",
    {
      item_name: z.string(),
      product_id: zUuid.optional(),
      outlet_id: zOutlet,
      entry_type: z.enum(["purchase", "sale", "adjustment", "transfer", "opening"]),
      quantity: z.number(),
      cost_price: z.number().optional(),
      batch_no: z.string().optional(),
      item_code: z.string().optional(),
      mfg_date: zDate.optional(),
      exp_date: zDate.optional(),
      notes: z.string().optional(),
      reference_id: zUuid.optional(),
      reference_type: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_stock_entry",
    "Update a pending stock entry.",
    "PUT",
    "/api/v1/inventory/entries/:id",
    {
      id: zUuid,
      quantity: z.number().optional(),
      cost_price: z.number().optional(),
      batch_no: z.string().optional(),
      item_code: z.string().optional(),
      mfg_date: zDate.optional(),
      exp_date: zDate.optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "approve_stock_entry", "Approve a pending stock entry.", "POST", "/api/v1/inventory/entries/:id/approve", { id: zUuid });
  endpoint(
    server,
    ctx,
    "reject_stock_entry",
    "Reject a pending stock entry.",
    "POST",
    "/api/v1/inventory/entries/:id/reject",
    { id: zUuid, reason: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "approve_all_stock_entries",
    "Approve all pending stock entries (optionally filtered to a reference).",
    "POST",
    "/api/v1/inventory/entries/approve-all",
    { reference_id: z.string().optional(), reference_type: z.string().optional() },
  );

  // ---------- Stock transfers ----------
  endpoint(
    server,
    ctx,
    "list_stock_transfers",
    "List inter-warehouse stock transfers.",
    "GET",
    "/api/v1/inventory/transfers",
    { status: z.string().optional().describe("draft|submitted|received|cancelled"), page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_stock_transfer",
    "Create a stock transfer between warehouses.",
    "POST",
    "/api/v1/inventory/transfers",
    {
      from_outlet_id: zOutlet.optional().describe("Source warehouse (default warehouse if omitted)"),
      to_outlet_id: zOutlet.describe("Destination warehouse"),
      notes: z.string().optional(),
      items: z.array(z.object({ product_id: zUuid, quantity: z.number().positive() })).min(1),
    },
  );
  endpoint(server, ctx, "get_stock_transfer", "Get a stock transfer with its items.", "GET", "/api/v1/inventory/transfers/:id", { id: zUuid });
  endpoint(server, ctx, "submit_stock_transfer", "Submit a draft transfer (marks goods as sent).", "POST", "/api/v1/inventory/transfers/:id/submit", { id: zUuid });
  endpoint(
    server,
    ctx,
    "receive_stock_transfer",
    "Receive a submitted transfer into the destination warehouse.",
    "POST",
    "/api/v1/inventory/transfers/:id/receive",
    {
      id: zUuid,
      items: z.array(z.object({ item_id: zUuid, received_quantity: z.number() })).optional().describe("Partial receive quantities per item"),
    },
  );

  // ---------- Stock adjustments / reservations ----------
  endpoint(
    server,
    ctx,
    "adjust_stock",
    "Manually adjust stock quantity for an item in a warehouse (stock correction).",
    "POST",
    "/api/v1/inventory/stocks/adjust",
    {
      item_name: z.string(),
      product_id: zUuid.optional(),
      outlet_id: zOutlet,
      quantity: z.number().describe("Signed quantity — positive adds, negative removes"),
      batch_no: z.string().optional(),
      reason: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "reserve_stock",
    "Reserve stock for an order (moves qty to reserved).",
    "POST",
    "/api/v1/inventory/stocks/reserve",
    { product_id: zUuid, outlet_id: zOutlet, quantity: z.number().positive(), batch_no: z.string().optional(), reason: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "release_stock",
    "Release previously reserved stock.",
    "POST",
    "/api/v1/inventory/stocks/release",
    { product_id: zUuid, outlet_id: zOutlet, quantity: z.number().positive(), batch_no: z.string().optional(), reason: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "refresh_closing_stock",
    "Rebuild the materialized daily closing-stock snapshots (run after backdated changes).",
    "POST",
    "/api/v1/inventory/snapshots/refresh-closing",
    { from_date: zDate.optional() },
  );

  // ---------- Serial numbers ----------
  endpoint(
    server,
    ctx,
    "list_serial_numbers",
    "List serial numbers (in_stock/sold/returned/damaged).",
    "GET",
    "/api/v1/serial-numbers",
    { product_id: zUuid.optional(), status: z.string().optional(), warehouse_id: zUuid.optional(), search: zSearch, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_serial_number",
    "Register one serial number for a product.",
    "POST",
    "/api/v1/serial-numbers",
    {
      product_id: zUuid,
      serial_number: z.string(),
      warehouse_id: zUuid.optional(),
      batch_no: z.string().optional(),
      mfg_date: zDate.optional(),
      exp_date: zDate.optional(),
      cost_price: z.number().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "bulk_create_serial_numbers",
    "Register many serial numbers for a product at once.",
    "POST",
    "/api/v1/serial-numbers/bulk",
    {
      product_id: zUuid,
      serial_numbers: z.array(z.string()).min(1),
      warehouse_id: zUuid.optional(),
      batch_no: z.string().optional(),
      mfg_date: zDate.optional(),
      exp_date: zDate.optional(),
      cost_price: z.number().optional(),
    },
  );
  endpoint(server, ctx, "get_serial_number", "Get a serial number record.", "GET", "/api/v1/serial-numbers/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_serial_number",
    "Update a serial number's status/warehouse/notes.",
    "PUT",
    "/api/v1/serial-numbers/:id",
    {
      id: zUuid,
      status: z.string().optional().describe("in_stock|sold|returned|damaged"),
      warehouse_id: zUuid.optional(),
      invoice_id: zUuid.optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_serial_number", "Delete a serial number record.", "DELETE", "/api/v1/serial-numbers/:id", { id: zUuid }, { destructive: true });
}
