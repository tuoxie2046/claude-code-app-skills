#!/usr/bin/env bash
# Lightroom Classic automation via a Lua plugin (auto-loaded from the Modules
# folder) triggered from File > Plug-in Extras using System Events.
# (LR's AppleScript has no business verbs; the Lua SDK is the real surface.
#  Requires Accessibility permission for the controlling terminal.)
#
# Usage: lr-classic.sh /path/to/plugin.lrplugin "Menu Item Title"
#   The .lrplugin must declare an LrExportMenuItems entry whose title matches.
set -euo pipefail
PLUGIN="${1:?path to a .lrplugin folder}"
TITLE="${2:?the File>Plug-in Extras menu item title to click}"
[[ -d "$PLUGIN" ]] || { echo "no such plugin dir: $PLUGIN" >&2; exit 1; }
MOD="$HOME/Library/Application Support/Adobe/Lightroom/Modules"
mkdir -p "$MOD"
DEST="$MOD/$(basename "$PLUGIN")"
rm -rf "$DEST"; cp -R "$PLUGIN" "$DEST"
echo "installed plugin: $DEST"

open -a "Adobe Lightroom Classic"
echo "waiting for LR to finish launching (clear any catalog/sign-in dialog if it blocks)..."
for _ in $(seq 1 40); do pgrep -f "Adobe Lightroom Classic.app/Contents/MacOS" >/dev/null && break; sleep 2; done
sleep 25

# trigger File > Plug-in Extras > <title> via UI scripting.
# LR's File menu is dynamic and can throw "Invalid index" if iterated while it
# rebuilds — so use indexed access guarded by try, and retry the whole thing.
trigger_once(){
osascript <<APPLE
tell application "Adobe Lightroom Classic" to activate
delay 1
tell application "System Events" to tell process "Adobe Lightroom Classic"
    key code 53
    delay 0.3
    click menu bar item "File" of menu bar 1
    delay 0.6
    set fileMenu to menu "File" of menu bar 1
    set n to count of menu items of fileMenu
    repeat with i from 1 to n
        try
            set mi to menu item i of fileMenu
            set nm to name of mi
            if nm is not missing value and nm contains "Plug-in Extras" then
                click mi
                delay 0.7
                set sm to menu 1 of mi
                set m to count of menu items of sm
                repeat with j from 1 to m
                    try
                        set sub to menu item j of sm
                        set snm to name of sub
                        if snm is not missing value and snm contains "$TITLE" then
                            click sub
                            return "CLICKED:" & snm
                        end if
                    end try
                end repeat
            end if
        end try
    end repeat
    try
        key code 53
    end try
    return "NOTFOUND"
end tell
APPLE
}

for try in 1 2 3; do
  res="$(trigger_once 2>/dev/null || true)"
  echo "trigger attempt $try: $res"
  [[ "$res" == CLICKED:* ]] && break
  sleep 4
done

# NOTE: the plugin stays installed in the Modules folder and reloads on every LR
# launch. Remove it when done (and quit LR) unless you want it kept:
echo "cleanup when done:  rm -rf \"$DEST\""
