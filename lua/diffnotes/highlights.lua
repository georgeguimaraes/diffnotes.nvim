local M = {}

function M.setup()
  local links = {
    DiffnotesNote = "DiagnosticInfo",
    DiffnotesSuggestion = "DiagnosticHint",
    DiffnotesIssue = "DiagnosticWarn",
    DiffnotesPraise = "DiagnosticOk",
    DiffnotesSign = "Comment",
    DiffnotesVirtText = "Comment",
  }

  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end

  -- Line highlights (subtle background)
  vim.api.nvim_set_hl(0, "DiffnotesNoteLine", { bg = "#1a3a4a", default = true })
  vim.api.nvim_set_hl(0, "DiffnotesSuggestionLine", { bg = "#2a3a2a", default = true })
  vim.api.nvim_set_hl(0, "DiffnotesIssueLine", { bg = "#3a3a1a", default = true })
  vim.api.nvim_set_hl(0, "DiffnotesPraiseLine", { bg = "#2a2a3a", default = true })

  vim.fn.sign_define("DiffnotesComment", {
    text = "●",
    texthl = "DiffnotesSign",
  })
end

return M
