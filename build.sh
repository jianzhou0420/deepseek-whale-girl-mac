#!/bin/zsh
# Builds WhaleGirl.app as a universal binary (Apple Silicon + Intel).
# Usage: ./build.sh          build only
#        ./build.sh --zip    build and package dist/WhaleGirl-macOS.zip
set -e
cd "$(dirname "$0")"
APP="WhaleGirl.app"
BIN="$APP/Contents/MacOS/WhaleGirl"
TMP="$(mktemp -d)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp assets/spritesheet.webp assets/AppIcon.icns "$APP/Contents/Resources/"
cp assets/LICENSE "$APP/Contents/Resources/ART-LICENSE"

echo "Compiling..."
swiftc -O -swift-version 5 -target arm64-apple-macos13.0 main.swift -o "$TMP/arm64"
if swiftc -O -swift-version 5 -target x86_64-apple-macos13.0 main.swift -o "$TMP/x86_64" 2>/dev/null; then
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
  <key>CFBundleName</key><string>WhaleGirl</string>
  <key>CFBundleDisplayName</key><string>WhaleGirl</string>
  <key>CFBundleIdentifier</key><string>io.github.jianzhou0420.whalegirl</string>
  <key>CFBundleExecutable</key><string>WhaleGirl</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
echo "Built: $(pwd)/$APP"

if [[ "$1" == "--zip" ]]; then
  mkdir -p dist
  rm -f dist/WhaleGirl-macOS.zip
  ditto -c -k --keepParent "$APP" dist/WhaleGirl-macOS.zip
  echo "Packaged: $(pwd)/dist/WhaleGirl-macOS.zip"
fi
