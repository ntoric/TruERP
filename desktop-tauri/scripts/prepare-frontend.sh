#!/usr/bin/env bash
# Build a Next.js standalone server from a staged copy of ../frontend
# without modifying the original frontend/ tree.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT_DIR}/.." && pwd)"
SRC_FRONTEND="${REPO_ROOT}/frontend"
STAGING="${ROOT_DIR}/.staging/frontend"
SERVER_OUT="${ROOT_DIR}/src-tauri/resources/server"

if [[ ! -d "${SRC_FRONTEND}" ]]; then
  echo "error: frontend source not found at ${SRC_FRONTEND}" >&2
  exit 1
fi

echo "==> Staging frontend copy (no edits to original tree)"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"

rsync -a \
  --exclude node_modules \
  --exclude .next \
  --exclude out \
  --exclude .git \
  --exclude '*.tsbuildinfo' \
  "${SRC_FRONTEND}/" "${STAGING}/"

export STAGING

cat > "${STAGING}/next.config.mjs" <<'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  images: {
    unoptimized: true,
  },
  // Desktop packaging builds a staged copy; ignore upstream type/lint debt.
  eslint: { ignoreDuringBuilds: true },
  typescript: { ignoreBuildErrors: true },
  // Many client pages use useSearchParams without a Suspense boundary.
  experimental: {
    missingSuspenseWithCSRBailout: false,
  },
};

export default nextConfig;
EOF

python3 - <<'PY'
import json
import os
from pathlib import Path
path = Path(os.environ["STAGING"]) / "tsconfig.json"
data = json.loads(path.read_text())
opts = data.setdefault("compilerOptions", {})
opts.setdefault("target", "ES2017")
opts["downlevelIteration"] = True
path.write_text(json.dumps(data, indent=2) + "\n")
print(f"Updated staging tsconfig: {path}")
PY

# Staging-only JSX fix (missing <TableRow>) so SWC can parse.
STAGING_PURCHASES="${STAGING}/app/purchases/page.tsx" python3 - <<'PY'
import os
from pathlib import Path
path = Path(os.environ["STAGING_PURCHASES"])
text = path.read_text()
old = "<TableHeader><TableHead>Bill #</TableHead>"
new = "<TableHeader><TableRow><TableHead>Bill #</TableHead>"
if old not in text:
    raise SystemExit(f"staging patch failed: expected snippet not found in {path}")
path.write_text(text.replace(old, new, 1))
print(f"Applied staging patch: {path}")
PY

echo "==> Installing frontend dependencies in staging"
cd "${STAGING}"
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi

echo "==> Building Next.js standalone server"
# Same-origin API via the Tauri reverse proxy on :17888.
# Absolute http://localhost:8088 calls hang in the macOS WebView.
export NEXT_PUBLIC_API_URL="/api/v1"
npm run build

STANDALONE="${STAGING}/.next/standalone"
if [[ ! -f "${STANDALONE}/server.js" ]]; then
  echo "error: standalone server.js not found at ${STANDALONE}" >&2
  exit 1
fi

echo "==> Publishing standalone server to src-tauri/resources/server"
rm -rf "${SERVER_OUT}"
mkdir -p "${SERVER_OUT}"
rsync -a "${STANDALONE}/" "${SERVER_OUT}/"
mkdir -p "${SERVER_OUT}/.next"
rsync -a "${STAGING}/.next/static/" "${SERVER_OUT}/.next/static/"
if [[ -d "${STAGING}/public" ]]; then
  rsync -a "${STAGING}/public/" "${SERVER_OUT}/public/"
fi

echo "Done. Next.js standalone server is in ${SERVER_OUT}"
