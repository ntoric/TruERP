#!/usr/bin/env bash
# Stage install payload: slim Node.js + Next standalone.
# AI embedding models are intentionally never bundled.
#
# Env:
#   NODE_VERSION   Default 20.18.1
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
BUNDLE_DIR="${ROOT_DIR}/bundle"
NODE_VERSION="${NODE_VERSION:-20.18.1}"
TARGET="${1:-windows-x64}"

rm -rf "${BUNDLE_DIR}"
mkdir -p "${BUNDLE_DIR}/runtime" "${BUNDLE_DIR}/data" "${BUNDLE_DIR}/node"

slim_nodejs() {
  local root="$1"
  local os="$2" # windows|darwin

  echo "==> Slimming Node.js runtime (drop headers, npm, docs)"
  if [[ "${os}" == "windows" ]]; then
    if [[ -f "${root}/node.exe" ]]; then
      mkdir -p "${BUNDLE_DIR}/node"
      cp "${root}/node.exe" "${BUNDLE_DIR}/node/node.exe"
      [[ -f "${root}/LICENSE" ]] && cp "${root}/LICENSE" "${BUNDLE_DIR}/node/LICENSE"
    else
      rsync -a "${root}/" "${BUNDLE_DIR}/node/"
    fi
  else
    mkdir -p "${BUNDLE_DIR}/node/bin"
    cp "${root}/bin/node" "${BUNDLE_DIR}/node/bin/node"
    chmod +x "${BUNDLE_DIR}/node/bin/node"
    [[ -f "${root}/LICENSE" ]] && cp "${root}/LICENSE" "${BUNDLE_DIR}/node/LICENSE"
  fi
}

echo "==> AI models are not packaged (by design)"

if [[ -f "${REPO_ROOT}/HSN_DATASET.csv" ]]; then
  echo "==> Copying HSN_DATASET.csv"
  cp "${REPO_ROOT}/HSN_DATASET.csv" "${BUNDLE_DIR}/HSN_DATASET.csv"
else
  echo "warning: HSN_DATASET.csv not found"
fi

: > "${BUNDLE_DIR}/runtime/.keep"

echo "==> Fetching portable Node.js ${NODE_VERSION} (${TARGET})"
TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

case "${TARGET}" in
  windows-x64|windows/amd64)
    ARCHIVE="node-v${NODE_VERSION}-win-x64.zip"
    URL="https://nodejs.org/dist/v${NODE_VERSION}/${ARCHIVE}"
    curl -fsSL "${URL}" -o "${TMP_DIR}/${ARCHIVE}"
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "${TMP_DIR}/${ARCHIVE}" -d "${TMP_DIR}"
    else
      python3 - <<PY
import zipfile
zipfile.ZipFile("${TMP_DIR}/${ARCHIVE}").extractall("${TMP_DIR}")
PY
    fi
    slim_nodejs "${TMP_DIR}/node-v${NODE_VERSION}-win-x64" windows
    ;;
  darwin-arm64)
    ARCHIVE="node-v${NODE_VERSION}-darwin-arm64.tar.gz"
    URL="https://nodejs.org/dist/v${NODE_VERSION}/${ARCHIVE}"
    curl -fsSL "${URL}" -o "${TMP_DIR}/${ARCHIVE}"
    tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"
    slim_nodejs "${TMP_DIR}/node-v${NODE_VERSION}-darwin-arm64" darwin
    ;;
  darwin-x64)
    ARCHIVE="node-v${NODE_VERSION}-darwin-x64.tar.gz"
    URL="https://nodejs.org/dist/v${NODE_VERSION}/${ARCHIVE}"
    curl -fsSL "${URL}" -o "${TMP_DIR}/${ARCHIVE}"
    tar -xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"
    slim_nodejs "${TMP_DIR}/node-v${NODE_VERSION}-darwin-x64" darwin
    ;;
  skip-node)
    echo "Skipping Node download (will use system node)"
    ;;
  *)
    echo "error: unsupported target '${TARGET}' (use windows-x64, darwin-arm64, darwin-x64, skip-node)" >&2
    exit 1
    ;;
esac

if [[ -f "${ROOT_DIR}/frontend/server/server.js" ]]; then
  echo "==> Copying frontend/server into bundle"
  mkdir -p "${BUNDLE_DIR}/server"
  rsync -a \
    --exclude '.DS_Store' \
    --exclude 'node_modules/next/dist/esm' \
    --exclude 'node_modules/next/dist/compiled/*/LICENSE' \
    "${ROOT_DIR}/frontend/server/" "${BUNDLE_DIR}/server/"
else
  echo "warning: frontend/server missing — run ./scripts/prepare-frontend.sh first"
fi

echo "==> Bundle size summary"
du -sh "${BUNDLE_DIR}" "${BUNDLE_DIR}"/* 2>/dev/null | sort -hr || true
echo "Bundle staged at ${BUNDLE_DIR}"
