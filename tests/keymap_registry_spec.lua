local keymaps = require("review.keymaps")
local config = require("review.config")

-- Review maps must be installed through codediff's keymap registry
-- (lifecycle.set_buf_keymap) so layout toggles retire/reinstall them
-- alongside codediff's own maps instead of racing via vim.keymap.set.
describe("review.keymaps registry", function()
  local tabpage
  local diff1, diff2, panel
  local saved_lifecycle
  local installed
  local removed

  before_each(function()
    config.setup()
    tabpage = vim.api.nvim_get_current_tabpage()

    diff1 = vim.api.nvim_create_buf(false, true)
    diff2 = vim.api.nvim_create_buf(false, true)
    panel = vim.api.nvim_create_buf(false, true)
    installed = {}
    removed = {}

    saved_lifecycle = package.loaded["codediff.ui.lifecycle"]
    package.loaded["codediff.ui.lifecycle"] = {
      get_session = function(tab)
        if tab ~= tabpage then
          return nil
        end
        return { stored_diff_result = { changes = {} } }
      end,
      get_buffers = function()
        return diff1, diff2
      end,
      find_tabpage_by_buffer = function(bufnr)
        if bufnr == diff1 or bufnr == diff2 then
          return tabpage
        end
        return nil
      end,
      set_buf_keymap = function(tab, bufnr, mode, lhs, rhs, opts, meta)
        table.insert(installed, { tab = tab, bufnr = bufnr, mode = mode, lhs = lhs, meta = meta })
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", opts or {}, { buffer = bufnr }))
        return true
      end,
      del_buf_keymap = function(tab, bufnr, mode, lhs)
        table.insert(removed, { tab = tab, bufnr = bufnr, mode = mode, lhs = lhs })
        pcall(vim.keymap.del, mode, lhs, { buffer = bufnr })
      end,
    }

    vim.api.nvim_set_current_buf(diff1)
    keymaps.setup_keymaps(tabpage)
  end)

  after_each(function()
    keymaps.cleanup()
    package.loaded["codediff.ui.lifecycle"] = saved_lifecycle
    for _, bufnr in ipairs({ diff1, diff2, panel }) do
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end)

  it("installs diff-buffer maps via the session registry", function()
    assert.is_true(#installed > 0)
    for _, call in ipairs(installed) do
      assert.equals(tabpage, call.tab)
      assert.is_true(call.bufnr == diff1 or call.bufnr == diff2)
    end
  end)

  it("claims close with priority so it overrides codediff quit", function()
    local close_calls = vim.tbl_filter(function(call)
      return call.lhs == "q" and call.mode == "n"
    end, installed)
    assert.equals(1, #close_calls)
    assert.is_not_nil(close_calls[1].meta)
    assert.is_true(close_calls[1].meta.priority > 0)
  end)

  it("claims non-colliding maps at default priority", function()
    local add_calls = vim.tbl_filter(function(call)
      return call.lhs == "i" and call.mode == "n"
    end, installed)
    assert.equals(1, #add_calls)
    assert.is_nil(add_calls[1].meta)
  end)

  it("never installs panel maps through the registry", function()
    vim.api.nvim_set_current_buf(panel)
    for _, call in ipairs(installed) do
      assert.is_nil(call.bufnr == panel and true or nil, "panel buffer claimed: " .. call.lhs)
    end
  end)

  it("removes maps via the session registry on cleanup", function()
    keymaps.cleanup()
    assert.is_true(#removed > 0)
    assert.equals(#installed, #removed)
  end)

  it("falls back to plain buffer maps when the registry API is missing", function()
    keymaps.cleanup()
    package.loaded["codediff.ui.lifecycle"] = {
      get_session = function()
        return {}
      end,
      get_buffers = function()
        return diff1, diff2
      end,
      find_tabpage_by_buffer = function(bufnr)
        if bufnr == diff1 or bufnr == diff2 then
          return tabpage
        end
        return nil
      end,
      -- no set_buf_keymap / del_buf_keymap: older codediff
    }
    vim.api.nvim_set_current_buf(diff1)
    keymaps.setup_keymaps(tabpage)
    vim.api.nvim_set_current_buf(diff1)
    local map = vim.fn.maparg("i", "n", false, true)
    assert.is_true(type(map) == "table" and next(map) ~= nil)
  end)
end)
