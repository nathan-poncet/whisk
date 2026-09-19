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

# The image is signed like the app inside it when a Developer ID is at
# hand, so Gatekeeper can vouch for the download as a whole.
IDENTITY="${CODESIGN_IDENTITY:--}"
if [ "$IDENTITY" != "-" ]; then
  codesign --force --timestamp --sign "$IDENTITY" dist/Whisk.dmg
fi
echo "built dist/Whisk.dmg (identity: $IDENTITY)"
