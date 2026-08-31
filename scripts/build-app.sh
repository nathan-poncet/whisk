#!/usr/bin/env bash
# Builds dist/Whisk.app.
#   scripts/build-app.sh [version] [native|universal]
set -euo pipefail

VERSION="${1:-0.0.0}"
ARCH="${2:-native}"

if [ "$ARCH" = "universal" ]; then
  swift build -c release --arch arm64 --arch x86_64
  BINARY=".build/apple/Products/Release/Whisk"
else
  swift build -c release
  BINARY=".build/release/Whisk"
fi

APP="dist/Whisk.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/Whisk"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Whisk</string>
    <key>CFBundleDisplayName</key>
    <string>Whisk</string>
    <key>CFBundleIdentifier</key>
    <string>com.nathanponcet.whisk</string>
    <key>CFBundleExecutable</key>
    <string>Whisk</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© Nathan Poncet — MIT License</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "built $APP (version $VERSION, $ARCH)"
