local LrApplication = import 'LrApplication'
local LrExportSession = import 'LrExportSession'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
LrTasks.startAsyncTask(function()
  local cat = LrApplication.activeCatalog()
  local photos = cat:getTargetPhotos()          -- current selection
  local out = LrPathUtils.child(LrPathUtils.getStandardFilePath('desktop'), 'ClaudeLRExport')
  local s = LrExportSession {
    photosToExport = photos,
    exportSettings = {
      LR_export_destinationType = 'specificFolder',
      LR_export_destinationPathPrefix = out,
      LR_format = 'JPEG', LR_jpeg_quality = 0.9,
      LR_size_doConstrain = true, LR_size_maxWidth = 2048, LR_size_maxHeight = 2048,
    },
  }
  s:doExportOnCurrentTask()
end)
