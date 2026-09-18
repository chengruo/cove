#!/usr/bin/env bash
set -e

# Cove - One-line Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/chengruo/cove/main/install.sh | bash

REPO_URL="https://github.com/chengruo/cove.git"
RELEASE_ZIP_URL="https://github.com/chengruo/cove/releases/latest/download/Cove.zip"
INSTALL_DIR="/Applications"
USER_INSTALL_DIR="${HOME}/Applications"

echo "================================================="
echo "        🌊 Installing Cove for macOS            "
echo "  Native Menu Bar Notch Overflow Utility        "
echo "================================================="

# 1. macOS Version Check
OS_NAME=$(uname -s)
if [ "$OS_NAME" != "Darwin" ]; then
    echo "❌ Error: Cove only supports macOS."
    exit 1
fi

MACOS_VERSION=$(sw_vers -productVersion | cut -d '.' -f 1)
if [ "$MACOS_VERSION" -lt 14 ]; then
    echo "⚠️ Warning: Cove is optimized for macOS 14 (Sonoma) and macOS 15 (Sequoia)+."
fi

# Determine destination directory
TARGET_DIR="${INSTALL_DIR}"
if [ ! -w "${TARGET_DIR}" ]; then
    mkdir -p "${USER_INSTALL_DIR}"
    TARGET_DIR="${USER_INSTALL_DIR}"
fi
TARGET_APP="${TARGET_DIR}/Cove.app"

TMP_WORK_DIR=$(mktemp -d /tmp/cove-install-XXXXXX)
trap "rm -rf '${TMP_WORK_DIR}'" EXIT

# 2. Check if we are already inside a clone of the Cove repo
if [ -f "./Scripts/build_app.sh" ] && [ -f "./Package.swift" ]; then
    echo "==> Building directly from current local repository..."
    ./Scripts/build_app.sh
    BUILT_APP="./build/Cove.app"
else
    echo "==> Checking for prebuilt release package..."
    HTTP_STATUS=$(curl -sIL -o /dev/null -w "%{http_code}" "${RELEASE_ZIP_URL}" 2>/dev/null || true)

    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
        echo "==> Downloading prebuilt Cove.zip from GitHub..."
        curl -fSL "${RELEASE_ZIP_URL}" -o "${TMP_WORK_DIR}/Cove.zip"
        echo "==> Extracting Cove.zip..."
        ditto -x -k "${TMP_WORK_DIR}/Cove.zip" "${TMP_WORK_DIR}/"
        BUILT_APP="${TMP_WORK_DIR}/Cove.app"
    else
        echo "==> Release package not found yet. Building from source via SwiftPM..."
        if ! command -v swift >/dev/null 2>&1; then
            echo "❌ Error: Xcode Command Line Tools or Swift compiler not found."
            echo "   Please install them using: xcode-select --install"
            exit 1
        fi

        echo "==> Cloning ${REPO_URL} into temporary workspace..."
        git clone --depth 1 "${REPO_URL}" "${TMP_WORK_DIR}/cove-src"
        cd "${TMP_WORK_DIR}/cove-src"
        ./Scripts/build_app.sh
        BUILT_APP="${TMP_WORK_DIR}/cove-src/build/Cove.app"
    fi
fi

if [ ! -d "${BUILT_APP}" ]; then
    echo "❌ Error: Failed to find or build Cove.app bundle."
    exit 1
fi

# 3. Terminate running instance if any
if pgrep -x "Cove" >/dev/null 2>&1; then
    echo "==> Stopping running Cove instance..."
    killall Cove 2>/dev/null || true
    sleep 1
fi

# 4. Install into Applications
echo "==> Installing Cove.app to ${TARGET_APP}..."
rm -rf "${TARGET_APP}"
cp -R "${BUILT_APP}" "${TARGET_APP}"

# 5. Register with macOS LaunchServices
echo "==> Registering with macOS LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "${TARGET_APP}" || true

# 6. Launch Application
echo "==> Launching Cove..."
open -a "${TARGET_APP}"

echo "================================================="
echo " 🎉 Cove installed successfully to ${TARGET_APP}!"
echo ""
echo " 📌 Important Setup:"
echo "   1. Cove needs Accessibility permission to scan menu items."
echo "      Go to: System Settings > Privacy & Security > Accessibility"
echo "      and make sure Cove is toggled ON."
echo "   2. Global Hotkey: Press ⌃⌥C (Control + Option + C) anytime"
echo "      to summon the panel, even if the icon is behind the Notch."
echo "   3. To keep Cove next to the input method, hold ⌘ (Command)"
echo "      and drag its menu bar icon to the far right."
echo "================================================="
