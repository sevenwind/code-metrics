#!/bin/bash
# Собирает CodeMetrics.app (release) без Xcode: SwiftPM + ручная упаковка бандла.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release --product CodeMetrics
BIN="$(swift build -c release --show-bin-path)"
APP="CodeMetrics.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/CodeMetrics" "$APP/Contents/MacOS/CodeMetrics"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Code Metrics</string>
  <key>CFBundleDisplayName</key><string>Code Metrics</string>
  <key>CFBundleIdentifier</key><string>dev.local.codemetrics</string>
  <key>CFBundleExecutable</key><string>CodeMetrics</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Готово: $(pwd)/$APP"
