/*
 * Demo XD UXP plugin (legacy manifest format so XD's built-in
 * "Reload Plugins (Legacy)" loads it without the UXP Developer Tool).
 *
 * On trigger it:
 *   1. adds a blue rectangle to the current document (proves scenegraph access)
 *   2. writes a proof file into the plugin data folder (proves fs access)
 *
 * Replace the body of claudeRun() with whatever you want to automate.
 */
const { Rectangle, Color } = require("scenegraph");
const fs = require("uxp").storage.localFileSystem;

async function claudeRun(selection) {
  const log = [];

  // 1) scenegraph edit — needs an open document (command is greyed out otherwise)
  try {
    const rect = new Rectangle();
    rect.width = 200;
    rect.height = 100;
    rect.fill = new Color("#1E5AC8");
    if (selection && selection.insertionParent) {
      selection.insertionParent.addChild(rect);
      rect.moveInParentCoordinates(80, 80);
      log.push("rect_added=yes");
    } else {
      log.push("rect_added=no_doc");
    }
  } catch (e) {
    log.push("rect_err=" + e);
  }

  // 2) write a proof file into the plugin data folder
  try {
    const dataFolder = await fs.getDataFolder();
    const f = await dataFolder.createFile("claude_xd_proof.txt", { overwrite: true });
    await f.write(
      "XD_PLUGIN_RAN " + log.join(" ") +
      " at=" + new Date().toISOString() +
      " path=" + (dataFolder.nativePath || "?")
    );
  } catch (e) {
    // swallow — nothing else we can do from here
  }
}

module.exports = { commands: { claudeRun } };
