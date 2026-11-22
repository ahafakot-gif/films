#!/bin/bash
# Builds Zohar.app and a .dmg. Run on a Mac with Xcode (or Command Line Tools).
set -euo pipefail
cd "$(dirname "$0")"
VERSION="${VERSION:-1.0.0}"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release "${ARCHS[@]}"
BIN_DIR="$(swift build -c release "${ARCHS[@]}" --show-bin-path)"

rm -rf dist build
APP="dist/Zohar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/icon.iconset
cp "$BIN_DIR/Zohar" "$APP/Contents/MacOS/Zohar"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

for s in 16 32 128 256 512; do
  sips -z $s $s Resources/icon.png --out "build/icon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z $d $d Resources/icon.png --out "build/icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP"
lipo -info "$APP/Contents/MacOS/Zohar"

mkdir -p build/dmg
cp -R "$APP" build/dmg/
cp "Resources/Как открыть - איך לפתוח.txt" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -volname "Zohar" -srcfolder build/dmg -ov -format UDZO "dist/Zohar-$VERSION.dmg"
echo "Built dist/Zohar-$VERSION.dmg"
