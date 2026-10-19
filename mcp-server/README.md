# TruERP MCP Server

A Model Context Protocol (MCP) server that exposes the complete TruERP billing/ERP REST API as **526 tools** for AI clients (Claude Desktop, Cursor, Windsurf, ChatGPT, custom agents, etc.) with native **OAuth 2.0 authentication** and dual transport support (**stdio** and **HTTP/SSE**).

## Covered Domains (100% Backend API Coverage)

- **Core**: profile, stores, business profile, user management, notifications, drafts
- **OAuth 2.0**: OAuth clients, OAuth metadata, userinfo, token revocation
- **Parties**: customers/vendors, ledgers, aging, loyalty, statements
- **Products**: products, variants, images, units, item codes, PLU
- **Categories**: product categories + expense categories
- **Inventory**: stock balance/valuation/entries/transfers/adjustments, reservations, low-stock alerts, serial numbers, snapshots
- **Warehouses**: warehouse CRUD, per-warehouse stock
- **Purchase**: orders, receipts (GRN), bills, returns
- **Sales**: invoices, quotations, sales returns, delivery challans
- **Payments**: payment-in, payment-out, payment splits
- **Credit & Debit Notes**: full lifecycle with allocations
- **Expenses**: expenses + categories
- **Cash & Bank**: bank accounts, transactions, transfers, payment-method mappings, cash-bank summary
- **Partners & Profit**: partner allocations, profit distributions
- **Reports**: dashboard, daily/periodic, P&L, bill-wise & daily profit, stock, sales, tax, revenue, outstanding, customer, product, category, payment, inventory reports
- **GST & Tax**: summary, GSTR-1/2/3B (+ portal exports), e-invoice, e-way bill, ITC, filings, tax periods/rates/rules/exemptions, GSTIN validation, HSN semantic search, tax calculators
- **HR & Payroll**: staff, attendance, deductions, advances, extras, payroll runs & partial payments
- **Accounting**: chart of accounts, journal entries, trial balance, P&L, balance sheet, general ledger, bank reconciliation
- **Marketing**: SMS campaigns, email campaigns, WhatsApp campaigns (CRUD, send, schedule, stats)
- **Developer Settings & DB**: developer settings, test email/whatsapp/sms, database maintenance (VACUUM schedule), database backups (S3, Mega, GDrive, local dump download)
- **Security & Audit**: security audit logs, stats, export, archiving, retention policies
- **Admin Notifications & Announcements**: event registry, external channels (SMTP, Telegram, WhatsApp, SMS, Push), broadcasts, delivery logs, in-app announcements
- **Support & Customer Portal**: user support requests, admin ticket triage, customer portal settings, access provisioning, customer portal client APIs (login, invoices, payments, statements, tickets)
- **Printer & Documents**: ESC/POS thermal printing, document printing, print preview, barcode label preview, document attachments
- **Migration & Imports**: async migration jobs, per-entity CSV importers (categories, inventory, sales, purchases, bank accounts, staff, daybook, etc.), myBillBook migration
- **User Management & 2FA**: 2FA status/setup/enable/disable, password management, profile update, activity logs, page feature toggles
- **POS**: sessions, cash in/out movements, drafts, offline sync

---

## OAuth 2.0 Authentication

The application features full OAuth 2.0 (RFC 6749, RFC 7636 PKCE, RFC 8414 metadata) implemented in both the Go backend and the MCP server.

### Supported Grant Types:
1. **Authorization Code with PKCE (`S256` and `plain`)**:
   - Interactive consent page at `/api/v1/oauth/authorize`
   - Issues authorization codes with 10-minute expiry
   - Exchanges code + `code_verifier` for access token + refresh token
2. **Client Credentials**:
   - Machine-to-machine / server-to-server MCP agent authentication
   - Authenticates via `client_id` + `client_secret`
3. **Refresh Token**:
   - Automatic token rotation with 30-day token lifetime
4. **Resource Owner Password Credentials**:
   - Authenticates via user email + password (+ optional TOTP)

### OAuth 2.0 Endpoints:
- `GET /.well-known/oauth-authorization-server` (RFC 8414 discovery)
- `GET /api/v1/oauth/authorize` (OAuth authorization consent & login UI)
- `POST /api/v1/oauth/authorize` (Process authorization and issue code)
- `POST /api/v1/oauth/token` (Issue access & refresh tokens)
- `GET /api/v1/oauth/userinfo` (OpenID/OAuth user profile claims)
- `POST /api/v1/oauth/revoke` (Revoke tokens)
- `GET /api/v1/oauth/clients` (Manage OAuth client applications)

Default seeded client:
- **Client ID**: `truerp-mcp-client`
- **Client Secret**: `truerp-mcp-secret`
- **Redirect URIs**: `http://localhost:3000/callback,http://localhost:8089/callback,https://oauth.pstmn.io/v1/callback`
- **Scopes**: `read write admin erp`

---

## Transport Modes

### 1. Stdio Transport (Default)
Used for process-based AI clients like Claude Desktop, Cursor, or Windsurf running on the local system.

```bash
cd mcp-server
npm run build
node dist/index.js
```

### 2. HTTP / Server-Sent Events (SSE) Remote Transport
Used for remote AI clients, web agents, multi-user deployments, or network access with OAuth 2.0 Bearer authentication.

```bash
cd mcp-server
npm run build
node dist/index.js --transport sse --port 8089 --host 0.0.0.0
```

When running in SSE mode:
- **SSE Endpoint**: `http://localhost:8089/sse` (Requires `Authorization: Bearer <token>`)
- **Messages Endpoint**: `http://localhost:8089/messages`
- **OAuth Discovery**: `http://localhost:8089/.well-known/oauth-authorization-server`
- **OAuth Authorize**: `http://localhost:8089/oauth/authorize`
- **OAuth Token**: `http://localhost:8089/oauth/token`
- **Health Check**: `http://localhost:8089/health`

---

## Environment Configuration

| Variable | Transport | Description |
|---|---|---|
| `TRUERP_API_URL` | all | Backend base URL (default: `http://localhost:8088`) |
| `TRUERP_OAUTH_TOKEN` | all | Pre-issued OAuth 2.0 Bearer token |
| `TRUERP_OAUTH_CLIENT_ID` | all | OAuth 2.0 Client ID (default: `truerp-mcp-client`) |
| `TRUERP_OAUTH_CLIENT_SECRET` | all | OAuth 2.0 Client Secret (default: `truerp-mcp-secret`) |
| `TRUERP_OAUTH_REFRESH_TOKEN` | all | OAuth 2.0 Refresh Token for auto-renewal |
| `TRUERP_EMAIL` | all | Account email for password login |
| `TRUERP_PASSWORD` | all | Account password for password login |
| `TRUERP_TOTP_CODE` | all | 2FA code if account has TOTP enabled |
| `TRUERP_STORE_ID` | all | `X-Store-ID` header for super-admin store scoping |
| `MCP_TRANSPORT` | all | `stdio` (default) or `sse` |
| `MCP_PORT` | sse | Port for HTTP/SSE transport (default: `8089`) |
| `MCP_HOST` | sse | Host for HTTP/SSE transport (default: `0.0.0.0`) |

---

## MCP Client Configuration

### Claude Desktop / Cursor (Stdio Transport with OAuth Client Credentials)
Add to your `mcp.json` or `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "truerp": {
      "command": "node",
      "args": ["/absolute/path/to/billbook_clone/mcp-server/dist/index.js"],
      "env": {
        "TRUERP_API_URL": "http://localhost:8088",
        "TRUERP_OAUTH_CLIENT_ID": "truerp-mcp-client",
        "TRUERP_OAUTH_CLIENT_SECRET": "truerp-mcp-secret"
      }
    }
  }
}
```

### Remote MCP Client / Web Agent (HTTP/SSE Transport with OAuth 2.0 Bearer)
Start the SSE server:
```bash
TRUERP_API_URL=http://localhost:8088 node mcp-server/dist/index.js --transport sse --port 8089
```

Configure your remote MCP client with:
- **SSE URL**: `http://localhost:8089/sse`
- **Authorization**: `Bearer <oauth-access-token>`
- **OAuth Discovery**: `http://localhost:8089/.well-known/oauth-authorization-server`

---

## Build and Testing

```bash
cd mcp-server
npm install
npm run build
npm test
```
