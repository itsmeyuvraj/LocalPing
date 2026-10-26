#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "==> 1. Building LocalPing in Release Mode..."
swift build -c release

APP_NAME="LocalPing.app"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 2. Assembling macOS App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary & plist
cp "$PROJECT_DIR/.build/release/LocalPing" "$MACOS_DIR/LocalPing"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/LocalPing"

echo "==> 3. Signing App Bundle with Ad-Hoc Signature..."
codesign --force --deep --sign - --entitlements "$PROJECT_DIR/Resources/LocalPing.entitlements" "$APP_BUNDLE"

TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

echo "==> 4. Installing to $TARGET_DIR/LocalPing.app..."
rm -rf "$TARGET_DIR/LocalPing.app"
cp -R "$APP_BUNDLE" "$TARGET_DIR/LocalPing.app"

echo "==> 5. Launching LocalPing..."
# If an older instance is running, stop it
killall LocalPing 2>/dev/null || true
sleep 0.5
open "$TARGET_DIR/LocalPing.app"

echo "==> Successfully installed and launched LocalPing!"
