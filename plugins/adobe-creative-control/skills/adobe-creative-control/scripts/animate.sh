#!/usr/bin/env bash
# Adobe Animate automation via JSFL: Animate executes a .jsfl when opened.
# Usage: animate.sh /path/script.jsfl
#   In the JSFL, use fl.* API; file URIs need the file:// prefix (3 slashes for
#   absolute paths, e.g. file:///private/tmp/...).
set -euo pipefail
JSFL="${1:?path to .jsfl}"
[[ -f "$JSFL" ]] || { echo "no such file: $JSFL" >&2; exit 1; }
APP="Adobe Animate 2024"
open -a "$APP"
for _ in $(seq 1 40); do pgrep -f "$APP.app/Contents/MacOS" >/dev/null && break; sleep 2; done
sleep 8
open -a "$APP" "$JSFL"
echo "JSFL dispatched to Animate: $JSFL"
