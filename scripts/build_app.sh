#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "==> Building NetPulse (Release configuration)..."
swift build -c release

APP_DIR="build/NetPulse.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Constructing NetPulse.app bundle..."
rm -rf "build"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp ".build/release/NetPulse" "$MACOS_DIR/NetPulse"
chmod +x "$MACOS_DIR/NetPulse"

# Copy Info.plist and PkgInfo
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy Icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "==> Signing application bundle (ad-hoc)..."
codesign --force --deep --sign - \
    --entitlements "Resources/NetPulse.entitlements" \
    "$APP_DIR"

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

VERSION="1.3.0"

echo "==> Packaging ZIP archive..."
(cd build && zip -r -y "NetPulse-${VERSION}.zip" "NetPulse.app")

echo "==> Packaging DMG disk image..."
DMG_STAGING="build/dmg_staging"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "NetPulse" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "build/NetPulse-${VERSION}.dmg"

rm -rf "$DMG_STAGING"

echo "==> Success! Artifacts created in build/:"
ls -lh build/
