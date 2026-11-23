# TruERP Mobile — Build Roadmap

A Flutter app for Android and iOS that works against the existing Go backend
(`backend/`, `/api/v1`). It covers the same business workflows as the web app
(`frontend/`), laid out for phones and tablets.

Status key: ☐ not started · ◐ in progress · ☑ done

## Running it

```bash
cd mobile
flutter pub get
flutter run                                   # talks to production: https://backend.truerp.co.in/api/v1
flutter run --dart-define=API_URL=http://10.0.2.2:8088/api/v1    # local backend from the Android emulator
flutter test && flutter analyze
```

You can also change the server at runtime with **Server settings** on the login screen.

---

## 1. Scope

### 1.1 What the backend offers (from `backend/routes/routes.go`)

~600 endpoints in ~60 groups. The web app has ~95 screens under `frontend/app/(app)`.
The web sidebar (`frontend/components/layout/nav-config.ts`) groups them like this:

| Group | Web screens | Mobile phase |
|---|---|---|
| Dashboard | dashboard | P1 |
| Parties | all / customers / vendors / create / ledger | P1 |
| Inventory | products, categories, stock, stock movement | P1 (products), P4 (the rest) |
| Warehouses | list / create | P4 |
| Sales | invoices, estimates, delivery challans, sales return, discount | P1 (invoices), P3 (the rest) |
| Purchases | purchase invoices, purchase return, purchase orders | P2 |
| Credit/Debit | credit notes, debit notes | P3 |
| Payments | payment in, payment out | P1 (in), P2 (out) |
| Expenses | expenses, expense categories | P2 |
| Cash & Bank | accounts, transactions, add/reduce/transfer | P5 |
| Profit Distribution | partners, distributions | P5 |
| Accounting | chart of accounts, journal, trial balance, P&L, balance sheet | P5 (read-only) |
| Reports | daily, daily profit, P&L, billwise profit, stock, party balance, analytics | P6 |
| GST | GSTR-1, GSTR-3B, summary, e-invoice history | P6 (read-only) |
| HR & Payroll | staff, attendance, attendance reminder, payroll, advances, deductions, extras | P7 |
| POS | terminal, session history | P8 |
| Marketing | SMS, email, WhatsApp campaigns, loyalty | P9 |
| Notifications / Announcements / Support | lists, read, raise ticket | P9 |
| Security / Settings | stores, users, audit, business profile, invoice/print settings, reminders, CA share | P10 |

### 1.2 Left out of mobile v1 (on purpose)

These are desktop or admin tasks and don't suit a phone. The web app keeps handling them.

- AI purchase-bill parsing (`/purchase/parse-bill-ai`), CSV/Excel bulk import and export, data migration jobs
- B2B Shop manager, Customer Portal admin, Design Kit, Developer Settings, DB backup/maintenance
- Weighing-scale integration, ESC/POS thermal printing, barcode label sheet layout
- Invoice template designer (mobile *uses* server PDFs, it doesn't design them)
- Compliance admin (roles/IP restrictions/GDPR), Page-features admin, super-admin notification events

We can revisit any of these after v1.

---

## 2. Architecture

### 2.1 Stack

| Concern | Choice | Why |
|---|---|---|
| State / DI | `flutter_riverpod` | Simple async providers and easy invalidation after a save. Works well for API-backed screens. |
| Routing | `go_router` | Declarative routes, deep links, auth redirect, shell route for bottom nav |
| HTTP | `dio` | Interceptors for `Authorization` + `X-Store-ID`, 401 handling, timeouts |
| Token storage | `flutter_secure_storage` | Keychain/Keystore. The token never goes in plain prefs. |
| Prefs | `shared_preferences` | Server URL, active store, theme mode |
| Charts | `fl_chart` | Dashboard sales trend, report charts |
| Formatting | `intl` | `en_IN` currency (₹ with lakh grouping), dates |
| Fonts | `google_fonts` (Poppins) | Same typeface as the web app |
| Links / share | `url_launcher`, `share_plus` | Open or share invoice PDFs, call/WhatsApp a party |
| Scanning (P8) | `mobile_scanner` | Barcode lookup in POS and product search |

### 2.2 Folder layout (feature-first)

```
mobile/lib/
  main.dart
  app.dart                     # MaterialApp.router, theme, providers
  core/
    api/        api_client.dart, api_exception.dart, paged.dart, json.dart
    auth/       auth_repository.dart, session_controller.dart
    config/     app_config.dart (server URL, store id)
    router/     app_router.dart, routes.dart
    theme/      tokens.dart, app_theme.dart, module_colors.dart
    utils/      formatters.dart, validators.dart, debouncer.dart
  shared/widgets/
    app_scaffold.dart  responsive_shell.dart  section_card.dart  stat_tile.dart
    status_chip.dart   amount_text.dart       empty_state.dart   error_view.dart
    paged_list_view.dart  search_bar.dart  filter_chips.dart  date_range_picker.dart
    form_fields.dart   party_picker.dart   product_picker.dart  confirm_sheet.dart
    skeleton.dart      key_value_rows.dart
  features/
    auth/ dashboard/ parties/ products/ invoices/ payments/ purchases/
    expenses/ sales_docs/ notes/ inventory/ cash_bank/ accounting/
    reports/ gst/ hr/ pos/ marketing/ notifications/ settings/ more/
```

Each feature folder holds `data/` (repository + model), `providers.dart`, and `ui/` (screens and widgets).

### 2.3 API layer: what the backend actually does

- **Base URL**: default is production, `https://backend.truerp.co.in/api/v1`. You can change it on the login screen. Override it at build time with `--dart-define=API_URL=…`. A bare hostname gets `https://` (the server 301-redirects plain HTTP, which would break POSTs); local or LAN addresses get `http://`.
- **Headers**: `Authorization: Bearer <token>` and `X-Store-ID: <active store>` (see `backend/middleware/auth.go`).
- **Login**: `POST /auth/login {email, password, totp_code}` returns `{token, user, store?, stores?}`. The flags `requires_2fa` and `requires_password_change` change the flow.
- **Session restore**: `GET /auth/profile` (gives `active_store`, `stores`). Store list comes from `GET /auth/my-stores`.
- **Lists come in three shapes.** One `Paged<T>` parser handles all of them:
  1. a bare array (legacy, unpaginated)
  2. `{ <key>: [...], total, page, per_page }`, where key is one of `invoices`, `parties`, `products`, `payments`, `payment_outs`, `bills`, `categories`, `transactions`
  3. `{ data: [...], total, ... }`
  
  Mobile always sends `page` and `per_page=25` so it gets the paginated form and can scroll forever.
- **Errors**: the body is `{error: "..."}`. It gets turned into an `ApiException`, and screens show it in a snackbar or an inline error view. A 401 clears the session and sends you back to login.
- **Idempotency**: invoice create sends `client_sale_id` and purchase-bill create sends `client_bill_id` (fresh UUIDs). A retry on a flaky mobile network then can't create a duplicate.
- **Models**: typed Dart classes for the core entities (Party, Product, Invoice, InvoiceItem, Payment, PaymentOut, PurchaseBill, Expense, BankAccount, Staff). Parsing is tolerant: numbers may arrive as strings and nulls are allowed. Secondary modules use a light `JsonMap` view so small backend changes don't crash the app.

### 2.4 Shared list/detail engine

About 25 modules are "list → detail → maybe create/cancel". So they don't each repeat the same code, there is a `ResourceSpec` that describes:
endpoint, list key, title/subtitle/amount/date/status getters, search and filter params, detail sections, and actions.
`ResourceListScreen` and `ResourceDetailScreen` draw any spec with the same UI: search, filter chips, pull to refresh, infinite scroll, skeleton loading, empty and error states.
The core flows get their own screens: invoice create, POS, payments, dashboard, reports, and attendance.

---

## 3. Design system

Based on the web app, adjusted for touch.

- **Brand**: Crimson ramp from `frontend/lib/colorThemes.ts`. Primary `#D4031A` (600), container `#FCE8EA` (50/100), deep `#B8002E` (700).
- **Neutrals**: background `#F4F4F5`, surface `#FFFFFF`, text `#3F3638`. Dark mode: background `#0B0A0B`, text `#ECE4E5`. Both light and dark follow the system setting, and you can override it in Settings.
- **Module accents**: the same hex per module as `nav-config.ts` (Parties `#7C3AED`, Inventory `#0891B2`, Sales `#2563EB`, Purchases `#EA580C`, Payments `#6366F1`, Expenses `#E11D48`, Cash & Bank `#16A34A`, Reports `#9333EA`, GST `#C026D3`, HR `#DB2777`, POS `#0284C7`, Marketing `#CA8A04`, …). They tint icons, tiles and headers so you always know which module you're in.
- **Type**: Poppins. Titles 600, body 400. Amounts use tabular figures.
- **Shape**: 10px radius on inputs and buttons (`--radius: 0.625rem`), 14px on cards. Elevation 0, with hairline borders as on the web.
- **Status colours** (same everywhere): paid/active = green, partial = amber, unpaid/overdue = red, draft = grey, cancelled = grey with strikethrough.
- **Touch**: 48dp minimum targets. Main action in a FAB or a sticky bottom bar. Destructive actions confirm in a bottom sheet. Lists swipe for quick actions where it's safe.

### Responsive layout

| Width | Navigation | Content |
|---|---|---|
| < 600 (phone) | Bottom bar: Home · Sales · Purchases · Parties · More | Single column, full-screen create forms |
| 600–1024 (small tablet / landscape) | NavigationRail, collapsed | 2-column grids, wider forms, dialogs for small forms |
| ≥ 1024 (tablet) | NavigationRail, extended with labels | List + detail side by side on main lists, 3–4 column stat grids |

"More" opens a grid of every module, grouped like the web sidebar and tinted with the module accents. It also has a search box.

---

## 4. Phases

Every phase ends with: `flutter analyze` clean, unit tests plus screen-render tests at phone and tablet sizes against a fake API, the release APK building, and this file updated.

**Testing rule: never test against production** (`backend.truerp.co.in`). Automated tests use an in-memory fake API. Any hands-on testing uses a local backend (`--dart-define=API_URL=http://10.0.2.2:8088/api/v1`).

### P0 — Foundation ☑
- ☑ `flutter create` (org `in.truerp`, package `truerp_mobile`), Android + iOS. App name "TruERP", INTERNET permission, cleartext HTTP only in debug builds, iOS local networking
- ☑ Theme tokens, light and dark `ThemeData`, module colours, Poppins — `lib/core/theme/`
- ☑ `ApiClient` (dio + `Authorization`/`X-Store-ID` interceptors, 401 → sign out), `ApiException`, `Paged<T>`, tolerant JSON helpers — `lib/core/api/`
- ☑ App config: server URL (can be changed on login and in the account sheet), active store, theme mode — `lib/core/config/app_config.dart`
- ☑ Auth: login with 2FA step, register, forgot password (email → OTP → new password), session restore, forced password change, logout — `lib/features/auth/`
- ☑ Store switcher in the account sheet, **super admins only** (`owner` / `super_admin`). Other roles see their assigned store read-only and are always pinned to it, even if an earlier session saved a different store. Switching re-keys the shell so every tab refetches.
- ☑ Router with auth redirects. Bottom bar on phones, rail on tablets, rail with labels on wide screens — `lib/core/router/`, `lib/features/shell/`
- ☑ Shared widgets: stat tile, status chip, key/value row, icon badge, initials avatar, paged list (infinite scroll + pull to refresh), search field, empty/error/skeleton, confirm sheet, error banner — `lib/shared/widgets/`
- ☑ "More" module hub, grouped and searchable, filtered by role. Modules from later phases open a "coming in phase N" page — `lib/core/router/modules.dart`
- ☑ Unit tests: list-envelope parser, JSON helpers, formatters, server URL, validators (18 passing). `flutter analyze` clean. `flutter build apk --debug` builds.

### P1 — Core sales loop ☑
- ☑ **Dashboard** (home tab): KPIs for Today / Week / Month / Year / All time (sales, received, to collect with overdue count, today, customers, low-stock items), 30-day paid-sales bar chart, quick actions, recent invoices and payments, top customers. Pull to refresh. Every tile links to its list.
- ☑ **Parties**: list with To collect / To pay summary cards (tap to filter), Customers/Vendors switch, search; detail with balance, call / WhatsApp / email, New invoice and Receive buttons, ledger (newest first, tap an invoice to open it), ledger PDF share, delete; create/edit form with an opening balance stated as "to collect / to pay", GSTIN that prefills the state, Indian state list with GST codes.
- ☑ **Products**: list with category chips and sorting (name, lowest stock, price), stock badge; detail with price/stock/margin tiles and live stock; create/edit (product or service, category, unit, prices, GST rate, HSN/SAC, generated item code, opening stock, low-stock level, active switch).
- ☑ **Invoices**: list with total/received/unpaid strip, status chips, date range, search; detail with payment progress, items, summary, linked payments, activity history, PDF share, WhatsApp, cancel with reason, Record payment bar; **create** with customer picker, product picker (searchable, shows stock, adds a new product inline), quantity steppers, per-line editor, custom lines, invoice discount and charges, amount received with mode and bank account, live total.
- ☑ **Payment In**: list with mode filter; detail sheet with receipt PDF, link to invoice, cancel with reason; receive form (prefilled from a party's balance or an invoice's balance due, discount, mode, bank account, reference).
- ☑ Tablets: list and detail side by side for parties, products and invoices.
- ☑ Tests: 30 unit tests (invoice maths against the server's rule, payload shape, fields the backend overwrites) and 34 screen-render tests (17 screens × phone/tablet) that fail on any layout error. `flutter analyze` clean, release APK builds.

**What the backend does, and how mobile follows it**
- **Invoices are billed tax-free.** `CreateInvoice` sets every item's tax rate to 0. The invoice preview leaves GST out so it matches the saved total. Product GST rate is still stored.
- **Invoice editing stays on the web.** `PUT /invoices/:id` rewrites fields mobile doesn't carry (custom fields, PDF template, charge items, signature), so mobile doesn't offer it.
- **Updates overwrite fields that aren't sent.** Products always rewrite `enable_batching`, `sale_price_with_tax`, `purchase_price_with_tax`; parties always rewrite `tan`. Mobile reads these and sends them back unchanged so an edit never resets them.
- **Duplicate-proof invoices:** each form sends one `client_sale_id` plus an `Idempotency-Key` header, so a retry after a dropped connection can't create a second invoice.

### P2 — Purchases & spend ☑
- ☑ **Purchase bills** (Purchases tab): list with total / paid / to-pay strip, status chips, date range, search; detail with payment progress, stock status, items with GST, summary, payments made, PDF share, Return items, delete (super admins only), Pay vendor bar; **create** with vendor picker, vendor bill number, product picker (purchase price, GST, MRP and sale price carried over), custom lines, tax-exempt switch, bill discount and charges, round off, amount paid with mode and account.
- ☑ **Purchase returns**: list with draft/processed filter; create from a bill (choose quantities per line, "return everything", refund as debit note / cash / bank / UPI); detail with Process (confirms the effect on stock and balance) and delete for drafts.
- ☑ **Purchase orders**: list, create (vendor, dates, items with GST), detail with Submit and delete for drafts, received quantities once submitted.
- ☑ **Payment Out**: list with mode filter, detail sheet with cancel and link to the bill, pay-vendor form (prefilled from the bill's balance or the vendor's balance).
- ☑ **Expenses**: list with category chips, date range, search; detail with GST breakdown, edit, cancel; create/edit with categories (add new inline), several items, GST toggle and rate, mode and account; category management screen.
- ☑ Vendors: party page now offers New purchase and Pay; ledger rows open invoices, bills, returns and expenses.
- ☑ Shared line-item editor (used by invoices, bills and orders) and shared document widgets.
- ☑ Tests: 40 unit tests, 66 screen renders (33 screens × phone/tablet). Release APK builds.

**What the backend does, and how mobile follows it**
- **The server trusts the bill total.** `CreatePurchaseBill` stores `total_amount` from the client and moves the vendor balance by it. Mobile copies the web formula exactly (line − discount + GST − bill discount + charges, rounded to the rupee by default) and tests it.
- **Stock goes in on save.** Bill stock entries are created already approved, and custom lines become new products. The form says so.
- **Expenses need items.** Without items the server saves ₹0, so the form always sends at least one.
- **Bill editing stays on the web**, for the same reason as invoices.
- **Returns use the discounted price.** Mobile returns lines at the price actually paid (after the line discount). The web return form uses the full price, which over-credits discounted lines.

### P3 — Other sales documents ☐ (deferred; P5 built first)
- Estimates/Quotations: list, create/edit, approve/accept/reject, convert to invoice, PDF
- Delivery challans: list, create/edit, view
- Sales returns: list, create from an invoice, process
- Credit notes and debit notes: list, create, issue, cancel
- Discount transactions log

### P4 — Inventory ☐
- Stock overview (`/inventory/stocks`, `/inventory/stats`), low-stock alerts
- Stock movements with type and date filters, plus a summary
- Stock adjust (in/out with reason), stock entries approve/reject
- Categories CRUD; Warehouses CRUD with per-warehouse stock; stock transfers (create, submit, receive)

### P5 — Money ☑ (built ahead of P3 and P4, on request)
- ☑ **Cash & Bank**: total balance with cash-in-hand and bank split, owner's equity; quick Add / Reduce / Transfer; accounts list (primary star, inactive section); account screen with balance, actions and its transactions; bank account create/edit (opening balance on create only, active switch), make primary, delete; all transactions with type chips, date range and search; payment routing (which account each payment mode deposits into; initial investment fixed to owner's equity).
- ☑ **Profit distribution**: payouts list with totals (overall and this year) and partner filter; partners tab with amount paid out per partner; partner add/edit/delete; payout form from cash or a bank account. Long-press a payout to delete it.
- ☑ **Accounting** (read-only): headline figures, chart of accounts grouped by type, journal with entry details, trial balance, profit & loss (defaults to the current financial year from 1 April), balance sheet, general ledger per account with date range. Every report row opens its account's ledger.
- ☑ Module hub and dashboard quick actions only send people to built modules (phases are tracked as a set now, since they don't land in order).
- ☑ Tests: 48 unit tests, 94 screen renders (47 screens × phone/tablet). Release APK builds.

**What the backend does, and how mobile follows it**
- **Transfers are bank-to-bank only.** Cash in hand is changed with Add / Reduce (no account). The transfer form only lists bank accounts and checks the source balance, as the server does.
- **Money in vs out** uses the server's rule: only `add` and `transfer_in` count as money in.
- **Deleting transactions** is offered only to super admins (the endpoint requires it), and only for hand-entered add/reduce rows. Rows created by invoices, payments or expenses belong to those documents.
- **Bank account edits rewrite every field**, including active status, so the form always sends all of them. The opening balance can't be edited after creation.
- **Profit payouts from a bank account can't exceed its balance** (server rule), so the form checks it first.

### P6 — Reports & GST ☐
- Reports hub (cards like `/reports/index`)
- Daily report (one date or a period), Daily profit, Profit & Loss, Billwise profit, Stock report, Party balances. Each has a date range, summary tiles and a breakdown list, and a "Share PDF/Excel" option that uses the existing server export endpoints.
- Analytics: sales, tax, outstanding, customer-wise, product-wise, category-wise, payments
- GST: summary, GSTR-1, GSTR-3B, GSTR-2 views; e-invoice and e-way-bill history

### P7 — HR & Payroll ☐
- Staff: list, detail (balance, attendance, advances, deductions, extras), create/edit
- Attendance: a daily marking sheet (present/absent/half-day/leave) with bulk mark, monthly stats, a calendar per staff member
- Payroll: list, calculate, create, record payments, cancel
- Advances, deductions, extras: list and create; recover, redeem
- Attendance reminder settings

### P8 — POS ☐
- Open or close a session (opening cash, cash in/out movements, session summary)
- Fast billing screen: product grid and search, barcode scan, cart, quick customer, split tender. Uses `is_pos=true` and `client_sale_id`.
- POS drafts (hold or resume a bill), session history

### P9 — Engagement ☐
- Loyalty: settings, stats, customers, transactions, point adjustment, card lookup
- SMS / Email / WhatsApp campaigns: list, stats, create, send, schedule
- Notifications: list, mark read / read all; announcements
- Support requests: list, create, conversation thread, close

### P10 — Settings & admin ☐
- Business profile (logo upload, GSTIN, bank, UPI), invoice settings, print settings
- Profile, change password, 2FA status/setup
- Users (store admins) CRUD and reset password; Stores (super admin); audit trail (read-only)
- Reminders, CA report sharing, WhatsApp invoice settings
- App settings: theme mode, server URL, about/version

### P11 — Hardening & release ☐
- Offline read cache for the main lists, a "you're offline" banner, retry queue for POS sales
- Hide features by role (`role`, super admin) and page features (`/page-features`), same as the web nav filters
- Widget tests for the main parts (Paged parser, tax maths, formatters); a golden test for the invoice summary
- App icon and splash from `logo.png`, release signing, Android App Bundle and iOS archive

---

## 5. Risks & decisions

| Risk | Mitigation |
|---|---|
| The surface is too big to finish in one pass | Phases are ordered by business value. P0–P1 alone give you something usable. The shared list engine makes P3–P9 cheaper. |
| Response shapes differ between endpoints | One tolerant `Paged<T>` parser and tolerant number parsing. Screens never use `as` on raw JSON. |
| Phone tax maths disagrees with the server | The server totals are the truth. The phone's calculation is only a preview, and after saving the detail screen shows the server's totals. |
| Local backend is unreachable from a device | Production is the default. For local work use `--dart-define=API_URL=http://10.0.2.2:8088/api/v1` or the login screen's server setting. Cleartext HTTP is allowed in debug builds only. |
| Roles differ (owner / super_admin / staff) | Endpoints that need super admin (deletes, imports) are hidden unless your role allows them. |
