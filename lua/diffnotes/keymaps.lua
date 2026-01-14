local M = {}

local config = require("diffnotes.config")
local comments = require("diffnotes.comments")
local export = require("diffnotes.export")

---@return table[] diffview keymap entries for view buffers
function M.get_diffview_keymaps()
  local cfg = config.get()
  local km = cfg.keymaps
  local readonly = cfg.diffview.readonly

  local keymaps = {}

  -- Simple keymaps (always available in readonly mode)
  if readonly then
    -- i for add with menu
    table.insert(keymaps, {
      "n", "i",
      function() comments.add_with_menu() end,
      { desc = "Add comment (pick type)" },
    })
    -- d for delete
    table.insert(keymaps, {
      "n", "d",
      function() comments.delete_at_cursor() end,
      { desc = "Delete comment" },
    })
    -- e for edit
    table.insert(keymaps, {
      "n", "e",
      function() comments.edit_at_cursor() end,
      { desc = "Edit comment" },
    })
  end

  -- <leader>c* keymaps (in edit mode, or as alternatives)
  if not readonly then
    table.insert(keymaps, {
      "n", km.add_note,
      function() comments.add_at_cursor("note") end,
      { desc = "Add note comment" },
    })
    table.insert(keymaps, {
      "n", km.add_suggestion,
      function() comments.add_at_cursor("suggestion") end,
      { desc = "Add suggestion comment" },
    })
    table.insert(keymaps, {
      "n", km.add_issue,
      function() comments.add_at_cursor("issue") end,
      { desc = "Add issue comment" },
    })
    table.insert(keymaps, {
      "n", km.add_praise,
      function() comments.add_at_cursor("praise") end,
      { desc = "Add praise comment" },
    })
    table.insert(keymaps, {
      "n", km.delete_comment,
      function() comments.delete_at_cursor() end,
      { desc = "Delete comment" },
    })
    table.insert(keymaps, {
      "n", km.edit_comment,
      function() comments.edit_at_cursor() end,
      { desc = "Edit comment" },
    })
  end

  -- Common keymaps (always available)
  table.insert(keymaps, {
    "n", "c",
    function() comments.list() end,
    { desc = "List all comments" },
  })
  table.insert(keymaps, {
    "n", km.next_comment,
    function() comments.goto_next() end,
    { desc = "Go to next comment" },
  })
  table.insert(keymaps, {
    "n", km.prev_comment,
    function() comments.goto_prev() end,
    { desc = "Go to previous comment" },
  })
  table.insert(keymaps, {
    "n", km.export,
    function() export.to_clipboard() end,
    { desc = "Export comments to clipboard" },
  })

  -- Layout toggle: simple 't' in readonly mode, configurable otherwise
  local layout_key = readonly and "t" or km.toggle_layout
  table.insert(keymaps, {
    "n", layout_key,
    function() require("diffnotes").toggle_layout() end,
    { desc = "Cycle layout (horizontal/vertical)" },
  })

  table.insert(keymaps, {
    "n", "q",
    function() vim.cmd("DiffviewClose") end,
    { desc = "Close diffview" },
  })

  -- Toggle readonly/edit mode
  table.insert(keymaps, {
    "n", "R",
    function() require("diffnotes").toggle_readonly() end,
    { desc = "Toggle readonly/edit mode" },
  })

  -- Tab/S-Tab to switch files and stay in diff view
  table.insert(keymaps, {
    "n", "<Tab>",
    function()
      local actions = require("diffview.actions")
      actions.select_next_entry()
      vim.defer_fn(function()
        actions.focus_entry()
      end, 10)
    end,
    { desc = "Next file" },
  })
  table.insert(keymaps, {
    "n", "<S-Tab>",
    function()
      local actions = require("diffview.actions")
      actions.select_prev_entry()
      vim.defer_fn(function()
        actions.focus_entry()
      end, 10)
    end,
    { desc = "Previous file" },
  })

  return keymaps
end

return M
