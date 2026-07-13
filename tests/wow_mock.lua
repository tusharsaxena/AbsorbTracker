-- Minimal WoW-API mock set for headless unit tests. Returns a builder so each run gets a fresh,
-- isolated environment. Only what the addon touches at load/test time is stubbed.

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

-- A universal frame stub: any PascalCase method is a no-op returning the frame itself; other
-- (lowercase/custom) field access misses through to nil so addon code can stash custom fields.
local function stubFrame()
  local f = {}
  setmetatable(f, { __index = function(_, k)
    if type(k) == "string" and k:match("^%u") then
      return function() return f end
    end
    return nil
  end })
  return f
end

return function()
  local M = {}

  -- time / string
  M.__now = 0
  M.time = os.time
  M.date = os.date
  M.GetTime = function() return M.__now end
  M.format = string.format
  M.wipe = function(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end return t end

  -- Scheduled one-shot timers, recorded so tests can inspect coalescing and fire them on demand.
  M.__timers = {}
  M.__fireTimers = function()
    local due = M.__timers
    M.__timers = {}
    for _, t in ipairs(due) do t.fn() end
  end

  -- player / absorb / world
  M.UnitClass = function() return "Mage", "MAGE", 8 end
  M.UnitGetTotalAbsorbs = function() return 0 end
  M.UnitHealthMax = function() return 100 end
  M.AbbreviateNumbers = function(n) return tostring(n) end
  M.C_ClassColor = { GetClassColor = function() return { r = 1, g = 1, b = 1 } end }
  M.InCombatLockdown = function() return false end

  -- UI
  M.UIParent = stubFrame()
  M.CreateFrame = function() return stubFrame() end
  M.UISpecialFrames = {}
  M.DEFAULT_CHAT_FRAME = stubFrame()
  M.StaticPopupDialogs = {}
  M.StaticPopup_Show = function() end
  M.GameTooltip = stubFrame()
  M.Settings = {
    RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end } end,
    RegisterCanvasLayoutSubcategory = function() return {} end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
  }

  -- LibStub + Ace library mocks
  local libs = {}
  libs["AceDB-3.0"] = {
    New = function(_, _name, defaults)
      return {
        global = deepcopy(defaults and defaults.global or {}),
        profile = deepcopy(defaults and defaults.profile or {}),
      }
    end,
  }
  libs["AceAddon-3.0"] = {
    NewAddon = function(_, target)
      target = target or {}
      local noop = function() end
      target.RegisterEvent = noop
      target.UnregisterEvent = noop
      target.RegisterChatCommand = noop
      target.ScheduleTimer = function(_, fn, delay)
        local timer = { fn = fn, delay = delay }
        M.__timers[#M.__timers + 1] = timer
        return timer
      end
      target.ScheduleRepeatingTimer = function() return {} end
      target.CancelTimer = noop
      -- Faithfully mirror AceConsole-3.0's Embed: it stamps a :Print mixin onto the addon object,
      -- clobbering any same-named custom NS.Print. Called as `NS.Print(msg)`, AceConsole treats the
      -- message as `self` and renders "|cff33ff99<msg>|r:" — green, trailing colon, no tag. The
      -- addon must reclaim NS.Print after NewAddon; reproducing the clobber here lets the tests
      -- exercise the real production print path instead of a clean one the client never uses.
      target.Print = function(selfOrMsg, ...)
        local parts = { "|cff33ff99" .. tostring(selfOrMsg) .. "|r:" }
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " ")) end
      end
      return target
    end,
  }
  libs["AceEvent-3.0"] = { Embed = function(_, obj) return obj end }
  libs["AceTimer-3.0"] = { Embed = function(_, obj) return obj end }
  libs["AceConsole-3.0"] = { Embed = function(_, obj) return obj end }

  -- LibStub("X") and LibStub("X", true) both resolve to the mock (or nil when absent). The
  -- second silent arg is ignored — a missing lib returns nil either way, mirroring the addon's
  -- soft-optional lib usage (LibSharedMedia / AceGUI are absent headlessly).
  M.LibStub = setmetatable(
    { GetLibrary = function(_, n) return libs[n] end },
    { __call = function(_, n) return libs[n] end }
  )

  return M
end
