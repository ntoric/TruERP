import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zDate, zPage, zPerPage, zSearch, type Ctx } from "./helpers.js";

export function registerCashBankTools(server: McpServer, ctx: Ctx) {
  // ---------- Summary ----------
  endpoint(
    server,
    ctx,
    "get_cash_bank_summary",
    "Cash-in-hand, bank account balances, unlinked transactions and net changes.",
    "GET",
    "/api/v1/cash-bank/summary",
  );

  // ---------- Bank accounts ----------
  endpoint(server, ctx, "list_bank_accounts", "List bank accounts with balances.", "GET", "/api/v1/cash-bank/accounts");
  endpoint(server, ctx, "get_bank_account", "Get a bank account by ID.", "GET", "/api/v1/cash-bank/accounts/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "create_bank_account",
    "Add a bank account.",
    "POST",
    "/api/v1/cash-bank/accounts",
    {
      account_name: z.string(),
      account_number: z.string(),
      bank_name: z.string(),
      ifsc_code: z.string().optional(),
      account_type: z.string().optional().describe("savings|current"),
      opening_balance: z.number().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_bank_account",
    "Update a bank account.",
    "PUT",
    "/api/v1/cash-bank/accounts/:id",
    {
      id: zUuid,
      account_name: z.string().optional(),
      account_number: z.string().optional(),
      bank_name: z.string().optional(),
      ifsc_code: z.string().optional(),
      account_type: z.string().optional(),
      is_active: z.boolean().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "delete_bank_account", "Delete a bank account.", "DELETE", "/api/v1/cash-bank/accounts/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "set_primary_bank_account", "Mark a bank account as primary.", "PUT", "/api/v1/cash-bank/accounts/:id/set-primary", { id: zUuid });

  // ---------- Payment method mapping ----------
  endpoint(
    server,
    ctx,
    "get_payment_method_mappings",
    "Get which bank account each payment mode deposits into.",
    "GET",
    "/api/v1/cash-bank/payment-method-mappings",
  );
  endpoint(
    server,
    ctx,
    "update_payment_method_mappings",
    "Map payment modes (upi, card, bank_transfer…) to bank accounts.",
    "PUT",
    "/api/v1/cash-bank/payment-method-mappings",
    {
      mappings: z.array(
        z.object({
          payment_method: z.string(),
          bank_account_id: zUuid.nullable(),
        }),
      ),
    },
  );

  // ---------- Cash transactions ----------
  endpoint(
    server,
    ctx,
    "list_cash_transactions",
    "List cash/bank ledger transactions (add, reduce, transfers, linked entries).",
    "GET",
    "/api/v1/cash-bank/transactions",
    {
      search: zSearch,
      account_id: zUuid.optional().describe("Bank account ID; omit for cash-in-hand"),
      transaction_type: z.string().optional(),
      unlinked: z.boolean().optional().describe("Only manual transactions not linked to a document"),
      start_date: zDate.optional(),
      end_date: zDate.optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_cash_transaction", "Get a cash/bank transaction by ID.", "GET", "/api/v1/cash-bank/transactions/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "add_money",
    "Add money to cash-in-hand or a bank account.",
    "POST",
    "/api/v1/cash-bank/transactions/add",
    {
      account_id: zUuid.optional().describe("Bank account ID; omit for cash-in-hand"),
      amount: z.number().positive(),
      date: zDate,
      description: z.string().optional(),
      reference: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "reduce_money",
    "Withdraw/reduce money from cash-in-hand or a bank account.",
    "POST",
    "/api/v1/cash-bank/transactions/reduce",
    {
      account_id: zUuid.optional().describe("Bank account ID; omit for cash-in-hand"),
      amount: z.number().positive(),
      date: zDate,
      description: z.string().optional(),
      reference: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "transfer_money",
    "Transfer money between bank accounts (or cash↔bank).",
    "POST",
    "/api/v1/cash-bank/transactions/transfer",
    {
      from_account_id: zUuid.describe("Source account ID"),
      to_account_id: zUuid.describe("Destination account ID"),
      amount: z.number().positive(),
      date: zDate,
      description: z.string().optional(),
      reference: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "delete_cash_transaction",
    "Delete a manual cash transaction (super admin only; linked transactions cannot be deleted).",
    "DELETE",
    "/api/v1/cash-bank/transactions/:id",
    { id: zUuid },
    { destructive: true },
  );

  // ---------- Partners ----------
  endpoint(server, ctx, "list_partners", "List business partners (for profit sharing).", "GET", "/api/v1/partners", { is_active: z.boolean().optional(), search: zSearch });
  endpoint(server, ctx, "get_partner", "Get a partner by ID.", "GET", "/api/v1/partners/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "create_partner",
    "Create a profit-sharing partner.",
    "POST",
    "/api/v1/partners",
    {
      name: z.string(),
      phone: z.string().optional(),
      email: z.string().optional(),
      address: z.string().optional(),
      pan: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_partner",
    "Update a partner.",
    "PUT",
    "/api/v1/partners/:id",
    {
      id: zUuid,
      name: z.string().optional(),
      phone: z.string().optional(),
      email: z.string().optional(),
      address: z.string().optional(),
      pan: z.string().optional(),
      notes: z.string().optional(),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "delete_partner", "Delete a partner.", "DELETE", "/api/v1/partners/:id", { id: zUuid }, { destructive: true });

  // ---------- Profit distributions ----------
  endpoint(
    server,
    ctx,
    "list_profit_distributions",
    "List profit distribution payouts to partners.",
    "GET",
    "/api/v1/profit-distributions",
    { partner_id: zUuid.optional(), start_date: zDate.optional(), end_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_profit_distribution", "Get a profit distribution by ID.", "GET", "/api/v1/profit-distributions/:id", { id: zUuid });
  endpoint(server, ctx, "get_next_distribution_number", "Preview the next distribution number.", "GET", "/api/v1/profit-distributions/next-number");
  endpoint(
    server,
    ctx,
    "create_profit_distribution",
    "Distribute profit to a partner — deducts from a bank account or cash-in-hand.",
    "POST",
    "/api/v1/profit-distributions",
    {
      partner_id: zUuid,
      amount: z.number().positive(),
      date: zDate,
      account_id: zUuid.optional().describe("Bank account ID; omit for cash-in-hand"),
      description: z.string().optional(),
      reference: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "delete_profit_distribution",
    "Delete a profit distribution (reverses the cash/bank entry).",
    "DELETE",
    "/api/v1/profit-distributions/:id",
    { id: zUuid },
    { destructive: true },
  );
}
