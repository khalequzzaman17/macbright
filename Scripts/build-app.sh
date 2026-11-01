#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

APP_DIR="$PROJECT_DIR/dist/Native Brightness.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
swiftc -target arm64-apple-macosx14.0 -O \
  -o "$APP_DIR/Contents/MacOS/NativeBrightness" \
  Sources/NativeBrightness/*.swift \
  -framework SwiftUI -framework AppKit -framework CoreGraphics -framework ServiceManagement
cp "Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Resources/NativeBrightness.icns" "$APP_DIR/Contents/Resources/NativeBrightness.icns"

SIGNING_IDENTITY="${CODE_SIGN_IDENTITY:--}"
codesign --force --options runtime --entitlements Resources/NativeBrightness.entitlements \
  --sign "$SIGNING_IDENTITY" "$APP_DIR"

echo "Built: $APP_DIR"
