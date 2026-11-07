#!/bin/sh
# Compiles the Foundation-only engine model code with a tiny test runner.
# Works on macOS (Xcode toolchain) or Linux (swift.org toolchain).
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${TMPDIR:-/tmp}/gdm-logic-tests"
swiftc -o "$OUT" "$ROOT/GopeedMac/Engine/TaskStats.swift" "$ROOT/Tests/LogicTests/main.swift"
"$OUT" "$ROOT/Tests/Fixtures"
