#!/usr/bin/env bash
# Prepare UI server + runtime bundle, then build a Windows NSIS installer via Wails.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

export PATH="$(go env GOPATH)/bin:${PATH}"

if ! command -v wails >/dev/null 2>&1; then
  echo "error: wails CLI not found. Install with: go install github.com/wailsapp/wails/v2/cmd/wails@latest" >&2
  exit 1
fi

PLATFORM="${1:-windows/amd64}"

echo "==> Preparing Next.js standalone UI"
./scripts/prepare-frontend.sh

echo "==> Preparing Windows runtime bundle (slim Node + server; no AI models)"
./scripts/prepare-bundle.sh windows-x64

echo "==> go mod tidy"
go mod tidy

echo "==> Building Wails app for ${PLATFORM} (stripped symbols)"
wails build -platform "${PLATFORM}" -nsis -ldflags "-s -w"

BIN_DIR="${ROOT_DIR}/build/bin"
if [[ -d "${BIN_DIR}" ]]; then
  echo "==> Copying runtime bundle beside executable(s) for portable use"
  rsync -a "${ROOT_DIR}/bundle/" "${BIN_DIR}/"
fi

echo
echo "Build complete."
echo "  Output directory: ${BIN_DIR}"
echo "  Expected install/portable layout:"
echo "    TruERP.exe"
echo "    server/          (Next.js standalone)"
echo "    node/            (portable Node.js)"
echo "    runtime/"
echo "    HSN_DATASET.csv"
echo "    (AI models are not included)"
