#!/usr/bin/env bash
# Run an ExtendScript (.jsx) inside InDesign via `do script ... language javascript`.
# Usage: indesign.sh /path/script.jsx
set -euo pipefail
JSX="${1:?path to .jsx}"
APP="Adobe InDesign 2026"; PROC="Adobe InDesign 2026"
[[ -f "$JSX" ]] || { echo "no such file: $JSX" >&2; exit 1; }
open -a "$APP"
for _ in $(seq 1 40); do
  osascript -e "tell application \"System Events\" to (name of processes) contains \"$PROC\"" 2>/dev/null | grep -q true && break
  sleep 2
done
sleep 6
osascript -e "tell application \"$APP\" to do script (POSIX file \"$JSX\") language javascript"
