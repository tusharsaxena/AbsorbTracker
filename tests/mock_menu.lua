-- tests/mock_menu.lua — a headless stand-in for the client's context-menu API (11.0+), for the
-- launcher's options menu (LibKa0s-Launcher minor 4, launcher-§2).
--
-- The library's right click opens `MenuUtil.CreateContextMenu(owner, generator)`. The generator is
-- handed a root description and builds the menu on it: `root:CreateTitle(text)` and
-- `root:CreateCheckbox(text, isSelected, setSelected, data)`, the second answering an element whose
-- `SetEnabled(false)` grays the entry. Clicking an enabled checkbox calls `setSelected(data)`.
--
-- Modeled on LibKa0s's own tests/mock_menu.lua, which is repo-local there and not in the kit, so a
-- consumer keeps its own (the library's docs/api/Launcher/version-4-docs.md, "Testing a host").
--
-- FIDELITY. Two things the client does that a convenient fake would not:
--   * a grayed entry is never clicked: `Click` refuses it the way the client does;
--   * the generator runs when the menu opens, once per open, so a cached state reads stale here as
--     it would in the client.
--
-- NOT installed by default. The harness's environment is the one a pre-11.0 client gives (no
-- `MenuUtil`), where the right click falls back to the settings panel; a case that wants the menu
-- calls `install()` and MUST call `remove()` before it returns, or every later suite's right click
-- opens a menu instead of the panel.

return function(mocks)
  local M = { menus = {}, opens = 0 }
  local RESPONSE = { Close = 1, Refresh = 2, Open = 3 }

  local function newRoot(owner)
    local menu = { owner = owner, titles = {}, entries = {} }
    local root = {}
    function root.CreateTitle(_, text)
      menu.titles[#menu.titles + 1] = text
      return {}
    end
    function root.CreateCheckbox(_, text, isSelected, setSelected, data)
      local entry = { text = text, isSelected = isSelected, setSelected = setSelected,
        data = data, enabled = true }
      local element = {}
      function element.SetEnabled(_, on) entry.enabled = on and true or false end
      function element.IsEnabled() return entry.enabled end
      menu.entries[#menu.entries + 1] = entry
      return element
    end

    --- The entries' texts, in order.
    function menu:Texts()
      local out = {}
      for i, e in ipairs(self.entries) do out[i] = e.text end
      return out
    end
    --- The entry whose text starts with `prefix`, or nil.
    function menu:Find(prefix)
      for _, e in ipairs(self.entries) do
        if e.text:sub(1, #prefix) == prefix then return e end
      end
    end
    --- Whether an entry draws checked, as the client asks it.
    function menu:Checked(prefix)
      local e = self:Find(prefix)
      return e and e.isSelected(e.data) and true or false
    end
    --- Click an entry as a player can: a grayed one does nothing and answers nil.
    function menu:Click(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      if not e.enabled then return nil end
      return e.setSelected(e.data)
    end
    return root, menu
  end

  M.MenuUtil = {
    CreateContextMenu = function(owner, generator)
      if owner == nil then error("CreateContextMenu: an owner region is required", 2) end
      local root, menu = newRoot(owner)
      M.opens = M.opens + 1
      generator(owner, root)
      M.menus[#M.menus + 1] = menu
      M.last = menu
      return menu
    end,
  }

  function M.install()
    M.menus, M.opens, M.last = {}, 0, nil
    mocks.MenuUtil = M.MenuUtil
    mocks.MenuResponse = RESPONSE
  end
  function M.remove()
    mocks.MenuUtil = nil
    mocks.MenuResponse = nil
  end

  M.RESPONSE = RESPONSE
  return M
end
