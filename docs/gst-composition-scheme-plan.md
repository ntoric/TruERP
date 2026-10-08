# GST Composition Scheme — Study Report & Implementation Plan

Status: **Plan — pending approval before implementation**
Scope decision: implement the **GST Composition Levy** by *upgrading the existing tax infrastructure* (no tables/endpoints deleted, no behavior change for existing users or data).

**Decisions locked with the user:**
- Default composition category: **Trader (1%)** — all 4 categories remain selectable in settings.
- **`regular` registration mode: hidden** from the UI (code plumbing designed for a later phase).
- **Turnover statuses** → store-specific configuration in **Developer Settings** (not hardcoded).
- **Bill of Supply numbering** → store-specific configuration in **Developer Settings**; default keeps the existing `INV-` series.

---

## Part A — Composition Scheme: Legal Research

### A.1 Legal basis

| Provision | What it covers |
|---|---|
| Section 10(1), CGST Act 2017 | Composition levy for goods suppliers & restaurants |
| Section 10(2A) + Notification 2/2019–CT(R) (as amended by 9/2019) | Composition for service providers at 6% |
| CGST Rules 3–7 | Conditions, intimation, withdrawal |
| CGST Rule 62 | CMP-08 (quarterly) + GSTR-4 (annual) |
| CGST Rule 46/49 | Bill of Supply contents & numbering |
| Notification 14/2019–CT | Turnover ceiling ₹1.5 cr |
| Section 9(3)/9(4) | Reverse charge still applies to composition dealers |

### A.2 Eligibility & turnover ceilings (preceding FY aggregate turnover, PAN-India)

| Category | Ceiling | Composition rate (CGST+SGST) |
|---|---|---|
| Manufacturer (goods) | ₹1.5 cr | **1%** (0.5+0.5) of *turnover in State* |
| Trader / other supplier of goods | ₹1.5 cr | **1%** (0.5+0.5) of *turnover of taxable supplies of goods only* — exempt/nil goods excluded from the base |
| Restaurant / catering (no alcohol) | ₹1.5 cr | **5%** (2.5+2.5) of turnover in State |
| Service provider u/s 10(2A) | ₹50 lakh | **6%** (3+3) of turnover in State ("first supplies" up to ₹50L in the FY) |

**Special-category states — ceiling is ₹75 lakh (not ₹1.5 cr):**
Arunachal Pradesh, Assam, Himachal Pradesh, Manipur, Meghalaya, Mizoram, Nagaland, Sikkim, Tripura, Uttarakhand.

**Marginal service allowance under 10(1):** a goods composition dealer may also supply services up to the higher of **10% of turnover** or **₹5 lakh**.

### A.3 Conditions & prohibitions (Section 10(2), Rule 5)

1. **No inter-state outward supply** (inter-state *purchases* are allowed).
2. No supply through e-commerce operators liable to TCS (Sec 52).
3. Cannot manufacture notified goods: ice cream (2105), pan masala (2106 90 20), tobacco & products (Ch 24), aerated water (2202 10), fly-ash bricks/blocks/tiles etc.
4. Not a casual taxable person or non-resident taxable person.
5. **Cannot collect tax from customers** — must issue a **Bill of Supply**, never a Tax Invoice.
6. **No Input Tax Credit** — GST paid on purchases becomes cost.
7. **Reverse charge (Sec 9(3)/9(4)) still applies at normal rates** — paid in cash, not at composition rate, and no ITC on it.
8. Bill of supply must state: *"composition taxable person, not eligible to collect tax on supplies"*; signboards must say *"composition taxable person"*.
9. All GSTINs under the same PAN must opt in together.
10. Cannot supply goods not leviable to GST (petrol, alcohol, etc.).

### A.4 Compliance calendar

| Form | Frequency | Due date |
|---|---|---|
| GST CMP-02 | Once — opt-in | Before start of FY (or in REG-01 for new registrations) |
| GST CMP-03 / ITC-03 | Once — stock intimation + ITC reversal | Within 60 days of opting in |
| **GST CMP-08** | **Quarterly** — statement cum self-assessed tax challan | **18th of month after quarter** |
| **GSTR-4** | **Annual** return | **30 June** after FY (FY 2024-25 onward; was 30 April) |
| GST CMP-04 | On withdrawal/exit | Within 7 days of event |

Late fee: ₹200/day (₹100 CGST + ₹100 SGST), max ₹5,000; 18% p.a. interest on delayed tax. Two consecutive unfiled CMP-08s block e-way bill generation.

Other rules:
- Composition dealers are **exempt from e-invoicing**. **E-way bills still apply** (goods movement > ₹50k).
- Turnover breach mid-year → must exit (CMP-04), issue tax invoices from that date.
- Credit/debit notes adjust value only — no tax shown.
- Aggregate turnover = taxable + exempt + export + inter-state supplies (all GSTINs on PAN), excluding RCM inward and the tax amount itself.

### A.5 CMP-08 content (what we must compute per quarter)

| Row | Contents |
|---|---|
| Outward supplies (intra-state) | Turnover in State; composition tax → CGST = SGST = rate/2 each |
| Inward supplies under RCM | Taxable value; tax at **normal** rates split CGST/SGST (intra-state) or IGST (inter-state) |
| Interest / late fee | On delayed payment/filing |
| Total payable | Sum |

---

## Part B — Current System Audit

### B.1 What exists already (reuse candidates)

| Asset | Location | State |
|---|---|---|
| `Business` settings row (GSTIN, StateCode…) | `models.Business`, `business.go`, `/api/v1/business` | Per-user config — ideal home for registration config |
| `Invoice.InvoiceType` (`tax_invoice/bill_of_supply/export`) | `models.Invoice:214` | Field exists, never populated/used for rendering |
| Full tax columns on invoices/items (`tax_rate`, `cgst`, `sgst`, `igst`, totals) | `Invoice`, `InvoiceItem`, `Quotation`, `CreditNoteItem`… | Present, all zero |
| GST reports GSTR-1/2/3B + summary | `controllers/gst.go` | Works, outputs zeros |
| Tax master models: `TaxRate`, `TaxRule`, `TaxExemption`, `TaxPeriod`, `InputTaxCredit`, `GSTFilingStatus`, `GSTR1Data`, `GSTR3BData` | `models.go`, `routes.go` | CRUD live; ITC created only manually |
| E-invoice / e-way-bill mock generators | `gst.go` | Works; e-invoice must be blocked for composition |
| `ValidateGSTIN`, state codes, `CalculateTax`, `ConvertPrice` | `compliance.go`, `gst.go` | Reusable as-is |
| `Product.GstEnabled` + `Product.TaxRate` | `models.go:1727-1728` | Present but force-zeroed |
| `isInterState` auto-detect (party.state ≠ business.state) | `SaleForm.tsx:391` | Reuse for the composition inter-state block |
| `PurchaseBill.TaxTotal` + `TaxExempt` | `models.go:966-967` | GST-on-purchases already recordable (no ITC = fine) |

### B.2 Where billing is hard-pinned to tax-free (upgrade points)

| File:line | Hardcode |
|---|---|
| `backend/controllers/invoice.go:296` | `taxRate := 0.0` (create) |
| `backend/controllers/invoice.go:619` | `tax := 0.0` (update) |
| `backend/controllers/quotation.go:160,361` | `taxRate := 0.0` |
| `backend/controllers/invoice_import.go:259` | migration import ignores line tax |
| `backend/controllers/product.go:35` | `product.TaxRate = 0` on save |
| `frontend/lib/numbers.ts:77-86` | `isProductGstEnabled()`→false, `productTaxRate()`→0 |
| `frontend/components/SaleForm.tsx:439,833` | `const tax = 0` |

### B.3 Print/PDF titles hardcoded (need type-aware title)

- `invoice_pdf.go:182,191` — `TAX INVOICE` ×2
- `print_pdf.go:65`, `printer.go:769` — `TAX INVOICE`
- `GstInvoicePreviewSample.tsx`, `posReceipt.ts` — preview/receipt header

### B.4 Gaps vs. composition requirements

1. No concept of GST registration type (unregistered / composition / regular).
2. No Bill of Supply document flow (type, title, statutory declaration).
3. No inter-state sale restriction.
4. No product-level taxable/exempt classification → cannot compute the trader 1% base or turnover splits.
5. No composition liability computation, no CMP-08/GSTR-4 reports, no filing tracking for those forms.
6. No RCM flag on purchases → RCM liability invisible.
7. No FY turnover tracker / threshold warnings.
8. ITC/GSTR-1/3B flows are meaningless under composition but harmless — they must be gated by registration type, not removed.

---

## Part C — Design (reuse-first, backward compatible)

### C.1 Core principle

Introduce **`Business.RegistrationType`** = `none | composition | regular` (default `none`).

- `none` → **exactly today's behavior** (tax-free billing). All existing users/rows land here → zero breakage.
- `composition` → tax-free billing **plus** Bill of Supply, restrictions, liability computation, CMP-08/GSTR-4.
- `regular` → reserved; plumbing is designed so a later phase can flip `taxRate := 0` to the item rate with no schema churn. (UI may expose it marked "coming soon" or we ship basic regular calc — see open questions.)

### C.2 Schema changes (all additive, AutoMigrate-safe)

**`businesses` — new columns:**
```go
RegistrationType   string  `gorm:"default:'none'"`        // none | composition | regular
CompositionCategory string `gorm:"default:''"`           // manufacturer|trader|restaurant|service
CompositionRate    float64 `gorm:"default:0"`            // derived: 1|5|6
CompositionFrom    *time.Time                            // effective date (default: FY start)
CompositionNotified75L bool `gorm:"default:false"`      // state in ₹75L list (auto-derived from StateCode, overridable)
```
`CompositionRate` is server-derived from category (trader & manufacturer → 1, restaurant → 5, service → 6); never client-trusted.

**New table `composition_tax_returns`** (register in `allApplicationModels()`):
```go
UserID, FinancialYear string("2025-26"), Quarter int(1-4)
TaxableTurnoverGoods  float64 // trader base: lines on taxable goods
TotalTurnover         float64 // all outward supplies in State
ExemptTurnover        float64 // nil/exempt lines
ServiceTurnover       float64 // lines on item_type='service'
CompositionTax        float64 // = applicable base × rate
CGST, SGST            float64 // each = tax/2
RCMTaxableValue, RCMTax float64 // from RCM-flagged purchase bills
Interest, LateFee     float64 // manual input
Status                string  // draft|paid|filed
PaidAmount, PaidAt, FiledAt, ARN
```
Persisted so payment/filing history survives; values recomputed until `filed`.

**`purchase_bills` / `purchase_receipts` — new columns:**
```go
ReverseCharge bool `gorm:"default:false"`
```
RCM tax = the bill's `TaxTotal` when `ReverseCharge` is set (vendor charges are already captured in `TaxTotal`).

**`developer_settings` — new columns (store-specific config, per user request):**
```go
CompositionTurnoverStatuses string `gorm:"default:'sent,paid,partial,overdue'"`
   // CSV of invoice statuses counted toward composition turnover.
   // Default = every status except draft & cancelled.
BillOfSupplyPrefix string `gorm:"default:''"`
   // Document prefix for bills of supply. Empty → keep existing InvoicePrefix
   // (INV-) series. Non-empty (e.g. "BOS") → separate numbered series allocated
   // by the same max-sequence allocator used for invoice numbers.
```

**`products`:** no schema change — stop forcing `TaxRate=0`; store `GstEnabled`/`TaxRate` as *classification data*. `GstEnabled && TaxRate>0` ⇒ "taxable supply"; otherwise exempt/nil-rated for turnover splits.

### C.3 Billing behavior under composition (server-enforced)

In `CreateInvoice`/`UpdateInvoice` (and quotation/migration paths):
1. Look up business once → `registration_type`.
2. `composition` → `InvoiceType = "bill_of_supply"`, item tax math stays zero (unchanged), `is_inter_state = false` **and reject** if input requests inter-state (400: "Composition dealers cannot make inter-state sales").
3. `none` → identical to today (`tax_invoice` type preserved for history, zero tax).
4. Reject `invoice_type` spoofing from client — server always derives it.
5. Credit notes/sales returns keep zero-tax math (already the case when parent items have `tax_rate=0`).
6. **Document numbering (configurable):** default = existing `InvoicePrefix`/`INV-` series via `allocateUniqueInvoiceNumber` — zero data migration. When `DeveloperSettings.BillOfSupplyPrefix` is set (e.g. `BOS`), bills of supply draw from a separate `PREFIX-000N` series by reusing the same max-sequence allocator (`maxInvoiceSequence` + uniqueness check). Rule 49 permits either approach.

### C.4 Calculation engine (`services/` or `controllers/gst_composition.go`)

```
supplyValue(invoice) = sub_total − discount_total − invoice_discount + additional_charges
                     − (issued sales returns / credit notes against it, in their own period)

CountedStatuses     = CSV from DeveloperSettings.CompositionTurnoverStatuses
                      (default sent,paid,partial,overdue)

TotalTurnover(Q)    = Σ supplyValue over invoices in quarter (status ∈ CountedStatuses)
TaxableGoodsTurnover= Σ line(qty×price − lineDisc − proRataShare(invoiceDiscount))
                      where product.GstEnabled && product.TaxRate > 0
ExemptTurnover      = TotalTurnover − TaxableGoodsTurnover − ServiceTurnover
ServiceTurnover     = Σ lines where item_type='service'

CompositionTax(Q)   = CompositionRate/100 × base
  base = TaxableGoodsTurnover   (trader)
       = TotalTurnover          (manufacturer / restaurant / service)

CGST = SGST = CompositionTax/2   (IGST always 0 — no inter-state sales)

RCMTax(Q) = Σ purchase_bills.TaxTotal where ReverseCharge && bill_date ∈ Q
            (intra-state → CGST/SGST halves; vendor inter-state → IGST)

Liability(Q) = CompositionTax + RCMTax + Interest + LateFee
FY Turnover  = Σ quarters (Apr→Mar) — drives the ₹1.5cr/₹75L/₹50L threshold warnings
```

**Worked example (trader, quarter):**
turnover ₹10,00,000 of which ₹1,50,000 exempt goods → tax = 1% × 8,50,000 = **₹8,500** (CGST ₹4,250 + SGST ₹4,250). RCM bill ₹20,000 @18% intra-state → **₹3,600** (1,800+1,800). CMP-08 payable = **₹12,100**.

### C.5 Reports & filing

- `GET /api/v1/gst/composition/summary?fy=YYYY-YY` → turnover, base, tax per quarter + threshold tracker.
- `GET /api/v1/gst/composition/cmp08?fy=&quarter=` → CMP-08 grid (outward, RCM inward, interest/fee, total).
- `GET /api/v1/gst/composition/gstr4?fy=` → annual aggregation incl. inward URD supplies (party.GSTIN empty) as GSTR-4 requires.
- `POST /api/v1/gst/composition/pay` & `/file` → mark paid/filed on `composition_tax_returns` (+ optional `GSTFilingStatus` rows with `return_type='CMP08'/'GSTR4'` — reuses existing filing-status UI).
- Branch `GetGSTSummary`: composition → composition payload keyed identically so the GST page never crashes; add `mode` to response.

### C.6 Validations & warnings

| Rule | Enforcement |
|---|---|
| Inter-state outward | 400 on create/update; SaleForm disables state-mismatched parties under composition |
| Turnover ≥ 80% / ≥ 100% of ceiling | Warning badge + notification; at 100% banner: "exit via CMP-04, switch registration" |
| Marginal service > 10%/₹5L (goods categories) | Warning in composition summary |
| E-invoice on composition bill | `GenerateEInvoice` returns 400 (exempt anyway) |
| E-way bill | Unchanged — still allowed |
| `TaxPeriod`/ITC/GSTR-1/3B endpoints | No-ops/hidden for composition users (data preserved for switch-back) |

### C.7 Print/documents

- `invoice_pdf.go`, `print_pdf.go`, `printer.go`, `GstInvoicePreviewSample.tsx`, `posReceipt.ts`: title = `"BILL OF SUPPLY"` when `InvoiceType == "bill_of_supply"`, else `"TAX INVOICE"`.
- Bill of supply footer line: *"composition taxable person, not eligible to collect tax on supplies."* (Rule 46).
- No tax columns rendered on BOS (they're zero today — render same, title only changes).

### C.8 Frontend changes

| File | Change |
|---|---|
| `settings/page.tsx` | New **"Tax / GST" card** in Business tab: registration type select; composition category select; derived rate chip; effective-from date; FY turnover progress vs ceiling |
| `lib/numbers.ts` | `isProductGstEnabled`/`productTaxRate` take an optional mode param (or read cached business); still `false`/`0` for `none`+`composition`; real values only under future `regular` |
| `SaleForm.tsx` | Header shows "Bill of Supply" under composition; block inter-state party (auto-detect already exists); hide/disable Tax% column input |
| `gst/page.tsx` | Mode-aware tabs: composition → CMP-08, GSTR-4, Turnover tracker, RCM; `none` → "not GST-registered" empty state; regular → existing tabs |
| `products` forms | Re-enable GST fields (classification master data; safe — billing ignores them) |
| `purchase-invoices` | "Reverse Charge" checkbox |
| `invoices` list/pdf pages | Show "Bill of Supply" title |

### C.9 Backward-compatibility guarantees

- `registration_type` defaults `none` → existing users see **byte-identical** billing & reports.
- All new columns default-valued; AutoMigrate only adds.
- No endpoint removed or response shape changed (only *added* keys/`mode`).
- Existing `tax_invoice` rows keep their type; only new composition-mode documents become `bill_of_supply`.
- ITC/GSTR1-3B code paths untouched; dormant, not deleted.

---

## Part D — Work Breakdown

| Phase | Deliverable | Files |
|---|---|---|
| **1. Config & schema** | Business fields + Update map; `composition_tax_returns` model + migrate; RCM flag; DeveloperSettings tax section (turnover statuses + BOS prefix) | `models.go`, `database.go`, `business.go`, `developer_settings.go` |
| **2. Billing enforcement** | registration-aware invoice type; inter-state block; BOS prefix-aware numbering; stop force-zeroing product tax; server derives type | `invoice.go`, `quotation.go`, `invoice_import.go`, `product.go`, `pos_offline.go` (allocator) |
| **3. Liability engine + reports** | status-config-aware turnover/tax computation, CMP-08, GSTR-4, pay/file endpoints, summary branch | new `gst_composition.go`, `gst.go`, `routes.go` |
| **4. Frontend** | settings card, SaleForm BOS mode + inter-state guard, GST page composition tabs, purchase RCM toggle, product GST fields, developer-settings tax section | settings, SaleForm, gst/page, numbers.ts, purchase pages, developer-settings page |
| **5. Documents** | BOS titles + declaration across PDF/thermal/preview | invoice_pdf.go, print_pdf.go, printer.go, previews |
| **6. Alerts** | threshold warnings, CMP-08/GSTR-4 due-date reminders | notifications, dashboard |
