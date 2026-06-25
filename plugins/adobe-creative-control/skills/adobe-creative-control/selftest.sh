#!/usr/bin/env bash
#
# selftest.sh — non-destructive self-check for the adobe-creative-control skill.
#
# Verifies file structure, shell/python syntax, argument validation, XD plugin
# consistency, optional dependencies, and which hard-coded Adobe app versions are
# actually installed — WITHOUT launching any Adobe app.
#
# Exit code: 0 if all hard checks pass, 1 if any FAIL (WARN does not fail).
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/scripts"
pass=0; fail=0; warn=0
ok(){ printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
no(){ printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
wn(){ printf '  \033[33mWARN\033[0m %s\n' "$1"; warn=$((warn+1)); }

echo "== files present & executable =="
for f in extendscript indesign bridgetalk aerender acrobat animate dreamweaver lr-classic xd-auto; do
  [[ -x "$S/$f.sh" ]] && ok "$f.sh" || no "$f.sh missing or not executable"
done
[[ -x "$S/charanim-midi.py" ]] && ok "charanim-midi.py" || no "charanim-midi.py missing"
[[ -x "$S/lib/click.py" ]] && ok "lib/click.py" || no "lib/click.py missing"

echo "== bash syntax =="
for f in "$S"/*.sh "$HERE/selftest.sh"; do
  bash -n "$f" 2>/dev/null && ok "syntax $(basename "$f")" || no "syntax $(basename "$f")"
done

echo "== python syntax =="
for f in "$S"/*.py "$S"/lib/*.py; do
  python3 -m py_compile "$f" 2>/dev/null && ok "pycompile $(basename "$f")" || no "pycompile $(basename "$f")"
done

echo "== argument validation (must reject cleanly, no app launch) =="
# expect_err <desc> <stderr-substring> <cmd...> : command must exit!=0 and stderr contain substring
expect_err(){
  local desc="$1" sub="$2"; shift 2
  local out rc
  out="$("$@" 2>&1 >/dev/null)"; rc=$?
  if [[ $rc -ne 0 && "$out" == *"$sub"* ]]; then ok "$desc"
  else no "$desc (rc=$rc, out='$out')"; fi
}
expect_err "extendscript rejects bad app"       "unknown app"       "$S/extendscript.sh" __bad__ /tmp/x.jsx
expect_err "extendscript rejects missing jsx"   "no such file"      "$S/extendscript.sh" photoshop "/tmp/nope.$$.jsx"
expect_err "bridgetalk rejects bad target"      "unknown target"    "$S/bridgetalk.sh" __bad__ /tmp/x.jsx
expect_err "bridgetalk rejects missing payload" "no such file"      "$S/bridgetalk.sh" ame "/tmp/nope.$$.jsx"
expect_err "indesign rejects missing jsx"       "no such file"      "$S/indesign.sh" "/tmp/nope.$$.jsx"
expect_err "animate rejects missing jsfl"       "no such file"      "$S/animate.sh" "/tmp/nope.$$.jsfl"
expect_err "lr-classic rejects missing plugin"  "no such plugin"    "$S/lr-classic.sh" "/tmp/nope.$$.lrplugin" Title
expect_err "xd-auto rejects unknown flag"       "unknown arg"       "$S/xd-auto.sh" --bogus

echo "== xd-auto --help is clean (no shebang leak) =="
h1="$("$S/xd-auto.sh" --help 2>/dev/null | grep -m1 . )"
[[ "$h1" != *"/usr/bin/env"* ]] && ok "help has no shebang" || no "help leaks shebang: '$h1'"

echo "== XD plugin consistency (commandId <-> export, legacy manifest) =="
for p in demo export-png; do
  m="$S/plugins/$p/manifest.json"; j="$S/plugins/$p/main.js"
  if [[ -f "$m" && -f "$j" ]]; then
    cid="$(python3 -c "import json;print(json.load(open('$m'))['uiEntryPoints'][0]['commandId'])" 2>/dev/null || echo '')"
    if [[ -n "$cid" ]] && grep -Eq "commands:[[:space:]]*\{[[:space:]]*$cid\b" "$j"; then
      ok "$p: commandId '$cid' is exported"
    else
      no "$p: commandId '$cid' not found in main.js commands"
    fi
    if python3 -c "import json,sys; d=json.load(open('$m')); sys.exit(1 if 'manifestVersion' in d else 0)" 2>/dev/null; then
      ok "$p: legacy manifest (no manifestVersion)"
    else
      no "$p: manifest has manifestVersion (won't load via Reload Plugins Legacy)"
    fi
  else
    no "$p: manifest.json/main.js missing"
  fi
done

echo "== SKILL.md referenced paths exist =="
for ref in "SKILL.md" "reference/capability-matrix.md" "reference/lr-plugin-template" "scripts/plugins/export-png" "scripts/lib/click.py"; do
  [[ -e "$HERE/$ref" ]] && ok "exists: $ref" || no "missing: $ref"
done

echo "== optional dependencies =="
command -v python3 >/dev/null && ok "python3 present" || no "python3 missing (required)"
python3 -c 'import Quartz' 2>/dev/null && ok "pyobjc Quartz (XD click)" || wn "pyobjc Quartz missing — XD preset click needs it: pip install --user pyobjc-framework-Quartz"
python3 -c 'import mido, rtmidi' 2>/dev/null && ok "mido+rtmidi (CharAnim MIDI)" || wn "mido/python-rtmidi missing — CharAnim MIDI needs them: pip install --user mido python-rtmidi"

echo "== installed Adobe apps (hard-coded names this skill targets) =="
# WARN (not FAIL) when absent: versions are hard-coded for this machine; edit the
# scripts if your installed version differs.
BUNDLES=(
  "Adobe Photoshop 2026/Adobe Photoshop 2026.app"
  "Adobe Illustrator 2026/Adobe Illustrator.app"
  "Adobe InDesign 2026/Adobe InDesign 2026.app"
  "Adobe After Effects 2026/Adobe After Effects 2026.app"
  "Adobe After Effects 2026/aerender"
  "Adobe Media Encoder 2026/Adobe Media Encoder 2026.app"
  "Adobe Premiere Pro 2026/Adobe Premiere Pro 2026.app"
  "Adobe Acrobat DC/Adobe Acrobat.app"
  "Adobe Animate 2024/Adobe Animate 2024.app"
  "Adobe Lightroom Classic/Adobe Lightroom Classic.app"
  "Adobe Dreamweaver 2021/Adobe Dreamweaver 2021.app"
  "Adobe XD/Adobe XD.app"
  "Adobe Character Animator 2026/Adobe Character Animator 2026.app"
)
for b in "${BUNDLES[@]}"; do
  if [[ -e "/Applications/$b" ]]; then ok "installed: ${b%%/*}"
  else wn "not found: /Applications/$b (edit the matching script if your version differs)"; fi
done

echo
echo "================ summary: $pass PASS, $warn WARN, $fail FAIL ================"
[[ "$fail" -eq 0 ]]
