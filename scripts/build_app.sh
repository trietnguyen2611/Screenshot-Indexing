#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    ACTIVE_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
    if [[ "$ACTIVE_DEV_DIR" == *CommandLineTools* ]] && [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
        export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
        echo "Using Xcode developer directory: ${DEVELOPER_DIR}"
    fi
fi

APP_NAME="Screenshot Indexing"
EXECUTABLE_TARGET="ScreenshotIndexing"
BUNDLE_ID="com.trietnguyen2611.screenshotindexing"
RAW_VERSION="${APP_VERSION:-2.0.0}"
VERSION="${RAW_VERSION#v}"
if [[ -z "$VERSION" ]]; then
    VERSION="2.0.0"
fi

APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BINARY_OUT="${MACOS_DIR}/${APP_NAME}"

echo "Building ${EXECUTABLE_TARGET} (Release, Apple Silicon arm64, version ${VERSION})..."
swift build -c release --arch arm64

BIN_PATH=".build/arm64-apple-macosx/release/${EXECUTABLE_TARGET}"
if [[ ! -x "$BIN_PATH" ]]; then
    BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
    BIN_PATH="${BIN_DIR}/${EXECUTABLE_TARGET}"
fi

if [[ ! -x "$BIN_PATH" ]]; then
    echo "Error: Release executable not found at ${BIN_PATH}" >&2
    exit 1
fi

ARCHS="$(lipo -archs "$BIN_PATH")"
echo "Built binary architectures: ${ARCHS}"
if [[ "$ARCHS" != *"arm64"* ]] || [[ "$ARCHS" == *"x86_64"* ]]; then
    echo "Error: Binary must be Apple Silicon (arm64) only. Got: ${ARCHS}" >&2
    exit 1
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_PATH" "$BINARY_OUT"
chmod +x "$BINARY_OUT"

BIN_DIR_ACTUAL="$(dirname "$BIN_PATH")"
for bundle in "${BIN_DIR_ACTUAL}"/*.bundle; do
    if [[ -d "$bundle" ]]; then
        cp -R "$bundle" "$RESOURCES_DIR/"
    fi
done

if [[ ! -f "macapp_icon.icns" ]]; then
    echo "Error: macapp_icon.icns not found in ${ROOT_DIR}" >&2
    exit 1
fi
cp "macapp_icon.icns" "${RESOURCES_DIR}/macapp_icon.icns"

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>macapp_icon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Screenshot Indexing uses AppleEvents to send automated page-turn shortcuts when capturing pages.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 trietnguyen2611. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Screenshot Indexing needs Screen Recording access to capture your selected screen region and preview full-screen coordinates.</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

plutil -lint "${CONTENTS_DIR}/Info.plist"

xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Successfully packaged and signed: ${APP_BUNDLE}"
