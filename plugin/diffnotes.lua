if vim.g.loaded_diffnotes then
  return
end
vim.g.loaded_diffnotes = true

local diffnotes = require("diffnotes")

vim.api.nvim_create_user_command("DiffnotesOpen", function()
  diffnotes.open()
end, { desc = "Open diffview with diffnotes enabled" })

vim.api.nvim_create_user_command("DiffnotesClose", function()
  diffnotes.close()
end, { desc = "Close diffview" })

vim.api.nvim_create_user_command("DiffnotesExport", function()
  diffnotes.export()
end, { desc = "Export comments to clipboard" })

vim.api.nvim_create_user_command("DiffnotesPreview", function()
  diffnotes.preview()
end, { desc = "Preview exported markdown" })

vim.api.nvim_create_user_command("DiffnotesClear", function()
  diffnotes.clear()
end, { desc = "Clear all comments" })

vim.api.nvim_create_user_command("DiffnotesToggleLayout", function()
  diffnotes.toggle_layout()
end, { desc = "Cycle layout (horizontal/vertical)" })

vim.api.nvim_create_user_command("DiffnotesList", function()
  require("diffnotes.comments").list()
end, { desc = "List all comments in quickfix" })

vim.api.nvim_create_user_command("DiffnotesToggleReadonly", function()
  require("diffnotes").toggle_readonly()
end, { desc = "Toggle readonly/edit mode" })
