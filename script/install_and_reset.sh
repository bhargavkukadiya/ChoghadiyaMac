#!/usr/bin/env bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_APP_NAME="Choghadiya.app"
DEST_PATH="/Applications/$TARGET_APP_NAME"
BUNDLE_ID="com.choghadiya.ChoghadiyaMacApp"
WIDGET_BUNDLE_ID="com.choghadiya.ChoghadiyaMacApp.ChoghadiyaWidget"
APP_GROUP_ID="group.com.choghadiya.mac"

# This maintenance tool intentionally clears user data. Require explicit consent
# before building, stopping processes, replacing installations, or resetting data.
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 --reset-data"
        echo "Replaces Choghadiya installations, deletes saved app/widget data,"
        echo "and restarts NotificationCenter and the widget daemon."
        exit 0
        ;;
    --reset-data)
        if [[ $# -ne 1 ]]; then
            echo "Usage: $0 --reset-data" >&2
            exit 2
        fi
        ;;
    *)
        echo "This script deletes saved Choghadiya app/widget data and replaces installed copies." >&2
        echo "Run '$0 --help' for details, or pass --reset-data to proceed." >&2
        exit 2
        ;;
esac

echo "=== Preflight: Building fresh Release bundle with XcodeGen & xcodebuild ==="
cd "$TASK_ROOT"
xcodegen generate
xcodebuild -project ChoghadiyaMac.xcodeproj -scheme ChoghadiyaMacApp \
    -destination 'platform=macOS' \
    -configuration Release \
    -derivedDataPath build/Install \
    clean build CODE_SIGNING_ALLOWED=NO

BUILT_APP="$TASK_ROOT/build/Install/Build/Products/Release/ChoghadiyaMacApp.app"
if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at $BUILT_APP" >&2
    exit 1
fi

echo "=== Preflight: Code signing app and widget extension ==="
BUILT_WIDGET="$BUILT_APP/Contents/PlugIns/ChoghadiyaWidget.appex"
codesign -s - -f --entitlements "$TASK_ROOT/Widget/Resources/Widget.entitlements" "$BUILT_WIDGET"
codesign -s - -f --entitlements "$TASK_ROOT/App/Resources/App.entitlements" "$BUILT_APP"
xattr -cr "$BUILT_APP"

codesign --verify --deep --strict "$BUILT_APP"

echo "=== 1. Terminating running processes ==="
pkill -9 -x ChoghadiyaMacApp 2>/dev/null || true
pkill -9 -x Choghadiya 2>/dev/null || true
pkill -9 -f ChoghadiyaWidget 2>/dev/null || true

echo "=== 2. Unregistering existing app and widget from LaunchServices & PlugInKit ==="
if [ -d "$DEST_PATH" ]; then
    /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "$DEST_PATH" 2>/dev/null || true
    pluginkit -r "$DEST_PATH/Contents/PlugIns/ChoghadiyaWidget.appex" 2>/dev/null || true
fi
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -u "/Applications/ChoghadiyaMacApp.app" 2>/dev/null || true
pluginkit -r "/Applications/ChoghadiyaMacApp.app/Contents/PlugIns/ChoghadiyaWidget.appex" 2>/dev/null || true

echo "=== 3. Removing existing installed app bundles ==="
rm -rf "$DEST_PATH"
rm -rf "/Applications/ChoghadiyaMacApp.app"
rm -rf "$HOME/Applications/$TARGET_APP_NAME"
rm -rf "$HOME/Applications/ChoghadiyaMacApp.app"

echo "=== 4. Resetting widget & app data, containers, preferences, and caches ==="
defaults delete "$BUNDLE_ID" 2>/dev/null || true
defaults delete "$WIDGET_BUNDLE_ID" 2>/dev/null || true
defaults delete "$APP_GROUP_ID" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$WIDGET_BUNDLE_ID.plist" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$APP_GROUP_ID.plist" 2>/dev/null || true

# Clean Sandbox Container Data for App
for subdir in "Preferences" "Caches" "Application Support" "Saved Application State" "HTTPStorages" "WebKit"; do
    rm -rf "$HOME/Library/Containers/$BUNDLE_ID/Data/Library/$subdir"/* 2>/dev/null || true
    rm -rf "$HOME/Library/Containers/$WIDGET_BUNDLE_ID/Data/Library/$subdir"/* 2>/dev/null || true
done
rm -rf "$HOME/Library/Containers/$BUNDLE_ID/Data/tmp"/* 2>/dev/null || true
rm -rf "$HOME/Library/Containers/$WIDGET_BUNDLE_ID/Data/tmp"/* 2>/dev/null || true
rm -rf "$HOME/Library/Containers/$BUNDLE_ID/Data/Documents"/* 2>/dev/null || true
rm -rf "$HOME/Library/Containers/$WIDGET_BUNDLE_ID/Data/Documents"/* 2>/dev/null || true

# Clean App Group Shared Container
if [ -d "$HOME/Library/Group Containers/$APP_GROUP_ID" ]; then
    rm -rf "$HOME/Library/Group Containers/$APP_GROUP_ID"/* 2>/dev/null || true
    rm -rf "$HOME/Library/Group Containers/$APP_GROUP_ID" 2>/dev/null || true
fi

echo "=== 5. Resetting WidgetKit / NotificationCenter subsystems ==="
killall -9 chronod 2>/dev/null || true
killall -9 NotificationCenter 2>/dev/null || true

echo "=== 7. Installing app to $DEST_PATH ==="
cp -R "$BUILT_APP" "$DEST_PATH"

WIDGET_PATH="$DEST_PATH/Contents/PlugIns/ChoghadiyaWidget.appex"

echo "=== 9. Registering with LaunchServices and PlugInKit ==="
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$DEST_PATH"
pluginkit -a "$WIDGET_PATH"
pluginkit -e use -i "$WIDGET_BUNDLE_ID"

echo "=== 10. Restarting widget daemon to reload new widget ==="
killall -9 chronod 2>/dev/null || true
killall -9 NotificationCenter 2>/dev/null || true

echo "=== 11. Launching installed app ==="
/usr/bin/open "$DEST_PATH"

echo "=== App installation and widget reset completed successfully! ==="
