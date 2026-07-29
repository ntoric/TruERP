# TruERP Desktop (Wails)

Desktop builds for **Windows** and **macOS**. Lives entirely under `desktop/` and does **not** modify the existing `backend/` or `frontend/` trees.

## Architecture

| Piece | How it runs |
|-------|-------------|
| Shell | Wails v2 (WebView2 on Windows, native WebView on macOS) |
| API | Same Go/Gin backend as `../backend`, in-process on `127.0.0.1:8088` |
| UI | Next.js **standalone** server on `127.0.0.1:3000` (staged copy of `../frontend`) |
| Node | Portable Node.js shipped inside the app (`node/`) |
| Data | Windows: `%AppData%\TruERP\` · macOS: `~/Library/Application Support/TruERP/` |

The WebView loads a splash page, then opens the local Next.js UI. API calls use existing frontend defaults (`http://localhost:8088`).

## Prerequisites

- Go 1.25+
- Node.js 18+ and npm (to *build* the UI; runtime Node is bundled)
- [Wails CLI v2](https://wails.io): `go install github.com/wailsapp/wails/v2/cmd/wails@latest`
- **Windows installer:** [NSIS](https://wails.io/docs/guides/windows-installer/) on the Windows build machine
- **macOS DMG:** run the macOS build on a Mac (`hdiutil`, `codesign`)

## Build macOS app + DMG

```bash
cd desktop
./scripts/build-macos.sh
```

Optional platform:

```bash
./scripts/build-macos.sh darwin/arm64      # Apple Silicon (default on M-series)
./scripts/build-macos.sh darwin/amd64      # Intel
./scripts/build-macos.sh darwin/universal  # universal binary (Node = host arch)
```

Faster rebuild when the UI server is already prepared:

```bash
SKIP_FRONTEND=1 ./scripts/build-macos.sh
```

Artifacts in `build/bin/`:

- `TruERP.app`
- `TruERP-<version>-macos-<arch>.dmg`

Install: open the DMG and drag **TruERP** into Applications.

## Build Windows installer

```powershell
cd desktop
.\scripts\build-windows.ps1
```

or:

```bash
cd desktop
./scripts/build-windows.sh windows/amd64
```

Artifacts in `build/bin/`:

- `TruERP.exe`
- `TruERP-amd64-installer.exe` (when NSIS is available)
- `server/`, `node/`, `runtime/`, `HSN_DATASET.csv`

## Manual steps

```bash
./scripts/prepare-frontend.sh

# macOS
./scripts/prepare-bundle.sh darwin-arm64   # or darwin-x64
wails build -platform darwin/arm64
# then copy bundle/* into TruERP.app/Contents/MacOS/

# Windows
./scripts/prepare-bundle.sh windows-x64
wails build -platform windows/amd64 -nsis
```

## Runtime layout

**macOS**

```
TruERP.app/Contents/MacOS/TruERP
TruERP.app/Contents/Resources/
  server/
  node/bin/node
  runtime/
  HSN_DATASET.csv
```

**Windows** (install / portable folder):

```
TruERP.exe
server/
node/node.exe
runtime/
HSN_DATASET.csv
```

AI embedding models (`models/`) are **not** packaged.

## Default admin

- Email: `admin@truerp.local`
- Password: `change-me-in-production`

Override with `SUPER_ADMIN_*` environment variables before launch if needed.

## Why is the package still tens of MB?

AI models are not included. Remaining size is mostly:

| Component | Approx size | Notes |
|-----------|-------------|--------|
| Portable Node.js | ~90 MB | Runs the Next.js UI server |
| `TruERP` binary | ~25–40 MB | Go API + Wails shell |
| Next.js `server/` | ~30 MB | UI standalone build |
| `HSN_DATASET.csv` | ~1 MB | HSN code list (not an AI model) |

## Printer support

Desktop builds expose OS printer APIs via Wails bindings:

- `ListPrinters` — installed printers (CUPS on macOS, Win32 on Windows)
- `PrintPDF` — print a real PDF page to a named/default printer (A4 or thermal size)

Invoices are rendered as PDF pages (not HTML). Configure **Settings → Print**: choose default mode (`thermal` or `A4`), paper size, thermal width (58/80mm), and optional named printers. Invoice **Print** and POS auto-print follow that config.

## Notes

- Staging copy lives in `desktop/.staging/` (gitignored). Next `output: 'standalone'` and small build fixes are applied only there.
- AI embedding models are never bundled in desktop builds.
- macOS builds are ad-hoc signed (`codesign -`). For Gatekeeper distribution, replace with your Developer ID certificate and notarize.
