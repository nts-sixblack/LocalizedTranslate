#!/usr/bin/env bash
# ==============================================================================
# LocalizedTranslate - Build, Local Sign & Install to /Applications
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="LocalizedTranslate"
SCHEME="LocalizedTranslate"
CONFIGURATION="Release"
DESTINATION_DIR="/Applications"
TARGET_APP="${DESTINATION_DIR}/${APP_NAME}.app"
DERIVED_DATA="${PROJECT_ROOT}/DerivedData"
ENTITLEMENTS="${PROJECT_ROOT}/LocalizedTranslate/LocalizedTranslate.entitlements"

echo "=========================================================="
echo "🚀 LocalizedTranslate: Building, Signing & Installing"
echo "=========================================================="

cd "${PROJECT_ROOT}"

# 1. Clean previous build if requested or prepare output directory
echo "📦 Step 1: Building Release application with xcodebuild..."
xcodebuild -scheme "${SCHEME}" \
           -configuration "${CONFIGURATION}" \
           -derivedDataPath "${DERIVED_DATA}" \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           clean build | xcbeautify 2>/dev/null || \
xcodebuild -scheme "${SCHEME}" \
           -configuration "${CONFIGURATION}" \
           -derivedDataPath "${DERIVED_DATA}" \
           CODE_SIGN_IDENTITY="" \
           CODE_SIGNING_REQUIRED=NO \
           CODE_SIGNING_ALLOWED=NO \
           clean build

BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"

if [ ! -d "${BUILT_APP}" ]; then
    echo "❌ Error: Built application not found at ${BUILT_APP}"
    exit 1
fi

echo "✅ Build completed successfully."

# 2. Stop running instance if any
if pgrep -x "${APP_NAME}" > /dev/null 2>&1; then
    echo "⚠️ Step 2: Quitting currently running instance of ${APP_NAME}..."
    killall "${APP_NAME}" || true
    sleep 1
fi

# 3. Copy to /Applications
echo "📂 Step 3: Installing to ${DESTINATION_DIR}..."
if [ -d "${TARGET_APP}" ]; then
    echo "   Removing older installation..."
    rm -rf "${TARGET_APP}"
fi

cp -R "${BUILT_APP}" "${DESTINATION_DIR}/"

# 4. Codesign Locally (Ad-hoc signature with sandboxing entitlements)
echo "🔐 Step 4: Signing application locally (Ad-Hoc / Local Signing)..."
if [ -f "${ENTITLEMENTS}" ]; then
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${TARGET_APP}"
else
    codesign --force --deep --sign - "${TARGET_APP}"
fi

# 5. Clear quarantine attribute (prevent Gatekeeper issues for local build)
echo "🛡️ Step 5: Removing quarantine attributes..."
xattr -cr "${TARGET_APP}" 2>/dev/null || true

# 6. Refresh macOS LaunchServices database
echo "🔄 Step 6: Registering with macOS LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "${TARGET_APP}" 2>/dev/null || true

echo ""
echo "=========================================================="
echo "🎉 SUCCESS: LocalizedTranslate is now installed!"
echo "📍 Location: ${TARGET_APP}"
echo "💡 You can now launch it from Spotlight, Raycast, or /Applications."
echo "=========================================================="
echo ""

read -p "Do you want to launch LocalizedTranslate now? (y/N): " -n 1 -r || true
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "${TARGET_APP}"
fi
