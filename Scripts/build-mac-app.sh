#!/bin/bash
# Xcode emits the App Intents metadata Siri/Shortcuts need; copying a SwiftPM
# executable alone omits that metadata. No developer account is needed for Mac.
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-debug}" in
  debug|Debug) CONFIG=Debug ;;
  release|Release) CONFIG=Release ;;
  *) echo "Usage: $0 [debug|release]" >&2; exit 2 ;;
esac
APP="build/Beacon.app"
if [[ "${BEACON_PREVIEW:-0}" == "1" ]]; then APP="build/BeaconPreview.app"; fi
mkdir -p build
if ! xcodebuild -project Beacon.xcodeproj -scheme BeaconMac \
    -configuration "$CONFIG" -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath build/DerivedData ONLY_ACTIVE_ARCH=YES \
    CODE_SIGNING_ALLOWED=NO ENABLE_DEBUG_DYLIB=NO build > build/mac-build.log 2>&1; then
    tail -80 build/mac-build.log >&2
    exit 1
fi
rm -rf "$APP"
ditto "build/DerivedData/Build/Products/$CONFIG/Beacon.app" "$APP"
if [[ "${BEACON_PREVIEW:-0}" == "1" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier dev.dylan.beacon.preview" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Beacon Preview" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Beacon Preview" "$APP/Contents/Info.plist"
fi
if security find-certificate -c "Beacon Dev" >/dev/null 2>&1; then
    codesign --force --sign "Beacon Dev" --timestamp=none "$APP"
else
    codesign --force --sign - --timestamp=none "$APP"
fi
codesign --verify --deep --strict "$APP"
test -f "$APP/Contents/Resources/Metadata.appintents/extract.actionsdata"
echo "Built $APP with Siri/Shortcuts metadata"
