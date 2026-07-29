#!/usr/bin/env bash
# Full macOS Tauri build for TruERP.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

PLATFORM="${1:-}"
case "${PLATFORM}" in
  ""|darwin/arm64|darwin-arm64)
    NODE_TARGET="darwin-arm64"
    ;;
  darwin/amd64|darwin/x64|darwin-x64)
    NODE_TARGET="darwin-x64"
    export GOARCH=amd64
    ;;
  *)
    echo "usage: $0 [darwin/arm64|darwin/amd64]" >&2
    exit 1
    ;;
esac

if [[ "${SKIP_FRONTEND:-0}" != "1" ]]; then
  ./scripts/prepare-frontend.sh
fi
./scripts/prepare-api.sh
./scripts/prepare-bundle.sh "${NODE_TARGET}"

if [[ ! -d node_modules ]]; then
  npm install
fi

echo "==> Building Tauri app"
npm run build

echo "Done. Artifacts under src-tauri/target/release/bundle/"
