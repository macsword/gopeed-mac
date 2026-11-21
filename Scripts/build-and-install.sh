#!/bin/zsh
# Builds GDM and installs it to /Applications. Run after every code change.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "▶ Building GDM…"
xcodebuild \
  -project "$ROOT/GopeedMac.xcodeproj" \
  -scheme GopeedMac \
  -destination 'platform=macOS' \
  -configuration Release \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 \
  build 2>&1 | grep -E '(error:|warning:|BUILD SUCCEEDED|BUILD FAILED|Installed|note:)' || true

DERIVED=$(ls -dt ~/Library/Developer/Xcode/DerivedData/GopeedMac-*/Build/Products/Release/GDM.app 2>/dev/null | head -1)
if [[ -z "$DERIVED" ]]; then
  echo "error: could not find built GDM.app in DerivedData" >&2
  exit 1
fi

echo "▶ Installing $DERIVED → /Applications/GDM.app"

if /usr/bin/pgrep -xq "GDM"; then
  /usr/bin/osascript -e 'tell application "GDM" to quit' >/dev/null 2>&1 || true
  for _ in {1..10}; do
    /usr/bin/pgrep -xq "GDM" || break
    sleep 0.2
  done
  /usr/bin/killall -9 GDM >/dev/null 2>&1 || true
fi

rm -rf "/Applications/GDM.app"
/usr/bin/ditto "$DERIVED" "/Applications/GDM.app"
/usr/bin/touch "/Applications/GDM.app"
echo "✅ GDM.app installed — $(stat -f '%Sm' /Applications/GDM.app)"
