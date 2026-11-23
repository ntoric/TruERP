# Sales Value Definitions — why report figures don't match invoice stats

Different screens report different "sales" numbers. This is intentional —
they measure different things. This doc records the definitions and how to
reconcile them.

## The two figures

### Invoices page — "Total Sales" stat card

`GET /invoices/stats` → `total_sales` = `SUM(invoices.total_amount)` over
non-cancelled invoices in the `from`/`to` date range (`DATE(date)` bounds).

- Backend: `backend/controllers/invoice.go` → `GetInvoiceStats`,
  `invoiceListFilters`
- Frontend: `frontend/app/(app)/invoices/page.tsx`

`total_amount` is the invoice **grand total**, computed at save time as:

```
total_amount = sub_total            -- Σ qty × unit_price (gross)
             − discount_total       -- line-item discounts
             + tax_total            -- CGST + SGST + IGST (0 under tax-free billing)
             − invoice_discount     -- invoice-level discount
             − loyalty_discount     -- loyalty points redemption (create path)
             + additional_charges   -- freight, packing, etc.
             + round_off            -- rounding to nearest rupee/2dp
```

### Bill-wise Profit report — "Sale value" card / column

`GET /reports/billwise-profit` → `sale_amount` = per bill,
`Σ items (qty × unit_price × (1 − item_discount/100))` — the **taxable line
value only**.

- Backend: `backend/controllers/billwise_profit_report.go` → `loadBillwiseProfitReport`
- Frontend: `frontend/app/(app)/reports/billwise-profit/page.tsx`

Excluded from sale value (shown separately or only used in profit calc):

- invoice-level + loyalty discounts → shown as `Discount`
- sales returns / credit notes → shown as `Returns` (netted only for profit/margin)
- tax, additional charges, round-off → not part of the profit report at all

## Reconciliation

For the same date range and user, with no data issues:

```
stats.total_sales = report.sale_amount
                  + tax_total
                  + additional_charges
                  + round_off
                  − invoice_discount
                  − loyalty_discount
```

Both queries filter the **same invoice set**: `user_id = ?`,
`status != 'cancelled'`, `DATE(date)` within range, soft-deletes excluded
(drafts are included in both). A mismatch therefore always reduces to the
amount components above — or to a UI filter (e.g. report `search`/`party_id`).

Equivalent per-invoice check: `sale_amount` equals `sub_total − discount_total`.

## Verified example — local DB, 2026-10-01

| user | Sale value | + addl charges | − invoice disc | + round off | = Total Sales |
|---|---|---|---|---|---|
| `3f0be372…` | 7,966.20 | +549.99 | −47.00 | +1.81 | 8,471.00 |
| `e13ace7a…` | 3,767.50 | +62.00 | −58.00 | +0.50 | 3,772.00 |

Debug query:

```sql
SELECT i.user_id,
       sum(i.total_amount) AS stats_total_sales,
       sum(ii.quantity * ii.unit_price * (1 - ii.discount/100)) AS report_sale_value,
       sum(i.tax_total) AS tax, sum(i.invoice_discount) AS inv_disc,
       sum(i.loyalty_discount) AS loyal_disc,
       sum(i.additional_charges) AS addl, sum(i.round_off) AS ro
FROM invoices i
JOIN invoice_items ii ON ii.invoice_id = i.id
WHERE i.deleted_at IS NULL AND i.status <> 'cancelled'
  AND i.date::date = 'YYYY-MM-DD'
GROUP BY i.user_id;
```
