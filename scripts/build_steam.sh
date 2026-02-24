#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -W 2>/dev/null || pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -W 2>/dev/null || pwd)"

echo "==> Building finzy for Steam (Docker)..."
MSYS_NO_PATHCONV=1 docker build \
  --platform linux/amd64 \
  -f "$PROJECT_ROOT/scripts/steam.Dockerfile" \
  -t finzy-steam-build \
  "$PROJECT_ROOT"

echo "==> Extracting tarball..."
MSYS_NO_PATHCONV=1 docker create --name finzy-steam-extract finzy-steam-build true 2>/dev/null \
  || { docker rm finzy-steam-extract 2>/dev/null; MSYS_NO_PATHCONV=1 docker create --name finzy-steam-extract finzy-steam-build true; }
MSYS_NO_PATHCONV=1 docker cp finzy-steam-extract:/app/finzy-steam-linux-x64.tar.gz "$PROJECT_ROOT/"
docker rm finzy-steam-extract

echo "==> Output: finzy-steam-linux-x64.tar.gz"
