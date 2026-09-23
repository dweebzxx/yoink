#!/bin/zsh
# Builds dist/yo!nk.app from a clean Release build of the Swift package.
# Usage (from the repository root):  zsh yoink/scripts/build-app.zsh
# Signs ad hoc ("sign to run locally") only. Developer ID signing and notarization are Human-only.
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PKG_DIR=${SCRIPT_DIR:h}
REPO_DIR=${PKG_DIR:h}
ASSETS="$REPO_DIR/assets/prompt-attachments/app-assets"
WORK="$PKG_DIR/.build/app-resources"
APP_NAME='yo!nk.app'
APP="$REPO_DIR/dist/$APP_NAME"
VERSION="1.0.0"
BUILD_NUMBER="1"

echo "==> Release build"
swift build --package-path "$PKG_DIR" -c release --product yoink
BIN="$(swift build --package-path "$PKG_DIR" -c release --show-bin-path)/yoink"

echo "==> Preparing resources"
rm -rf "$WORK"
mkdir -p "$WORK/AppIcon.iconset"
# Square art: crop the 2816 px renders to the square around the body, then scale for 160 pt @2x.
for pair in "floating-button.PNG:square.png" "floating-button-locked.PNG:square-locked.png"; do
  src=${pair%%:*}; dst=${pair##*:}
  sips -c 2082 2082 --cropOffset 325 386 "$ASSETS/$src" --out "$WORK/crop-$dst" >/dev/null
  sips -Z 512 "$WORK/crop-$dst" --out "$WORK/$dst" >/dev/null
done
# App icon from the 3024 px source.
for size in 16 32 128 256 512; do
  sips -z $size $size "$ASSETS/app-icon.PNG" --out "$WORK/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) "$ASSETS/app-icon.PNG" --out "$WORK/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$WORK/AppIcon.iconset" -o "$WORK/AppIcon.icns"

echo "==> Assembling $APP_NAME"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/yoink"
cp "$WORK/square.png" "$WORK/square-locked.png" "$WORK/AppIcon.icns" "$APP/Contents/Resources/"
cp "$ASSETS/floating-button-when-dragged-moving.gif" "$APP/Contents/Resources/square-dragged.gif"
cp "$ASSETS/menu-bar-icon.png" "$APP/Contents/Resources/menu-bar-icon.png"
cp "$ASSETS/menu-bar-icon@2x.png" "$APP/Contents/Resources/menu-bar-icon@2x.png"
cp "$ASSETS/audio-hehe.mp3" "$APP/Contents/Resources/copy-sound.mp3"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>yoink</string>
  <key>CFBundleIdentifier</key><string>com.dweebzxx.yoink</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>yo!nk</string>
  <key>CFBundleDisplayName</key><string>yo!nk</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> Ad-hoc signing (local run only, Hardened Runtime on)"
codesign --force --sign - --options runtime --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "==> Built $APP"
