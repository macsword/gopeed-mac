#!/bin/zsh
# Packages GDM.app into dist/GDM.zip for GitHub Releases.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"

echo "▶ Building Release configuration…"
xcodebuild \
  -project "$ROOT/GopeedMac.xcodeproj" \
  -scheme GopeedMac \
  -destination 'platform=macOS' \
  -configuration Release \
  ONLY_ACTIVE_ARCH=YES ARCHS=arm64 \
  build 2>&1 | grep -E '(error:|warning:|BUILD SUCCEEDED|BUILD FAILED|note:)' || true

DERIVED=$(ls -dt ~/Library/Developer/Xcode/DerivedData/GopeedMac-*/Build/Products/Release/GDM.app 2>/dev/null | head -1)
if [[ -z "$DERIVED" ]]; then
  echo "error: could not find built GDM.app in DerivedData" >&2
  exit 1
fi

mkdir -p "$DIST"
rm -f "$DIST/GDM.zip"

echo "▶ Packaging $DERIVED → $DIST/GDM.zip…"
/usr/bin/ditto -c -k --keepParent "$DERIVED" "$DIST/GDM.zip"

SIZE=$(du -h "$DIST/GDM.zip" | cut -f1)
echo "✅ Packaged: $DIST/GDM.zip ($SIZE)"
echo ""
echo "To publish a release on GitHub:"
echo "  gh release create v0.2.0 dist/GDM.zip --title \"v0.2.0\" --generate-notes"
echo "Or upload dist/GDM.zip at: https://github.com/macsword/gopeed-mac/releases/new"
