#!/usr/bin/env bash
# Run an ExtendScript (.jsx) inside Photoshop / Illustrator / After Effects.
# These apps expose `do javascript of file` (PS/AI) and AE uses DoScriptFile.
#
# Usage:
#   extendscript.sh photoshop  /path/script.jsx
#   extendscript.sh illustrator /path/script.jsx
#   extendscript.sh aftereffects /path/script.jsx
#
# App AppleScript names (note: Illustrator has NO version suffix):
set -euo pipefail
APP_KEY="${1:?app: photoshop|illustrator|aftereffects}"
JSX="${2:?path to .jsx}"

# validate the app enum BEFORE checking the file, so the error names the real problem
case "$APP_KEY" in
  photoshop)     APP="Adobe Photoshop 2026"; PROC="Adobe Photoshop 2026";;
  illustrator)   APP="Adobe Illustrator";    PROC="Adobe Illustrator";;
  aftereffects)  APP="Adobe After Effects 2026"; PROC="Adobe After Effects 2026";;
  *) echo "unknown app: $APP_KEY (photoshop|illustrator|aftereffects)" >&2; exit 1;;
esac

[[ -f "$JSX" ]] || { echo "no such file: $JSX" >&2; exit 1; }

open -a "$APP"
for _ in $(seq 1 40); do
  osascript -e "tell application \"System Events\" to (name of processes) contains \"$PROC\"" 2>/dev/null | grep -q true && break
  sleep 2
done
sleep 6

if [[ "$APP_KEY" == "aftereffects" ]]; then
  osascript -e "tell application \"$APP\" to DoScriptFile \"$JSX\""
else
  osascript -e "tell application \"$APP\" to do javascript of file \"$JSX\""
fi
