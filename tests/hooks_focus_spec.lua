local hooks = require("review.hooks")

describe("hooks focus behavior", function()
  local mod_buf, mod_win, orig_buf, orig_win
  local extra_bufs, extra_tabs

  before_each(function()
    extra_bufs = {}
    extra_tabs = {}

    -- Model the CodeDiff side-by-side layout closely enough for focus rules:
    -- an original pane on the left and a modified pane on the right.
    orig_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(orig_buf, 0, -1, false, { "old line" })

    mod_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(mod_buf, 0, -1, false, { "new line" })

    orig_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(orig_win, orig_buf)

    vim.cmd("vsplit")
    mod_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(mod_win, mod_buf)
  end)

  after_each(function()
    for _, tabpage in ipairs(extra_tabs) do
      if vim.api.nvim_tabpage_is_valid(tabpage) then
        vim.api.nvim_set_current_tabpage(tabpage)
        vim.cmd("tabclose")
      end
    end

    -- Close windows before deleting buffers so Neovim does not retarget
    -- displayed buffers into another test's window layout.
    while #vim.api.nvim_tabpage_list_wins(0) > 1 do
      vim.cmd("quit")
    end

    for _, bufnr in ipairs(extra_bufs) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
    if vim.api.nvim_buf_is_valid(orig_buf) then
      vim.api.nvim_buf_delete(orig_buf, { force = true })
    end
    if vim.api.nvim_buf_is_valid(mod_buf) then
      vim.api.nvim_buf_delete(mod_buf, { force = true })
    end

  end)

  it("focuses the modified pane normally", function()
    local tabpage = vim.api.nvim_get_current_tabpage()

    -- Initial review setup may still move focus from unrelated windows into
    -- the modified pane; only CodeDiff-owned panes should be protected.
    local other_buf = vim.api.nvim_create_buf(false, true)
    table.insert(extra_bufs, other_buf)
    vim.cmd("vsplit")
    local other_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(other_win, other_buf)

    local lifecycle = {
      get_session = function()
        return { original_win = orig_win, modified_win = mod_win }
      end,
    }

    hooks._focus_modified_pane(lifecycle, tabpage)

    assert.equals(mod_win, vim.api.nvim_get_current_win())
  end)

  it("should not steal focus from floating windows", function()
    local tabpage = vim.api.nvim_get_current_tabpage()
    vim.api.nvim_set_current_win(orig_win)

    local lifecycle = {
      get_session = function()
        return { modified_win = mod_win }
      end,
    }

    -- Stub nvim_win_get_config to simulate current window being a float
    local original_get_config = vim.api.nvim_win_get_config
    vim.api.nvim_win_get_config = function(win)
      if win == vim.api.nvim_get_current_win() then
        return { relative = "cursor", width = 40, height = 5 }
      end
      return original_get_config(win)
    end

    hooks._focus_modified_pane(lifecycle, tabpage)

    -- Focus should stay on the current window, not jump to mod_win
    assert.equals(orig_win, vim.api.nvim_get_current_win())

    vim.api.nvim_win_get_config = original_get_config
  end)

  it("should not steal focus from another tab", function()
    local review_tabpage = vim.api.nvim_get_current_tabpage()

    -- _focus_modified_pane is scheduled with a delay, so the user may leave
    -- the review tab before the callback runs.
    vim.cmd("tabnew")
    local other_tabpage = vim.api.nvim_get_current_tabpage()
    local other_win = vim.api.nvim_get_current_win()
    table.insert(extra_tabs, other_tabpage)

    local lifecycle = {
      get_session = function()
        return { original_win = orig_win, modified_win = mod_win }
      end,
    }

    hooks._focus_modified_pane(lifecycle, review_tabpage)

    assert.equals(other_tabpage, vim.api.nvim_get_current_tabpage())
    assert.equals(other_win, vim.api.nvim_get_current_win())
  end)

  it("should not steal focus from the original pane", function()
    local tabpage = vim.api.nvim_get_current_tabpage()
    vim.api.nvim_set_current_win(orig_win)

    local lifecycle = {
      get_session = function()
        return { original_win = orig_win, modified_win = mod_win }
      end,
    }

    hooks._focus_modified_pane(lifecycle, tabpage)

    assert.equals(orig_win, vim.api.nvim_get_current_win())
  end)

  it("should not steal focus from the explorer window", function()
    local tabpage = vim.api.nvim_get_current_tabpage()
    vim.cmd("vsplit")
    local explorer_win = vim.api.nvim_get_current_win()

    local lifecycle = {
      get_explorer = function()
        -- _focus_modified_pane only needs the explorer split's window id,
        -- matching the CodeDiff explorer object shape used by review.nvim.
        return { split = { winid = explorer_win } }
      end,
      get_session = function()
        return { original_win = orig_win, modified_win = mod_win }
      end,
    }

    vim.api.nvim_set_current_win(explorer_win)
    hooks._focus_modified_pane(lifecycle, tabpage)

    assert.equals(explorer_win, vim.api.nvim_get_current_win())
  end)
end)
