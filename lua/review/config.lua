local M = {}

---@class ReviewConfig
---@field comment_types table<string, CommentType>
---@field keymaps ReviewKeymaps
---@field codediff ReviewCodediffConfig

---@class CommentType
---@field key string
---@field name string
---@field icon string
---@field hl string
---@field line_hl string

---@class ReviewKeymaps
---@field add_comment string|false
---@field add_note string|false
---@field add_suggestion string|false
---@field add_issue string|false
---@field add_praise string|false
---@field delete_comment string|false
---@field edit_comment string|false
---@field next_comment string|false
---@field prev_comment string|false
---@field list_comments string|false
---@field export_clipboard string|false
---@field send_sidekick string|false
---@field clear_comments string|false
---@field close string|false
---@field toggle_readonly string|false
---@field next_file string|false
---@field prev_file string|false
---@field toggle_file_panel string|false
---@field readonly_add string|false
---@field readonly_delete string|false
---@field readonly_edit string|false
---@field readonly_add_file string|false
---@field add_file_comment string|false
---@field popup_submit string|false
---@field popup_cancel string|false
---@field show_help string|false
---@field popup_cycle_type string|false

---@class ReviewCodediffConfig
---@field readonly boolean

---@type ReviewConfig
M.defaults = {
  comment_types = {
    note = { key = "n", name = "Note", icon = "📝", hl = "ReviewNote", line_hl = "ReviewNoteLine" },
    suggestion = { key = "s", name = "Suggestion", icon = "💡", hl = "ReviewSuggestion", line_hl = "ReviewSuggestionLine" },
    issue = { key = "i", name = "Issue", icon = "⚠️", hl = "ReviewIssue", line_hl = "ReviewIssueLine" },
    praise = { key = "p", name = "Praise", icon = "✨", hl = "ReviewPraise", line_hl = "ReviewPraiseLine" },
  },
  keymaps = {
    -- Edit mode (leader-based)
    add_comment = "<localleader>cc",
    add_note = "<localleader>cn",
    add_suggestion = "<localleader>cs",
    add_issue = "<localleader>ci",
    add_praise = "<localleader>cp",
    add_file_comment = "<localleader>cf",
    delete_comment = "<localleader>cd",
    edit_comment = "<localleader>ce",
    -- Navigation
    next_comment = "]n",
    prev_comment = "[n",
    next_file = "<Tab>",
    prev_file = "<S-Tab>",
    toggle_file_panel = "f",
    -- Common actions
    list_comments = "c",
    export_clipboard = "C",
    send_sidekick = "S",
    clear_comments = "<C-r>",
    close = "q",
    toggle_readonly = "R",
    -- Readonly mode (simple keys)
    readonly_add = "i",
    readonly_delete = "d",
    readonly_edit = "e",
    readonly_add_file = "F",
    -- Help
    show_help = "?",
    -- Popup keymaps
    popup_submit = "<C-s>",
    popup_cancel = "q",
    popup_cycle_type = "<Tab>",
  },
  codediff = {
    readonly = true,
  },
}

---@type ReviewConfig
M.config = vim.deepcopy(M.defaults)

-- Review keymaps that never touch diff buffers (popup-local) and are
-- therefore excluded from conflict detection.
local NON_DIFF_KEYMAPS = {
  popup_submit = true,
  popup_cancel = true,
  popup_cycle_type = true,
}

-- Deliberate overrides skipped by conflict detection:
-- { [review_key] = { role = <codediff role>, name = <codediff name> } }.
-- Review's close intentionally shadows codediff's view.quit on diff buffers
-- via a priority registry claim (see keymaps.lua).
local KNOWN_OVERRIDES = {
  close = { role = "view", name = "quit" },
}

--- Flatten one codediff keymap role to a list of { name, lhs }.
---@param role_maps table|nil
---@return { name: string, lhs: string }[]
local function flatten_role(role_maps)
  local out = {}
  if type(role_maps) ~= "table" then
    return out
  end
  for name, lhs in pairs(role_maps) do
    for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
      if type(key) == "string" and key ~= "" then
        table.insert(out, { name = name, lhs = key })
      end
    end
  end
  return out
end

--- Best-effort canonicalization so equivalent spellings compare equal.
---@param lhs string
---@return string
local function canonical(lhs)
  local ok, normalize = pcall(require, "codediff.keymap.normalize")
  if ok and normalize and normalize.canonical then
    local ok2, result = pcall(normalize.canonical, lhs)
    if ok2 and result then
      return result
    end
  end
  return lhs
end

--- Compare resolved review maps against the codediff roles that land on
--- diff buffers (view is tab-wide, conflict is diff/result scoped) and warn
--- about silent shadowing. Silently returns {} when codediff is absent.
---@return string[] overlaps human-readable overlap descriptions
function M.check_codediff_conflicts()
  local ok, codediff_config = pcall(require, "codediff.config")
  if not ok or type(codediff_config) ~= "table" then
    return {}
  end
  local keymaps = codediff_config.options and codediff_config.options.keymaps
  if type(keymaps) ~= "table" then
    return {}
  end

  local codediff_maps = {}
  for _, role in ipairs({ "view", "conflict" }) do
    for _, entry in ipairs(flatten_role(keymaps[role])) do
      table.insert(codediff_maps, { role = role, name = entry.name, lhs = entry.lhs })
    end
  end

  local overlaps = {}
  for review_key, lhs in pairs(M.config.keymaps) do
    if not NON_DIFF_KEYMAPS[review_key] and type(lhs) == "string" and lhs ~= "" then
      for _, cm in ipairs(codediff_maps) do
        if canonical(lhs) == canonical(cm.lhs) then
          local override = KNOWN_OVERRIDES[review_key]
          if not (override and override.role == cm.role and override.name == cm.name) then
            table.insert(
              overlaps,
              string.format("keymaps.%s (%s) overlaps codediff %s.%s", review_key, lhs, cm.role, cm.name)
            )
          end
        end
      end
    end
  end
  table.sort(overlaps)

  if #overlaps > 0 then
    vim.notify(
      "review.nvim keymap conflict(s) with codediff.nvim:\n- " .. table.concat(overlaps, "\n- "),
      vim.log.levels.WARN,
      { title = "review.nvim" }
    )
  end
  return overlaps
end

---@param opts? ReviewConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  M.check_codediff_conflicts()
end

---@return ReviewConfig
function M.get()
  return M.config
end

return M
