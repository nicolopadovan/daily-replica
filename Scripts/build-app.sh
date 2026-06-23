#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: bash Scripts/build-app.sh [debug|release]

Builds DailyReplica.app at .build/DailyReplica.app.

Environment variables:
  DAILY_REPLICA_VERSION             CFBundleShortVersionString (default: 0.1.1)
  DAILY_REPLICA_BUILD_NUMBER        CFBundleVersion integer (default: 2)
  DAILY_REPLICA_CODE_SIGN_IDENTITY  Optional codesign identity
  DAILY_REPLICA_CODE_SIGN_TEAM_ID   Optional expected Apple team identifier
USAGE
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
PRODUCT_NAME="DailyReplica"
VERSION="${DAILY_REPLICA_VERSION:-0.1.1}"
BUILD_NUMBER="${DAILY_REPLICA_BUILD_NUMBER:-2}"
CODE_SIGN_IDENTITY="${DAILY_REPLICA_CODE_SIGN_IDENTITY:-}"
CODE_SIGN_TEAM_ID="${DAILY_REPLICA_CODE_SIGN_TEAM_ID:-}"
APP_DIR="$ROOT_DIR/.build/$PRODUCT_NAME.app"
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME"
INFO_PLIST_TEMPLATE="$ROOT_DIR/Sources/DailyReplica/Resources/Info.plist"

case "$CONFIGURATION" in
    -h|--help)
        usage
        exit 0
        ;;
    debug|release)
        ;;
    *)
        echo "Unsupported configuration: $CONFIGURATION" >&2
        usage >&2
        exit 64
        ;;
esac

if [[ -z "$VERSION" ]]; then
    echo "DAILY_REPLICA_VERSION must not be empty" >&2
    exit 64
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "DAILY_REPLICA_BUILD_NUMBER must be an integer" >&2
    exit 64
fi

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/clang-module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$PRODUCT_NAME"

sed \
    -e "s|\$(DEVELOPMENT_LANGUAGE)|en|g" \
    -e "s|\$(EXECUTABLE_NAME)|$PRODUCT_NAME|g" \
    -e "s|\$(PRODUCT_BUNDLE_IDENTIFIER)|local.daily-replica.app|g" \
    -e "s|\$(PRODUCT_BUNDLE_PACKAGE_TYPE)|APPL|g" \
    -e "s|\$(MARKETING_VERSION)|$VERSION|g" \
    -e "s|\$(CURRENT_PROJECT_VERSION)|$BUILD_NUMBER|g" \
    -e "s|\$(MACOSX_DEPLOYMENT_TARGET)|14.0|g" \
    "$INFO_PLIST_TEMPLATE" > "$APP_DIR/Contents/Info.plist"

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
