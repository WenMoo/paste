#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building Clip…"
swift build -c release --product Clip

APP="$ROOT/dist/Clip.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$ROOT/.build/release/Clip" "$APP/Contents/MacOS/Clip"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

ICONSET="$ROOT/Resources/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
ICON_PNG="$ROOT/Resources/icon-1024.png"
swift "$ROOT/Scripts/make-icon.swift" "$ICON_PNG"

sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp "$APP/Contents/Resources/AppIcon.icns" "$ROOT/Resources/AppIcon.icns"
rm -rf "$ICONSET"

printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --deep --sign - --identifier app.local.clip --timestamp=none "$APP" >/dev/null

echo "Built $APP"
echo "Run: open \"$APP\""
