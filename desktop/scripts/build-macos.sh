#!/usr/bin/env bash
# Prepare UI server + runtime bundle, build TruERP.app, inject assets, create a DMG.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

export PATH="$(go env GOPATH)/bin:${PATH}"

if ! command -v wails >/dev/null 2>&1; then
  echo "error: wails CLI not found. Install with: go install github.com/wailsapp/wails/v2/cmd/wails@latest" >&2
  exit 1
fi

HOST_ARCH="$(uname -m)"
case "${HOST_ARCH}" in
  arm64|aarch64) DEFAULT_PLATFORM="darwin/arm64"; DEFAULT_NODE="darwin-arm64"; ARCH_LABEL="arm64" ;;
  x86_64)        DEFAULT_PLATFORM="darwin/amd64"; DEFAULT_NODE="darwin-x64";  ARCH_LABEL="amd64" ;;
  *)
    echo "error: unsupported host arch ${HOST_ARCH}" >&2
    exit 1
    ;;
esac

PLATFORM="${1:-${DEFAULT_PLATFORM}}"
case "${PLATFORM}" in
  darwin/arm64) NODE_TARGET="darwin-arm64"; ARCH_LABEL="arm64" ;;
  darwin/amd64) NODE_TARGET="darwin-x64";  ARCH_LABEL="amd64" ;;
  darwin/universal)
    NODE_TARGET="${DEFAULT_NODE}"
    ARCH_LABEL="universal"
    echo "note: universal binary will embed Node for host arch (${DEFAULT_NODE})"
    ;;
  *)
    echo "error: unsupported platform '${PLATFORM}' (use darwin/arm64, darwin/amd64, or darwin/universal)" >&2
    exit 1
    ;;
esac

PRODUCT_VERSION="$(python3 - <<'PY'
import json
from pathlib import Path
print(json.loads(Path("wails.json").read_text()).get("info", {}).get("productVersion", "1.0.0"))
PY
)"

if [[ "${SKIP_FRONTEND:-0}" != "1" ]]; then
  echo "==> Preparing Next.js standalone UI"
  ./scripts/prepare-frontend.sh
else
  echo "==> Skipping frontend prepare (SKIP_FRONTEND=1)"
  if [[ ! -f frontend/server/server.js ]]; then
    echo "error: frontend/server/server.js missing; run without SKIP_FRONTEND" >&2
    exit 1
  fi
fi

echo "==> Preparing macOS runtime bundle (slim Node + server; no AI models)"
./scripts/prepare-bundle.sh "${NODE_TARGET}"

echo "==> go mod tidy"
go mod tidy

BIN_DIR="${ROOT_DIR}/build/bin"
APP_PATH="${BIN_DIR}/TruERP.app"
MACOS_DIR="${APP_PATH}/Contents/MacOS"
RESOURCES_DIR="${APP_PATH}/Contents/Resources"

echo "==> Building Wails app for ${PLATFORM} (stripped symbols)"
# Keep Windows artifacts if present: only remove prior macOS app/dmg for this build.
rm -rf "${APP_PATH}" "${BIN_DIR}/TruERP-"*.dmg 2>/dev/null || true
# -s -w drops symbol/DWARF tables from the Go binary (~30-40% smaller).
wails build -platform "${PLATFORM}" -ldflags "-s -w"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: expected app bundle at ${APP_PATH}" >&2
  exit 1
fi

echo "==> Injecting runtime bundle into TruERP.app/Contents/Resources"
mkdir -p "${RESOURCES_DIR}"
# Remove any previous mistaken MacOS-side payload / leftover AI models from older builds.
rm -rf "${MACOS_DIR}/server" "${MACOS_DIR}/node" "${MACOS_DIR}/runtime" "${MACOS_DIR}/models" \
  "${MACOS_DIR}/HSN_DATASET.csv" "${MACOS_DIR}/data" \
  "${RESOURCES_DIR}/models" 2>/dev/null || true
rsync -a \
  --exclude '.DS_Store' \
  --exclude 'models' \
  "${ROOT_DIR}/bundle/" "${RESOURCES_DIR}/"
# Ensure AI model weights are never left in the app bundle.
rm -rf "${RESOURCES_DIR}/models"

# Ensure node binary is executable
if [[ -f "${RESOURCES_DIR}/node/bin/node" ]]; then
  chmod +x "${RESOURCES_DIR}/node/bin/node"
fi
chmod +x "${MACOS_DIR}/TruERP" 2>/dev/null || true

echo "==> Ad-hoc codesign after bundling resources"
# Sign only Mach-O binaries. Do not --deep the app (Next.js modules break deep sign).
# Do not use hardened runtime (--options runtime) on Node — it breaks V8 JIT/memory.
if [[ -f "${RESOURCES_DIR}/node/bin/node" ]]; then
  codesign --force --sign - "${RESOURCES_DIR}/node/bin/node"
fi
codesign --force --sign - "${MACOS_DIR}/TruERP"
codesign --force --sign - "${APP_PATH}"

DMG_NAME="TruERP-${PRODUCT_VERSION}-macos-${ARCH_LABEL}.dmg"
DMG_PATH="${BIN_DIR}/${DMG_NAME}"
STAGE="${BIN_DIR}/dmg-stage"

echo "==> Creating DMG ${DMG_NAME}"
rm -rf "${STAGE}" "${DMG_PATH}"
mkdir -p "${STAGE}"
# Copy app into stage (preserve bundle)
ditto "${APP_PATH}" "${STAGE}/TruERP.app"
ln -sf /Applications "${STAGE}/Applications"

hdiutil create \
  -volname "TruERP" \
  -srcfolder "${STAGE}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

rm -rf "${STAGE}"

echo
echo "Build complete."
echo "  App:  ${APP_PATH}"
echo "  DMG:  ${DMG_PATH}"
echo
echo "App layout:"
echo "  Contents/MacOS/TruERP"
echo "  Contents/Resources/server/"
echo "  Contents/Resources/node/"
echo "  Contents/Resources/runtime/"
echo "  Contents/Resources/HSN_DATASET.csv"
echo "  (AI models are not included)"
echo
echo "User data: ~/Library/Application Support/TruERP/"
echo "Install: open the DMG and drag TruERP.app to Applications."
