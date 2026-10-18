#!/bin/bash
# One-line installer: downloads the latest WhaleSeek release into ~/Applications and launches it.
set -euo pipefail
REPO="jianzhou0420/whaleseek"
URL="https://github.com/$REPO/releases/latest/download/WhaleSeek-macOS.zip"
DEST="$HOME/Applications"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "🐋 Downloading WhaleSeek..."
curl -fL --progress-bar "$URL" -o "$TMP/WhaleSeek-macOS.zip"
ditto -x -k "$TMP/WhaleSeek-macOS.zip" "$TMP/app"

pkill -x WhaleSeek 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/WhaleSeek.app"
mv "$TMP/app/WhaleSeek.app" "$DEST/WhaleSeek.app"
xattr -dr com.apple.quarantine "$DEST/WhaleSeek.app" 2>/dev/null || true

# The app was called WhaleBalance before v0.3.0. Its settings and keys are migrated on first launch;
# the old app is moved to the Trash so only one whale is running.
for OLD in "$DEST/WhaleBalance.app" "/Applications/WhaleBalance.app"; do
  if [ -d "$OLD" ]; then
    pkill -x WhaleBalance 2>/dev/null || true
    mv "$OLD" "$HOME/.Trash/WhaleBalance-$(date +%s).app" 2>/dev/null && echo "   Moved the old WhaleBalance.app to the Trash."
  fi
done

open "$DEST/WhaleSeek.app"
echo "✅ Installed: $DEST/WhaleSeek.app"
echo "   Paste your DeepSeek API key in the settings window that opens."
echo "   Quit from the 🐳 icon in the menu bar. Search \"WhaleSeek\" in Spotlight to open it again."
