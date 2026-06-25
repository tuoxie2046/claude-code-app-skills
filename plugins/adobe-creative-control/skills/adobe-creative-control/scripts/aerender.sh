#!/usr/bin/env bash
# After Effects headless render via the aerender CLI (no GUI scripting needed).
# Passes all args straight through to aerender.
#
# Example:
#   aerender.sh -reuse -project a.aep -comp "Main" -RStemplate "Best Settings" \
#               -OMtemplate "Lossless" -output out.mov
#
# Tip: aerender ignores your output extension and uses the chosen output module
#      (e.g. "Lossless" -> .mov). Build .aep first via extendscript.sh aftereffects.
set -euo pipefail
AERENDER="/Applications/Adobe After Effects 2026/aerender"
[[ -x "$AERENDER" ]] || { echo "aerender not found at $AERENDER" >&2; exit 1; }
exec "$AERENDER" "$@"
