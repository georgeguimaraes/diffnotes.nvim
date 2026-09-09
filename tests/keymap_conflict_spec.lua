local config = require("review.config")

describe("review.config conflict detection", function()
  local saved_codediff_config
  local saved_notify
  local notifications

  before_each(function()
    config.setup()
    saved_codediff_config = package.loaded["codediff.config"]
    saved_notify = vim.notify
    notifications = {}
    vim.notify = function(msg, level, opts)
      table.insert(notifications, { msg = msg, level = level, opts = opts })
    end
  end)

  after_each(function()
    vim.notify = saved_notify
    package.loaded["codediff.config"] = saved_codediff_config
    config.setup()
  end)

  local function stub_codediff(keymaps)
    package.loaded["codediff.config"] = { options = { keymaps = keymaps } }
  end

  it("warns when a review map overlaps a codediff view map", function()
    stub_codediff({ view = { quit = "q", toggle_layout = "t" } })
    local overlaps = config.check_codediff_conflicts()
    -- close/q vs view.quit/q is deliberate and excluded
    assert.equals(0, #overlaps)
    assert.equals(0, #notifications)

    config.setup({ keymaps = { toggle_readonly = "t" } })
    assert.equals(1, #notifications)
    assert.equals(vim.log.levels.WARN, notifications[1].level)
    assert.matches("toggle_readonly", notifications[1].msg)
    assert.matches("toggle_layout", notifications[1].msg)
  end)

  it("stays silent when codediff is unavailable", function()
    package.loaded["codediff.config"] = nil
    local overlaps = config.check_codediff_conflicts()
    assert.equals(0, #overlaps)
    assert.equals(0, #notifications)
  end)

  it("ignores popup-local maps and disabled maps", function()
    stub_codediff({ view = { quit = "q", other = "<C-s>" } })
    config.setup({ keymaps = { popup_submit = "<C-s>", toggle_readonly = false } })
    assert.equals(0, #notifications)
  end)

  it("compares conflict-role maps that land on diff buffers", function()
    stub_codediff({ conflict = { accept_incoming = "C" } })
    config.setup({ keymaps = { export_clipboard = "C" } })
    assert.equals(1, #notifications)
    assert.matches("export_clipboard", notifications[1].msg)
  end)
end)
