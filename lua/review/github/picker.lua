local M = {}

local Popup = require("nui.popup")
local api = require("review.github.api")

---@type table[]
local all_prs = {}
---@type table[]
local filtered_prs = {}
---@type any
local popup = nil
---@type string
local search_query = ""

-- PR icons (nerdfonts)
local PR_ICON = " " -- nf-oct-git_pull_request
local DRAFT_ICON = " " -- nf-oct-git_pull_request_draft
local BRANCH_ICON = "" -- nf-oct-git_branch

local function format_line(pr)
  local icon = pr.isDraft and DRAFT_ICON or PR_ICON
  local draft_tag = pr.isDraft and " [draft]" or ""
  local title = pr.title
  if #title > 50 then
    title = title:sub(1, 47) .. "..."
  end
  local line = string.format(
    "%s #%-4d %s%s  %s %s → %s  @%s",
    icon,
    pr.number,
    title,
    draft_tag,
    BRANCH_ICON,
    pr.headRefName,
    pr.baseRefName,
    pr.author.login
  )
  if #line > 120 then
    line = line:sub(1, 117) .. "..."
  end
  return line
end

---Get highlight ranges for a PR line
---@param pr table
---@param line string
---@return table[] Array of {col_start, col_end, hl_group}
local function get_line_highlights(pr, line)
  local highlights = {}
  local icon = pr.isDraft and DRAFT_ICON or PR_ICON

  -- Icon highlight
  local icon_end = #icon + 1
  table.insert(highlights, { 0, icon_end, pr.isDraft and "ReviewPRDraft" or "ReviewPRIcon" })

  -- PR number highlight
  local num_str = string.format("#%-4d", pr.number)
  local num_start = icon_end
  local num_end = num_start + #num_str + 1
  table.insert(highlights, { num_start, num_end, "ReviewPRNumber" })

  -- Find branch section (after the branch icon)
  local branch_start = line:find(BRANCH_ICON)
  if branch_start then
    -- Branch icon and names
    local arrow_pos = line:find("→", branch_start)
    if arrow_pos then
      local author_pos = line:find("@", arrow_pos)
      if author_pos then
        table.insert(highlights, { branch_start - 1, author_pos - 3, "ReviewPRBranch" })
        table.insert(highlights, { author_pos - 1, #line, "ReviewPRAuthor" })
      end
    end
  end

  -- Draft tag highlight
  if pr.isDraft then
    local draft_start = line:find("%[draft%]")
    if draft_start then
      table.insert(highlights, { draft_start - 1, draft_start + 6, "ReviewPRDraft" })
    end
  end

  return highlights
end

local function filter_prs()
  if search_query == "" then
    filtered_prs = all_prs
    return
  end

  local query = search_query:lower()
  filtered_prs = {}
  for _, pr in ipairs(all_prs) do
    local searchable = string.format(
      "#%d %s %s %s %s",
      pr.number,
      pr.title,
      pr.headRefName,
      pr.baseRefName,
      pr.author.login
    ):lower()
    if searchable:find(query, 1, true) then
      table.insert(filtered_prs, pr)
    end
  end
end

local function render_lines()
  if not popup then
    return
  end

  local buf = popup.bufnr
  local lines = {}
  local pr_lines = {} -- Store formatted lines with their PRs for highlighting

  -- Search prompt line
  local prompt = " / " .. search_query
  if search_query == "" then
    prompt = " / (type to search)"
  end
  table.insert(lines, prompt)
  table.insert(lines, string.rep("─", 80))

  for _, pr in ipairs(filtered_prs) do
    local line = format_line(pr)
    table.insert(lines, line)
    table.insert(pr_lines, { pr = pr, line = line })
  end

  if #filtered_prs == 0 and #all_prs > 0 then
    table.insert(lines, "  (no matches)")
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  -- Apply highlights
  local ns_id = vim.api.nvim_create_namespace("review_pr_picker")
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

  -- Search prompt highlight
  vim.api.nvim_buf_add_highlight(buf, ns_id, "ReviewPRSearch", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, ns_id, "Comment", 1, 0, -1)

  -- PR line highlights
  for i, pr_line in ipairs(pr_lines) do
    local line_idx = i + 1 -- +2 for header lines, -1 for 0-based = +1
    local highlights = get_line_highlights(pr_line.pr, pr_line.line)
    for _, hl in ipairs(highlights) do
      pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, hl[3], line_idx, hl[1], hl[2])
    end
  end

  -- Position cursor on first PR (line 3)
  if #filtered_prs > 0 then
    pcall(vim.api.nvim_win_set_cursor, popup.winid, { 3, 0 })
  end
end

local function close_picker()
  if popup then
    popup:unmount()
    popup = nil
  end
  all_prs = {}
  filtered_prs = {}
  search_query = ""
end

local function confirm_selection(callback)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  -- Subtract 2 for search prompt and separator
  local pr_idx = line_num - 2
  local pr = filtered_prs[pr_idx]
  close_picker()

  if pr then
    callback(pr.number)
  end
end

local function handle_char(char)
  search_query = search_query .. char
  filter_prs()
  render_lines()
end

local function handle_backspace()
  if #search_query > 0 then
    search_query = search_query:sub(1, -2)
    filter_prs()
    render_lines()
  end
end

local function clear_search()
  search_query = ""
  filter_prs()
  render_lines()
end

---Open PR picker
---@param callback fun(pr_number: number)
function M.open(callback)
  if not api.is_available() then
    vim.notify("gh CLI not found. Install from https://cli.github.com", vim.log.levels.ERROR, { title = "Review" })
    return
  end

  if not api.is_authenticated() then
    vim.notify("Not authenticated with GitHub. Run: gh auth login", vim.log.levels.ERROR, { title = "Review" })
    return
  end

  vim.notify("Fetching PRs...", vim.log.levels.INFO, { title = "Review" })

  all_prs = api.list_prs({ limit = 50 }) or {}
  search_query = ""
  filter_prs()

  if #all_prs == 0 then
    vim.notify("No open PRs found", vim.log.levels.WARN, { title = "Review" })
    return
  end

  local width = math.min(120, vim.o.columns - 10)
  local height = math.min(25, #all_prs + 4, vim.o.lines - 10)

  popup = Popup({
    position = "50%",
    size = {
      width = width,
      height = height,
    },
    border = {
      style = "rounded",
      text = {
        top = " Select PR to review ",
        top_align = "center",
        bottom = " <CR> select | <C-u> clear | q quit ",
        bottom_align = "center",
      },
    },
    buf_options = {
      modifiable = false,
      buftype = "nofile",
    },
    win_options = {
      cursorline = true,
    },
  })

  popup:mount()
  render_lines()

  vim.api.nvim_set_current_win(popup.winid)

  local map_opts = { noremap = true, nowait = true }
  popup:map("n", "<CR>", function() confirm_selection(callback) end, map_opts)
  popup:map("n", "q", close_picker, map_opts)
  popup:map("n", "<Esc>", close_picker, map_opts)
  popup:map("n", "<C-u>", clear_search, map_opts)
  popup:map("n", "<BS>", handle_backspace, map_opts)

  -- Map printable characters for search
  local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_@#"
  for i = 1, #chars do
    local char = chars:sub(i, i)
    popup:map("n", char, function() handle_char(char) end, map_opts)
  end
end

return M
