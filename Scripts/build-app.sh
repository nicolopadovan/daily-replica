#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: bash Scripts/build-app.sh [debug|release]

Builds DailyReplica from DailyReplica.xcodeproj.

Commands:
  debug    Build an unsigned Debug app and copy it to .build/DailyReplica.app.
  release  Archive/export a Developer ID app, notarize, zip, and update docs/appcast.xml.

Environment variables:
  DAILY_REPLICA_VERSION
      CFBundleShortVersionString / MARKETING_VERSION. Default: 0.1.1
  DAILY_REPLICA_BUILD_NUMBER
      CFBundleVersion / CURRENT_PROJECT_VERSION integer. Default: 2
  DAILY_REPLICA_SPARKLE_PUBLIC_ED_KEY
      Optional override for the project Sparkle public EdDSA key.
  DAILY_REPLICA_NOTARY_PROFILE
      notarytool keychain profile name. Required for release.
  DAILY_REPLICA_EXPORT_OPTIONS_PLIST
      Optional export options plist. Default: Scripts/ExportOptions.plist
  DAILY_REPLICA_SPARKLE_TOOLS_DIR
      Optional directory containing Sparkle's generate_appcast tool.
  DAILY_REPLICA_APPCAST_DOWNLOAD_URL_PREFIX
      Optional appcast archive URL prefix. Default:
      https://github.com/nicolopadovan/daily-replica/releases/download/v$DAILY_REPLICA_VERSION/
USAGE
}

fail() {
    echo "$1" >&2
    exit "${2:-1}"
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "Required command not found: $1"
    fi
}

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMMAND="${1:-release}"
PRODUCT_NAME="DailyReplica"
SCHEME="DailyReplica"
PROJECT_PATH="$ROOT_DIR/DailyReplica.xcodeproj"
VERSION="${DAILY_REPLICA_VERSION:-0.1.1}"
BUILD_NUMBER="${DAILY_REPLICA_BUILD_NUMBER:-2}"
SPARKLE_PUBLIC_ED_KEY="${DAILY_REPLICA_SPARKLE_PUBLIC_ED_KEY:-}"
NOTARY_PROFILE="${DAILY_REPLICA_NOTARY_PROFILE:-}"
EXPORT_OPTIONS_PLIST="${DAILY_REPLICA_EXPORT_OPTIONS_PLIST:-$ROOT_DIR/Scripts/ExportOptions.plist}"
SPARKLE_TOOLS_DIR="${DAILY_REPLICA_SPARKLE_TOOLS_DIR:-}"
DERIVED_DATA_DIR="$ROOT_DIR/.build/xcode-derived"
APP_DIR="$ROOT_DIR/.build/$PRODUCT_NAME.app"
ARCHIVE_DIR="$ROOT_DIR/.build/archives"
ARCHIVE_PATH="$ARCHIVE_DIR/$PRODUCT_NAME-$VERSION.xcarchive"
EXPORT_PATH="$ROOT_DIR/.build/export/$PRODUCT_NAME-$VERSION"
RELEASE_DIR="$ROOT_DIR/.build/releases"
ZIP_PATH="$RELEASE_DIR/$PRODUCT_NAME-$VERSION-macos-arm64.zip"
APPCAST_PATH="$ROOT_DIR/docs/appcast.xml"
APPCAST_DOWNLOAD_URL_PREFIX="${DAILY_REPLICA_APPCAST_DOWNLOAD_URL_PREFIX:-https://github.com/nicolopadovan/daily-replica/releases/download/v$VERSION/}"

case "$COMMAND" in
    -h|--help)
        usage
        exit 0
        ;;
    debug|release)
        ;;
    *)
        usage >&2
        fail "Unsupported command: $COMMAND" 64
        ;;
esac

if [[ -z "$VERSION" || ! "$VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ ]]; then
    fail "DAILY_REPLICA_VERSION must be non-empty and contain only version-safe characters." 64
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    fail "DAILY_REPLICA_BUILD_NUMBER must be an integer." 64
fi

if [[ "$APPCAST_DOWNLOAD_URL_PREFIX" != */ ]]; then
    APPCAST_DOWNLOAD_URL_PREFIX="$APPCAST_DOWNLOAD_URL_PREFIX/"
fi

XCODE_BUILD_OVERRIDES=(
    MARKETING_VERSION="$VERSION"
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
)

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    XCODE_BUILD_OVERRIDES+=(SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY")
fi

run_debug() {
    require_command xcodebuild
    require_command ditto

    mkdir -p "$ROOT_DIR/.build"
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "platform=macOS" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        "${XCODE_BUILD_OVERRIDES[@]}" \
        build

    local built_app="$DERIVED_DATA_DIR/Build/Products/Debug/$PRODUCT_NAME.app"
    if [[ ! -d "$built_app" ]]; then
        fail "Expected Xcode build product was not found: $built_app"
    fi

    rm -rf "$APP_DIR"
    ditto "$built_app" "$APP_DIR"
    echo "Built $APP_DIR"
}

find_generate_appcast() {
    if [[ -n "$SPARKLE_TOOLS_DIR" ]]; then
        local configured_tool="$SPARKLE_TOOLS_DIR/generate_appcast"
        if [[ -x "$configured_tool" ]]; then
            echo "$configured_tool"
            return 0
        fi
        fail "DAILY_REPLICA_SPARKLE_TOOLS_DIR does not contain an executable generate_appcast: $configured_tool"
    fi

    local root
    for root in "$DERIVED_DATA_DIR" "$ROOT_DIR/.build"; do
        if [[ -d "$root" ]]; then
            local found_tool
            found_tool="$(find "$root" -path "*/Sparkle/bin/generate_appcast" -type f -perm -111 -print -quit 2>/dev/null || true)"
            if [[ -n "$found_tool" ]]; then
                echo "$found_tool"
                return 0
            fi
        fi
    done

    fail "Could not find Sparkle's generate_appcast tool. Build once with Xcode or set DAILY_REPLICA_SPARKLE_TOOLS_DIR." 65
}

update_appcast() {
    local generate_appcast
    generate_appcast="$(find_generate_appcast)"

    "$generate_appcast" \
        --download-url-prefix "$APPCAST_DOWNLOAD_URL_PREFIX" \
        "$RELEASE_DIR"

    if [[ ! -f "$RELEASE_DIR/appcast.xml" ]]; then
        fail "Sparkle did not write $RELEASE_DIR/appcast.xml"
    fi

    mkdir -p "$(dirname "$APPCAST_PATH")"
    cp "$RELEASE_DIR/appcast.xml" "$APPCAST_PATH"
    echo "Updated $APPCAST_PATH"
}

run_release() {
    require_command xcodebuild
    require_command xcrun
    require_command ditto

    if [[ -z "$NOTARY_PROFILE" ]]; then
        fail "DAILY_REPLICA_NOTARY_PROFILE is required for release builds." 64
    fi

    if [[ ! -f "$EXPORT_OPTIONS_PLIST" ]]; then
        fail "Export options plist was not found: $EXPORT_OPTIONS_PLIST" 66
    fi

    mkdir -p "$ARCHIVE_DIR" "$RELEASE_DIR"
    rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
    rm -f "$ZIP_PATH"

    xcodebuild archive \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "generic/platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        "${XCODE_BUILD_OVERRIDES[@]}" \
        ARCHS=arm64 \
        ONLY_ACTIVE_ARCH=NO

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

    local exported_app="$EXPORT_PATH/$PRODUCT_NAME.app"
    if [[ ! -d "$exported_app" ]]; then
        fail "Expected exported app was not found: $exported_app"
    fi

    local exported_public_key
    exported_public_key="$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$exported_app/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -z "$exported_public_key" || "$exported_public_key" == *'$('* ]]; then
        fail "Exported app is missing a resolved Sparkle SUPublicEDKey."
    fi

    local notary_zip="$RELEASE_DIR/$PRODUCT_NAME-$VERSION-notary.zip"
    local notary_result="$RELEASE_DIR/$PRODUCT_NAME-$VERSION-notary.json"
    rm -f "$notary_zip"
    rm -f "$notary_result"
    ditto -c -k --sequesterRsrc --keepParent "$exported_app" "$notary_zip"
    if ! xcrun notarytool submit "$notary_zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$notary_result"; then
        cat "$notary_result" >&2
        fail "notarytool submit failed."
    fi
    cat "$notary_result"

    local notary_status
    notary_status="$(/usr/bin/plutil -extract status raw -o - "$notary_result" 2>/dev/null || true)"
    if [[ "$notary_status" != "Accepted" ]]; then
        local notary_id
        notary_id="$(/usr/bin/plutil -extract id raw -o - "$notary_result" 2>/dev/null || true)"
        fail "Notarization finished with status '${notary_status:-unknown}'. Inspect: xcrun notarytool log ${notary_id:-<submission-id>} --keychain-profile $NOTARY_PROFILE"
    fi

    xcrun stapler staple "$exported_app"
    rm -f "$notary_zip"

    ditto -c -k --sequesterRsrc --keepParent "$exported_app" "$ZIP_PATH"
    update_appcast
    echo "Built $ZIP_PATH"
}

cd "$ROOT_DIR"

case "$COMMAND" in
    debug)
        run_debug
        ;;
    release)
        run_release
        ;;
esac
