-- tests/test_events.lua — every event registration survives an unknown name (events-frames-taint-§1).
--
-- The client RAISES `Attempt to register unknown event "<NAME>"` on a name it does not know, and a
-- block of bare RegisterEvent calls loses every line after the one that raised. One event retired by
-- a patch would take the whole enable path down with it. So every registration the addon makes goes
-- through LibKa0s-Core's SafeRegister helpers (published as NS.SafeRegisterEvent /
-- NS.SafeRegisterUnitEvent by core/CoreSetup.lua), and every refused name lands once in the session
-- list NS.State.rejectedEvents, which `/at debug events` and the [Init] summary read back.
--
-- The kit's __badEvents is read at call time on every path from revision 26: the AceEvent registry,
-- a raw frame's RegisterEvent AND RegisterUnitEvent, and C_EventUtils.IsEventValid. So one table
-- models a retired event for both the AceEvent half and the per-unit frame half.
--
-- CLEANUP IS NOT OPTIONAL. This suite runs on the SHARED environment immediately before
-- test_disabled, which compares registration sets, so every case puts back the full registration set
-- and leaves __badEvents and the rejected list empty.

local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LIFECYCLE = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

--- Is `event` live on `target` as `kind`, optionally for `unit`?
local function registered(target, kind, event, unit)
  for _, r in ipairs(M.__registrations()) do
    if r.target == target and r.kind == kind and r.event == event
        and (unit == nil or r.unit == unit) then
      return true
    end
  end
  return false
end

local function countOf(list, name)
  local n = 0
  for _, v in ipairs(list) do if v == name then n = n + 1 end end
  return n
end

--- Drop the addon's lifecycle registrations so the next registration is the event's first on the
--- addon object, which is where the client (and the kit's AceEvent registry) raises.
local function dropLifecycle()
  for _, e in ipairs(LIFECYCLE) do NS.addon:UnregisterEvent(e) end
end

--- Put everything back: no bad names, an empty rejected list, the full registration set.
local function restore()
  M.__badEvents = {}
  local list = NS.State.rejectedEvents
  for i = #list, 1, -1 do list[i] = nil end
  NS.addon:RegisterLifecycleEvents()
  NS.addon:SyncUnitEventFrames()
end

--- Run `fn`, then restore whether or not it raised, then re-raise.
local function guarded(fn)
  local ok, err = pcall(fn)
  restore()
  if not ok then error(err, 0) end
end

local function capture(fn)
  local out = {}
  local cf = M.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err, 0) end
  return out
end

local function slash(line)
  local out = capture(function() NS.Slash:OnSlash(line) end)
  for i, l in ipairs(out) do out[i] = l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
  return table.concat(out, "\n")
end

test("events: the session rejected list exists and starts empty", function()
  assertEqual(type(NS.State.rejectedEvents), "table", "NS.State.rejectedEvents is the session list")
  assertEqual(#NS.State.rejectedEvents, 0, "nothing rejected in a clean session")
end)

test("events: one unknown lifecycle name costs only itself, and is listed once", function()
  -- red under: a bare self:RegisterEvent in RegisterLifecycleEvents (the first name raises and
  -- the two after it are never registered).
  guarded(function()
    dropLifecycle()
    M.__badEvents = { PLAYER_ENTERING_WORLD = true }
    local ok, err = pcall(NS.addon.RegisterLifecycleEvents, NS.addon)
    assertTrue(ok, "RegisterLifecycleEvents raised on one unknown name: " .. tostring(err))
    assertTrue(registered(NS.addon, "event", "PLAYER_REGEN_DISABLED"),
      "PLAYER_REGEN_DISABLED is still registered after the name before it was refused")
    assertTrue(registered(NS.addon, "event", "PLAYER_REGEN_ENABLED"),
      "PLAYER_REGEN_ENABLED is still registered after the name before it was refused")
    assertFalse(registered(NS.addon, "event", "PLAYER_ENTERING_WORLD"),
      "the refused name is not registered")
    assertEqual(countOf(NS.State.rejectedEvents, "PLAYER_ENTERING_WORLD"), 1)

    -- A disable/enable cycle runs the same block again; the list must not grow.
    NS.addon:RegisterLifecycleEvents()
    assertEqual(countOf(NS.State.rejectedEvents, "PLAYER_ENTERING_WORLD"), 1,
      "a second pass does not list the same name twice")
  end)
end)

test("events: one unknown unit event on the per-unit frame costs only itself", function()
  -- red under: a bare f:RegisterUnitEvent in SyncUnitEventFrames (kit 26's frame raises on it).
  guarded(function()
    NS.addon:SyncUnitEventFrames()
    local f = NS.addon.__unitEventFrames.player
    f:UnregisterAllEvents()
    M.__badEvents = { UNIT_MAXHEALTH = true }
    local ok, err = pcall(NS.addon.SyncUnitEventFrames, NS.addon)
    assertTrue(ok, "SyncUnitEventFrames raised on one unknown name: " .. tostring(err))
    assertTrue(registered(f, "unit", "UNIT_ABSORB_AMOUNT_CHANGED", "player"),
      "UNIT_ABSORB_AMOUNT_CHANGED is still registered on the player frame")
    assertFalse(registered(f, "unit", "UNIT_MAXHEALTH", "player"),
      "the refused unit event is not registered")
    assertEqual(countOf(NS.State.rejectedEvents, "UNIT_MAXHEALTH"), 1)
  end)
end)

test("events: a name IsEventValid refuses never reaches the target", function()
  guarded(function()
    dropLifecycle()
    local utils = M.C_EventUtils
    assertEqual(type(utils), "table", "the kit publishes C_EventUtils (revision 26)")
    local realValid = utils.IsEventValid
    utils.IsEventValid = function(name) return name ~= "PLAYER_REGEN_ENABLED" end
    local seen = {}
    local realRegister = rawget(NS.addon, "RegisterEvent")
    rawset(NS.addon, "RegisterEvent", function(self, event, ...)
      seen[#seen + 1] = event
      return realRegister(self, event, ...)
    end)
    local ok, err = pcall(NS.addon.RegisterLifecycleEvents, NS.addon)
    rawset(NS.addon, "RegisterEvent", realRegister)
    utils.IsEventValid = realValid
    assertTrue(ok, tostring(err))
    assertEqual(countOf(seen, "PLAYER_REGEN_ENABLED"), 0,
      "the front gate refused the name before the target's RegisterEvent saw it")
    assertEqual(countOf(seen, "PLAYER_ENTERING_WORLD"), 1, "the other names still reach the target")
    assertEqual(countOf(NS.State.rejectedEvents, "PLAYER_REGEN_ENABLED"), 1)
  end)
end)

test("events: /at debug events lists the rejected names, and 'none' once they are gone", function()
  guarded(function()
    dropLifecycle()
    M.__badEvents = { PLAYER_ENTERING_WORLD = true, PLAYER_REGEN_ENABLED = true }
    NS.addon:RegisterLifecycleEvents()
    local out = slash("debug events")
    assertTrue(out:find("Rejected events: PLAYER_ENTERING_WORLD, PLAYER_REGEN_ENABLED", 1, true) ~= nil,
      "the verb prints the comma-joined list, got: " .. out)
  end)
  local out = slash("debug events")
  assertTrue(out:find("Rejected events: none", 1, true) ~= nil,
    "after cleanup the verb prints 'none', got: " .. out)
  for _, e in ipairs(LIFECYCLE) do
    assertTrue(registered(NS.addon, "event", e), e .. " is registered again after cleanup")
  end
end)
