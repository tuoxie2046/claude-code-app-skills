---
name: adobe-creative-control
description: >
  Drive Adobe Creative Cloud desktop apps on macOS from the shell — Photoshop,
  Illustrator, InDesign, After Effects, Premiere Pro, Media Encoder, Acrobat,
  Animate, Lightroom Classic, Dreamweaver, and Adobe XD. Use when the user wants
  to automate, script, batch-process, or programmatically control any Adobe app:
  generate/edit images (PS/AI), lay out or export PDFs (InDesign/Acrobat), render
  video (After Effects aerender), transcode (Media Encoder), build/export Premiere
  projects, batch-export artboards from XD, run JSFL in Animate, run Lightroom
  Classic Lua plugins, execute Dreamweaver code, or live-control Character Animator
  via MIDI. Triggers: "automate Photoshop", "batch export", "render After Effects",
  "transcode with Media Encoder", "用 Photoshop/AE/XD 批量…", Adobe 自动化/脚本调用.
metadata:
  short-description: Drive Adobe CC desktop apps (PS/AI/ID/AE/Pr/AME/Acrobat/Animate/LrC/Dw/XD) from the shell
---

# Adobe Creative Control

Tested recipes to drive each installed Adobe app from a shell. All paths/versions
below were verified on this machine. Helper scripts live in `scripts/`.

Run `./selftest.sh` for a non-destructive health check (structure, syntax, arg
validation, plugin consistency, deps, and which hard-coded app versions are
installed) — it launches no Adobe app and exits non-zero on any failure.

## Capability matrix (what actually works)

| App | Channel | Helper | Headless? |
|-----|---------|--------|-----------|
| Photoshop | ExtendScript `do javascript` | `extendscript.sh photoshop x.jsx` | GUI launches; script runs unattended |
| Illustrator | ExtendScript `do javascript` | `extendscript.sh illustrator x.jsx` | same |
| After Effects | DoScriptFile + **`aerender` CLI** | `extendscript.sh aftereffects build.jsx` + `aerender.sh …` | aerender is true CLI |
| InDesign | `do script … language javascript` | `indesign.sh x.jsx` | GUI launches; unattended |
| Acrobat | AppleScript dictionary | `acrobat.sh '<applescript>'` | GUI launches |
| Animate | JSFL (open `.jsfl`) | `animate.sh x.jsfl` | GUI launches |
| Media Encoder | **BridgeTalk via PS relay** | `bridgetalk.sh ame payload.jsx` | GUI launches |
| Premiere Pro | **BridgeTalk via PS relay** | `bridgetalk.sh premierepro payload.jsx` | GUI launches |
| Lightroom Classic | Lua plugin + menu trigger (needs Accessibility) | `lr-classic.sh plug.lrplugin "Title"` | no (UI click) |
| Dreamweaver | Startup-folder auto-run (`dw`/`DWfile`) | `dreamweaver.sh code.js` | runs on launch |
| Adobe XD | UXP plugin (legacy manifest) + UI trigger | `xd-auto.sh --plugin … --out …` | no (UI click + Quartz) |
| Character Animator | **MIDI** live control | `charanim-midi.py note 72` | yes (after 1× GUI bind) |

Not drivable locally (cloud-only / gated — see `reference/capability-matrix.md`):
**Adobe Dimension** (DnCR cloud API, dormant) and **Lightroom CC** (lr.adobe.io
REST API, partner-gated). Their local apps have no automation entry point.

## Prerequisites
- Apps installed and signed in.
- For Lightroom/XD UI triggering and any System Events menu clicks: the terminal
  needs **Accessibility** permission (System Settings → Privacy & Security).
- `pip install --user pyobjc-framework-Quartz` (XD preset click), `mido python-rtmidi` (CharAnim).
- Write temporary `.jsx`/`.jsfl`/output files under the session scratchpad.

## How to use (per app)

### Photoshop / Illustrator (ExtendScript)
Write a `.jsx` using the app DOM, then:
```bash
scripts/extendscript.sh photoshop /tmp/job.jsx
```
PS: `app.documents.add(...)`, text layers, `doc.saveAs(file, new PNGSaveOptions(), true)`.
AI app name is **"Adobe Illustrator"** (no version suffix). Have the script
`doc.close(SaveOptions.DONOTSAVECHANGES)` and end with a status string.

### After Effects (build then render)
1. Build a project with a `.jsx` (`app.newProject`, `addComp`, `addText`, `proj.save(file)`):
   `scripts/extendscript.sh aftereffects /tmp/build.jsx`
2. Render headlessly:
   `scripts/aerender.sh -reuse -project /tmp/a.aep -comp "Main" -RStemplate "Best Settings" -OMtemplate "Lossless" -output /tmp/out.mov`

### InDesign
`.jsx` with `doc.exportFile(ExportFormat.PDF_TYPE, new File("/out.pdf"))`, then
`scripts/indesign.sh /tmp/job.jsx`.

### Media Encoder / Premiere (BridgeTalk)
The payload `.jsx` runs *inside* the target. Real API (reflected on-device):
- AME: `app.getFrontend().addFileToBatch(input, "H.264", presetPath, output); app.getEncoderHost().runBatch();`
  Presets: `/Applications/Adobe Media Encoder 2026/.../MediaIO/systempresets/.../*.epr`.
- Premiere (self-consistent — `newProject` first; bin = `rootItem`):
  `app.newProject(path); var root=app.project.rootItem; app.project.importFiles([f], true, root, false); var clip=root.children[0]; var s=app.project.createNewSequenceFromClips("S",[clip],root); app.encoder.encodeSequence(app.project.activeSequence, out, preset, app.encoder.ENCODE_ENTIRE, 1); app.encoder.startBatch();`
Run: `scripts/bridgetalk.sh ame /tmp/encode.jsx`  (or `premierepro`).

### Acrobat
`scripts/acrobat.sh 'open POSIX file "/in.pdf"
save active doc to (POSIX file "/out.pdf")'`

### Animate (JSFL)
`fl.createDocument(); ...; doc.exportPNG("file:///out.png", true, true);`
then `scripts/animate.sh /tmp/job.jsfl`.

### Lightroom Classic (Lua plugin)
Build a `.lrplugin` (Info.lua with `LrExportMenuItems`), then:
`scripts/lr-classic.sh /tmp/My.lrplugin "Export Selected"`.
See `reference/lr-plugin-template/`.

### Dreamweaver
Put `dw`/`DWfile` code in a `.js` and `scripts/dreamweaver.sh /tmp/code.js`
(installs a Startup .htm and relaunches DW; remove it afterwards to stop auto-run).

### Adobe XD (UXP plugin + batch export)
`scripts/xd-auto.sh --plugin scripts/plugins/export-png --no-doc --out ~/Desktop/out`
exports every artboard of the open document to PNG. Plugins use the **legacy**
manifest shape (no `manifestVersion`, `host.minVersion`="13.0.0") so no UXP
Developer Tool is needed. See the XD section in `reference/capability-matrix.md`.

### Character Animator (MIDI)
`pip install --user mido python-rtmidi`, bind a Trigger to a MIDI note in CharAnim
once, then `scripts/charanim-midi.py note 72` fires it (focus-independent).

## Cleanup discipline
GUI apps launched for automation should be quit when done (`osascript -e 'tell
application "<App>" to quit'`); decline save dialogs for throwaway docs. Remove any
installed plugin / Startup file unless the user wants it kept. Avoid full-screen
`screencapture` (may capture private windows) — capture a specific window region
via `-R x,y,w,h` from the window's AX bounds instead.
