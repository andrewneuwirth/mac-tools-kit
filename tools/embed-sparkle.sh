#!/usr/bin/env bash
# Puts Sparkle.framework (from the SwiftPM build) in APP/Contents/Frameworks, adds the rpath, and signs Sparkle's
# nested helpers inside-out with IDENTITY. Run it after the executable is copied in, before the app itself is signed.
#   embed-sparkle.sh build/Pier.app "$IDENTITY" [--release]
# --release adds a secure timestamp (notarization needs it). IDENTITY "-" signs ad hoc. See docs/updates.md.
set -euo pipefail
APP=${1:?usage: embed-sparkle.sh path/to/App.app identity [--release]}
IDENTITY=${2:?usage: embed-sparkle.sh path/to/App.app identity [--release]}
TIMESTAMP=--timestamp=none; [ "${3:-}" = --release ] && TIMESTAMP=--timestamp
BUILD=${SPARKLE_BUILD_DIR:-.build/release}
EXE="$APP/Contents/MacOS/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"

mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
ditto "$BUILD/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
LOADS=$(otool -l "$EXE")   # captured first: grep -q on a pipe trips pipefail
[[ "$LOADS" == *"@executable_path/../Frameworks"* ]] || install_name_tool -add_rpath @executable_path/../Frameworks "$EXE"

# The hardened runtime on every helper (ad hoc can't use it), Downloader keeps its own entitlements.
RUNTIME=(--options runtime); [ "$IDENTITY" = - ] && RUNTIME=()
B="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign() { codesign --force ${RUNTIME[@]+"${RUNTIME[@]}"} "$TIMESTAMP" --sign "$IDENTITY" "$@"; }
sign "$B/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$B/XPCServices/Downloader.xpc"
sign "$B/Autoupdate"
sign "$B/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
