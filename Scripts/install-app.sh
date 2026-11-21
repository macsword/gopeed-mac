#!/bin/zsh
# Copies the built GDM.app into /Applications. Invoked as an Xcode post-build
# script so Cmd-B / Cmd-R always refresh the installed app.
set -euo pipefail

if [[ "${ENABLE_PREVIEWS:-NO}" == "YES" ]]; then
  exit 0
fi
if [[ "${ACTION:-build}" == "indexbuild" ]]; then
  exit 0
fi

src="${BUILT_PRODUCTS_DIR:-}/${FULL_PRODUCT_NAME:-GDM.app}"
dest="/Applications/${FULL_PRODUCT_NAME:-GDM.app}"

if [[ ! -d "$src" ]]; then
  echo "error: built app not found at $src" >&2
  exit 1
fi

if /usr/bin/pgrep -xq "GDM"; then
  /usr/bin/osascript -e 'tell application "GDM" to quit' >/dev/null 2>&1 || true
  for _ in {1..10}; do
    /usr/bin/pgrep -xq "GDM" || break
    sleep 0.2
  done
  /usr/bin/killall -9 GDM >/dev/null 2>&1 || true
fi

rm -rf "$dest"
/usr/bin/ditto "$src" "$dest"
/usr/bin/touch "$dest"
echo "Installed $dest"
