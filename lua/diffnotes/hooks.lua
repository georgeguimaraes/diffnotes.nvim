local M = {}

local marks = require("diffnotes.marks")
local config = require("diffnotes.config")

---@type table|nil
local current_view = nil

---@return table|nil
function M.get_current_view()
  return current_view
end

---@return table|nil file entry, number|nil window id
function M.get_current_file()
  if not current_view then
    return nil, nil
  end

  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return nil, nil
  end

  local view = lib.get_current_view()
  if not view then
    return nil, nil
  end

  local entry = view.cur_entry
  if not entry then
    return nil, nil
  end

  local layout = view.cur_layout
  local win_id = nil
  if layout then
    local main_win = layout:get_main_win()
    if main_win then
      win_id = main_win.id
    end
  end

  return entry, win_id
end

---@return string|nil file path
---@return number|nil line number
function M.get_cursor_position()
  local entry, win_id = M.get_current_file()
  if not entry then
    return nil, nil
  end

  local cursor
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    cursor = vim.api.nvim_win_get_cursor(win_id)
  else
    cursor = vim.api.nvim_win_get_cursor(0)
  end

  return entry.path, cursor[1]
end

function M.on_view_opened(view)
  current_view = view
end

function M.on_view_closed()
  current_view = nil
end

function M.on_diff_buf_read(bufnr)
  marks.render_for_buffer(bufnr)

  -- Make diff buffers read-only if configured
  local cfg = config.get()
  if cfg.diffview.readonly and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
  end
end

---@return table diffview hooks config
function M.get_diffview_hooks()
  return {
    view_opened = function(view)
      M.on_view_opened(view)
    end,
    view_closed = function()
      M.on_view_closed()
    end,
    diff_buf_read = function(bufnr)
      M.on_diff_buf_read(bufnr)
    end,
  }
end

return M
