#!/usr/bin/env bash
# Build the Go API as a sidecar binary for the Tauri shell.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
BACKEND="${REPO_ROOT}/backend"
OUT_DIR="${ROOT_DIR}/src-tauri/resources/bin"

if [[ ! -d "${BACKEND}" ]]; then
  echo "error: backend not found at ${BACKEND}" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

GOOS="${GOOS:-$(go env GOOS)}"
GOARCH="${GOARCH:-$(go env GOARCH)}"
EXT=""
if [[ "${GOOS}" == "windows" ]]; then
  EXT=".exe"
fi

OUT="${OUT_DIR}/truerp-api${EXT}"
echo "==> Building TruERP API for ${GOOS}/${GOARCH} -> ${OUT}"
(
  cd "${BACKEND}"
  CGO_ENABLED="${CGO_ENABLED:-1}" GOOS="${GOOS}" GOARCH="${GOARCH}" \
    go build -trimpath -ldflags="-s -w" -o "${OUT}" .
)
chmod +x "${OUT}" || true
echo "Done. API binary: ${OUT}"
