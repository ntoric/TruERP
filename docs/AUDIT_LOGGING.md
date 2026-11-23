# Audit Logging

All data changes are captured automatically and persisted asynchronously —
logging never blocks the request that caused it.

## What is logged

GORM callbacks (`backend/services/audit/hooks.go`) intercept every
create/update/delete on the whitelisted tables and enqueue an `audit_logs`
entry containing:

- `action` — `create` / `update` / `delete`
- `entity_type`, `entity_id`, `entity_name` — the row that changed
- `previous_data` / `new_data` — full row snapshots as JSON (before/after)
- `changes` — per-field `{old, new}` diff for updates
- `changed_by_user_id` / `changed_by_name` — the authenticated user
- `ip_address`, `user_agent`, `request_id` — request context
- `user_id` — the data-scope owner (store owner) used for tenant filtering
- `status`, `error_message`, `created_at`

Covered modules: products/product categories, parties, inventory
(warehouses, stock entries, transfers), purchases (bills, orders, receipts,
returns), sales (invoices, returns, payments in/out, quotations, credit/debit
notes, delivery challans), expenses, cash & bank (transactions, accounts,
movements, reconciliations), profit distribution (partners), HR & payroll
(staff, attendance, payrolls, deductions, advances, extras), users/roles and
stores. Extend `auditedTables` in `hooks.go` to add more.

Sensitive columns (anything containing `password`, `secret`, `token`,
`api_key`, `private_key`) are stored as `[REDACTED]`.

## Who made the change

`middleware.AuthRequired` binds the authenticated actor (user, IP, request
ID) to the request goroutine; the hooks resolve the actor from that binding
(or from `audit.ContextWithActor` for code that uses `db.WithContext`).
Background work with no actor still logs, attributed to the row's `user_id`.

## Monthly shard tables

New entries are written to `audit_logs_YYYY_MM` for the entry's month, never
to the legacy `audit_logs` table (which remains for history and is still
included in all reads). Shards are created automatically:

- lazily on first insert of a month, and
- ahead of time by an hourly scheduler that pre-creates next month's table.

Postgres shards are cloned with `CREATE TABLE ... (LIKE audit_logs INCLUDING
ALL)`; SQLite shards reuse the base table's DDL plus equivalent indexes.

## Async pipeline

`audit.Start(db)` (called once in `main.go`) registers the hooks and starts
2 workers draining a 16k-entry buffered channel. Entries are batched (500
rows / 200 ms) and written with `CreateInBatches` grouped per month table —
the enqueue path is a non-blocking channel send; if the queue is full the
entry is dropped and counted (`queue_dropped` in `/audit/stats`). On
SIGINT/SIGTERM the queue is flushed before exit.

## Crash spool (restart durability)

`backend/services/audit/spool.go` adds a local append-only journal
(`data/audit_spool.jsonl`, override with `AUDIT_SPOOL_PATH`, disable with
`AUDIT_SPOOL_DISABLED=1`). Every entry is appended as a JSON line before the
channel send; committed entry IDs are acked by the workers and a compactor
rewrites the file without them (every 30 s, or once it exceeds 8 MiB, plus a
final pass at shutdown). On startup the file is replayed into the queue and
inserts use `ON CONFLICT DO NOTHING` on the entry UUID, so replays of
already-committed lines are harmless no-ops.

This survives process crashes, kills and restarts — including entries that
were only queued (never committed) and entries dropped under load. It does
not fsync per line, so a power loss could theoretically lose the last
unflushed bytes; that's the accepted trade-off for keeping writes cheap.

Reads (`GET /api/v1/audit/logs`, `/stats`, `/logs/export`, `/logs/:id`)
UNION ALL across `audit_logs` + existing shards; `from`/`to` filters narrow
the shard list. `DELETE /logs` deletes per-table with the same filters;
`CleanupOldAuditLogs` drops whole shards beyond the retention window.

For explicit, controller-level logging use `controllers.LogDataChange(c,
action, entityType, entityID, entityName, description, previous, newData)`
or the existing `CreateAuditLog(...)` — both enqueue asynchronously.

Known limitation: a change inside a transaction that later rolls back still
produces a log entry (the hooks fire per statement, not per commit).
