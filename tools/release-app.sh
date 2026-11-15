#!/usr/bin/env bash
# Notarizes a Developer ID-signed .app and wraps it in a signed, notarized, stapled DMG.
#   tools/release-app.sh build/Pier.app [out-dir]
# Needs: the app already signed with "Developer ID Application" (hardened runtime + --timestamp), and a
# notarytool keychain profile (default "notary"; override with NOTARY_PROFILE). Writes <out-dir>/<Name>-<version>.dmg.
# With APPCAST and DMG_URL set it also signs the DMG for Sparkle and adds it to that appcast (docs/updates.md):
#   APPCAST=../newitools-site/pier/appcast.xml   the appcast file to create or update
#   DMG_URL=https://.../Pier-0.1.1.dmg           where the DMG will be published (the enclosure URL)
#   APPCAST_LINK=https://newitools.app/pier/     the app's page (the channel link; default: the appcast's folder URL)
#   RELEASE_NOTES_URL=... or RELEASE_NOTES="..."  optional: a notes page, or notes inline (HTML allowed)
set -euo pipefail

APP=${1:?usage: release-app.sh path/to/App.app [out-dir]}
OUT=${2:-dist}
PROFILE=${NOTARY_PROFILE:-notary}
NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP/Contents/Info.plist" 2>/dev/null || basename "$APP" .app)
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=\(Developer ID Application:.*\)$/\1/p' | sed -n 1p)
[ -n "$IDENTITY" ] || { echo "$APP is not signed with a Developer ID Application identity" >&2; exit 1; }
SIGNATURE=$(codesign -d --verbose=4 "$APP" 2>&1)   # captured first: grep -q on a pipe trips pipefail
[[ "$SIGNATURE" == *"(runtime)"* ]] || { echo "$APP lacks the hardened runtime" >&2; exit 1; }

if [ -n "${APPCAST:-}" ]; then   # checked before the slow part
  [ -n "${DMG_URL:-}" ] || { echo "APPCAST needs DMG_URL (where the DMG will be published)" >&2; exit 1; }
  TOOLS="$(cd "$(dirname "$0")" && pwd)"
  "$TOOLS/fetch-sparkle.sh" >/dev/null
  APPKEY=$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP/Contents/Info.plist" 2>/dev/null || true)
  [ "$APPKEY" = "$("$TOOLS/sparkle/bin/generate_keys" -p)" ] || { echo "$APP's SUPublicEDKey doesn't match the signing key" >&2; exit 1; }
fi

mkdir -p "$OUT"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

echo "==> Notarizing ${NAME} ${VERSION} (app)..."
if xcrun stapler validate "$APP" >/dev/null 2>&1; then
  echo "    already notarized and stapled"
else
  ditto -c -k --keepParent "$APP" "$WORK/app.zip"
  xcrun notarytool submit "$WORK/app.zip" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$APP"
fi

echo "==> Building the disk image..."
mkdir "$WORK/dmg"
cp -R "$APP" "$WORK/dmg/"
ln -s /Applications "$WORK/dmg/Applications"
DMG="$OUT/$NAME-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "$NAME" -srcfolder "$WORK/dmg" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing ${DMG}..."
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
spctl --assess --type execute --verbose=2 "$APP"

if [ -n "${APPCAST:-}" ]; then
  echo "==> Signing ${DMG} for Sparkle and updating ${APPCAST}..."
  ED=$("$TOOLS/sparkle/bin/sign_update" "$DMG")   # sparkle:edSignature="..." length="..."
  SIG=$(sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' <<<"$ED")
  LEN=$(sed -n 's/.*length="\([0-9]*\)".*/\1/p' <<<"$ED")
  [ -n "$SIG" ] && [ -n "$LEN" ] || { echo "sign_update gave no signature (is the key in the login keychain?)" >&2; exit 1; }
  BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")
  MIN=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")
  FEED=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP/Contents/Info.plist" 2>/dev/null || true)
  mkdir -p "$(dirname "$APPCAST")"
  python3 -I "$TOOLS/appcast.py" "$APPCAST" --title "$NAME" --link "${APPCAST_LINK:-${FEED%appcast.xml}}" \
    --version "$BUILD" --short "$VERSION" --min-system "$MIN" --url "$DMG_URL" --length "$LEN" --signature "$SIG" \
    ${RELEASE_NOTES_URL:+--notes-url "$RELEASE_NOTES_URL"} ${RELEASE_NOTES:+--notes "$RELEASE_NOTES"}
  echo "    $APPCAST: $NAME $VERSION ($BUILD) -> $DMG_URL"
fi

shasum -a 256 "$DMG"
echo "Ready: $DMG"
