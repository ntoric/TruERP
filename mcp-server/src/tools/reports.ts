import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import {
  endpoint,
  zUuid,
  zDate,
  zPage,
  zPerPage,
  zSearch,
  zFromToDate,
  type Ctx,
} from "./helpers.js";

const zPeriod = z.string().optional().describe("Period grain: daily|weekly|monthly|yearly (default monthly)");
const zPeriodRange = {
  period: zPeriod,
  date: zDate.optional().describe("Anchor date inside the period (default today)"),
  start_date: zDate.optional().describe("Custom range start — overrides period"),
  end_date: zDate.optional().describe("Custom range end — overrides period"),
};

export function registerReportTools(server: McpServer, ctx: Ctx) {
  // ---------- Dashboard ----------
  endpoint(
    server,
    ctx,
    "get_dashboard_stats",
    "Headline business stats: sales, invoices, parties, products, pending amount, low stock, overdue.",
    "GET",
    "/api/v1/dashboard/stats",
    { ...zFromToDate, period: z.string().optional().describe("today|week|month|year|custom") },
  );
  endpoint(server, ctx, "get_recent_invoices", "Most recent invoices for the dashboard.", "GET", "/api/v1/dashboard/recent-invoices", { limit: z.number().int().optional() });
  endpoint(server, ctx, "get_recent_payments", "Most recent payments received.", "GET", "/api/v1/dashboard/recent-payments", { limit: z.number().int().optional() });
  endpoint(
    server,
    ctx,
    "get_dashboard_sales_report",
    "Sales trend buckets for the dashboard chart.",
    "GET",
    "/api/v1/dashboard/sales-report",
    { period: zPeriod },
  );
  endpoint(server, ctx, "get_dashboard_gst_report", "GST collected vs paid summary for the dashboard.", "GET", "/api/v1/dashboard/gst-report");
  endpoint(server, ctx, "get_top_parties", "Top parties by sales.", "GET", "/api/v1/dashboard/top-parties", { limit: z.number().int().optional(), period: zPeriod });

  // ---------- Daily / periodic reports ----------
  endpoint(
    server,
    ctx,
    "get_daily_report",
    "Full day report: sales, purchases, payments in/out, expenses, cash flow for one date.",
    "GET",
    "/api/v1/dashboard/daily-report",
    { date: zDate.optional().describe("Report date (default today)") },
  );
  endpoint(
    server,
    ctx,
    "get_periodic_report",
    "Aggregated report over a period (daily/weekly/monthly/yearly or a custom range).",
    "GET",
    "/api/v1/dashboard/periodic-report",
    zPeriodRange,
  );

  // ---------- Profit reports ----------
  endpoint(
    server,
    ctx,
    "get_profit_loss_report",
    "Profit & loss: revenue, COGS, gross profit, expenses and net profit for a period.",
    "GET",
    "/api/v1/dashboard/profit-loss-report",
    zPeriodRange,
  );
  endpoint(
    server,
    ctx,
    "get_billwise_profit_report",
    "Per-invoice profitability (sale minus purchase cost of items sold).",
    "GET",
    "/api/v1/dashboard/billwise-profit-report",
    { ...zFromToDate, party_id: zUuid.optional(), search: zSearch, sort: z.string().optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "get_daily_profit_report",
    "Materialized per-day profit rows.",
    "GET",
    "/api/v1/dashboard/daily-profit-report",
    { date: zDate.optional(), sort: z.string().optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "refresh_daily_profit_report", "Recompute the daily profit snapshot.", "POST", "/api/v1/dashboard/daily-profit-report/refresh");

  // ---------- Stock report ----------
  endpoint(
    server,
    ctx,
    "get_stock_report",
    "Opening/closing stock quantities and values with movements over a period.",
    "GET",
    "/api/v1/dashboard/stock-report",
    zPeriodRange,
  );

  // ---------- Report widgets & detailed reports ----------
  endpoint(server, ctx, "get_report_widgets", "Report landing-page widgets/metrics.", "GET", "/api/v1/reports/widgets");
  endpoint(
    server,
    ctx,
    "get_sales_report",
    "Detailed sales report (invoices, items, tax) for a period.",
    "GET",
    "/api/v1/reports/sales",
    { period: zPeriod, ...zFromToDate },
  );
  endpoint(server, ctx, "get_tax_report", "Tax report — tax collected on sales vs paid on purchases.", "GET", "/api/v1/reports/tax", { period: zPeriod, ...zFromToDate });
  endpoint(server, ctx, "get_revenue_report", "Revenue trend report.", "GET", "/api/v1/reports/revenue", { period: zPeriod, ...zFromToDate });
  endpoint(server, ctx, "get_outstanding_report", "Outstanding invoices (receivables) report.", "GET", "/api/v1/reports/outstanding", { party_id: zUuid.optional() });
  endpoint(server, ctx, "get_customer_wise_report", "Sales grouped by customer.", "GET", "/api/v1/reports/customers", { period: zPeriod, ...zFromToDate, limit: z.number().int().optional() });
  endpoint(server, ctx, "get_product_wise_report", "Sales grouped by product.", "GET", "/api/v1/reports/products", { period: zPeriod, ...zFromToDate, limit: z.number().int().optional() });
  endpoint(server, ctx, "get_category_wise_report", "Sales grouped by category.", "GET", "/api/v1/reports/categories", { period: zPeriod, ...zFromToDate, limit: z.number().int().optional() });
  endpoint(server, ctx, "get_payments_report", "Payments received/made report.", "GET", "/api/v1/reports/payments", { period: zPeriod, ...zFromToDate });
  endpoint(server, ctx, "get_inventory_report", "Inventory report (stock positions, valuation).", "GET", "/api/v1/reports/inventory", { period: zPeriod, ...zFromToDate });
  endpoint(
    server,
    ctx,
    "get_custom_report",
    "Custom metric report — pick a metric and period.",
    "GET",
    "/api/v1/reports/custom",
    { metric: z.string().optional().describe("sales|purchases|payments|expenses|tax"), period: zPeriod, ...zFromToDate },
  );

  // ---------- GST / tax ----------
  endpoint(server, ctx, "get_gst_summary", "GST summary: sales vs purchase tax and net liability for a period.", "GET", "/api/v1/gst/summary", { period: z.string().optional().describe("e.g. 2026-10 or monthly") });
  endpoint(server, ctx, "get_gstr1", "GSTR-1 outward supplies data for a tax period.", "GET", "/api/v1/gst/gstr1", { period: z.string().describe("Tax period YYYY-MM") });
  endpoint(server, ctx, "get_gstr2", "GSTR-2 inward supplies data for a tax period.", "GET", "/api/v1/gst/gstr2", { period: z.string().describe("Tax period YYYY-MM") });
  endpoint(server, ctx, "get_gstr3b", "GSTR-3B summary (liability minus ITC) for a tax period.", "GET", "/api/v1/gst/gstr3b", { period: z.string().describe("Tax period YYYY-MM") });
  endpoint(server, ctx, "export_gstr1", "Export GSTR-1 in portal format for a tax period.", "GET", "/api/v1/gst/export/gstr1", { period: z.string() });
  endpoint(server, ctx, "export_gstr3b", "Export GSTR-3B in portal format for a tax period.", "GET", "/api/v1/gst/export/gstr3b", { period: z.string() });
  endpoint(
    server,
    ctx,
    "validate_gstin",
    "Validate a GSTIN checksum/format.",
    "POST",
    "/api/v1/gst/validate-gstin",
    { gstin: z.string() },
  );
  endpoint(server, ctx, "list_state_codes", "List Indian state codes for GST.", "GET", "/api/v1/gst/state-codes");
  endpoint(server, ctx, "get_hsn_rates", "Look up the GST rate for an HSN code.", "GET", "/api/v1/gst/hsn-rates", { code: z.string().describe("HSN code") });
  endpoint(
    server,
    ctx,
    "search_hsn_codes",
    "Search HSN codes (optionally AI-powered semantic search when enabled).",
    "GET",
    "/api/v1/gst/hsn-search",
    { search: z.string().describe("HSN code or product description"), use_ai: z.boolean().optional() },
  );
  endpoint(
    server,
    ctx,
    "hsn_semantic_search",
    "AI semantic HSN search — describe the item in plain language. Returns the best matching HSN code.",
    "POST",
    "/api/v1/hsn/search",
    { description: z.string().describe("Plain-language item description, e.g. 'cotton men's t-shirt'") },
  );
  endpoint(
    server,
    ctx,
    "calculate_tax",
    "Split an amount into taxable value + tax at a rate (inclusive or exclusive).",
    "POST",
    "/api/v1/gst/calculate",
    { amount: z.number(), tax_rate: z.number(), is_inclusive: z.boolean().optional() },
  );
  endpoint(
    server,
    ctx,
    "convert_price",
    "Convert a price between tax-inclusive and tax-exclusive.",
    "POST",
    "/api/v1/gst/convert-price",
    { price: z.number(), tax_rate: z.number(), from_type: z.enum(["inclusive", "exclusive"]), to_type: z.enum(["inclusive", "exclusive"]) },
  );

  // e-invoice / e-way bill
  endpoint(server, ctx, "generate_einvoice", "Generate an e-invoice (IRN) for an invoice.", "POST", "/api/v1/gst/einvoice/generate", { invoice_id: zUuid });
  endpoint(server, ctx, "cancel_einvoice", "Cancel a generated e-invoice.", "POST", "/api/v1/gst/einvoice/cancel", { invoice_id: zUuid, cancel_reason: z.string() });
  endpoint(server, ctx, "get_einvoice_history", "List generated/cancelled e-invoices.", "GET", "/api/v1/gst/einvoice/history");
  endpoint(
    server,
    ctx,
    "generate_eway_bill",
    "Generate an e-way bill for an invoice.",
    "POST",
    "/api/v1/gst/ewaybill/generate",
    { invoice_id: zUuid, transporter: z.string().optional(), vehicle_no: z.string().optional(), distance: z.number().optional() },
  );
  endpoint(server, ctx, "cancel_eway_bill", "Cancel an e-way bill.", "POST", "/api/v1/gst/ewaybill/cancel", { ewb_no: z.string(), cancel_reason: z.string() });
  endpoint(server, ctx, "get_eway_bill_history", "List generated/cancelled e-way bills.", "GET", "/api/v1/gst/ewaybill/history");

  // Tax periods
  endpoint(server, ctx, "list_tax_periods", "List GST tax periods.", "GET", "/api/v1/gst/tax-periods");
  endpoint(server, ctx, "create_tax_period", "Create a tax period (YYYY-MM).", "POST", "/api/v1/gst/tax-periods", { period: z.string() });
  endpoint(server, ctx, "get_tax_period", "Get a tax period.", "GET", "/api/v1/gst/tax-periods/:id", { id: zUuid });
  endpoint(server, ctx, "update_tax_period", "Update a tax period (status, GSTR statuses, notes).", "PUT", "/api/v1/gst/tax-periods/:id", { id: zUuid, status: z.string().optional(), gstr1_status: z.string().optional(), gstr3b_status: z.string().optional(), gstr1_filed_at: zDate.optional(), gstr3b_filed_at: zDate.optional(), notes: z.string().optional() });

  // Input tax credit
  endpoint(
    server,
    ctx,
    "create_itc_entry",
    "Record an input tax credit from a purchase document.",
    "POST",
    "/api/v1/gst/itc",
    {
      tax_period: z.string().describe("YYYY-MM"),
      source_id: zUuid,
      source_type: z.string().describe("purchase_receipt|purchase_bill"),
      cgst_available: z.number().optional(),
      sgst_available: z.number().optional(),
      igst_available: z.number().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "list_itc_entries", "List input tax credit entries for a period.", "GET", "/api/v1/gst/itc", { tax_period: z.string().optional() });
  endpoint(
    server,
    ctx,
    "utilize_itc",
    "Mark part of an ITC entry as utilized against liability.",
    "PUT",
    "/api/v1/gst/itc/:id/utilize",
    { id: zUuid, cgst_utilized: z.number().optional(), sgst_utilized: z.number().optional(), igst_utilized: z.number().optional() },
  );

  // GST filing status
  endpoint(
    server,
    ctx,
    "record_gst_filing",
    "Record a GST return filing (GSTR1/GSTR3B status + ARN).",
    "POST",
    "/api/v1/gst/filing",
    {
      tax_period: z.string(),
      return_type: z.string().describe("GSTR1|GSTR3B"),
      status: z.string(),
      arn: z.string().optional(),
      reference_number: z.string().optional(),
      total_tax_liability: z.number().optional(),
      tax_paid: z.number().optional(),
      interest: z.number().optional(),
      penalty: z.number().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_gst_filing_status", "Get filing status for tax periods.", "GET", "/api/v1/gst/filing", { tax_period: z.string().optional() });

  // Tax rates / rules / exemptions
  // Tax rates / rules / exemptions
  endpoint(server, ctx, "list_tax_rates", "List configured tax rates.", "GET", "/api/v1/tax-rates");
  endpoint(
    server,
    ctx,
    "create_tax_rate",
    "Create a tax rate (component split optional — total_rate is required).",
    "POST",
    "/api/v1/tax-rates",
    {
      name: z.string(),
      total_rate: z.number().describe("Combined rate, e.g. 18"),
      cgst_rate: z.number().optional(),
      sgst_rate: z.number().optional(),
      igst_rate: z.number().optional(),
      cess_rate: z.number().optional(),
      is_default: z.boolean().optional(),
      description: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_tax_rate",
    "Update a tax rate.",
    "PUT",
    "/api/v1/tax-rates/:id",
    { id: zUuid, name: z.string().optional(), total_rate: z.number().optional(), cgst_rate: z.number().optional(), sgst_rate: z.number().optional(), igst_rate: z.number().optional(), cess_rate: z.number().optional(), is_default: z.boolean().optional(), description: z.string().optional(), is_active: z.boolean().optional() },
  );
  endpoint(server, ctx, "delete_tax_rate", "Delete a tax rate.", "DELETE", "/api/v1/tax-rates/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "get_default_tax_rate", "Get the default tax rate.", "GET", "/api/v1/tax-rates/default");

  const taxRuleFields = {
    country: z.string(),
    country_code: z.string().describe("e.g. IN"),
    state: z.string().optional(),
    state_code: z.string().optional(),
    tax_type: z.string().describe("e.g. GST, VAT"),
    tax_name: z.string(),
    rate: z.number(),
    is_compound: z.boolean().optional(),
    threshold_amount: z.number().optional(),
    hsn_code: z.string().optional(),
    category: z.string().optional(),
    effective_from: zDate.optional(),
    effective_until: zDate.optional(),
    notes: z.string().optional(),
  };
  endpoint(server, ctx, "list_tax_rules", "List tax rules (conditional rate application).", "GET", "/api/v1/tax-rules");
  endpoint(server, ctx, "create_tax_rule", "Create a tax rule.", "POST", "/api/v1/tax-rules", taxRuleFields);
  endpoint(
    server,
    ctx,
    "get_applicable_tax_rule",
    "Resolve the tax rule applicable for a place/hsn/category/amount context.",
    "GET",
    "/api/v1/tax-rules/applicable",
    { country: z.string().optional(), state: z.string().optional(), hsn_code: z.string().optional(), category: z.string().optional(), amount: z.number().optional() },
  );
  endpoint(
    server,
    ctx,
    "update_tax_rule",
    "Update a tax rule.",
    "PUT",
    "/api/v1/tax-rules/:id",
    { id: zUuid, ...Object.fromEntries(Object.entries(taxRuleFields).map(([k, v]) => [k, (v as z.ZodTypeAny).optional()])), is_active: z.boolean().optional() },
  );
  endpoint(server, ctx, "delete_tax_rule", "Delete a tax rule.", "DELETE", "/api/v1/tax-rules/:id", { id: zUuid }, { destructive: true });

  endpoint(server, ctx, "list_tax_exemptions", "List tax exemptions.", "GET", "/api/v1/tax-exemptions");
  endpoint(
    server,
    ctx,
    "create_tax_exemption",
    "Create a tax exemption.",
    "POST",
    "/api/v1/tax-exemptions",
    {
      name: z.string(),
      code: z.string().describe("Exemption code"),
      exemption_type: z.string().describe("e.g. hsn_exempt, nil_rated, zero_rated, threshold"),
      description: z.string().optional(),
      max_amount: z.number().optional(),
      valid_from: zDate.optional(),
      valid_until: zDate.optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_tax_exemption",
    "Update a tax exemption.",
    "PUT",
    "/api/v1/tax-exemptions/:id",
    { id: zUuid, name: z.string().optional(), code: z.string().optional(), exemption_type: z.string().optional(), description: z.string().optional(), max_amount: z.number().optional(), valid_from: zDate.optional(), valid_until: zDate.optional(), is_applicable: z.boolean().optional(), notes: z.string().optional() },
  );
  endpoint(server, ctx, "delete_tax_exemption", "Delete a tax exemption.", "DELETE", "/api/v1/tax-exemptions/:id", { id: zUuid }, { destructive: true });
}
