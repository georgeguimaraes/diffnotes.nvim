local keymaps = require("review.keymaps")
local config = require("review.config")

-- Regression test: review keymaps must only land on codediff diff buffers,
-- never on explorer/history panel buffers where codediff owns keys like
-- i (toggle_view_mode), S (stage_all) and R (refresh).
describe("review.keymaps scoping", function()
  local tabpage
  local diff1, diff2, panel
  local saved_lifecycle

  local function buf_maparg(bufnr, lhs, mode)
    vim.api.nvim_set_current_buf(bufnr)
    local map = vim.fn.maparg(lhs, mode, false, true)
    if type(map) ~= "table" or next(map) == nil then
      return nil
    end
    return map
  end

  before_each(function()
    config.setup()
    tabpage = vim.api.nvim_get_current_tabpage()

    diff1 = vim.api.nvim_create_buf(false, true)
    diff2 = vim.api.nvim_create_buf(false, true)
    panel = vim.api.nvim_create_buf(false, true)

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

  it("applies review maps to diff buffers", function()
    assert.is_not_nil(buf_maparg(diff1, "i", "n"))
    assert.is_not_nil(buf_maparg(diff2, "i", "n"))
    assert.is_not_nil(buf_maparg(diff1, "q", "n"))
  end)

  it("applies no review maps to panel buffers", function()
    vim.api.nvim_set_current_buf(panel)
    for _, lhs in ipairs({ "i", "e", "d", "F", "S", "R", "q", "c", "C", "f" }) do
      assert.is_nil(buf_maparg(panel, lhs, "n"), "panel should not carry review map " .. lhs)
    end
  end)

  describe("is_diff_buffer", function()
    it("matches session diff buffers only", function()
      local lifecycle = require("codediff.ui.lifecycle")
      local t = keymaps._test
      assert.is_true(t.is_diff_buffer(lifecycle, tabpage, diff1))
      assert.is_true(t.is_diff_buffer(lifecycle, tabpage, diff2))
      assert.is_false(t.is_diff_buffer(lifecycle, tabpage, panel))
    end)
  end)
end)
