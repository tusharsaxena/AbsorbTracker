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
  local f = { __shown = false, __scripts = {} }
  -- Track shown state so IsShown/Toggle behave (the debug console's visibility checkbox reads it).
  -- Every other capitalized method still no-ops through the metatable below.
  function f:Show() self.__shown = true; return self end
  function f:Hide() self.__shown = false; return self end
  function f:SetShown(v) self.__shown = not not v; return self end
  function f:IsShown() return self.__shown end
  function f:IsVisible() return self.__shown end

  -- Store handlers instead of discarding them, and expose __fire so a test can drive the lazy
  -- OnShow paths the panel depends on (the deferred body render, and EnsureDefaultsButton's
  -- first-OnShow build — options-ui-§5). A no-op SetScript made those unreachable.
  function f:SetScript(name, fn) self.__scripts[name] = fn; return self end
  function f:GetScript(name) return self.__scripts[name] end
  function f:HookScript(name, fn)
    local prev = self.__scripts[name]
    self.__scripts[name] = function(...)
      if prev then prev(...) end
      return fn(...)
    end
    return self
  end
  function f:__fire(name, ...)
    local fn = self.__scripts[name]
    if fn then return fn(self, ...) end
  end

  -- Geometry and naming must return real values, not the frame: settings/ScrollPatch.lua does
  -- arithmetic on GetHeight() and string-concatenates GetName(), both of which raise on a table.
  -- Deliberately NOT defining the setters (SetSize/SetWidth/...): tests spy on those by rawsetting
  -- a recorder and rawsetting nil to restore, which would erase an explicit definition for good.
  function f:GetName() return nil end
  function f:GetHeight() return 0 end
  function f:GetWidth() return 0 end

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
  M.UnitAffectingCombat = function() return false end

  -- UI
  M.UIParent = stubFrame()
  M.CreateFrame = function() return stubFrame() end
  M.UISpecialFrames = {}
  M.DEFAULT_CHAT_FRAME = stubFrame()
  M.StaticPopupDialogs = {}
  M.StaticPopup_Show = function() end
  M.GameTooltip = stubFrame()
  -- Record the canvas frames as they are registered. This is the only public seam a test has for
  -- reaching the real page panels built by settings/<page>.lua, which is what makes it possible to
  -- fire their OnShow and exercise the genuine deferred render.
  M.__mainPanel    = nil
  M.__subcategories = {}   -- [displayName] = panel frame
  M.Settings = {
    RegisterCanvasLayoutCategory = function(panel)
      M.__mainPanel = panel
      return { GetID = function() return 1 end }
    end,
    RegisterCanvasLayoutSubcategory = function(_parent, panel, name)
      M.__subcategories[name] = panel
      return {}
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() end,
  }

  -- LibStub + Ace library mocks
  local libs = {}
  -- AceDB-3.0 with a WORKING profile surface. A bare {global, profile} stub left the entire
  -- `/at profile` verb untestable: runProfile bails at `if not db.SetProfile` before touching a
  -- single subcommand, so a broken switch/copy/delete would pass the suite silently. Model enough
  -- of the real lib to exercise it — a named profile store, switch/copy/delete/reset, and the
  -- OnProfileChanged / OnProfileCopied / OnProfileReset callbacks AceDB fires via CallbackHandler
  -- (which is what wires NS.OnProfileChanged in core/Database.lua).
  libs["AceDB-3.0"] = {
    -- `tbl` is the real signature's first arg: either the STRING name of a global SavedVariables
    -- table (what the addon passes: `AceDB:New("AbsorbTrackerDB", ...)`), or an actual table.
    -- Resolving it against `_G` (rather than always starting fresh) is what lets a test seed
    -- `_G.AbsorbTrackerDB` with a legacy profile and then drive the REAL NS:InitDB() path to
    -- prove the v3 migration lift actually fires against real AceDB's merge-in-place semantics,
    -- instead of only against a bespoke plain-table `NS.db` that never triggers them.
    New = function(_, tbl, defaults)
      local sv
      if type(tbl) == "string" then
        sv = _G[tbl]
        if not sv then
          sv = {}
          _G[tbl] = sv
        end
      else
        sv = tbl or {}
      end
      sv.profiles = sv.profiles or {}
      sv.global = sv.global or {}

      local db = {}
      local current, callbacks = "Default", {}

      -- Faithful (if simplified) copy of AceDB-3.0's copyDefaults: recurse into every
      -- TABLE-valued default, creating the dest sub-table if it's missing, but only ever fill a
      -- SCALAR leaf when the dest doesn't already have it. An existing user value always wins —
      -- this is the exact merge-in-place behavior that made the real v3 lift bug possible (a
      -- bare read of db.profile silently pre-populates a brand-new `units` table from defaults
      -- before RunMigrations' old `units == nil` guard ever got to look at it).
      local function copyDefaults(dest, src)
        for k, v in pairs(src or {}) do
          if type(v) == "table" then
            if type(dest[k]) ~= "table" then dest[k] = {} end
            copyDefaults(dest[k], v)
          elseif dest[k] == nil then
            dest[k] = v
          end
        end
      end

      local function ensureProfile(name)
        sv.profiles[name] = sv.profiles[name] or {}
        copyDefaults(sv.profiles[name], defaults and defaults.profile)
        return sv.profiles[name]
      end

      copyDefaults(sv.global, defaults and defaults.global)
      db.global  = sv.global
      db.profile = ensureProfile(current)

      local function fire(event)
        for _, cb in ipairs(callbacks[event] or {}) do cb(event, db, current) end
      end

      -- CallbackHandler shape: db.RegisterCallback(target, event, fn) — dot-called, so the
      -- registering object arrives as the first arg. core/Database.lua passes a function ref.
      db.RegisterCallback = function(_target, event, fn)
        callbacks[event] = callbacks[event] or {}
        callbacks[event][#callbacks[event] + 1] = fn
      end

      db.GetCurrentProfile = function() return current end

      db.GetProfiles = function()
        local names = {}
        for name in pairs(sv.profiles) do names[#names + 1] = name end
        table.sort(names)
        return names
      end

      db.SetProfile = function(_, name)
        if name == current then return end
        current = name
        db.profile = ensureProfile(name)
        fire("OnProfileChanged")
      end

      db.ResetProfile = function()
        -- Wipe in place: the real lib keeps the profile table's identity across a reset, so
        -- anything holding a reference to db.profile keeps seeing the live table.
        local p = sv.profiles[current]
        for k in pairs(p) do p[k] = nil end
        copyDefaults(p, defaults and defaults.profile)
        fire("OnProfileReset")
      end

      db.CopyProfile = function(_, name)
        local src = sv.profiles[name]
        if not src or name == current then return end
        local p = sv.profiles[current]
        for k in pairs(p) do p[k] = nil end
        for k, v in pairs(deepcopy(src)) do p[k] = v end
        fire("OnProfileCopied")
      end

      db.DeleteProfile = function(_, name)
        if name == current then return end
        sv.profiles[name] = nil
      end

      return db
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
  -- AceEvent-3.0 message bus. A no-op Embed would hide the whole (message, target)
  -- clobber class of bug (architecture-§4 / anti-pattern #33): the real lib keys
  -- callbacks by (message, target) through one shared registry, so a SendMessage on
  -- any embedded object fans out to every target that registered that message, and
  -- two receivers on ONE target would overwrite each other. Model that faithfully:
  -- one registry shared across every embed, dispatching fn(message, ...) exactly as
  -- CallbackHandler fires a function-ref callback. Fresh per build() for isolation.
  local busRegistry = {}  -- [message] = { [target] = fn }
  libs["AceEvent-3.0"] = {
    Embed = function(_, obj)
      obj.RegisterMessage = function(self, msg, fn)
        busRegistry[msg] = busRegistry[msg] or {}
        busRegistry[msg][self] = fn
      end
      obj.UnregisterMessage = function(self, msg)
        if busRegistry[msg] then busRegistry[msg][self] = nil end
      end
      obj.SendMessage = function(_, msg, ...)
        local subs = busRegistry[msg]
        if not subs then return end
        for _, fn in pairs(subs) do fn(msg, ...) end
      end
      return obj
    end,
  }
  -- AceGUI-3.0. Without this NS.AceGUI stays nil, every widget maker in settings/Widgets.lua
  -- returns early, and the schema → widget translation layer (four makers + RenderField +
  -- RenderSchema) is untestable. Widgets here are inert data recorders rather than frames: they
  -- remember what was set on them and, crucially, expose __fire so a test can drive the
  -- OnValueChanged / OnMouseUp / OnValueConfirmed callbacks the way a real click would — which is
  -- what exercises the read → SetByPath → RefreshAllPanels loop.
  local function makeWidget(wtype)
    local w = {
      type      = wtype,
      children  = {},
      callbacks = {},
      frame     = stubFrame(),
    }
    function w:SetLabel(v) self.labelText = v; return self end
    function w:SetText(v) self.text = v; return self end
    function w:SetValue(v) self.value = v; return self end
    function w:GetValue() return self.value end
    function w:SetList(items, order) self.list, self.order = items, order; return self end
    function w:SetColor(r, g, b, a) self.color = { r = r, g = g, b = b, a = a }; return self end
    function w:SetHasAlpha(v) self.hasAlpha = v; return self end
    function w:SetDisabled(v) self.disabled = v and true or false; return self end
    function w:SetSliderValues(mn, mx, st) self.min, self.max, self.step = mn, mx, st; return self end
    function w:SetIsPercent(v) self.isPercent = v; return self end
    function w:SetWidth(v) self.width = v; return self end
    function w:SetHeight(v) self.height = v; return self end
    function w:SetRelativeWidth(v) self.relativeWidth = v; return self end
    function w:SetFullWidth(v) self.fullWidth = v and true or false; return self end
    function w:SetLayout(v) self.layout = v; return self end
    function w:SetAutoAdjustHeight(v) self.autoAdjustHeight = v; return self end
    function w:SetImage(...) self.image = { ... }; return self end
    function w:SetImageSize(...) self.imageSize = { ... }; return self end
    function w:SetCallback(name, fn) self.callbacks[name] = fn; return self end
    function w:AddChild(child) self.children[#self.children + 1] = child; return self end
    function w:ReleaseChildren() self.children = {}; return self end
    function w:DoLayout() self.layoutCount = (self.layoutCount or 0) + 1; return self end
    -- AceGUI invokes a callback as fn(widget, eventName, ...); mirror that exactly, because the
    -- makers destructure it as function(_, _, value).
    function w:__fire(name, ...)
      local fn = self.callbacks[name]
      if fn then return fn(self, name, ...) end
    end

    if wtype == "ScrollFrame" then
      -- settings/ScrollPatch.lua reaches into these three by name and does real work with them.
      w.scrollbar   = stubFrame()
      w.scrollframe = stubFrame()
      w.content     = stubFrame()
      w.content.original_width = 400
      w.localstatus = { offset = 0 }
      function w:FixScroll() self.fixScrollCount = (self.fixScrollCount or 0) + 1 end
      function w:MoveScroll(v) self.movedTo = v end
      function w:SetScroll(v) self.scrolledTo = v end
    end
    return w
  end

  local aceGUI = {
    -- Populated by RegisterWidgetType. Empty by default, which models
    -- AceGUI-3.0-SharedMediaWidgets being absent: makeDropdown asks GetWidgetVersion about
    -- LSM30_* and falls back to a plain Dropdown when it comes back nil.
    WidgetRegistry   = {},
    __widgetVersions = {},
  }
  function aceGUI:Create(wtype)
    local ctor = self.WidgetRegistry[wtype]
    if ctor then return ctor() end
    return makeWidget(wtype)
  end
  function aceGUI:GetWidgetVersion(wtype) return self.__widgetVersions[wtype] end
  function aceGUI:RegisterWidgetType(wtype, ctor, version)
    self.WidgetRegistry[wtype]   = ctor
    self.__widgetVersions[wtype] = version
  end
  M.__makeAceGUIWidget = makeWidget
  libs["AceGUI-3.0"] = aceGUI

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
