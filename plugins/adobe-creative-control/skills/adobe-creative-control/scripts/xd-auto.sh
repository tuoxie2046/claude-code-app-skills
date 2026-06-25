#!/usr/bin/env bash
#
# xd-auto.sh — one-click Adobe XD automation from the shell.
#
# Chain:  install plugin -> launch XD -> reload plugins (legacy)
#         -> (optional) create a document -> trigger the plugin command
#
# Why it works without the UXP Developer Tool: the bundled plugin uses the
# *legacy* manifest format, which XD's built-in
#   Plugins > Development > Reload Plugins (Legacy)
# loads straight from the develop folder.
#
# Requirements (one-time):
#   * Adobe XD installed and signed in
#   * The terminal running this script has macOS **Accessibility** permission
#     (System Settings > Privacy & Security > Accessibility)
#   * Screen Recording permission is NOT required by this script
#   * pip install --user mido python-rtmidi   # not needed here
#   * pip install --user pyobjc-framework-Quartz   # for the preset-tile click
#
# Usage:
#   ./xd-auto.sh                         # run bundled demo plugin (creates a doc, adds a rectangle)
#   ./xd-auto.sh --plugin /path/to/myplugin
#   ./xd-auto.sh --no-doc                # don't create a doc (use the doc already open)
#   ./xd-auto.sh --trigger-only          # skip install+reload, just fire the command
#   ./xd-auto.sh --keep                  # leave the plugin installed afterwards
#   ./xd-auto.sh --preset-x 0.537 --preset-y 0.411   # tune Home preset-tile click point
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="Adobe XD"
PROC="Adobe XD"
DEV_DIR="$HOME/Library/Application Support/Adobe/Adobe XD/develop"
UXP_DATA="$HOME/Library/Application Support/Adobe/UXP/PluginsStorage/SPRK/Developer"

PLUGIN_SRC="$HERE/plugins/demo"
DO_NEWDOC=1
TRIGGER_ONLY=0
KEEP=0
OUT=""
PRESET_FX=0.537   # Web 1920 tile, fraction of Home window width
PRESET_FY=0.411   # fraction of Home window height

log(){ printf '\033[1;36m[xd-auto]\033[0m %s\n' "$*"; }
err(){ printf '\033[1;31m[xd-auto]\033[0m %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin)      PLUGIN_SRC="$2"; shift 2;;
    --no-doc)      DO_NEWDOC=0; shift;;
    --trigger-only) TRIGGER_ONLY=1; shift;;
    --keep)        KEEP=1; shift;;
    --out)         OUT="$2"; shift 2;;
    --preset-x)    PRESET_FX="$2"; shift 2;;
    --preset-y)    PRESET_FY="$2"; shift 2;;
    -h|--help)     grep '^#' "$0" | grep -v '^#!' | sed 's/^# \{0,1\}//'; exit 0;;
    *) err "unknown arg: $1"; exit 1;;
  esac
done

MANIFEST="$PLUGIN_SRC/manifest.json"
[[ -f "$MANIFEST" ]] || { err "manifest not found: $MANIFEST"; exit 1; }

# ---- read id / name / command label from the manifest ----
eval "$(python3 - "$MANIFEST" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
ep = (d.get("uiEntryPoints") or [{}])[0]
def q(s): return "'" + str(s).replace("'", "'\\''") + "'"
print("PID="    + q(d.get("id", "")))
print("PNAME="  + q(d.get("name", d.get("id", ""))))
print("PLABEL=" + q(ep.get("label", "")))
PY
)"
[[ -n "$PID" ]] || { err "manifest has no id"; exit 1; }
log "plugin id='$PID' name='$PNAME' command='$PLABEL'"

# ---------- helpers ----------
xd_running(){ pgrep -f "Adobe XD.app/Contents/MacOS" >/dev/null 2>&1; }

wait_xd(){
  log "waiting for XD to be running..."
  for _ in $(seq 1 40); do xd_running && { sleep 6; return 0; }; sleep 2; done
  err "XD did not start"; return 1
}

# returns the enabled state ("true"/"false") of the plugin command, or "missing"
cmd_state(){
  osascript 2>/dev/null <<APPLE || echo missing
tell application "System Events" to tell process "$PROC"
    try
        set pi to menu item "$PNAME" of menu "Plugins" of menu bar 1
        click pi
        delay 0.4
        set en to enabled of (menu item "$PLABEL" of menu 1 of pi)
        key code 53
        return en as text
    on error
        try
            key code 53
        end try
        return "missing"
    end try
end tell
APPLE
}

# ---------- 1. install ----------
if [[ "$TRIGGER_ONLY" -eq 0 ]]; then
  log "installing plugin into develop folder..."
  mkdir -p "$DEV_DIR/$PID"
  cp -f "$PLUGIN_SRC"/* "$DEV_DIR/$PID/"
fi

# ---------- 2. launch XD ----------
if ! xd_running; then
  log "launching XD..."
  open -a "$APP"
fi
wait_xd

# ---------- 3. reload plugins (legacy) ----------
if [[ "$TRIGGER_ONLY" -eq 0 ]]; then
  log "reloading plugins (legacy)..."
  osascript 2>/dev/null <<APPLE || true
tell application "$APP" to activate
delay 1
tell application "System Events" to tell process "$PROC"
    set devItem to menu item "Development" of menu "Plugins" of menu bar 1
    click devItem
    delay 0.5
    click menu item "Reload Plugins (Legacy)" of menu 1 of devItem
end tell
APPLE
  sleep 2
fi

# verify the command exists in the menu
st="$(cmd_state)"
[[ "$st" == "missing" ]] && { err "plugin command not found in Plugins menu (manifest/format issue?)"; exit 1; }
log "plugin command present (enabled=$st)"

# ---------- 4. create a document if needed ----------
if [[ "$DO_NEWDOC" -eq 1 && "$st" != "true" ]]; then
  log "no usable document — creating one via Home preset tile..."
  # cold-launched Home is CEF-rendered and may not be clickable immediately: retry
  for attempt in 1 2 3; do
    osascript 2>/dev/null -e "tell application \"$APP\" to activate" || true
    osascript 2>/dev/null <<APPLE || true
tell application "System Events" to tell process "$PROC"
    try
        click menu item "New" of menu "File" of menu bar 1
    end try
end tell
APPLE
    sleep 3
    BOUNDS="$(osascript -e "tell application \"System Events\" to tell process \"$PROC\" to get {position, size} of window 1" 2>/dev/null || echo '')"
    if [[ -n "$BOUNDS" ]]; then
      IFS=', ' read -r WX WY WW WH <<< "$BOUNDS"
      CX="$(python3 -c "print(int($WX + $PRESET_FX*$WW))")"
      CY="$(python3 -c "print(int($WY + $PRESET_FY*$WH))")"
      log "attempt $attempt: clicking preset tile at screen ($CX,$CY)..."
      python3 "$HERE/lib/click.py" "$CX" "$CY" >/dev/null
      sleep 4
    else
      err "could not read XD window bounds; is a window open?"
    fi
    for _ in $(seq 1 6); do
      st="$(cmd_state)"; [[ "$st" == "true" ]] && break; sleep 1
    done
    [[ "$st" == "true" ]] && break
    log "attempt $attempt: document not ready yet, retrying..."
  done
  [[ "$st" == "true" ]] || err "command still disabled after 3 tries (tune --preset-x/--preset-y for your screen)"
fi

# ---------- 5. trigger ----------
log "triggering: Plugins > $PNAME > $PLABEL"
PROOF="$UXP_DATA/$PID/PluginData/claude_xd_proof.txt"
rm -f "$PROOF" 2>/dev/null || true
osascript 2>/dev/null <<APPLE || true
tell application "$APP" to activate
delay 0.5
tell application "System Events" to tell process "$PROC"
    set pi to menu item "$PNAME" of menu "Plugins" of menu bar 1
    click pi
    delay 0.6
    click menu item "$PLABEL" of menu 1 of pi
end tell
APPLE

# ---------- 6. report + collect outputs ----------
sleep 2
PD="$UXP_DATA/$PID/PluginData"
if [[ -d "$PD" ]] && [[ -n "$(ls -A "$PD" 2>/dev/null)" ]]; then
  log "OK — plugin ran. PluginData output:"
  ls -la "$PD" | awk 'NR>1{print "    "$5"  "$NF}'
  # show any index/proof text
  for t in "$PD"/index.txt "$PD"/claude_xd_proof.txt; do
    [[ -f "$t" ]] && { echo "    ---- $(basename "$t") ----"; sed 's/^/    /' "$t"; echo; }
  done
  # collect to --out
  if [[ -n "$OUT" ]]; then
    mkdir -p "$OUT"
    cp -f "$PD"/* "$OUT"/ 2>/dev/null || true
    n=$(ls -1 "$OUT"/*.png 2>/dev/null | wc -l | tr -d ' ')
    log "collected $n PNG(s) + index into: $OUT"
  fi
else
  log "command fired, but no PluginData output found."
  log "(Check the plugin writes via fs.getDataFolder(); expected at $PD)"
fi

# ---------- cleanup ----------
if [[ "$TRIGGER_ONLY" -eq 0 && "$KEEP" -eq 0 ]]; then
  log "removing plugin (pass --keep to leave it installed)..."
  rm -rf "$DEV_DIR/$PID" "$UXP_DATA/$PID"
fi
log "done."
