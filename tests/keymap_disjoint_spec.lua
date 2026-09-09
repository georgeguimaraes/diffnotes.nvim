-- The busted harness resets rtp, so opt-in to a real codediff checkout via
-- CODEDIFF_DIR (e.g. CODEDIFF_DIR=~/.local/share/nvim/lazy/codediff.nvim).
-- Without it the tests below pending-skip.
local codediff_dir = os.getenv("CODEDIFF_DIR")
if codediff_dir and vim.fn.isdirectory(codediff_dir) == 1 then
  vim.opt.rtp:append(codediff_dir)
end

local review_config = require("review.config")

-- The test that would have caught this whole class of bug: resolving both
-- plugins' default keymap tables and asserting no lhs overlap on the same
-- buffer roles. Fails if either side's defaults drift into collision.
-- Skipped when codediff.nvim is not on the rtp (e.g. CI); run it in a
-- real session with both plugins installed.
describe("review/codediff default disjointness", function()
  local function codediff_defaults()
    local ok, cc = pcall(require, "codediff.config")
    if not ok or type(cc) ~= "table" or type(cc.defaults) ~= "table" then
      return nil
    end
    return cc.defaults.keymaps
  end

  --- Flatten a codediff role to { lhs -> name }.
  local function flatten(role_maps)
    local out = {}
    if type(role_maps) ~= "table" then
      return out
    end
    for name, lhs in pairs(role_maps) do
      for _, key in ipairs(type(lhs) == "table" and lhs or { lhs }) do
        if type(key) == "string" and key ~= "" then
          out[key] = name
        end
      end
    end
    return out
  end

  --- Review defaults that land on diff buffers (popup maps are popup-local).
  local function review_diff_maps()
    local out = {}
    for key, lhs in pairs(review_config.defaults.keymaps) do
      if not key:match("^popup_") and type(lhs) == "string" and lhs ~= "" then
        out[lhs] = key
      end
    end
    return out
  end

  it("has exactly one diff-role overlap: the deliberate q override", function()
    local cd = codediff_defaults()
    if not cd then
      pending("codediff.nvim not on rtp")
      return
    end

    local review_maps = review_diff_maps()
    local overlaps = {}
    for _, role in ipairs({ "view", "conflict" }) do
      for lhs, name in pairs(flatten(cd[role])) do
        if review_maps[lhs] then
          table.insert(overlaps, { review_key = review_maps[lhs], role = role, name = name, lhs = lhs })
        end
      end
    end

    -- q is deliberately overridden by review's close via a priority
    -- registry claim. Anything else (or a missing q) means defaults
    -- drifted and the override contract needs revisiting.
    assert.equals(1, #overlaps)
    assert.same({ review_key = "close", role = "view", name = "quit", lhs = "q" }, overlaps[1])
  end)

  it("keeps panel-role overlaps within the scoped allowlist", function()
    local cd = codediff_defaults()
    if not cd then
      pending("codediff.nvim not on rtp")
      return
    end

    -- i/S/R collide with explorer maps but are safe ONLY because review
    -- never installs maps on panel buffers (see keymap_scope_spec.lua).
    -- Anything beyond this allowlist must be scoped, not renamed.
    local allowlist = { i = true, S = true, R = true }
    local review_maps = review_diff_maps()
    for _, role in ipairs({ "explorer", "history" }) do
      for lhs, name in pairs(flatten(cd[role])) do
        if review_maps[lhs] then
          assert.is_true(
            allowlist[lhs],
            string.format("review keymaps.%s (%s) collides with codediff %s.%s", review_maps[lhs], lhs, role, name)
          )
        end
      end
    end
  end)
end)
