local M = {}

function M.setup()
  local links = {
    ReviewNote = "DiagnosticInfo",
    ReviewSuggestion = "DiagnosticHint",
    ReviewIssue = "DiagnosticWarn",
    ReviewPraise = "DiagnosticOk",
    ReviewSign = "Comment",
    ReviewVirtText = "Comment",
  }

  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end

  -- Line highlights (darker background, no underline)
  vim.api.nvim_set_hl(0, "ReviewNoteLine", { bg = "#0d1f28", underline = false, default = true })
  vim.api.nvim_set_hl(0, "ReviewSuggestionLine", { bg = "#152015", underline = false, default = true })
  vim.api.nvim_set_hl(0, "ReviewIssueLine", { bg = "#28250d", underline = false, default = true })
  vim.api.nvim_set_hl(0, "ReviewPraiseLine", { bg = "#15152a", underline = false, default = true })

  vim.fn.sign_define("ReviewComment", {
    text = "●",
    texthl = "ReviewSign",
  })

  -- GitHub thread highlights
  vim.api.nvim_set_hl(0, "ReviewGitHubThread", { fg = "#7c3aed", bold = true, default = true })
  vim.api.nvim_set_hl(0, "ReviewGitHubResolved", { fg = "#6b7280", default = true })
  vim.api.nvim_set_hl(0, "ReviewGitHubOutdated", { bg = "#1f1f1f", italic = true, default = true })
  vim.api.nvim_set_hl(0, "ReviewGitHubVirtText", { fg = "#6b7280", italic = true, default = true })
  vim.api.nvim_set_hl(0, "ReviewGitHubAuthor", { fg = "#60a5fa", bold = true, default = true })

  -- PR picker highlights
  vim.api.nvim_set_hl(0, "ReviewPRIcon", { fg = "#3fb950", default = true }) -- Green PR icon
  vim.api.nvim_set_hl(0, "ReviewPRDraft", { fg = "#6b7280", italic = true, default = true }) -- Gray for drafts
  vim.api.nvim_set_hl(0, "ReviewPRNumber", { fg = "#58a6ff", bold = true, default = true }) -- Blue PR number
  vim.api.nvim_set_hl(0, "ReviewPRBranch", { fg = "#f78166", default = true }) -- Orange branch names
  vim.api.nvim_set_hl(0, "ReviewPRAuthor", { fg = "#8b949e", default = true }) -- Gray author
  vim.api.nvim_set_hl(0, "ReviewPRSearch", { fg = "#c9d1d9", italic = true, default = true }) -- Search prompt
end

return M
