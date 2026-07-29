#!/usr/bin/env bash
# Windows Tauri build (run on Windows or cross-compile with care).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

export GOOS=windows
export GOARCH=amd64

if [[ "${SKIP_FRONTEND:-0}" != "1" ]]; then
  ./scripts/prepare-frontend.sh
fi
./scripts/prepare-api.sh
./scripts/prepare-bundle.sh windows-x64

if [[ ! -d node_modules ]]; then
  npm install
fi

echo "==> Building Tauri app"
npm run build

echo "Done. Artifacts under src-tauri/target/release/bundle/"
