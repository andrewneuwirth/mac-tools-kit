#!/usr/bin/env bash
# Notarizes a Developer ID-signed .app and wraps it in a signed, notarized, stapled DMG.
#   tools/release-app.sh build/Pier.app [out-dir]
# Needs: the app already signed with "Developer ID Application" (hardened runtime + --timestamp), and a
# notarytool keychain profile (default "notary"; override with NOTARY_PROFILE). Writes <out-dir>/<Name>-<version>.dmg.
set -euo pipefail

APP=${1:?usage: release-app.sh path/to/App.app [out-dir]}
OUT=${2:-dist}
PROFILE=${NOTARY_PROFILE:-notary}
NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP/Contents/Info.plist" 2>/dev/null || basename "$APP" .app)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=\(Developer ID Application:.*\)$/\1/p' | head -1)
[ -n "$IDENTITY" ] || { echo "$APP is not signed with a Developer ID Application identity" >&2; exit 1; }
codesign -d --verbose=4 "$APP" 2>&1 | grep -q 'flags=.*runtime' || { echo "$APP lacks the hardened runtime" >&2; exit 1; }

mkdir -p "$OUT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo "==> Notarizing $NAME $VERSION (app)…"
ditto -c -k --keepParent "$APP" "$WORK/app.zip"
xcrun notarytool submit "$WORK/app.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"

echo "==> Building the disk image…"
mkdir "$WORK/dmg"
cp -R "$APP" "$WORK/dmg/"
ln -s /Applications "$WORK/dmg/Applications"
DMG="$OUT/$NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "$NAME" -srcfolder "$WORK/dmg" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing $DMG…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
shasum -a 256 "$DMG"
echo "Ready: $DMG"
