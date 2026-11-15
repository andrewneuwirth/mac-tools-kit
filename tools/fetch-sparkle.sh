#!/usr/bin/env bash
# Downloads Sparkle's release tools (generate_keys, sign_update, generate_appcast) into tools/sparkle/.
# Pinned version and sha256 (from the GitHub release's asset digest); the binaries stay out of git.
# Keep VERSION in step with the Sparkle pin in Package.swift.
set -euo pipefail
VERSION=2.10.1
SHA256=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
DIR="$(cd "$(dirname "$0")" && pwd)/sparkle"

if [ -x "$DIR/bin/sign_update" ] && [ "$(cat "$DIR/VERSION" 2>/dev/null)" = "$VERSION" ]; then
  echo "Sparkle $VERSION tools already in $DIR"; exit 0
fi
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
curl -fsSL -o "$WORK/sparkle.tar.xz" \
  "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz"
echo "$SHA256  $WORK/sparkle.tar.xz" | shasum -a 256 -c -
mkdir -p "$WORK/x" && tar -xJf "$WORK/sparkle.tar.xz" -C "$WORK/x"
rm -rf "$DIR" && mkdir -p "$DIR"
cp -R "$WORK/x/bin" "$DIR/bin"
echo "$VERSION" > "$DIR/VERSION"
echo "Sparkle $VERSION tools in $DIR/bin"
