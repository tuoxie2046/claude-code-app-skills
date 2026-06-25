#!/usr/bin/env bash
# Adobe Acrobat automation via its AppleScript dictionary (open / save / props).
# Pass an AppleScript snippet that runs inside a `tell application "Adobe Acrobat"`.
#
# Usage:
#   acrobat.sh 'open POSIX file "/in.pdf"
#               save active doc to (POSIX file "/out.pdf")'
set -euo pipefail
SNIPPET="${1:?AppleScript body to run inside Adobe Acrobat}"
open -a "Adobe Acrobat"
for _ in $(seq 1 30); do
  osascript -e 'tell application "System Events" to (name of processes) contains "Adobe Acrobat"' 2>/dev/null | grep -q true && break
  sleep 2
done
sleep 5
osascript <<APPLE
tell application "Adobe Acrobat"
    activate
    $SNIPPET
end tell
APPLE
