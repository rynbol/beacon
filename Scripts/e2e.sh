#!/bin/bash
# Runs the end-to-end check against the live Reminders database.
#
# It runs inside Beacon.app, so it uses the app's own reminders grant and the
# same code path the app uses. A separate binary would need its own grant and
# would prove less.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build-mac-app.sh >/dev/null
REPORT="$PWD/build/e2e-report.txt"
rm -f "$REPORT"

open -W -a "$PWD/build/Beacon.app" --args --e2e --report "$REPORT" || true
echo
cat "$REPORT" 2>/dev/null || echo "No report written — allow Reminders access when macOS asks, then run again."
