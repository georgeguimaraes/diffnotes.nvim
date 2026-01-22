local M = {}

local config = require("review.config")
local store = require("review.store")
local export = require("review.export")
local review = require("review")

local id_marker_prefix = "<!--r:id="
local id_marker_suffix = "-->"

---@return string|nil
local function get_git_root()
  local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result ~= "" then
      return result:gsub("%s+$", "")
    end
  end
  return nil
end

---@return string|nil
local function get_export_path()
  local cfg = config.get().export.file
  if not cfg or not cfg.enabled then
    return nil
  end

  local git_root = get_git_root()
  if not git_root then
    return nil
  end

  local dir = cfg.dir or "."
  if not dir or dir == "" then
    dir = "."
  end

  local base
  if dir:sub(1, 1) == "/" then
    base = dir
  else
    base = git_root .. "/" .. dir
  end

  local filename = cfg.filename or "CODE_REVIEW.md"
  return base .. "/" .. filename
end

---@param path string
---@return boolean
local function ensure_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir == "" then
    return false
  end
  local ok, err = pcall(vim.fn.mkdir, dir, "p")
  if not ok then
    vim.notify("Failed to create directory: " .. dir .. " (" .. tostring(err) .. ")", vim.log.levels.ERROR, { title = "Review" })
    return false
  end
  return true
end

---@param path string
---@return string
local function normalize_path(path)
  if not path then
    return path
  end
  path = path:gsub("^%./", "")
  path = path:gsub("/+$", "")
  return path
end

---@param line string
---@return string|nil
---@return string
local function extract_id(line)
  local id = nil
  local start_pos = line:find(id_marker_prefix, 1, true)
  if not start_pos then
    return nil, line
  end

  local end_pos = line:find(id_marker_suffix, start_pos + #id_marker_prefix, true)
  if not end_pos then
    return nil, line
  end

  local id_start = start_pos + #id_marker_prefix
  local id_end = end_pos - 1
  if id_start <= id_end then
    id = line:sub(id_start, id_end)
  end

  local cleaned = line:sub(1, start_pos - 1):gsub("%s+$", "")
  return id, cleaned
end

---@param type_str string
---@return string|nil
local function normalize_type(type_str)
  local t = type_str:lower()
  if t == "note" or t == "suggestion" or t == "issue" or t == "praise" then
    return t
  end
  return nil
end

---@param path_with_line string
---@return string|nil
---@return number|nil
local function split_path_line(path_with_line)
  local path, line_str = path_with_line:match("^(.*):(%d+)$")
  if not path or not line_str then
    return nil, nil
  end
  local line_num = tonumber(line_str)
  if not line_num then
    return nil, nil
  end
  return path, line_num
end

---@param line string
---@return table|nil
local function parse_comment_line(line)
  local id, cleaned = extract_id(line)

  local type_str = cleaned:match("%*%*%[([^%]]+)%]%*%*")
  if not type_str then
    return nil
  end

  local normalized_type = normalize_type(type_str)
  if not normalized_type then
    return nil
  end

  local loc = cleaned:match("`([^`]+)`")
  if not loc then
    return nil
  end

  local file, line_num = split_path_line(loc)
  if not file or not line_num then
    return nil
  end

  local text = cleaned:match(" %- (.+)$")
  if not text or text == "" then
    return nil
  end

  local comment_id = id or store.generate_id()

  return {
    id = comment_id,
    file = normalize_path(file),
    line = line_num,
    type = normalized_type,
    text = text,
    created_at = os.time(),
  }
end

---@param comments table<string, table>
---@param comment table
local function add_comment(comments, comment)
  if not comments[comment.file] then
    comments[comment.file] = {}
  end
  table.insert(comments[comment.file], comment)
end

---@param path string
---@return table<string, table>
local function parse_file(path)
  local file = io.open(path, "r")
  if not file then
    return {}
  end

  local comments = {}
  for line in file:lines() do
    local comment = parse_comment_line(line)
    if comment then
      add_comment(comments, comment)
    end
  end

  file:close()
  return comments
end

---@return boolean
function M.load_into_store()
  local path = get_export_path()
  if not path then
    return false
  end

  local stat = vim.loop.fs_stat(path)
  if not stat then
    return false
  end

  local comments = parse_file(path)
  store.replace_all(comments)
  return true
end

---@param include_ids boolean
---@return string
local function generate_markdown(include_ids)
  local all_comments = store.get_all()

  if #all_comments == 0 then
    return "No comments yet."
  end

  local lines = {}
  table.insert(lines, "I reviewed your code and have the following comments. Please address them.")
  table.insert(lines, "")
  table.insert(lines, "Comment types: ISSUE (problems to fix), SUGGESTION (improvements), NOTE (observations), PRAISE (positive feedback)")
  table.insert(lines, "")

  for i, comment in ipairs(all_comments) do
    local type_name = string.upper(comment.type)
    local line = string.format("%d. **[%s]** `%s:%d` - %s", i, type_name, comment.file, comment.line, comment.text)
    if include_ids then
      line = line .. " " .. id_marker_prefix .. comment.id .. id_marker_suffix
    end
    table.insert(lines, line)
  end

  return table.concat(lines, "\n")
end

---@param opts? { copy: boolean, close: boolean }
---@return boolean
function M.write_from_store(opts)
  local path = get_export_path()
  if not path then
    return false
  end

  if not ensure_dir(path) then
    return false
  end

  local markdown = generate_markdown(true)
  local file = io.open(path, "w")
  if not file then
    return false
  end

  file:write(markdown)
  file:close()

  local count = store.count()
  vim.notify(string.format("Wrote %d comment(s) to %s", count, vim.fn.fnamemodify(path, ":.")), vim.log.levels.INFO, { title = "Review" })

  if opts and opts.copy then
    export.to_clipboard()
  end

  if opts and opts.close then
    review.close_tab_only()
  end

  return true
end

return M
