local M = {}

local store = require("review.store")
local config = require("review.config")

local ns_id = vim.api.nvim_create_namespace("review")

---Normalize a file path to match how comments are stored
---@param path string
---@return string
local function normalize_path(path)
  if not path then
    return path
  end
  -- Remove leading ./ if present
  path = path:gsub("^%./", "")
  -- Remove trailing slashes
  path = path:gsub("/+$", "")
  return path
end

---Get file path for a buffer using lifecycle API (consistent with hooks.get_cursor_position)
---@param bufnr number
---@return string|nil
local function get_file_for_buffer(bufnr)
  local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
  if not ok then
    return nil
  end

  local tabpage = vim.api.nvim_get_current_tabpage()
  local sess = lifecycle.get_session(tabpage)
  if not sess then
    return nil
  end

  local orig_path, mod_path = lifecycle.get_paths(tabpage)
  local orig_buf, mod_buf = lifecycle.get_buffers(tabpage)

  -- Determine which file based on buffer
  local file_path
  if bufnr == orig_buf then
    file_path = orig_path
  elseif bufnr == mod_buf then
    file_path = mod_path
  end

  if not file_path then
    return nil
  end

  -- Get relative path using git context
  local git_ctx = lifecycle.get_git_context(tabpage)
  if git_ctx and git_ctx.git_root then
    local abs_path = vim.fn.fnamemodify(file_path, ":p")
    local rel_path = abs_path:gsub("^" .. vim.pesc(git_ctx.git_root) .. "/", "")
    return normalize_path(rel_path)
  end

  return normalize_path(vim.fn.fnamemodify(file_path, ":."))
end

---@param bufnr number
function M.render_for_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Try to get file path from lifecycle API first (consistent with hooks.get_cursor_position)
  local file = get_file_for_buffer(bufnr)

  -- Fallback to buffer name parsing if lifecycle API fails
  if not file then
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if not bufname or bufname == "" then
      return
    end

    -- Extract file path, handling codediff:// virtual buffers
    if bufname:match("^codediff://") then
      -- Virtual buffer: extract path from URI
      -- Format: codediff://repo/path/to/file.lua?rev=xxx
      local path = bufname:match("^codediff://[^/]+/(.+)%?") or bufname:match("^codediff://[^/]+/(.+)$")
      if path then
        file = normalize_path(path)
      end
    else
      file = normalize_path(vim.fn.fnamemodify(bufname, ":."))
    end
  end

  if not file then
    return
  end

  local comments = store.get_for_file(file)

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local cfg = config.get()

  for _, comment in ipairs(comments) do
    local type_info = cfg.comment_types[comment.type]
    local icon = type_info and type_info.icon or "●"
    local hl = type_info and type_info.hl or "ReviewSign"
    local line_hl = type_info and type_info.line_hl
    local name = type_info and type_info.name or comment.type

    local line = comment.line - 1
    if line >= 0 then
      local virt_lines = {}
      local text_lines = vim.split(comment.text, "\n")

      -- Calculate max text width for box sizing (using display width)
      local max_text_width = 0
      for _, text_line in ipairs(text_lines) do
        max_text_width = math.max(max_text_width, vim.fn.strdisplaywidth(text_line))
      end
      local header_text = string.format("[%s]", string.upper(name))
      local content_width = math.max(max_text_width, 20)

      -- Top border: ╭─[NOTE]───────────────────────╮
      local top_dashes = content_width - vim.fn.strdisplaywidth(header_text) + 1
      local top_line = "╭─" .. header_text .. string.rep("─", top_dashes) .. "╮"
      table.insert(virt_lines, { { top_line, hl } })

      -- Content lines: │ text                        │
      for _, text_line in ipairs(text_lines) do
        local text_width = vim.fn.strdisplaywidth(text_line)
        local padding = content_width - text_width
        local content = "│ " .. text_line .. string.rep(" ", padding) .. " │"
        table.insert(virt_lines, { { content, hl } })
      end

      -- Bottom border: ╰─────────────────────────────╯
      local bottom = "╰" .. string.rep("─", content_width + 2) .. "╯"
      table.insert(virt_lines, { { bottom, hl } })

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
  local ok, hooks = pcall(require, "review.hooks")
  if not ok then
    return
  end

  local orig_buf, mod_buf = hooks.get_buffers()
  if orig_buf then
    M.render_for_buffer(orig_buf)
  end
  if mod_buf then
    M.render_for_buffer(mod_buf)
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
