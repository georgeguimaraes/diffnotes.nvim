local M = {}

local api = require("review.github.api")
local picker = require("review.github.picker")

---@class PRContext
---@field number number PR number
---@field owner string Repository owner
---@field repo string Repository name
---@field title string PR title
---@field author string PR author
---@field base_ref string Base branch name
---@field head_ref string Head branch name
---@field base_sha string Base commit SHA
---@field head_sha string Head commit SHA
---@field merge_base string Merge-base commit SHA
---@field url string PR URL

---@type PRContext|nil
M.current_pr = nil

---Open a PR for review
---@param number? number PR number (opens picker if nil)
function M.open(number)
  if not api.is_available() then
    vim.notify("gh CLI not found. Install from https://cli.github.com", vim.log.levels.ERROR, { title = "Review" })
    return
  end

  if not api.is_authenticated() then
    vim.notify("Not authenticated with GitHub. Run: gh auth login", vim.log.levels.ERROR, { title = "Review" })
    return
  end

  if number then
    M._open_pr(number)
  else
    picker.open(function(pr_number)
      M._open_pr(pr_number)
    end)
  end
end

---Internal: open PR by number
---@param number number
function M._open_pr(number)
  vim.notify(string.format("Loading PR #%d...", number), vim.log.levels.INFO, { title = "Review" })

  -- Get PR details
  local pr = api.get_pr(number)
  if not pr then
    vim.notify(string.format("Failed to fetch PR #%d", number), vim.log.levels.ERROR, { title = "Review" })
    return
  end

  -- Fetch PR refs without checking out (keeps current branch clean)
  vim.notify(string.format("Fetching PR #%d...", number), vim.log.levels.INFO, { title = "Review" })
  local ok, err = api.fetch_pr(number)
  if not ok then
    vim.notify(string.format("Failed to fetch PR: %s", err or "unknown error"), vim.log.levels.ERROR, { title = "Review" })
    return
  end

  -- Also fetch the base branch to ensure we have it
  vim.fn.system(string.format("git fetch origin %s 2>&1", pr.base_ref))

  -- Calculate merge-base for accurate diff using the fetched refs
  local merge_base = api.get_merge_base("origin/" .. pr.base_ref, pr.head_sha)
  if not merge_base then
    -- Fallback to base SHA if merge-base fails
    merge_base = pr.base_sha
  end
  pr.merge_base = merge_base

  -- Store current PR context
  M.current_pr = pr

  -- Load review.nvim store
  local store = require("review.store")
  store.load()

  -- Open codediff with the correct refs
  local codediff_ok, _ = pcall(require, "codediff")
  if not codediff_ok then
    vim.notify("codediff.nvim is required", vim.log.levels.ERROR, { title = "Review" })
    return
  end

  vim.cmd(string.format("CodeDiff %s %s", merge_base, pr.head_sha))

  -- Set up review.nvim hooks after codediff initializes
  vim.defer_fn(function()
    local review = require("review")
    review._check_codediff_session()

    -- Fetch and display GitHub threads
    local threads = require("review.github.threads")
    vim.notify("Fetching PR comments...", vim.log.levels.INFO, { title = "Review" })
    if threads.fetch(pr.number) then
      local thread_count = #threads.threads
      threads.render_all()
      vim.notify(
        string.format("Reviewing PR #%d: %s (%d threads)", pr.number, pr.title, thread_count),
        vim.log.levels.INFO,
        { title = "Review" }
      )
    else
      vim.notify(
        string.format("Reviewing PR #%d: %s", pr.number, pr.title),
        vim.log.levels.INFO,
        { title = "Review" }
      )
    end
  end, 300)
end

---Get current PR context
---@return PRContext|nil
function M.get_current_pr()
  return M.current_pr
end

---Check if currently reviewing a PR
---@return boolean
function M.is_pr_review()
  return M.current_pr ~= nil
end

---Clear current PR context
function M.clear()
  M.current_pr = nil
end

return M
