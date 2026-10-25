#!/usr/bin/env bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${BUILD_DIR}/dist"
APP_DIR="${DIST_DIR}/Clipstream.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"

echo "=== 1. Building Release Binary ==="
cd "${PROJECT_ROOT}/macos"
swift build -c release

echo "=== 2. Creating App Bundle Structure ==="
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${ICONSET_DIR}"

# Copy binary
cp "${PROJECT_ROOT}/macos/.build/release/Clipstream" "${MACOS_DIR}/Clipstream"
chmod +x "${MACOS_DIR}/Clipstream"

echo "=== 3. Generating AppIcon.icns ==="
SRC_IMG="${PROJECT_ROOT}/site/assets/app-icon.jpg"

sips -s format png -z 16 16     "${SRC_IMG}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -s format png -z 32 32     "${SRC_IMG}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32     "${SRC_IMG}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -s format png -z 64 64     "${SRC_IMG}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128   "${SRC_IMG}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -s format png -z 256 256   "${SRC_IMG}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256   "${SRC_IMG}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -s format png -z 512 512   "${SRC_IMG}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512   "${SRC_IMG}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "${SRC_IMG}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null

iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

echo "=== 4. Creating Info.plist ==="
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>cloud.sysnode.clipstream</string>
    <key>CFBundleName</key>
    <string>Clipstream</string>
    <key>CFBundleDisplayName</key>
    <string>Clipstream</string>
    <key>CFBundleExecutable</key>
    <string>Clipstream</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Clipstream. MIT License.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Clipstream requires accessibility access to simulate Command+V paste into your active application.</string>
</dict>
</plist>
EOF

echo "=== 5. Code Signing App Bundle ==="
codesign --force --deep -s - "${APP_DIR}"

echo "=== 6. Packaging .dmg ==="
ln -sf /Applications "${DIST_DIR}/Applications"

DMG_OUT="${PROJECT_ROOT}/Clipstream.dmg"
rm -f "${DMG_OUT}"

hdiutil create -volname "Clipstream" -srcfolder "${DIST_DIR}" -ov -format UDZO "${DMG_OUT}"

echo "=== Packaging Complete! ==="
ls -lh "${DMG_OUT}"
