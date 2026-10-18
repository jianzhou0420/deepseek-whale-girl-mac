#!/bin/bash
# One-line installer: downloads the latest WhaleBalance release into ~/Applications and launches it.
set -euo pipefail
REPO="jianzhou0420/deepseek-whale-girl-mac"
URL="https://github.com/$REPO/releases/latest/download/WhaleBalance-macOS.zip"
DEST="$HOME/Applications"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "🐋 Downloading WhaleBalance..."
curl -fL --progress-bar "$URL" -o "$TMP/WhaleBalance-macOS.zip"
ditto -x -k "$TMP/WhaleBalance-macOS.zip" "$TMP/app"

pkill -x WhaleBalance 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/WhaleBalance.app"
mv "$TMP/app/WhaleBalance.app" "$DEST/WhaleBalance.app"
xattr -dr com.apple.quarantine "$DEST/WhaleBalance.app" 2>/dev/null || true

open "$DEST/WhaleBalance.app"
echo "✅ Installed: $DEST/WhaleBalance.app"
echo "   Paste your DeepSeek API key in the settings window that opens."
echo "   Quit from the 🐳 icon in the menu bar. Search \"WhaleBalance\" in Spotlight to open it again."
