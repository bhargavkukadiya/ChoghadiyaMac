#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# create_dmg.sh - Build and Package Drag-and-Drop macOS Disk Image (.dmg)
# ==============================================================================

TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TASK_ROOT"

# Determine Version (argument, git tag, or plist value)
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    VERSION=$(git describe --tags --exact-match 2>/dev/null || true)
fi
if [ -z "$VERSION" ]; then
    VERSION=$(defaults read "$TASK_ROOT/App/Resources/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0.1")
fi
# Strip leading 'v' if present for filename consistency
VERSION="${VERSION#v}"

APP_NAME="Choghadiya"
DMG_NAME="Choghadiya-${VERSION}.dmg"
BUILD_DIR="$TASK_ROOT/build/Release"
OUTPUT_DIR="$TASK_ROOT/build/Artifacts"
STAGING_DIR="$TASK_ROOT/build/DMG_Staging"

echo "=== 1. Building Release bundle for ${APP_NAME} v${VERSION} ==="
mkdir -p "$OUTPUT_DIR"
rm -rf "$STAGING_DIR"

xcodebuild -project ChoghadiyaMac.xcodeproj \
    -scheme ChoghadiyaMacApp \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -onlyUsePackageVersionsFromResolvedFile \
    clean build CODE_SIGNING_ALLOWED=NO

BUILT_APP="$BUILD_DIR/Build/Products/Release/ChoghadiyaMacApp.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at $BUILT_APP" >&2
    exit 1
fi

echo "=== 2. Ad-hoc code signing app and widget extension ==="
BUILT_WIDGET="$BUILT_APP/Contents/PlugIns/ChoghadiyaWidget.appex"

if [ -d "$BUILT_WIDGET" ]; then
    codesign -s - -f --entitlements "$TASK_ROOT/Widget/Resources/Widget.entitlements" "$BUILT_WIDGET"
fi
codesign -s - -f --entitlements "$TASK_ROOT/App/Resources/App.entitlements" "$BUILT_APP"
xattr -cr "$BUILT_APP"

echo "Verifying code signature:"
codesign --verify --deep --strict "$BUILT_APP"

echo "=== 3. Preparing DMG staging directory ==="
mkdir -p "$STAGING_DIR"
# Copy as friendly user-facing name "Choghadiya.app"
cp -R "$BUILT_APP" "$STAGING_DIR/${APP_NAME}.app"
# Create symlink to /Applications for standard drag-and-drop installer
ln -s /Applications "$STAGING_DIR/Applications"

echo "=== 4. Creating compressed DMG image with hdiutil ==="
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "=== 5. Generating SHA256 checksum ==="
cd "$OUTPUT_DIR"
shasum -a 256 "$DMG_NAME" > "${DMG_NAME}.sha256"

# Cleanup staging
rm -rf "$STAGING_DIR"

echo "=== Build and packaging completed successfully! ==="
echo "DMG File:     $DMG_PATH"
echo "Checksum File: ${DMG_PATH}.sha256"
echo "Checksum:     $(cat "${DMG_NAME}.sha256")"
