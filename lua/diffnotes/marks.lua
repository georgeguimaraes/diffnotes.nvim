local M = {}

local store = require("diffnotes.store")
local config = require("diffnotes.config")

local ns_id = vim.api.nvim_create_namespace("diffnotes")

---@param bufnr number
function M.render_for_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if not bufname or bufname == "" then
    return
  end

  local file = vim.fn.fnamemodify(bufname, ":.")
  local comments = store.get_for_file(file)

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local cfg = config.get()

  for _, comment in ipairs(comments) do
    local type_info = cfg.comment_types[comment.type]
    local icon = type_info and type_info.icon or "●"
    local hl = type_info and type_info.hl or "DiffnotesSign"
    local line_hl = type_info and type_info.line_hl
    local name = type_info and type_info.name or comment.type

    local line = comment.line - 1
    if line >= 0 then
      -- Build virtual lines for the comment
      local virt_lines = {}
      local header = string.format(" %s %s: ", icon, name)

      -- Split comment text into lines if it's multiline
      local text_lines = vim.split(comment.text, "\n")
      for i, text_line in ipairs(text_lines) do
        if i == 1 then
          table.insert(virt_lines, { { header .. text_line, hl } })
        else
          table.insert(virt_lines, { { string.rep(" ", #header) .. text_line, hl } })
        end
      end

      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns_id, line, 0, {
        sign_text = icon,
        sign_hl_group = hl,
        line_hl_group = line_hl,
        virt_lines = virt_lines,
        virt_lines_above = false,
      })
    end
  end
end

function M.refresh()
  local ok, lib = pcall(require, "diffview.lib")
  if not ok then
    return
  end

  local view = lib.get_current_view()
  if not view or not view.cur_layout then
    return
  end

  local layout = view.cur_layout
  local wins = { layout.a, layout.b, layout.c, layout.d }

  for _, win in ipairs(wins) do
    if win and win.file and win.file.bufnr then
      M.render_for_buffer(win.file.bufnr)
    end
  end
end

function M.clear_all()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    end
  end
end

return M
