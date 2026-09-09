# MyBillBook → TruERP Migration — Implementation Status

Tracking file. Updated after each completed task. See `MIGRATION_REPORT.md` for the full plan.

Legend: [ ] pending · [~] in progress · [x] done · [!] blocked

## Backend

- [x] 1. Add `SourceURL` + `SourceHTMLURL` fields to `PurchaseBill` model + AutoMigrate (models.go:654-661; AutoMigrate picks up via existing `allApplicationModels`)
- [x] 2. Parties CSV importer (`POST /api/v1/parties/import/csv`) — controllers/migration.go `ImportPartiesCSV`
- [x] 3. Purchase bills CSV importer (`POST /api/v1/purchase/bills/import/csv`) — `ImportPurchaseBillsCSV` (stores SourceURL, optional HTML snapshot, dedupes by link)
- [x] 4. Payments CSV importer (`POST /api/v1/payments/import/csv`) — `ImportPaymentsCSV` (splits multi-invoice payments, links to invoices/purchase bills, updates balances)
- [x] 5. Expenses CSV importer (`POST /api/v1/expenses/import/csv`) — `ImportExpensesCSV` (creates expense categories on demand)
- [x] 6. myBillBook ZIP orchestrator (`POST /api/v1/migration/mybillbook`) — `MigrateMyBillBookZIP` (preamble-stripping parser, vendor-hint derivation, optional HTML snapshot via `snapshot_html` form field)
- [x] 7. Download-source endpoint (`POST /api/v1/purchase/bills/download-source`) — `DownloadSourcePurchaseBills` (chromedp PDF render → ZIP, concurrency-limited, _skipped.csv manifest)
- [x] 8. Wire all new routes in `routes/routes.go` (parties, payments, expenses, purchase bills import + download-source, migration/mybillbook)
- [x] 9. Add `chromedp` + `cdproto` dependencies to `go.mod` (also added `UploadBytes` to StorageService interface + Local/S3 impls)
- [x] 10. `go build` / `go vet` / `go test` pass (only pre-existing sqlite/email vet warnings remain)

## Frontend

- [x] 11. Purchase invoices list — "Open source" / "Download source" row actions + bulk "Download Source" button (purchase-invoices/page.tsx)
- [x] 12. Purchase invoices view — "Source document" section with original link + stored HTML snapshot (purchase-invoices/view/page.tsx)
- [x] 13. Migration upload page — upload ZIP, optional `snapshot_html`, run orchestrator, per-step counts + collapsible row errors (migration/page.tsx); nav entry "Data Migration" added
- [x] 14. `tsc` / `npm run build` — my files compile with zero errors. The repo build fails on a **pre-existing** error in `app/(app)/attendance/page.tsx:245` (Set spread vs tsconfig target) that exists on `main` before any of my changes (verified via `git stash` baseline build). None of the migration/purchase-invoices/nav-config files produce type errors.

## Notes

- CSVs in `exports/` are **samples**; importers are data-agnostic (parse by header name, strip myBillBook preamble).
- Purchase links (`https://mybillbook.in/cpp/<id>`) resolve to a React SPA HTML page, not a direct PDF. Download feature uses chromedp to render → PDF, plus an HTML snapshot stored via the storage service during migration (when `snapshot_html=true`).
- `go.mod` go directive bumped 1.25.4 → 1.26 (required by `github.com/chromedp/cdproto`).
- chromedp requires Chromium/Chrome installed on the host running the backend. The download endpoint returns a `_skipped.csv` manifest listing any bills it could not render.
