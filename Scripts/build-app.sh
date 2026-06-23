#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
PRODUCT_NAME="DailyReplica"
APP_DIR="$ROOT_DIR/.build/$PRODUCT_NAME.app"
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/clang-module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Daily Replica</string>
    <key>CFBundleExecutable</key>
    <string>DailyReplica</string>
    <key>CFBundleIdentifier</key>
    <string>local.daily-replica.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Daily Replica</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAccessibilityUsageDescription</key>
    <string>Daily Replica reads the focused window title to make your local activity timeline more useful.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Daily Replica reads the active Chrome tab URL locally so Chrome activity can be categorized by host.</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built $APP_DIR"
