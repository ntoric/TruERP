import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zPage, zPerPage, type Ctx } from "./helpers.js";

export function registerMigrationTools(server: McpServer, ctx: Ctx) {
  // ---- Migration Jobs ----
  endpoint(
    server,
    ctx,
    "list_migration_jobs",
    "List asynchronous data migration/import jobs (super admin).",
    "GET",
    "/api/v1/migration/jobs",
    {
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_migration_job", "Get status and row counts of a migration job by ID (super admin).", "GET", "/api/v1/migration/jobs/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "enqueue_migration_job",
    "Enqueue an asynchronous data import/migration job (super admin).",
    "POST",
    "/api/v1/migration/jobs",
    {
      kind: z.string().describe("categories, inventory, parties, sales, purchase, etc."),
      payload: z.record(z.any()).optional().describe("Job options or raw data"),
    },
  );

  // ---- CSV Importers (direct JSON array or CSV payload) ----
  endpoint(
    server,
    ctx,
    "import_categories_csv",
    "Import product categories via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/categories/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_expense_categories_csv",
    "Import expense categories via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/expense-categories/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_inventory_csv",
    "Import inventory / products via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/inventory/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_bank_accounts_csv",
    "Import bank accounts via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/bank-accounts/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_cash_transactions_csv",
    "Import cash ledger transactions via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/cash-transactions/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_users_csv",
    "Import users via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/users/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_staff_csv",
    "Import staff employees via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/staff/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_stock_summary_csv",
    "Import stock summary opening balance via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/stock-summary/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_batched_items_csv",
    "Import batched items via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/batched-items/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_purchase_payments_csv",
    "Import purchase bill payments via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/purchase-payments/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_purchase_items_csv",
    "Import purchase line items via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/purchase-items/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_sales_items_csv",
    "Import sales line items via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/sales-items/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_sales_links_csv",
    "Import sales invoice link metadata via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/sales-links/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_sales_csv",
    "Import sales transactions via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/sales/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_purchase_returns_csv",
    "Import purchase returns via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/purchase-returns/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_sales_returns_csv",
    "Import sales returns via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/sales-returns/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_cash_bank_statement_csv",
    "Import cash & bank statement entries via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/cash-bank-statement/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "import_daybook_csv",
    "Import daybook rows via CSV payload (super admin).",
    "POST",
    "/api/v1/migration/daybook/import/csv",
    { rows: z.array(z.record(z.any())).optional(), csv_data: z.string().optional() },
  );
}
