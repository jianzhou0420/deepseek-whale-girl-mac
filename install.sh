#!/bin/bash
# 一键安装鲸鱼娘桌宠：下载最新版到 ~/Applications 并启动
set -euo pipefail
REPO="jianzhou0420/deepseek-whale-girl-mac"
URL="https://github.com/$REPO/releases/latest/download/WhaleGirl-macOS.zip"
DEST="$HOME/Applications"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "🐳 正在下载鲸鱼娘……"
curl -fL --progress-bar "$URL" -o "$TMP/WhaleGirl-macOS.zip"
ditto -x -k "$TMP/WhaleGirl-macOS.zip" "$TMP/app"

pkill -x WhaleGirl 2>/dev/null || true
mkdir -p "$DEST"
rm -rf "$DEST/WhaleGirl.app"
mv "$TMP/app/WhaleGirl.app" "$DEST/WhaleGirl.app"
xattr -dr com.apple.quarantine "$DEST/WhaleGirl.app" 2>/dev/null || true

open "$DEST/WhaleGirl.app"
echo "✅ 安装完成：$DEST/WhaleGirl.app"
echo "   点菜单栏的 🐳 可以退出。以后在启动台或「应用程序」里搜「鲸鱼娘」就能再打开。"
