#!/bin/bash
# Packages the BeaconApp executable into a launchable macOS bundle.
#
# EventKit will not hand a plain executable any reminders: it needs a bundle
# carrying NSRemindersFullAccessUsageDescription, and a code signature for the
# privacy system to attach the grant to.
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG="${1:-debug}"
APP="build/Beacon.app"

swift build -c "$CONFIG" --product BeaconApp

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c "$CONFIG" --product BeaconApp --show-bin-path)/BeaconApp" \
   "$APP/Contents/MacOS/Beacon"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Sign with a stable identity when one exists, so macOS keeps the reminders and
# notification grants across rebuilds. An ad-hoc signature is derived from the
# binary and changes every build, which makes every build look like a new app
# and silently drops both grants.
#
# Create the identity once with ./Scripts/make-signing-identity.sh
if security find-certificate -c "Beacon Dev" >/dev/null 2>&1; then
    codesign --force --sign "Beacon Dev" --timestamp=none "$APP" >/dev/null 2>&1
else
    echo "note: no stable signing identity — run ./Scripts/make-signing-identity.sh"
    echo "      or macOS will ask for permissions again after every rebuild."
    codesign --force --sign - --timestamp=none "$APP" >/dev/null 2>&1
fi

echo "Built $APP"
echo "Run it:  open $APP"
