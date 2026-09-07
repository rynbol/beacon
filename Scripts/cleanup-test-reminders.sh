#!/bin/bash
# Removes every reminder the end-to-end check ever created.
#
# The check creates real reminders and deletes them when it finishes, so a run
# that is interrupted leaves them in the real database. This sweeps them by name.
# It touches Reminders and nothing else: no audio, no notifications.
set -euo pipefail
cd "$(dirname "$0")/.."

./Scripts/build-mac-app.sh >/dev/null
REPORT="$PWD/build/cleanup-report.txt"
rm -f "$REPORT"

open -W -a "$PWD/build/Beacon.app" --args --cleanup --report "$REPORT" || true
echo
cat "$REPORT" 2>/dev/null || echo "No report written — allow Reminders access, then run again."
