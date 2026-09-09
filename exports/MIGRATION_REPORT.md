# MyBillBook → TruERP Migration Report & Plan

**Generated:** 2026-09-09
**Source business:** MARKET PURCHASE (Phone: 9894404450)
**Export window:** 07/09/2025 – 06/09/2026 (some reports span 10/11/2023 – 06/09/2027)
**Source app:** myBillBook (https://mybillbook.in)
**Target system:** TruERP (Go/Gin backend + Next.js/Tauri frontend, GORM/PostgreSQL)

---

## 1. Executive Summary

The `exports/` directory contains **11 CSV reports** exported from a myBillBook
account. They are *report-style* exports (headers, title rows, summary totals
mixed with data rows) rather than clean relational dumps, so they cannot be
loaded verbatim. This document maps each export to its TruERP counterpart,
identifies data/structural gaps, and lays out a phased migration plan.

A notable finding: the **Purchase Summary Report** contains a `Purchase link`
column with 429 unique `https://mybillbook.in/cpp/<id>` URLs — one per purchase
bill. These resolve to a public **SharedLedger Portal** HTML page (a React SPA,
*not* a direct PDF). A download option for these source invoices is therefore
non-trivial and is addressed in §6.

### 1.1 Data volumes at a glance

| Export file | Data rows | TruERP target entity |
|---|---:|---|
| `all_party_balance_as_of_06-09-2026.csv` | 57 | `Party` |
| `rate_list_as_of_06-09-2027.csv` | 298 | `Product` |
| `item_summary_report_as_of_06-09-2026.csv` | 291 | (aggregate, no direct table) |
| `stock_summary_report_as_of_06-09-2026.csv` | 901 | `Product` + `InventoryStock` |
| `item_batch_report_as_of_06-09-2027.csv` | 786 | `InventoryStock` (batch-level) |
| `purchase_summary_report_as_of_06-09-2026.csv` | 430 | `PurchaseBill` (+ `PurchaseBillItem`) |
| `bill_wise_profit_report_as_of_06-09-2026.csv` | 1,228 | `Invoice` (profit is derived) |
| `daybook_report_as_of_06-09-2026.csv` | 2,734 | Mixed ledger (see §3.8) |
| `cash_and_bank_statement_as_of_06-09-2026.csv` | 1,413 | `Payment`/`PaymentOut`/`CashTransaction`/`Expense` |
| `expense_category_report_as_of_06-09-2026.csv` | 28 | `ExpenseCategory` |
| `expense_transactions_as_of_06-09-2026.csv` | 17 | `Expense` |

**Critical gap:** None of the exports contain **line-item detail** for sales
invoices or purchase bills. Only header-level totals are present. Full fidelity
migration of sales/purchase *items* is **not possible** from these files alone
(see §5.1).

---

## 2. MyBillBook Export File Inventory

All files share a common preamble before the data table:

```
Company Name: MARKET PURCHASE
Phone No: 9894404450
<blank>
<blank>
<Report Title>
Dated: <range>
<optional summary line(s)>
<blank>
<blank>
<CSV header row>
<CSV data rows>
```

The parser must skip the preamble and locate the header row by its first column
name (e.g. `Date,`, `Name,`, `Purchase No,`, `Item Name,`).

### 2.1 File-by-file schema

#### all_party_balance_as_of_06-09-2026.csv
Header: `Name, GST, Address, State, Pincode, Mob No., Bal., Party Category`
- 57 parties. Most have empty GST/Address/State/Pincode; only `Mob No.` and
  `Bal.` are populated for many rows.
- `Bal.` is the **current outstanding** (positive = receivable from customer,
  negative = payable to vendor). Sign convention must be inferred per party
  type (customer vs vendor).
- `Party Category` is empty for all rows in this export.
- Includes a synthetic `Cash Sale` party (mobile = business phone).

#### rate_list_as_of_06-09-2027.csv
Header: `Name, Code, MRP, Price`
- 298 products. `Code` is the product barcode/item-code. `MRP` is 0 for most
  rows; `Price` is the selling price. No purchase price, tax, HSN, or unit.

#### item_summary_report_as_of_06-09-2026.csv
Header: `Item Name, Unit, Sales Quantity, Purchase Quantity`
- 291 aggregate rows (qty sold/purchased over the period). No money values.
- Useful for cross-checking product names/units, not for import.

#### stock_summary_report_as_of_06-09-2026.csv
Header: `Name, Batch No., Item Code, Purchase Price, Selling Price, Stock Quantity, Stock Value, Item Category Name, MRP, batch no., exp. date, mfg date`
- 901 rows — one per **(product × batch)**. `Stock Quantity` includes a unit
  suffix (e.g. `33.0 PCS`, `0.0 BOX`).
- Note the duplicated/legacy columns: `Batch No.` (populated) vs `batch no.`
  (empty), `exp. date`/`mfg date` (empty). Only the first set is usable.
- 38 distinct `Item Category Name` values (FRUITS, SYRUP, PACKING, …), 61 blank.

#### item_batch_report_as_of_06-09-2027.csv
Header: `Item Name, Batch Number, Expiry Date, MFG Date, MRP, Purchase Price, Selling Price, Current Stock`
- 786 rows. Overlaps with stock_summary but adds explicit batch/expiry/mfg
  dates (though many are empty). `Current Stock` carries a unit suffix.

#### purchase_summary_report_as_of_06-09-2026.csv
Header: `Purchase No, Original Invoice No, Purchase Date, Party Name, Purchase Amount, Purchase link, Notes`
- 430 purchase bills. `Original Invoice No` is **empty for all rows** (the
  vendor's own bill number was never captured).
- `Purchase link` = `https://mybillbook.in/cpp/<10-char-id>` — 429 unique
  links (one row has a duplicate id). These are the source-of-truth bills.
- 13 distinct parties; `MARKET PURCHASE` (the business itself) is the party on
  315 rows — i.e. most purchases are logged as self-purchases.
- **No line items, no tax breakdown, no payment status.**

#### bill_wise_profit_report_as_of_06-09-2026.csv
Header: `Date, Inv No., Party Name, Invoice Val., Sales Val., Purchase Val., Profit, Profit Percentage(%)`
- 1,228 sales invoices. `Inv No.` is a sequential integer (1…1250).
- `Invoice Val.` = total charged; `Sales Val.` = taxable value; `Purchase Val.`
  = COGS. Profit is derived — TruERP computes this from line items.
- **No line items, no tax split, no payment mode.**

#### daybook_report_as_of_06-09-2026.csv
Header: `Date, Name, Transaction Type, Sr No., Total Amount, Money In, Money Out, Balance Amount, Created By`
- 2,734 rows — a chronological ledger of all transactions. Transaction types:
  `Sales Invoice` (1,228), `Payment-in` (564), `Purchase Bill` (429),
  `Expense` (324), `Payment-out` (161), `Add Money` (14), `Reduce Money` (8),
  `Sales Return` (5), `Quotation` (1).
- `Sr No.` is per-type sequential. `Created By` is `Your Name` (default) or
  `SALMAN` (a real user).
- This is the **master chronological feed** and the best source for
  reconstructing opening balances and payment linkage.

#### cash_and_bank_statement_as_of_06-09-2026.csv
Header: `Date, Type, Txn No, Party, Invoice numbers, Mode, Paid, Received, Balance, Notes`
- 1,413 rows. Types mirror the daybook plus `Opening Balance` (1) and `Sales
  Invoice` (22 — a subset where cash was collected at sale time).
- `Mode`: Upi (1,063), Cash (334), Bank (15).
- `Invoice numbers` is a comma-separated list of invoice numbers the payment
  settles — **this is the only payment↔invoice linkage** in the export.
- `Balance` is `-` (running balance not tracked in the export).

#### expense_category_report_as_of_06-09-2026.csv
Header: `Name, Amount`
- 28 expense categories with period totals. Includes non-expense entries like
  `Payment In Discount` (a contra). Must be filtered on import.

#### expense_transactions_as_of_06-09-2026.csv
Header: `Date, Serial No., Exp. Name, Pymt Mode, Amt., Notes`
- Only 17 rows (the export was filtered to 31/08–06/09). `Pymt Mode` = UPI/Cash.
- This is a *partial* extract — the daybook shows 324 expenses for the full
  period. A full-period re-export is needed for complete expense migration.

---

## 3. Mapping to TruERP Data Structures

TruERP is multi-tenant: every operational row is scoped by `UserID` (and
optionally `StoreID`). A migration user/tenant must be created first, then all
imported rows assigned to it.

### 3.1 Parties → `models.Party`
| MyBillBook field | TruERP field | Notes |
|---|---|---|
| `Name` | `Name` | Trim; create `Cash Sale` as a customer |
| `Mob No.` | `Phone` | |
| `GST` | `GSTIN` | Mostly empty |
| `Address` | `Address` | Mostly empty |
| `State` | `State` | |
| `Pincode` | `Pincode` | |
| `Bal.` | `OpeningBalance` + `Balance` | Sign by inferred type |
| `Party Category` | `Category` | Empty here |

- `PartyType` must be derived: parties appearing in `purchase_summary` =
  `vendor`; parties in `bill_wise_profit` = `customer`; `MARKET PURCHASE`
  appears as both → set to `vendor` (it's the business's own purchase alias).
  TruERP's `Party` is a single table with a `party_type` discriminator, so a
  party that is both customer and vendor needs a decision (duplicate or use
  `vendor` and allow sales too). **Gap:** no first-class dual-type party.

### 3.2 Products → `models.Product`
Sources: `rate_list` (names + sale price + code), `stock_summary` (purchase
price, batch, category, MRP), `item_batch` (batch/expiry).

| MyBillBook field | TruERP field |
|---|---|
| `Name` | `Name` (trim leading space) |
| `Code` / `Item Code` | `ItemCode` (and `SKU` if absent) |
| `Price` / `Selling Price` | `SalePrice` |
| `Purchase Price` | `PurchasePrice` |
| `MRP` | `MRP` |
| `Item Category Name` | `Category` (resolve via `Category` table) |
| unit suffix from `Stock Quantity` | `Unit` |
| (not in export) | `HSNCode`, `TaxRate`, `GstEnabled` — **gap** |

- TruERP requires a unique `SKU`; generate from name if missing
  (`utils.GenerateUniqueProductSKU`).
- `PLU` auto-assigned via `utils.AssignProductPLU`.
- `EnableBatching` should be set `true` for any product that has >1 batch in
  the stock/item_batch exports.

### 3.3 Inventory / Batches → `models.InventoryStock`
From `stock_summary` and `item_batch`, keyed by `(ProductID, BatchNo)`.
- `BatchNo` ← `Batch No.` / `Batch Number` (e.g. `16/05/26`, `Batch #1`).
- `MfgDate`/`ExpDate` ← the (often empty) date columns.
- `Quantity` ← numeric part of `Stock Quantity` / `Current Stock`.
- `AverageCost` ← `Purchase Price`.
- One `InventoryStock` row per (product, batch, outlet). Outlet = the
  migration tenant's default warehouse.

### 3.4 Purchase Bills → `models.PurchaseBill` (+ `PurchaseBillItem`)
From `purchase_summary` (header only) + `daybook` (cross-reference).

| MyBillBook field | TruERP field |
|---|---|
| `Purchase No` | `BillNumber` (e.g. `P-0001`) |
| `Original Invoice No` | (empty — store in `Notes` if present) |
| `Purchase Date` | `BillDate` |
| `Party Name` | `PartyID` (lookup by name) |
| `Purchase Amount` | `TotalAmount` |
| `Purchase link` | **no field exists** — see §6 |
| `Notes` | `Notes` |

- `Status`: default `unpaid`; cross-reference `cash_and_bank` `Payment-out` /
  `Purchase Bill` rows to set `paid`/`partial` and `PaidAmount`.
- **No line items in export** → either (a) create a single summary line per
  bill (`Description = "Migrated summary"`, qty 1, unit price = total), or
  (b) fetch line items from the `Purchase link` (see §6). Option (a) loses
  stock-by-batch granularity; option (b) is preferred if the links can be
  parsed.
- `StockStatus`: set `approved` if we create `StockEntry`/`InventoryStock`
  rows for the bill.

### 3.5 Sales Invoices → `models.Invoice` (+ `InvoiceItem`)
From `bill_wise_profit` (header only) + `daybook`.

| MyBillBook field | TruERP field |
|---|---|
| `Inv No.` | `InvoiceNumber` |
| `Date` | `Date` |
| `Party Name` | `PartyID` |
| `Invoice Val.` | `TotalAmount` |
| `Sales Val.` | `SubTotal` |
| `Purchase Val.` | (derived; not stored) |
| `Profit` | (derived; not stored) |

- **No line items, no tax split (CGST/SGST/IGST), no payment mode.** A
  migrated invoice will have a single summary line and `TaxTotal = 0` unless
  tax is reconstructed (not possible from these exports).
- `Status`: derive from `cash_and_bank` — if a `Payment-in` references this
  invoice number and covers the full amount → `paid`; else `sent`/`overdue`.
- `AmountPaid`: sum of `Payment-in` rows whose `Invoice numbers` contains
  this invoice number.

### 3.6 Payments → `models.Payment` / `models.PaymentOut`
From `cash_and_bank` where `Type` ∈ {`Payment-in`, `Payment-out`}.

| MyBillBook field | TruERP `Payment` field |
|---|---|
| `Date` | `Date` |
| `Party` | `PartyID` |
| `Invoice numbers` | `InvoiceID` (lookup; multi-link via multiple `Payment` rows or `PaymentSplits`) |
| `Mode` | `Mode` (map `Upi`→`upi`, `Cash`→`cash`, `Bank`→`bank_transfer`) |
| `Received` | `AmountReceived` |
| `Txn No` | `PaymentInNumber` |
| `Notes` | `Notes` |

- `Payment-out` rows → `PaymentOut` (`AmountPaid` ← `Paid`, `PaymentOutNumber`
  ← `Txn No`, link `PurchaseBillID` by matching `Invoice numbers` to purchase
  no).
- **Gap:** TruERP `Payment` links to a single `InvoiceID`; myBillBook payments
  often settle *multiple* invoices (`"1247, 1237, 1208, …"`). The importer must
  either split the payment across N `Payment` rows (proportional or
  sequential) or store the raw list in `Notes` and leave `InvoiceID` null.
  TruERP already supports this pattern via linked `Payment` rows
  (`PaymentSplits`).

### 3.7 Expenses → `models.Expense` (+ `ExpenseCategory`)
From `expense_transactions` (full re-export needed) + `daybook` (`Expense`
type rows give the full 324).

| MyBillBook field | TruERP field |
|---|---|
| `Date` | `Date` |
| `Exp. Name` | `Category` (must exist in `ExpenseCategory`) |
| `Pymt Mode` | `PaymentMode` |
| `Amt.` | `Amount` |
| `Serial No.` | `ExpenseNumber` |
| `Notes` | `Notes` |

- Seed `ExpenseCategory` from `expense_category_report` first (filter out
  `Payment In Discount` — that's a sales discount, not an expense).
- `Vendor` is not in the export → leave blank.

### 3.8 Daybook / Cash-Bank → `CashTransaction` + ledger
The daybook is a *reconstruction* feed, not a primary entity. Use it to:
1. Establish chronological order and `Sr No.` per type.
2. Backfill `Created By` → map `Your Name`/`SALMAN` to TruERP users.
3. Reconcile counts (e.g. 1,228 sales invoices in daybook = 1,228 in
   bill_wise_profit ✓; 429 purchase bills = 430 in purchase_summary — **off by
   one**, investigate duplicate `Purchase link`).
4. `Add Money`/`Reduce Money` → `CashTransaction` (`transaction_type` =
  `add`/`reduce`).

### 3.9 Opening Balance
`cash_and_bank` row 1 is `Opening Balance` (Type=`Opening Balance`). This
becomes the `BankAccount.OpeningBalance` / `CashTransaction` seed. The
`all_party_balance` `Bal.` column provides per-party opening balances as of
the report date — but since the export window starts 07/09/2025 and parties
have activity from 2023, the `Bal.` is a *current* balance, not a true
opening. **Gap:** true opening balances per party as of 07/09/2025 cannot be
derived without older data; the closing balance must be reverse-engineered
by replaying the daybook.

---

## 4. TruERP Import Infrastructure (existing)

The codebase already has CSV import endpoints that the migration can reuse or
extend:

| Existing endpoint | Reusable for |
|---|---|
| `POST /api/v1/products/import/csv` (`ImportProductsCSV`) | Products |
| `POST /api/v1/products/import/excel` | Products (xlsx) |
| `POST /api/v1/invoices/import/csv` (`ImportInvoicesCSV`) | Sales invoices (line-item grouped by invoice number) |
| `POST /api/v1/inventory/stocks/bulk-update/csv` | Stock batches |
| `GET /api/v1/products/export/csv` | (reference for export format) |

**Missing importers** that must be built:
- `POST /api/v1/parties/import/csv` — parties
- `POST /api/v1/purchase/bills/import/csv` — purchase bills (header + items)
- `POST /api/v1/payments/import/csv` — payment-in / payment-out
- `POST /api/v1/expenses/import/csv` — expenses
- `POST /api/v1/migration/mybillbook` — orchestrator that accepts a ZIP of
  the 11 CSVs and runs the full phased import in §7.

The existing importers expect a **flat header row** with no preamble, so the
myBillBook files must be *pre-cleaned* (strip the 7-line preamble, drop
summary/total rows) before feeding them in.

---

## 5. Gaps & Risks

### 5.1 Missing line-item detail (HIGH)
No export contains sales or purchase **line items**. Consequences:
- Stock movement history per invoice/bill cannot be reconstructed →
  `StockEntry` rows for historical sales/purchases cannot be created.
- Tax (CGST/SGST/IGST) per line is unknown → GST reports (GSTR-1/3B) will be
  blank for the migrated period.
- Profit per line is unknown → `bill_wise_profit` is the only profit source,
  and it's already aggregated.

**Mitigation:** Fetch line items from the `Purchase link` URLs (§6) for
purchases; for sales, request a myBillBook "Sales Invoice Detail" export or
use the daybook as the only record.

### 5.2 No tax / HSN data (HIGH)
`rate_list`, `stock_summary`, `item_batch` have no HSN or tax rate. TruERP
products will import with `TaxRate=0`, `GstEnabled=false`, `HSNCode=""`.
GST-compliant invoicing will require manual HSN assignment post-migration
(the repo ships `HSN_DATASET.csv` + an AI HSN search feature to help).

### 5.3 Payment ↔ invoice linkage is fragile (MEDIUM)
`cash_and_bank.Invoice numbers` is a free-text comma list. Parsing must
handle whitespace, missing numbers, and the `Purchase Bill` type rows that
reference purchase numbers, not invoice numbers. Some `Payment-in` rows have
empty `Invoice numbers` (unallocated receipts) → import as `Payment` with
`InvoiceID = nil`.

### 5.4 Party type ambiguity (MEDIUM)
`MARKET PURCHASE` is both a vendor (315 purchase rows) and the business name.
`Cash Sale` is a pseudo-customer. TruERP's `Party.PartyType` is single-valued.
Recommendation: import `MARKET PURCHASE` as a vendor; create a separate
`Cash Sale` customer; for parties that are genuinely both, default to
`customer` and allow purchase bills to reference customers too (TruERP
`PurchaseBill.PartyID` is not restricted by type).

### 5.5 Date formats & locale (LOW)
Dates are `DD/MM/YYYY` (Indian). The existing `parseImportDate` in
`invoice_import.go` already handles this; reuse it.

### 5.6 Duplicate / off-by-one counts (LOW)
- Purchase summary has 430 rows but 429 unique links and daybook shows 429
  purchase bills → one duplicate link. Dedupe on `Purchase link` before
  import.
- `expense_transactions` covers only 7 days (17 rows) vs 324 in daybook →
  request a full-period re-export.

### 5.7 No purchase-bill source-document storage (MEDIUM — addressed in §6)
TruERP `PurchaseBill` has no field for the original myBillBook URL. The
`Expense` model has `ReceiptURL` but `PurchaseBill` does not.

### 5.8 Multi-currency / rounding (LOW)
All amounts are INR with one decimal. TruERP uses `float64`; no issue.

---

## 6. Downloading Purchase Invoice Source Documents

### 6.1 What the links are
Each `Purchase link` is `https://mybillbook.in/cpp/<id>` → a public
**SharedLedger Portal** page (React SPA, `Content-Type: text/html`). It is
**not** a direct PDF. The page renders the bill client-side; there is no
unauthenticated JSON/PDF API at a predictable path (probed
`/api/cpp/<id>/pdf` → HTTP 400).

### 6.2 Recommended approach: store the link + on-demand fetch
1. **Schema change:** add `SourceURL string` to `models.PurchaseBill`
   (mirrors `Expense.ReceiptURL`). AutoMigrate will add the column.
2. **Migration:** store the myBillBook URL in `SourceURL` for each imported
   bill.
3. **UI:** in `purchase-invoices/view/page.tsx` and the list dropdown, add a
   "View source bill" link that opens `SourceURL` in a new tab
   (`window.open(bill.source_url, '_blank', 'noopener')`).
4. **Bulk download (new feature):** add a "Download source invoices" action
   that, for selected bills, fetches each `SourceURL`, renders the HTML via
   a headless browser (Chromium via `chromedp` on the backend, or the Tauri
   webview on desktop), prints to PDF, and returns a ZIP. This reuses the
   existing `JSZip` bulk-export pattern in
   `app/(app)/purchase-invoices/page.tsx` (`handleBulkExport`).

### 6.3 Backend endpoint (proposed)
```
POST /api/v1/purchase/bills/download-source
Body: { "ids": ["<uuid>","<uuid>",...] }
Response: application/zip  (one PDF per bill)
```
Implementation sketch (`controllers/purchase.go`):
- For each bill, read `SourceURL`.
- Use `chromedp.Run(ctx, chromedp.Navigate(url), chromedp.WaitReady("body"),
  chromedp.PrintToPDF(...))` to produce a PDF.
- Stream PDFs into a `jszip`-like Go zip writer (`archive/zip`).
- Return the zip; frontend saves via `downloadBlob` (already imported).

Fallback if headless rendering is too heavy: store the raw HTML snapshot
during migration (a one-time `curl` + save to S3/local via the existing
`services.StorageFactory`), and offer HTML download instead of PDF.

### 6.4 Frontend changes (proposed)
- `app/(app)/purchase-invoices/page.tsx`:
  - Add `source_url?: string` to the `PurchaseBill` interface.
  - In the row dropdown (line ~842), add a `Download source` /
    `Open source` `DropdownMenuItem` when `bill.source_url` is set.
  - Add a bulk "Download source invoices (PDF)" button next to the existing
    "Export" button that calls the new endpoint and saves the zip.
- `app/(app)/purchase-invoices/view/page.tsx`: add a "Source" row showing the
  myBillBook link as an external anchor.

---

## 7. Migration Plan (phased)

### Phase 0 — Preparation
1. Create a dedicated TruERP user/tenant for `MARKET PURCHASE`
   (or use the existing owner).
2. Request from myBillBook a **full-period** `expense_transactions` export
   (currently only 7 days).
3. Request, if available, a **Sales Invoice Detail** (line-item) export and a
   **Purchase Bill Detail** export — these would eliminate the §5.1 gap.
4. Pre-process all 11 CSVs: strip preamble, normalize headers, dedupe
   purchase links, parse unit suffixes. Output clean CSVs to
   `exports/clean/`.

### Phase 1 — Master data
1. Import `ExpenseCategory` from `expense_category_report` (filter
   `Payment In Discount`).
2. Import `Party` from `all_party_balance` (derive `PartyType`).
3. Import `Product` from `rate_list` ∪ `stock_summary` (merge prices/code).
4. Import `InventoryStock` batches from `stock_summary` / `item_batch`.
5. Seed `BankAccount` (cash + the one bank implied by `Mode=Bank`).

### Phase 2 — Transactions (chronological, via daybook order)
1. Import `PurchaseBill` headers from `purchase_summary` (store `SourceURL`).
2. Import `Invoice` headers from `bill_wise_profit`.
3. Import `Payment` (Payment-in) and `PaymentOut` (Payment-out) from
   `cash_and_bank`, linking to invoices/purchase bills via the
   `Invoice numbers` field.
4. Import `Expense` from full-period expense export (fall back to daybook
   `Expense` rows).
5. Import `CashTransaction` for `Add Money`/`Reduce Money`/`Opening Balance`.

### Phase 3 — Reconciliation
1. Recompute `Invoice.AmountPaid`/`Status` and `PurchaseBill.PaidAmount`/
   `Status` from linked payments.
2. Recompute `Party.Balance` from transactions; compare to `all_party_balance`
   `Bal.` — discrepancies indicate missing data.
3. Cross-check daybook counts vs imported counts (§3.8).
4. Backfill `StockEntry` for opening stock (entry_type=`opening`) from
   `InventoryStock` initial quantities.

### Phase 4 — Source documents (§6)
1. Add `SourceURL` column; populate from `purchase_summary.Purchase link`.
2. Build the `download-source` endpoint + UI.
3. Optionally snapshot each link's HTML to object storage during migration.

### Phase 5 — Verification & cutover
1. Run TruERP reports (daily report, party balance, stock summary, profit)
   and diff against the myBillBook exports.
2. Fix deltas; mark the myBillBook account read-only.

---

## 8. Build / verification commands

```bash
# Backend
cd backend && go build ./... && go vet ./...
cd backend && go test ./...

# Frontend
cd frontend && npm install && npm run build
cd frontend && npx tsc --noEmit
```

No migration code is written yet; this document is the plan. Implementation
should follow the phases in §7, adding the importers listed in §4 and the
source-download feature in §6.
