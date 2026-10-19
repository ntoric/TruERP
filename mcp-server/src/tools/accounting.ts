import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zDate, zPage, zPerPage, zSearch, zFromToDate, type Ctx } from "./helpers.js";

export function registerAccountingTools(server: McpServer, ctx: Ctx) {
  // ---------- Chart of accounts ----------
  endpoint(
    server,
    ctx,
    "list_accounts",
    "List chart-of-accounts entries (asset/liability/equity/income/expense).",
    "GET",
    "/api/v1/accounting/accounts",
    { account_type: z.string().optional(), is_group: z.boolean().optional(), search: zSearch, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_account",
    "Create a ledger account (code is auto-assigned).",
    "POST",
    "/api/v1/accounting/accounts",
    {
      name: z.string(),
      account_type: z.enum(["asset", "liability", "equity", "income", "expense"]),
      parent_id: zUuid.optional(),
      opening_balance: z.number().optional(),
      is_default: z.boolean().optional(),
      description: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_account", "Get a ledger account by ID.", "GET", "/api/v1/accounting/accounts/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_account",
    "Update a ledger account.",
    "PUT",
    "/api/v1/accounting/accounts/:id",
    { id: zUuid, name: z.string().optional(), parent_id: zUuid.optional(), is_active: z.boolean().optional(), description: z.string().optional() },
  );
  endpoint(server, ctx, "delete_account", "Delete a ledger account.", "DELETE", "/api/v1/accounting/accounts/:id", { id: zUuid }, { destructive: true });

  // ---------- Journal entries ----------
  endpoint(
    server,
    ctx,
    "list_journal_entries",
    "List journal entries (draft and posted).",
    "GET",
    "/api/v1/accounting/journal",
    { status: z.string().optional().describe("draft|posted"), ...zFromToDate, page: zPage, per_page: zPerPage },
  );
  endpoint(
    server,
    ctx,
    "create_journal_entry",
    "Create a manual journal entry. Debits must equal credits across ≥2 lines.",
    "POST",
    "/api/v1/accounting/journal",
    {
      entry_date: zDate,
      description: z.string().optional(),
      lines: z
        .array(
          z.object({
            account_id: zUuid,
            debit: z.number().optional(),
            credit: z.number().optional(),
            description: z.string().optional(),
          }),
        )
        .min(2),
    },
  );
  endpoint(server, ctx, "get_journal_entry", "Get a journal entry with lines.", "GET", "/api/v1/accounting/journal/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_journal_entry",
    "Update a draft journal entry.",
    "PUT",
    "/api/v1/accounting/journal/:id",
    {
      id: zUuid,
      entry_date: zDate.optional(),
      description: z.string().optional(),
      lines: z
        .array(
          z.object({
            account_id: zUuid,
            debit: z.number().optional(),
            credit: z.number().optional(),
            description: z.string().optional(),
          }),
        )
        .min(2)
        .optional(),
    },
  );
  endpoint(server, ctx, "post_journal_entry", "Post a draft journal entry to the ledger (irreversible).", "POST", "/api/v1/accounting/journal/:id/post", { id: zUuid });
  endpoint(server, ctx, "delete_journal_entry", "Delete a draft journal entry.", "DELETE", "/api/v1/accounting/journal/:id", { id: zUuid }, { destructive: true });

  // ---------- Financial reports ----------
  endpoint(server, ctx, "get_accounting_stats", "Accounting summary stats.", "GET", "/api/v1/accounting/stats");
  endpoint(
    server,
    ctx,
    "get_trial_balance",
    "Trial balance — all account debit/credit balances as of a date.",
    "GET",
    "/api/v1/accounting/trial-balance",
    { as_of_date: zDate.optional() },
  );
  endpoint(
    server,
    ctx,
    "get_accounting_profit_loss",
    "Accounting-basis profit & loss for a date range.",
    "GET",
    "/api/v1/accounting/profit-loss",
    zFromToDate,
  );
  endpoint(
    server,
    ctx,
    "get_balance_sheet",
    "Balance sheet as of a date.",
    "GET",
    "/api/v1/accounting/balance-sheet",
    { as_of_date: zDate.optional() },
  );
  endpoint(
    server,
    ctx,
    "get_general_ledger",
    "General ledger for one account — all postings with running balance.",
    "GET",
    "/api/v1/accounting/general-ledger/:id",
    { id: zUuid.describe("Account ID"), ...zFromToDate },
  );
  endpoint(
    server,
    ctx,
    "list_ledgers",
    "List all ledger postings across accounts.",
    "GET",
    "/api/v1/accounting/ledgers",
    { account_id: zUuid.optional(), transaction_type: z.string().optional(), ...zFromToDate, page: zPage, per_page: zPerPage },
  );

  // ---------- Bank reconciliation ----------
  endpoint(
    server,
    ctx,
    "list_bank_reconciliations",
    "List bank reconciliations.",
    "GET",
    "/api/v1/accounting/bank-reconciliation",
    { bank_account_id: zUuid.optional() },
  );
  endpoint(
    server,
    ctx,
    "create_bank_reconciliation",
    "Start a bank reconciliation for a statement date/balance.",
    "POST",
    "/api/v1/accounting/bank-reconciliation",
    {
      bank_account_id: zUuid,
      statement_date: zDate,
      statement_balance: z.number(),
      reconciled_items: z.array(z.string()).optional().describe("Reconciled transaction IDs"),
      unreconciled_items: z.array(z.string()).optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "complete_bank_reconciliation",
    "Mark a bank reconciliation as complete.",
    "PUT",
    "/api/v1/accounting/bank-reconciliation/:id/complete",
    { id: zUuid },
  );
}
