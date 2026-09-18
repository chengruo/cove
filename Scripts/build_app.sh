#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/.build"
APP_BUNDLE="${PROJECT_DIR}/build/Cove.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building Cove binary via Swift Package Manager..."
mkdir -p "${BUILD_DIR}/tmp" "${BUILD_DIR}/clang-cache"
CLANG_MODULE_CACHE_PATH="${BUILD_DIR}/clang-cache" \
TMPDIR="${BUILD_DIR}/tmp" \
swift build --disable-sandbox -c release

echo "==> Packaging Cove.app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BUILD_DIR}/release/Cove" "${MACOS_DIR}/Cove"
if [ -f "${PROJECT_DIR}/Assets/AppIcon.icns" ]; then
    cp "${PROJECT_DIR}/Assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Cove</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.cove.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Cove</string>
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
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Cove. All rights reserved.</string>
</dict>
</plist>
EOF

echo "==> Code signing Cove.app with stable identifier requirement..."
# Using designated identifier requirement ensures macOS TCC does not invalidate
# permissions on every rebuild.
codesign --force --deep --sign - \
  --identifier "com.cove.app" \
  -r="designated => identifier \"com.cove.app\"" \
  "${APP_BUNDLE}"

echo "==> Registering Cove.app with LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${APP_BUNDLE}" || true

echo "==> Build complete: ${APP_BUNDLE}"
