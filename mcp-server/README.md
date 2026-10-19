# TruERP MCP Server

A Model Context Protocol (MCP) server that exposes the full TruERP billing/ERP
REST API (`backend/`) as ~390 tools for AI clients (Claude Desktop, Cursor,
Windsurf, etc.).

Covered domains:

- **Core**: profile, stores, business settings, users, notifications, drafts
- **Parties**: customers/vendors, ledgers, aging, loyalty, statements
- **Products**: products, variants, images, units, item codes, PLU
- **Categories**: product categories + expense categories
- **Inventory**: stock balance/valuation/entries/transfers/adjustments,
  reservations, low-stock alerts, serial numbers, snapshots
- **Warehouses**: CRUD, per-warehouse stock
- **Purchase**: orders, receipts (GRN), bills, returns
- **Sales**: invoices, quotations, sales returns, delivery challans
- **Payments**: payment-in and payment-out
- **Credit/Debit notes**: full lifecycle incl. issue
- **Expenses**: expenses + categories
- **Cash & Bank**: bank accounts, transactions, transfers, payment-method
  mappings, cash-bank summary
- **Partners & Profit distributions**
- **Reports**: dashboard, daily/periodic, P&L, bill-wise & daily profit,
  stock, sales/tax/revenue/outstanding/customer/product/category/payment/
  inventory reports
- **GST & Tax**: summary, GSTR-1/2/3B (+portal exports), e-invoice, e-way bill,
  ITC, filings, tax periods/rates/rules/exemptions, GSTIN validation, HSN
  (incl. AI semantic search), tax calculators
- **HR & Payroll**: staff, attendance, deductions, advances, extras, payroll
  runs & partial payments
- **Accounting**: chart of accounts, journal entries, trial balance, P&L,
  balance sheet, general ledger, bank reconciliation
- **Misc**: POS sessions & cash movements, reminders, invoice/print settings,
  notification automation, sync status, support requests, PDF downloads
  (invoice, quotation, purchase bill, party ledger, receipt, statement)

## Requirements

- Node.js ≥ 18
- A running TruERP backend (default `http://localhost:8088`)

## Setup

```bash
cd mcp-server
npm install
npm run build
```

## Configuration

| Env var             | Required | Default                 | Description                                          |
| ------------------- | -------- | ----------------------- | ---------------------------------------------------- |
| `TRUERP_API_URL`    | no       | `http://localhost:8088` | Backend base URL                                     |
| `TRUERP_TOKEN`      | yes*     | —                       | Pre-issued JWT (alternative to email/password login) |
| `TRUERP_EMAIL`      | yes*     | —                       | Login email                                          |
| `TRUERP_PASSWORD`   | yes*     | —                       | Login password                                       |
| `TRUERP_TOTP_CODE`  | no       | —                       | 2FA code if the account has TOTP enabled             |
| `TRUERP_STORE_ID`   | no       | —                       | `X-Store-ID` header (super-admin store scoping)      |

\* Either `TRUERP_TOKEN` **or** `TRUERP_EMAIL` + `TRUERP_PASSWORD`.

Tokens obtained via login are cached in-process and refreshed on 401.

## MCP client configuration

### Claude Desktop / Cursor / Windsurf

Add to your `mcp.json` (or `claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "truerp": {
      "command": "node",
      "args": ["/absolute/path/to/billbook_clone/mcp-server/dist/index.js"],
      "env": {
        "TRUERP_API_URL": "http://localhost:8088",
        "TRUERP_EMAIL": "you@example.com",
        "TRUERP_PASSWORD": "your-password"
      }
    }
  }
}
```

Or via `npx`-style one-liner once published — for now use the local path above.

## Development

```bash
npm run dev        # tsc --watch
npm run typecheck  # type-check only
```

### Layout

```
src/
  index.ts        server bootstrap (stdio transport)
  client.ts       REST client — auth, retries, downloads
  tools/
    helpers.ts    endpoint() table-driven tool registration + shared zod bits
    core.ts       session, stores, business, users, drafts, notifications
    parties.ts    parties, ledger, loyalty, statements
    products.ts   products, variants, images, categories
    inventory.ts  warehouses, stock, entries, transfers, serials
    purchase.ts   orders, receipts, bills, returns
    sales.ts      invoices, quotations, returns, challans
    money.ts      payments in/out, credit/debit notes, expenses
    cashbank.ts   bank accounts, cash ledger, partners, profit distributions
    reports.ts    dashboard, reports, GST/tax
    hr.ts         staff, attendance, payroll
    accounting.ts chart of accounts, journal, ledgers, recon
    misc.ts       POS, reminders, settings, sync, support
```

Each tool maps 1:1 to a REST endpoint; `list_*` tools pass filters as query
params and return the API JSON verbatim.
