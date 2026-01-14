local M = {}

---@class DiffnotesConfig
---@field comment_types table<string, CommentType>
---@field keymaps DiffnotesKeymaps
---@field export DiffnotesExportConfig
---@field diffview DiffnotesDiffviewConfig

---@class CommentType
---@field key string
---@field name string
---@field icon string
---@field hl string
---@field line_hl string

---@class DiffnotesKeymaps
---@field add_note string
---@field add_suggestion string
---@field add_issue string
---@field add_praise string
---@field delete_comment string
---@field edit_comment string
---@field next_comment string
---@field prev_comment string
---@field export string
---@field toggle_layout string

---@class DiffnotesExportConfig
---@field context_lines number
---@field include_file_stats boolean

---@class DiffnotesDiffviewConfig
---@field readonly boolean

---@type DiffnotesConfig
M.defaults = {
  comment_types = {
    note = { key = "n", name = "Note", icon = "📝", hl = "DiffnotesNote", line_hl = "DiffnotesNoteLine" },
    suggestion = { key = "s", name = "Suggestion", icon = "💡", hl = "DiffnotesSuggestion", line_hl = "DiffnotesSuggestionLine" },
    issue = { key = "i", name = "Issue", icon = "⚠️", hl = "DiffnotesIssue", line_hl = "DiffnotesIssueLine" },
    praise = { key = "p", name = "Praise", icon = "✨", hl = "DiffnotesPraise", line_hl = "DiffnotesPraiseLine" },
  },
  keymaps = {
    add_note = "<leader>cn",
    add_suggestion = "<leader>cs",
    add_issue = "<leader>ci",
    add_praise = "<leader>cp",
    delete_comment = "<leader>cd",
    edit_comment = "<leader>ce",
    next_comment = "]c",
    prev_comment = "[c",
    export = "<C-e>",
    toggle_layout = "<C-t>",
  },
  export = {
    context_lines = 3,
    include_file_stats = true,
  },
  diffview = {
    readonly = true,
  },
}

---@type DiffnotesConfig
M.config = vim.deepcopy(M.defaults)

---@param opts? DiffnotesConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

---@return DiffnotesConfig
function M.get()
  return M.config
end

return M
