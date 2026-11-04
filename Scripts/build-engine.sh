#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST="$ROOT/engine/host"
OUT_DIR="$ROOT/GopeedMac/Frameworks"

mkdir -p "$OUT_DIR"
cd "$HOST"

if [[ ! -f go.sum ]]; then
  go mod tidy
fi

export MACOSX_DEPLOYMENT_TARGET=14.0
export CGO_CFLAGS="-mmacosx-version-min=14.0"
export CGO_LDFLAGS="-mmacosx-version-min=14.0"
CGO_ENABLED=1 go build -tags nosqlite -ldflags="-w -s" -buildmode=c-shared \
  -o "$OUT_DIR/libgopeed.dylib" .

install_name_tool -id @rpath/libgopeed.dylib "$OUT_DIR/libgopeed.dylib"
echo "Built $OUT_DIR/libgopeed.dylib"
