#!/usr/bin/env bash
# Packages dist/Whisk.app into dist/Whisk.dmg with an /Applications
# shortcut. The asset name stays version-less so the GitHub
# releases/latest/download URL is permanent.
set -euo pipefail

APP="dist/Whisk.app"
if [ ! -d "$APP" ]; then
  echo "error: $APP not found — run scripts/build-app.sh first" >&2
  exit 1
fi

STAGE="dist/dmg-stage"
rm -rf "$STAGE" dist/Whisk.dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "Whisk" \
  -srcfolder "$STAGE" \
  -format UDZO \
  -ov \
  "dist/Whisk.dmg" \
  -quiet

rm -rf "$STAGE"
echo "built dist/Whisk.dmg"
