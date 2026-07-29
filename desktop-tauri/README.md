# TruERP Desktop (Tauri)

Offline desktop builds for **Windows** and **macOS**. Lives entirely under `desktop-tauri/` and does **not** replace the existing Wails app in `desktop/`.

## Architecture

| Piece | How it runs |
|-------|-------------|
| Shell | Tauri 2 (WebView2 on Windows, WKWebView on macOS) |
| API | Go/Gin backend from `../backend`, spawned as a local binary on `127.0.0.1:8088` |
| UI | Next.js **standalone** server on `127.0.0.1:3000` |
| Proxy | Rust reverse proxy on `127.0.0.1:17888` (same-origin `/api/v1` for the WebView) |
| Node | Portable Node.js shipped in app resources |
| Data | Windows: `%AppData%\TruERP\` · macOS: `~/Library/Application Support/TruERP/` |

Works fully offline: SQLite + local uploads under the TruERP data directory. No cloud required.

## Prerequisites

- Rust (stable) + Cargo
- Go 1.25+
- Node.js 18+ and npm (to *build* the UI; runtime Node is bundled)
- [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/) for your OS

## Quick start (dev)

```bash
cd desktop-tauri
npm install

# One-time / when UI or API changes:
./scripts/prepare-frontend.sh   # or reuse ../desktop/frontend/server via prepare-bundle
./scripts/prepare-api.sh
./scripts/prepare-bundle.sh     # downloads portable Node for this machine

npm run dev
```

## Build macOS

```bash
cd desktop-tauri
./scripts/build-macos.sh
# or: SKIP_FRONTEND=1 ./scripts/build-macos.sh   # if server already prepared
```

Artifacts: `src-tauri/target/release/bundle/macos/` and `dmg/` when available.

## Build Windows

```bash
cd desktop-tauri
./scripts/build-windows.sh
```

## Runtime resources

Packaged under `src-tauri/resources/`:

```
bin/truerp-api[.exe]
server/                 # Next.js standalone
node/                   # portable Node
runtime/
HSN_DATASET.csv
```

AI embedding models (`models/`) are **not** packaged.

## Default admin

- Email: `admin@truerp.local`
- Password: `change-me-in-production`

Override with `SUPER_ADMIN_*` environment variables before launch if needed.

## Printer support

Tauri exposes the same desktop print surface the Wails app uses (via a Wails-compatible bridge):

- `ListPrinters` / `list_printers`
- `PrintPDF` / `print_pdf`
- `HasNativePrinting` / `has_native_printing`

Configure **Settings → Print** in the app as usual.

## Notes

- Staging copy lives in `desktop-tauri/.staging/` (gitignored).
- The original `frontend/` and `backend/` trees are not modified by these scripts.
- The Wails desktop app in `desktop/` remains available and unchanged.
