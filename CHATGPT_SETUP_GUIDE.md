# TruERP MCP Server & ChatGPT Integration Guide

This guide walks you through hosting the **TruERP Backend**, running the **MCP Server** in HTTP/SSE mode, and connecting it with **ChatGPT** via **OAuth 2.0** and **ChatGPT Custom Actions / MCP**.

---

## 1. Architecture Overview

```
┌─────────────────────────────────┐
│       OpenAI / ChatGPT          │
│  (Custom GPT Action or MCP)     │
└────────────────┬────────────────┘
                 │
                 │ HTTPS (OAuth 2.0 Bearer)
                 ▼
┌────────────────────────────────────────────────────────┐
│             Public HTTPS Tunnel / Host                 │
│  e.g. operation-common-joseph-univ.trycloudflare.com   │
└────────────────┬───────────────────────────────────────┘
                 │
                 ├──▶ GET  /openapi.json             (ChatGPT Actions Schema)
                 ├──▶ GET  /oauth/authorize          (Browser Login & Consent UI)
                 ├──▶ POST /oauth/token              (Token Exchange & Refresh)
                 ├──▶ GET  /sse                      (MCP Server SSE Stream)
                 └──▶ POST /messages                 (MCP Client Messages)
                 │
                 ▼
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│        TruERP MCP Server        │──────▶│         TruERP Backend          │
│    (Port 8089 - Node / SSE)     │ REST  │      (Port 8088 - Go API)       │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

---

## 2. Server Setup & Startup

### Step 2.1: Start TruERP Go Backend

The Go backend powers all business logic, database models, and the OAuth 2.0 provider.

```bash
cd backend
go run .
```

- **Runs on**: `http://localhost:8088`
- **Database**: Automatically runs schema migrations and seeds default OAuth client credentials:
  - **Client ID**: `truerp-mcp-client`
  - **Client Secret**: `truerp-mcp-secret`
  - **Allowed Scopes**: `read write admin erp`

---

### Step 2.2: Start TruERP MCP Server in HTTP/SSE Mode

The MCP server translates all 526 ERP tools, handles OAuth discovery, and provides the SSE transport for AI clients.

```bash
cd mcp-server
npm install
npm run build
node dist/index.js --transport sse --port 8089 --host 0.0.0.0
```

- **Runs on**: `http://0.0.0.0:8089`
- **SSE Stream**: `http://localhost:8089/sse`
- **OAuth Discovery**: `http://localhost:8089/.well-known/oauth-authorization-server`
- **OpenAPI Schema for ChatGPT**: `http://localhost:8089/openapi.json`

---

### Step 2.3: Expose via Cloudflare Tunnel (HTTPS)

OpenAI strictly requires public HTTPS. Start your Cloudflare tunnel pointing to port `8089`:

```bash
cloudflared tunnel --url http://localhost:8089
```

Your tunnel URL is active:
```
https://operation-common-joseph-univ.trycloudflare.com
```

---

## 3. ChatGPT Custom GPT Setup (Step-by-Step)

### Step 3.1: Create a Custom GPT

1. Go to [chatgpt.com](https://chatgpt.com) -> Click your profile in the lower left / top right -> **My GPTs**.
2. Click **+ Create a GPT**.
3. Select the **Configure** tab:
   - **Name**: `TruERP Business Assistant`
   - **Description**: `AI assistant for managing TruERP billing, invoices, customers, inventory, and reports.`
   - **Instructions**:
     ```markdown
     You are the official TruERP Assistant. You help the user manage invoices, customers, vendors, products, stock levels, payments, and financial reports. 
     
     Guidelines:
     - Always query existing parties and products first before creating new invoices.
     - Provide clear invoice totals including tax and discounts.
     - Never delete records without explicit confirmation from the user.
     - Format amounts cleanly with the currency symbol.
     ```

---

### Step 3.2: Add Action and Import OpenAPI Schema

1. Under the **Actions** section in the GPT editor, click **Create new action**.
2. In the **Schema** box:
   - Either paste the URL:
     ```
     https://operation-common-joseph-univ.trycloudflare.com/openapi.json
     ```
     *(Click **Import** to fetch it dynamically)*
   - Or paste the complete contents of `mcp-server/chatgpt-actions-openapi.json` directly into the box.

ChatGPT will automatically detect the endpoints:
- `getDashboardStats`
- `listInvoices`, `createInvoice`, `getInvoice`
- `listParties`, `createParty`, `getParty`
- `listProducts`, `createProduct`, `getLowStockAlerts`
- `listPayments`, `createPayment`
- `getProfitAndLossReport`

---

### Step 3.3: Configure OAuth 2.0 Authentication in ChatGPT

Under **Authentication**, click the gear icon (or **Edit**) and select **OAuth**:

| Field | Configuration Value |
|---|---|
| **Authentication Type** | `OAuth` |
| **Client ID** | `truerp-mcp-client` |
| **Client Secret** | `truerp-mcp-secret` |
| **Authorization URL** | `https://operation-common-joseph-univ.trycloudflare.com/oauth/authorize` |
| **Token URL** | `https://operation-common-joseph-univ.trycloudflare.com/oauth/token` |
| **Scope** | `read write admin erp` |
| **Token Exchange Method** | `Default (POST request)` |

---

### Step 3.4: ChatGPT Callback URL Verification

ChatGPT will display a generated **Callback URI** (e.g., `https://chat.openai.com/aip/g-XXXXXXXX/oauth/callback` or `https://chatgpt.com/aip/g-XXXXXXXX/oauth/callback`).

> The built-in TruERP OAuth client (`truerp-mcp-client`) is already pre-configured to accept redirect callbacks from both `chat.openai.com` and `chatgpt.com`.

If you prefer to register a dedicated client with your custom secret and name, run this `curl` command:

```bash
curl -X POST https://operation-common-joseph-univ.trycloudflare.com/api/v1/oauth/clients \
  -H "Authorization: Bearer <SUPER_ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "chatgpt-action",
    "client_secret": "my-secret-key-123",
    "client_name": "ChatGPT TruERP Assistant",
    "redirect_uris": "https://chatgpt.com/aip/g-XXXXXXXX/oauth/callback,https://chat.openai.com/aip/g-XXXXXXXX/oauth/callback",
    "scopes": "read write admin erp"
  }'
```

---

## 4. Testing Your ChatGPT Integration

1. In the **Preview** panel of the Custom GPT builder, type:
   > *"Show me our dashboard summary and recent sales stats."*
2. ChatGPT displays a prompt: **"Log in to operation-common-joseph-univ.trycloudflare.com"**.
3. Click **Log In**. A modern TruERP authentication window will open.
4. Enter your TruERP account email and password, then click **Authorize Access**.
5. The window closes automatically, ChatGPT securely receives the OAuth token, queries your live backend, and responds with real-time financial stats!

---

## 5. Sample Prompts You Can Test

- *"List our top 5 customers and their outstanding balances."*
- *"Are there any products with low stock alerts right now?"*
- *"Create an invoice for customer Acme Corp for 10 units of Widget A at $25 each."*
- *"Show me our Profit and Loss statement for this month."*
- *"Record a cash payment of $250 received from party John Doe."*

---

## 6. Production Hosting Checklist

When deploying for production:
1. **Set Environment Variables**:
   - `JWT_SECRET`: Set a strong random secret.
   - `TRUERP_API_URL`: Backend URL (e.g. `http://localhost:8088`).
   - `MCP_TRANSPORT`: `sse`
   - `MCP_PORT`: `8089`
2. **Reverse Proxy (Nginx / Caddy / Cloudflare)**:
   - Configure SSL termination on port `443`.
   - Proxy `/api/` to port `8088` (Go Backend).
   - Proxy `/` to port `8089` (MCP Server with SSE streaming).
3. **Database Backups**:
   - Enable automated DB backups in Developer Settings or via the MCP backup tools.
