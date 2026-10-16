#!/bin/bash
# One-line installer: downloads the latest WhaleGirl release into ~/Applications and launches it.
set -euo pipefail
REPO="jianzhou0420/deepseek-whale-girl-mac"
URL="https://github.com/$REPO/releases/latest/download/WhaleGirl-macOS.zip"
DEST="$HOME/Applications"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "🐳 Downloading WhaleGirl..."
curl -fL --progress-bar "$URL" -o "$TMP/WhaleGirl-macOS.zip"
ditto -x -k "$TMP/WhaleGirl-macOS.zip" "$TMP/app"

pkill -x WhaleGirl 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/WhaleGirl.app"
mv "$TMP/app/WhaleGirl.app" "$DEST/WhaleGirl.app"
xattr -dr com.apple.quarantine "$DEST/WhaleGirl.app" 2>/dev/null || true

open "$DEST/WhaleGirl.app"
echo "✅ Installed: $DEST/WhaleGirl.app"
echo "   Quit from the 🐳 icon in the menu bar. Search \"WhaleGirl\" in Spotlight to open it again."
