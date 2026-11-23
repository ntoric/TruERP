# Stock Valuation Investigation — Report
**Store:** Honeys Dates and Nuts (user `3f0be372…`) · **Period analyzed:** Sep 26 – Oct 27, 2026 · **Prepared:** Oct 27, 2026

---

## 1. The question

Opening stock on **Oct 1** was showing **₹7,88,998.75** (equal to Sep-30 closing), then changed to **₹7,86,228.93** with no visible document edited. Why?

## 2. How the system actually works

- "Opening stock" is **not a stored number**. It is recomputed from scratch on every snapshot rebuild by replaying the stock ledger plus a synthetic "baseline" for migrated stock, priced at **live `average_cost` at rebuild time**.
- Oct-1 opening = `override(₹7,96,734.33) + [computed Sep-30 close − computed Sep-29 close]`
- Any change to `average_cost`, live quantity vs ledger, or the override rewrites history. It drifts by design.

## 3. What changed (verified against two live backups)

| Position | Oct-2 backup | Oct-27 live | Δ |
|---|---:|---:|---|
| Computed Sep-29 close | 7,97,633.90 | 8,40,765.51 | +43,131.61 |
| Computed Sep-30 close | 7,89,889.36 | 8,30,260.11 | +40,370.76 |
| **Displayed Oct-1 opening** | ~7,88,989.79 | **7,86,228.93** | **−2,769.82** |

Quantities were **identical** between backups — the entire change was **price re-rating**, not missing documents.

## 4. Root causes found

| # | Cause | Evidence | Impact |
|---|---|---|---|
| 1 | **Bug — restore at selling price**: every invoice edit/cancel/delete restored stock by re-rating `average_cost` at the **sale price** (₹1,900), not cost | `restoreInvoiceSaleStockQuantities`; BADAM CALIFORNIA avg hit ₹4,674 on ~₹1,100 goods; ~50 deleted entries on that product alone | Progressive cost inflation → baseline re-priced ~+₹43k on Sep-29/30 |
| 2 | **Bug — orphaned ledger entries**: `DeleteInvoice` restored qty but kept the invoice's sale entries → live stock above what the ledger explains | INV-0589 (deleted Oct-11: GIFT ITEMS 28 ×2, ATTAR ×1, KUMKUM ×1, LEAF ×1), INV-0290 (PISTA +0.05) | **+5.05 phantom units** injected into Sep-26 baseline |
| 3 | October purchases at higher prices (Oct-4/12/23 bills: BADAM @1200/1140, CASHEW @960, WALNUT @1550, PISTA @2740) | purchase_bill entries | Legitimate re-rating — amplified by the migrated baseline |
| 4 | Code change Oct-8 (`b44442f`) added override-delta seeding to opening | git history | Display semantics differed between deploys (789,889 vs 788,989 on identical data) |
| 5 | Negative-quantity batches + duplicate batch rows (e.g., −3 @ ₹0, two rows for batch `02/01/26`) | `inventory_stocks` | WAC formula divides by ~0/negative → explosive costs; a −0.725-unit product contributed −₹2,606 of the swing alone |

## 5. Fixes applied (code)

| File | Fix |
|---|---|
| `controllers/inventory.go` (`restoreInvoiceSaleStockQuantities`) | Restore passes cost `0` — no longer re-rates WAC at selling price |
| `controllers/inventory.go` (`UpdateStockEntry`) | Reversal passes cost `0` — same leak closed |
| `controllers/sales_return.go` (`ProcessSalesReturn`) | Returns re-enter stock at current avg cost, not `item.UnitPrice` |
| `controllers/invoice.go` (`DeleteInvoice`) | Invoice's stock entries now soft-delete **inside the same transaction** as the invoice — no more orphans |

Build + tests pass. These stop **future** drift.

## 6. Reconciliation executed (`backend/scripts/reconcile_stock.sql`)

| Phase | Action | Result |
|---|---|---|
| 1 | Soft-delete ledger entries referencing deleted documents | **46 orphaned entries removed** (−43.6 units) |
| 2 | Recompute `average_cost` from costed-inflow WAC | **1,341 rows corrected** (e.g., DRY FIG MEXICO ₹25,000 → ₹800; CASHEW PEPPER ₹3,019 → ~₹1,704-class) |
| 3 | Negative-quantity rows | 462 rows listed — **manual review still needed** |

**Verification:** computed Sep-29 qty now = **8,153.6948 = exactly the declared override quantity** — ledger and live stock reconcile.

## 7. Corrected October P&L (Oct 1–27)

| Line | Before reconcile | **After reconcile** |
|---|---:|---:|
| Net Sales (931 invoices) | 2,90,839.00 | **2,90,839.00** |
| Net Purchases (21 bills) | 1,56,186.50 | **1,56,186.50** |
| Opening Stock | 7,86,228.93 | **7,89,862.80** |
| Closing Stock | 7,42,667.11 | **7,67,985.34** |
| **Gross Profit** | 91,091 | **₹1,12,775** (38.8%) |
| Expenses | 52,477.70 | **52,477.70** |
| **Net Profit** | 38,613 | **₹60,297** |

**Cross-validation:** independent COGS method (sales − cost at purchase price, ignoring snapshots entirely) gives **₹1,16,805** — within ₹4k/1.4%. The pre-reconcile ₹91k GP was the corrupted figure.

## 8. The profit "bump" explained

GP = NetSales − NetPurchases + (Closing − Opening). Corrupted `average_cost` had overstated the cost of every unit sold → the month's stock drawdown looked like −₹54,067 instead of −₹28,749 → ~₹25k phantom COGS suppressed GP. The reconcile removed phantom expense; it did not create phantom profit.

## 9. Remaining issues

1. **462 negative-quantity stock rows** (MONSTER ENERGY −36, KINDER BUENO −24, etc.) — still distort per-product values; need stock-in entries or adjustments.
2. **Baseline drift continues** with every future cost change — by design. Anchor permanently by backfilling real `opening` ledger entries at migration costs.
3. The Sep-30 override (₹7,96,734.33) is a declared anchor — all displayed positions ride on it.
4. For audit-grade figures: physical stock count reconciliation.

## 10. How to run the reconcile on live

```bash
psql -d <live_db> -v dry_run=1 -f scripts/reconcile_stock.sql   # preview (rolls back)
psql -d <live_db> -f scripts/reconcile_stock.sql                # apply
```
Take a DB backup first. Snapshots rebuild automatically on next report read.

---

## 11. Prioritized work list

### P0 — Done this session
- [x] Patch restore-at-selling-price (3 sites) + orphan ledger entries on invoice delete
- [x] Reconcile script written, dry-run validated, applied on restored copy

### P1 — This week (correctness)
- [ ] **Deploy the patched backend to live** — fixes are dormant until deployed
- [ ] **Run reconcile script on live DB** (backup first; verify a report read afterwards)
- [ ] **Clear the 462 negative-quantity stock rows** — biggest distortion source. Order by value impact: MONSTER ENERGY −36, KINDER BUENO −24, NIPPO BATTERY BIG −23, CHOCO 250/- −12, INNACO JELLY −12, SWOOT MARSHMALLOW −9, WATCH 35 −8, BADAM CALIFORNIA −3 … Do a physical count, then stock-in/adjust to match reality
- [ ] **Guard `updateInventoryStock` WAC division**: when `prevQty <= 0`, set `average_cost = costPrice` directly — prevents cost explosions (₹25,000-type values) on negative/zero stock
- [ ] **Decide policy for insufficient stock at billing**: currently `pickFEFOBatch` falls back to whatever exists → overselling → negative rows. Either block/warn at invoice save, or accept negatives deliberately

### P2 — Structural (stop drift permanently)
- [ ] **Anchor history with real `opening` ledger entries at migration** (entry_type='opening', cost = migrated cost) so baseline → 0 and historical positions stop depending on live `average_cost`
- [ ] **Freeze day-close values**: serve historical days from `daily_stock_summary_log` (written once at 01:00) instead of live replay — reports become immutable per closed day
- [ ] **Purchase returns don't reduce live stock** (`ProcessPurchaseReturn` creates product-less entries, no `updateInventoryStock` call) — returned-to-vendor goods stay on hand. Wire product_id + stock deduction
- [ ] **`loadDailyProfitAggregates` / sales-return entry `cost_price`** stores sale price — harmless to snapshots now, but misleading in the ledger; consider storing cost
- [ ] **Re-check the Sep-30 override** (₹7,96,734.33): after cleanup, confirm it still reflects declared opening, or replace with real opening entries

### P3 — Hygiene / hardening
- [ ] Add unit tests: invoice edit/cancel/delete restores at cost-0, entries die with invoice
- [ ] Alert/metric when `|liveQty − ledgerNet|` grows per product (baseline drift detector)
- [ ] Product/batch cleanup: merge duplicate batch rows (`02/01/26` ×2), normalize batch names (`1`, `Batch #1`, `batch#3`…), fix messy product names
- [ ] Concurrency: `updateInventoryStock` has no row lock — concurrent sales can oversell; consider `SELECT … FOR UPDATE` or atomic updates
- [ ] Soft-deleted documents keep ledger entries elsewhere? Audit other reference_types (`sales_return`, `purchase_return`) for the same orphan pattern

---

## 12. Step-by-step rollout plan

### Step 0 — Safety (before anything touches live)
1. Take a full live DB backup: `pg_dump -Fc <live_db> > truerp_pre_reconcile_$(date +%F).dump`
2. Confirm the restored-copy reconcile numbers look sane (done — see §7).
3. Notify operators: reports will shift ~±5% on stock values after rebuild; that's the correction landing, not new data loss.

### Step 1 — Deploy the patched backend
1. Review diff: 4 hunks (`inventory.go` ×2, `sales_return.go`, `invoice.go`).
2. `go build ./... && go test ./controllers/` — already green locally.
3. Deploy to live; confirm version is running.

### Step 2 — Reconcile live data
1. Dry-run: `psql -d <live> -v dry_run=1 -f scripts/reconcile_stock.sql` → eyeball the Phase-2 table (every delta should land on a plausible purchase cost; nothing should look absurd).
2. Apply: `psql -d <live> -f scripts/reconcile_stock.sql`
3. Open the daily-profit report once (or wait for the 30-min snapshot sweep) → triggers rebuild.
4. Verify: Oct-1 opening should read ≈ ₹7,89,862.80 and `stock_snapshot_meta.rebuilt_at` should be fresh.

### Step 3 — Clean negative-quantity stock (manual, ~1–2 days)
1. Export the Phase-3 list sorted by value impact.
2. For each product: physical count → record actual on-hand.
3. Fix by merging fragmentation, not just adding stock:
   - If batches are a naming mess (`''`, `Batch #1`, `batch#3`, dates), consolidate to one batch per product, then adjust qty to physical count.
   - If batching matters, move stock into the real batch rows via adjustment entries.
4. Recheck: `SELECT count(*) FROM inventory_stocks WHERE quantity < 0` → should reach 0.

### Step 4 — Verify reports end-to-end
1. October P&L on live should match §7 (GP ≈ ₹1,12,775, Net ≈ ₹60,297).
2. Daily-profit report: every day's `opening == previous day's closing` (the original complaint).
3. Stock report per product: no absurd per-unit costs (nothing > max real purchase price).
4. Spot-check 3–5 products' `average_cost` against last purchase bill.

### Step 5 — Stop new negatives at the source
1. Add the WAC guard: `prevQty <= 0 → average_cost = costPrice` in `updateInventoryStock`.
2. Fix batch routing at billing: when item has no batch, deduct from the product's primary/'' consolidated row — never create a fresh negative row while stock exists under another batch.
3. Optional hard rule: warn/block invoice save when a product would go negative.

### Step 6 — Lock history (structural)
1. Serve closed days from `daily_stock_summary_log` (the 01:00 IST writer) — yesterday never recomputes.
2. Backfill `opening` ledger entries from migration data so baseline → 0.
3. Add drift monitor: alert when `|Σ liveQty − Σ ledgerNet|` per user changes between rebuilds.

### Step 7 — Regression safety
1. Unit tests: invoice edit/cancel/delete keeps `average_cost` unchanged and removes ledger rows.
2. Same-pattern audit for `sales_return`/`purchase_return` reference orphans.
3. Keep the Sep-30 override (₹7,96,734.33) until a physical count confirms the reconciled truth; then either adjust or replace with real opening entries.

### Sign-off checklist
- [ ] Live backup archived
- [ ] Patched binary deployed
- [ ] Reconcile applied + rebuild verified
- [ ] Zero negative-qty rows
- [ ] Opening=closing chain holds across October
- [ ] P&L numbers communicated to stakeholders
