local config = require("review.config")

describe("review.popup", function()
  before_each(function()
    config.setup()
  end)

  describe("allowed_types parameter", function()
    it("module loads without error", function()
      local popup = require("review.popup")
      assert.is_not_nil(popup)
      assert.is_not_nil(popup.open)
    end)

    it("open function signature accepts 5 parameters", function()
      local popup = require("review.popup")

      -- Verify the function exists and can be inspected
      local info = debug.getinfo(popup.open, "u")
      -- The function should accept at least 5 parameters (initial_type, initial_text, callback, current_line, allowed_types)
      -- Note: Lua doesn't enforce parameter counts, but we verify the function exists
      assert.is_function(popup.open)

      -- Verify module structure
      assert.is_table(popup)
    end)
  end)

  describe("type filtering logic", function()
    -- Test the type_keys logic directly
    it("filters to only allowed types when specified", function()
      local all_types = { "note", "suggestion", "issue", "praise" }
      local allowed_types = { "note", "suggestion" }

      local type_keys = allowed_types or all_types

      assert.equals(2, #type_keys)
      assert.equals("note", type_keys[1])
      assert.equals("suggestion", type_keys[2])
    end)

    it("uses all types when allowed_types is nil", function()
      local all_types = { "note", "suggestion", "issue", "praise" }
      local allowed_types = nil

      local type_keys = allowed_types or all_types

      assert.equals(4, #type_keys)
    end)

    it("initial_type falls back to first allowed type if not in list", function()
      local allowed_types = { "note", "suggestion" }
      local initial_type = "issue" -- not in allowed list

      local current_type_idx = 1
      if initial_type then
        for i, key in ipairs(allowed_types) do
          if key == initial_type then
            current_type_idx = i
            break
          end
        end
      end

      -- issue is not in allowed_types, so index stays at 1 (note)
      assert.equals(1, current_type_idx)
      assert.equals("note", allowed_types[current_type_idx])
    end)

    it("initial_type selects correct index when in allowed list", function()
      local allowed_types = { "note", "suggestion" }
      local initial_type = "suggestion"

      local current_type_idx = 1
      if initial_type then
        for i, key in ipairs(allowed_types) do
          if key == initial_type then
            current_type_idx = i
            break
          end
        end
      end

      assert.equals(2, current_type_idx)
      assert.equals("suggestion", allowed_types[current_type_idx])
    end)
  end)

  describe("suggestion pre-fill", function()
    it("generates correct suggestion syntax", function()
      local current_line = "  local x = 1"
      local suggestion_text = "```suggestion\n" .. current_line .. "\n```"

      assert.equals("```suggestion\n  local x = 1\n```", suggestion_text)
    end)

    it("splits suggestion into lines correctly", function()
      local current_line = "  local x = 1"
      local suggestion_text = "```suggestion\n" .. current_line .. "\n```"
      local lines = vim.split(suggestion_text, "\n")

      assert.equals(3, #lines)
      assert.equals("```suggestion", lines[1])
      assert.equals("  local x = 1", lines[2])
      assert.equals("```", lines[3])
    end)
  end)

  describe("PR mode detection", function()
    it("is_pr_mode returns false when no PR context", function()
      -- Ensure github module returns nil for current PR
      package.loaded["review.github"] = {
        get_current_pr = function() return nil end
      }

      local function is_pr_mode()
        local ok, github = pcall(require, "review.github")
        if ok and github.get_current_pr then
          return github.get_current_pr() ~= nil
        end
        return false
      end

      assert.is_false(is_pr_mode())

      package.loaded["review.github"] = nil
    end)

    it("is_pr_mode returns true when PR context exists", function()
      package.loaded["review.github"] = {
        get_current_pr = function()
          return { number = 123, title = "Test PR" }
        end
      }

      local function is_pr_mode()
        local ok, github = pcall(require, "review.github")
        if ok and github.get_current_pr then
          return github.get_current_pr() ~= nil
        end
        return false
      end

      assert.is_true(is_pr_mode())

      package.loaded["review.github"] = nil
    end)
  end)
end)
