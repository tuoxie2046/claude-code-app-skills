#!/usr/bin/env bash
# Drive Media Encoder ("ame") or Premiere Pro ("premierepro") by injecting an
# ExtendScript via BridgeTalk, relayed through Photoshop (a live BridgeTalk node).
#
# Why a relay: ame/premierepro accept BridgeTalk but we send from a scriptable
# host. PS is driven by `do javascript`, and PS forwards via BridgeTalk.
#
# NOTE: Dreamweaver's "dreamweaver" target is registered but DEAD
#       (ERROR: TARGET COULD NOT BE LAUNCHED) and Character Animator's
#       "character" target connects but does not evaluate scripts — neither works here.
#
# Usage: bridgetalk.sh ame|premierepro /path/payload.jsx
#   The payload runs INSIDE the target app's ExtendScript engine.
set -euo pipefail
TARGET="${1:?target: ame|premierepro}"
PAYLOAD="${2:?path to payload .jsx (runs inside target)}"

# validate the target enum BEFORE checking the file, so the error names the real problem
case "$TARGET" in
  ame)         APP="Adobe Media Encoder 2026";;
  premierepro) APP="Adobe Premiere Pro 2026";;
  *) echo "unknown target: $TARGET (ame|premierepro)" >&2; exit 1;;
esac

[[ -f "$PAYLOAD" ]] || { echo "no such file: $PAYLOAD" >&2; exit 1; }

# ensure both target app and the PS relay are running
open -a "$APP"
open -a "Adobe Photoshop 2026"
for _ in $(seq 1 50); do
  r1=$(pgrep -f "$APP.app/Contents/MacOS" | wc -l)
  r2=$(pgrep -f "Adobe Photoshop 2026.app/Contents/MacOS" | wc -l)
  [[ "$r1" -ge 1 && "$r2" -ge 1 ]] && break
  sleep 2
done
# Premiere is much slower to become BridgeTalk-ready on a cold start than AME.
case "$TARGET" in
  premierepro) sleep 30;;
  *)           sleep 12;;
esac

# launcher: PS sends BridgeTalk to the target, body = $.evalFile(payload)
TMP="$(mktemp /tmp/bt_launch.XXXXXX.jsx)"
cat > "$TMP" <<JSX
var bt = new BridgeTalk();
bt.target = "$TARGET";
bt.body = '\$.evalFile("$PAYLOAD")';
bt.send();
"SENT_to_$TARGET";
JSX
osascript -e "tell application \"Adobe Photoshop 2026\" to do javascript of file \"$TMP\""
rm -f "$TMP"
