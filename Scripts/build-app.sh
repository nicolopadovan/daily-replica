#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
PRODUCT_NAME="DailyReplica"
VERSION="${DAILY_REPLICA_VERSION:-0.1.1}"
BUILD_NUMBER="${DAILY_REPLICA_BUILD_NUMBER:-2}"
CODE_SIGN_IDENTITY="${DAILY_REPLICA_CODE_SIGN_IDENTITY:-}"
CODE_SIGN_TEAM_ID="${DAILY_REPLICA_CODE_SIGN_TEAM_ID:-}"
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

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
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
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
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

if [[ -n "$CODE_SIGN_IDENTITY" ]]; then
    if [[ -n "$CODE_SIGN_TEAM_ID" && "$CODE_SIGN_IDENTITY" != *"($CODE_SIGN_TEAM_ID)"* ]]; then
        echo "Refusing to sign: identity does not match team $CODE_SIGN_TEAM_ID" >&2
        exit 1
    fi

    xattr -cr "$APP_DIR" 2>/dev/null || true
    codesign --force --timestamp --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
    codesign --force --timestamp --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"

    if [[ -n "$CODE_SIGN_TEAM_ID" ]]; then
        SIGNED_TEAM_ID="$(codesign -dv --verbose=4 "$APP_DIR" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
        if [[ "$SIGNED_TEAM_ID" != "$CODE_SIGN_TEAM_ID" ]]; then
            echo "Refusing signed app: got team $SIGNED_TEAM_ID, expected $CODE_SIGN_TEAM_ID" >&2
            exit 1
        fi
    fi
fi

echo "Built $APP_DIR"
