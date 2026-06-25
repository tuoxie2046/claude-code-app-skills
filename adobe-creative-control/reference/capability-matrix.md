# Adobe automation — full capability matrix & gotchas

Verified on macOS (Apple Silicon) with CC 2026-era apps. "Headless" = runs without
a human clicking; most GUI apps still launch on screen but execute unattended.

## Channels by app

### ExtendScript injection (strongest)
- **Photoshop** — `osascript -e 'tell application "Adobe Photoshop 2026" to do javascript of file "x.jsx"'`. Has an `.sdef` too.
- **Illustrator** — same, app name **"Adobe Illustrator"** (NO version suffix, or you get "Unable to find application").
- **After Effects** — `DoScriptFile "x.jsx"` to build; **`aerender` CLI** to render (true headless). `app.newProject` exists but is NOT in `reflect.methods`.

### InDesign
- `do script (POSIX file "x.jsx") language javascript`.

### BridgeTalk (the backdoor for AME & Premiere)
- `BridgeTalk.getTargets()` (run inside PS) lists: `indesign, character, flash, photoshop, ame, dreamweaver, illustrator, aftereffects, premierepro`.
- **Listed ≠ usable.** Only targets that *evaluate and return* work: `ame`, `premierepro`, plus the ExtendScript apps.
- **ame** — `app.getFrontend().addFileToBatch(file, "H.264", presetPath, out)` (4-arg!) + `app.getEncoderHost().runBatch()`. Old docs' `app.encoder`/`app.bind` DO NOT exist here; events are `addEventListener`. Formats via `getEncoderHost().getFormatList()` (27: H.264, HEVC, ProRes, GIF, PNG, …).
- **premierepro** — full project API (`newProject`, `importFiles`, `createNewSequenceFromClips`, `encodeSequence`). Must `newProject` first (Home screen has a stub project where `importFiles` returns false); target bin = `rootItem`, not `getInsertionBin()` (null).
- **dreamweaver** — target is DEAD: `ERROR: TARGET COULD NOT BE LAUNCHED`.
- **character** (Character Animator) — connects but never returns (no ExtendScript engine).

### Acrobat
- AppleScript dictionary (`Acrobat.sdef`): open / save / window props. Mac AS is limited vs Windows.

### Animate
- Not AppleScript-scriptable. Automation = **JSFL**: `open -a "Adobe Animate 2024" script.jsfl` runs it. `fl.*` API; `file://` URIs.

### Lightroom Classic
- AppleScript dictionary is empty of business verbs (only `version`/`name`). Returns 15.x.
- Real surface = **Lua Plugin SDK**. Plugins in `~/Library/Application Support/Adobe/Lightroom/Modules/` auto-load and register `File > Plug-in Extras` items. Trigger via System Events (needs **Accessibility**). `LrInitPlugin` auto-run is unreliable; menu trigger is solid.

### Dreamweaver
- NOT ExtendScript (`dw`/`DWfile` own engine). BridgeTalk dead. No AppleScript.
- Works: **Startup folder** `~/Library/Application Support/Adobe/Dreamweaver 2021/en_US/Configuration/Startup/*.htm` auto-runs JS on launch. Also Commands menu (`<config>/Commands/*.js` → Tools>Commands) + System Events. `dreamweaver://` URL scheme exists but is for CC licensing, not commands.

### Adobe XD
- No ExtendScript/AppleScript/BridgeTalk. Only **UXP plugins**, triggered by a Plugins-menu click (no headless run).
- Loading a custom plugin **without** the UXP Developer Tool: put it in
  `~/Library/Application Support/Adobe/Adobe XD/develop/<id>/` with a **LEGACY** manifest
  (NO `manifestVersion`; `host.minVersion`="13.0.0"), then `Plugins > Development > Reload Plugins (Legacy)`.
  UXP v4 manifests do NOT load this way. `UnifiedPluginInstallerAgent --install` reports success but XD won't show it.
- Plugin menu commands are **disabled until a document is open**. Home preset tiles are CEF (AX-invisible) → create a doc via a **Quartz coordinate click** computed from window bounds.
- Plugin file output (`fs.getDataFolder()`) lands in `~/Library/Application Support/Adobe/UXP/PluginsStorage/SPRK/Developer/<id>/PluginData/`.
- XD is in maintenance mode (removed from sale 2023); mechanism is frozen but works.

### Character Animator
- No scripting engine at all. One external channel = **MIDI** (notes/CC → bound Triggers/behaviors), focus-independent. Use a virtual MIDI port (`python-rtmidi`) or the macOS IAC Driver. Keyboard triggers only fire when focused; MIDI does not require focus. No headless render (the internal "Ch Headless" is Dynamic-Link only).

## Cloud-only / gated (local apps NOT drivable)

### Adobe Dimension
- Zero local hooks (no ExtendScript/AppleScript/CEP/UXP/CLI/SDK/URL scheme).
- Only headless path: **DnCR cloud render API** `POST https://dncr.adobe.io/v1/variation/render` (signed `.dn` URL, OAuth + `x-api-key`). Docs frozen since 2019, whitelist-only, no public credential path → effectively dead. For real 3D render automation use the **Substance 3D** toolchain (`sbsrender`).

### Lightroom CC (cloud app, com.adobe.lightroomCC ≠ Classic)
- Local app sealed (`NSAppleScriptEnabled=false`, no BridgeTalk, no Plug-in Manager; the `adobelightroom://` scheme is not an automation API).
- Programmatic access = **Lightroom REST API** `https://lr.adobe.io/v2/...` (catalogs/albums/assets, upload/download renditions, XMP develop). Auth: Adobe IMS OAuth + `X-API-Key`, scopes `lr_partner_apis`/`lr_partner_rendition_apis`. **Partner-gated** — "Lightroom Services" in the Developer Console is greyed out for non-allowlisted accounts. Not a personal-automation route.

## Permissions reality
- `osascript`/System Events UI scripting needs **Accessibility**; `screencapture` of the
  full screen needs **Screen Recording**. Grant to the controlling terminal. Without
  Accessibility, all menu-trigger paths (LR, XD, DW Commands) fail with
  "osascript is not allowed assistive access".
- Prefer per-window region capture `screencapture -R x,y,w,h` (from AX window bounds)
  over full-screen to avoid capturing unrelated/private windows.
