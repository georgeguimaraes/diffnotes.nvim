local M = {}

local store = require("diffnotes.store")

---@return string
function M.generate_markdown()
  local all_comments = store.get_all()

  if #all_comments == 0 then
    return "No comments yet."
  end

  local lines = {}

  -- Header
  table.insert(lines, "I reviewed your code and have the following comments. Please address them.")
  table.insert(lines, "")
  table.insert(lines, "Comment types: ISSUE (problems to fix), SUGGESTION (improvements), NOTE (observations), PRAISE (positive feedback)")
  table.insert(lines, "")

  -- Numbered list of comments
  for i, comment in ipairs(all_comments) do
    local type_name = string.upper(comment.type)
    table.insert(lines, string.format("%d. **[%s]** `%s:%d` - %s", i, type_name, comment.file, comment.line, comment.text))
  end

  return table.concat(lines, "\n")
end

function M.to_clipboard()
  local markdown = M.generate_markdown()

  vim.fn.setreg("+", markdown)
  vim.fn.setreg("*", markdown)

  local count = store.count()
  vim.notify(
    string.format("diffnotes: Exported %d comment(s) to clipboard", count),
    vim.log.levels.INFO
  )
end

function M.preview()
  local markdown = M.generate_markdown()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(markdown, "\n"))
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end

return M
