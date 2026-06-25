#!/usr/bin/env bash
# Dreamweaver automation via the Startup folder: a .htm placed there auto-runs
# its JavaScript (dw / DWfile native API) every time DW launches.
# (DW is NOT ExtendScript; its BridgeTalk target is dead. Startup is the hook.)
#
# Usage: dreamweaver.sh /path/to/code.js
#   The file's contents are wrapped in a Startup .htm and executed on launch.
#   Use DWfile.write("file:///abs/path", text) to produce files; dw.* for the DOM.
set -euo pipefail
CODEFILE="${1:?path to a .js containing DW API code}"
[[ -f "$CODEFILE" ]] || { echo "no such file: $CODEFILE" >&2; exit 1; }
STARTUP="$HOME/Library/Application Support/Adobe/Dreamweaver 2021/en_US/Configuration/Startup"
mkdir -p "$STARTUP"
HTM="$STARTUP/ClaudeRun.htm"
{
  echo '<html><head><title>ClaudeRun</title><script language="javascript">'
  echo 'try{'
  cat "$CODEFILE"
  echo '}catch(e){ try{ DWfile.write("file:///tmp/dw_err.txt","ERR:"+e); }catch(_){} }'
  echo '</script></head><body></body></html>'
} > "$HTM"
echo "Startup script installed: $HTM"

# (re)launch DW to execute it
osascript -e 'tell application "Adobe Dreamweaver 2021" to quit' 2>/dev/null || true
sleep 3
open -a "Adobe Dreamweaver 2021"
echo "DW relaunching — Startup code runs on load. Remove $HTM afterwards to stop auto-run."
