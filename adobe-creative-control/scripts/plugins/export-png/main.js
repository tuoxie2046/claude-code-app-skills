/*
 * Batch-export every artboard in the current XD document to PNG.
 *
 * Files are written into the plugin data folder (no save dialog needed):
 *   ~/Library/Application Support/Adobe/UXP/PluginsStorage/SPRK/Developer/
 *     com.claude.xdexport/PluginData/<artboard>.png
 * plus an index.txt. The xd-auto.sh `--out <dir>` flag then copies them out.
 *
 * Tunables below: SCALE, and SEED_EMPTY (demo aid — labels blank artboards so
 * the test PNG isn't pure white; it is a safe no-op on real, populated docs).
 */
const application = require("application");
const scenegraph = require("scenegraph");
const { Artboard, Rectangle, Text, Color } = scenegraph;
const fs = require("uxp").storage.localFileSystem;

const SCALE = 2;          // 1 = 1x, 2 = @2x, 3 = @3x ...
const SEED_EMPTY = true;  // label empty artboards so demo output is visible (no-op on real docs)

async function exportPNG(selection, documentRoot) {
  const rootNode = documentRoot || scenegraph.root;

  // collect all artboards
  const artboards = [];
  rootNode.children.forEach((n) => { if (n instanceof Artboard) artboards.push(n); });

  // ---- demo seeding: must happen BEFORE any await (no scenegraph edits after await) ----
  if (SEED_EMPTY) {
    artboards.forEach((ab) => {
      if (ab.children.length === 0) {
        const r = new Rectangle();
        r.width = Math.max(40, Math.min(400, ab.width - 80));
        r.height = Math.max(20, Math.min(200, ab.height - 80));
        r.fill = new Color("#1E5AC8");
        ab.addChild(r);
        r.moveInParentCoordinates(40, 40);

        const t = new Text();
        t.text = ab.name;
        t.fontSize = 48;
        t.fill = new Color("#FFFFFF");
        ab.addChild(t);
        t.moveInParentCoordinates(60, 120);
      }
    });
  }

  // ---- build rendition settings (async file creation only; no scenegraph edits past here) ----
  const dataFolder = await fs.getDataFolder();
  const settings = [];
  const names = [];
  for (const ab of artboards) {
    const safe = (ab.name || ("artboard_" + settings.length)).replace(/[^\w.\-]+/g, "_");
    const file = await dataFolder.createFile(safe + ".png", { overwrite: true });
    settings.push({
      node: ab,
      outputFile: file,
      type: application.RenditionType.PNG,
      scale: SCALE,
    });
    names.push(safe + ".png");
  }

  let exported = 0;
  let errLine = "";
  try {
    if (settings.length > 0) {
      const results = await application.createRenditions(settings);
      exported = results.length;
    }
  } catch (e) {
    errLine = "\nERROR: " + e;
  }

  // index / proof file
  const idx = await dataFolder.createFile("index.txt", { overwrite: true });
  await idx.write(
    "exported=" + exported + " of " + artboards.length +
    " scale=" + SCALE +
    " at=" + new Date().toISOString() + "\n" +
    names.join("\n") + errLine
  );
}

module.exports = { commands: { exportPNG } };
