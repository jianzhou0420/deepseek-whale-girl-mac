#!/bin/zsh
# Builds WhaleSeek.app as a universal binary (Apple Silicon + Intel).
# Usage: ./build.sh          build only
#        ./build.sh --zip    build and package dist/WhaleSeek-macOS.zip
set -e
cd "$(dirname "$0")"
APP="WhaleSeek.app"
BIN="$APP/Contents/MacOS/WhaleSeek"
TMP="$(mktemp -d)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp assets/spritesheet.webp "$APP/Contents/Resources/"
cp assets/LICENSE "$APP/Contents/Resources/ART-LICENSE"
[ -f assets/AppIcon.icns ] && cp assets/AppIcon.icns "$APP/Contents/Resources/"
[ -d assets/generated ] && cp -R assets/generated "$APP/Contents/Resources/generated"
[ -d assets/anims ] && cp -R assets/anims "$APP/Contents/Resources/anims"

echo "Compiling..."
swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos13.0 Sources/*.swift -o "$TMP/arm64"
if swiftc -O -swift-version 5 -parse-as-library -target x86_64-apple-macos13.0 Sources/*.swift -o "$TMP/x86_64" 2>/dev/null; then
  lipo -create "$TMP/arm64" "$TMP/x86_64" -output "$BIN"
else
  echo "(Intel build failed; building Apple Silicon only)"
  cp "$TMP/arm64" "$BIN"
fi
rm -rf "$TMP"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>WhaleSeek</string>
  <key>CFBundleDisplayName</key><string>WhaleSeek</string>
  <key>CFBundleIdentifier</key><string>io.github.jianzhou0420.whaleseek</string>
  <key>CFBundleExecutable</key><string>WhaleSeek</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.6</string>
  <key>CFBundleVersion</key><string>6</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
echo "Built: $(pwd)/$APP"

if [[ "$1" == "--zip" ]]; then
  mkdir -p dist
  rm -f dist/WhaleSeek-macOS.zip
  ditto -c -k --keepParent "$APP" dist/WhaleSeek-macOS.zip
  echo "Packaged: $(pwd)/dist/WhaleSeek-macOS.zip"
fi
