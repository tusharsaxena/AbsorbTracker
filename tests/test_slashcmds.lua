local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- settings/Slash.lua, second half: the verbs tests/test_slash.lua does not reach — lock/unlock,
-- toggle, the three reset verbs, update, test, the whole /at profile sub-dispatcher, and the
-- get/set failure paths. Together with test_slash.lua this covers every entry in NS.COMMANDS.

-- Same capture seam as test_slash.lua: Slash.lua bound `local print = NS.Print` at load, so the
-- only interceptable point is the chat frame's AddMessage sink.
local function capture(fn)
  local out = {}
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err) end
  return out
end

local function stripColor(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Run a slash line and return its plain-text output lines.
local function slash(line)
  local out = capture(function() NS.Slash:OnSlash(line) end)
  local plain = {}
  for i, l in ipairs(out) do plain[i] = stripColor(l) end
  return plain
end

local function joined(lines) return table.concat(lines, "\n") end

local function contains(lines, needle)
  return joined(lines):find(needle, 1, true) ~= nil
end

-- ── COMMANDS table shape ───────────────────────────────────────────────────────────

test("every COMMANDS entry is a {name, description, handler} triple", function()
  for i, entry in ipairs(NS.COMMANDS) do
    local where = "COMMANDS[" .. i .. "]"
    assertEqual(type(entry[1]), "string", where .. " has a name")
    assertTrue(entry[1] ~= "", where .. " name is non-empty")
    assertEqual(type(entry[2]), "string", where .. " (" .. entry[1] .. ") has a description")
    assertTrue(entry[2] ~= "", where .. " (" .. entry[1] .. ") description is non-empty")
    assertEqual(type(entry[3]), "function", where .. " (" .. entry[1] .. ") has a handler")
  end
end)

test("COMMANDS verbs are unique and already lower-case", function()
  -- OnSlash lower-cases the typed verb before lookup, so an upper-case entry here would be
  -- permanently unreachable.
  local seen = {}
  for _, entry in ipairs(NS.COMMANDS) do
    assertEqual(entry[1], entry[1]:lower(), entry[1] .. " must be lower-case to be dispatchable")
    assertEqual(seen[entry[1]], nil, "duplicate verb: " .. entry[1])
    seen[entry[1]] = true
  end
end)

test("NS.SlashCommands is the same table the About page renders", function()
  assertEqual(NS.SlashCommands, NS.COMMANDS, "the two must not drift apart")
end)

-- ── lock / unlock / toggle ─────────────────────────────────────────────────────────

test("/at lock and /at unlock write the `locked` setting and acknowledge", function()
  local out = slash("lock")
  assertTrue(NS.GetSetting("locked"), "lock sets locked = true")
  assertTrue(contains(out, "Bar locked"), joined(out))

  out = slash("unlock")
  assertFalse(NS.GetSetting("locked"), "unlock sets locked = false")
  assertTrue(contains(out, "Bar unlocked"), joined(out))
end)

-- Bare `/at toggle` flips EVERY bar together: off if any is on, otherwise all on. A plain
-- per-unit flip would invert a mixed set (player on + target off -> player off + target on),
-- which is not what "toggle the bars" means.
test("/at toggle turns every bar off, then every bar back on", function()
  NS.db.profile.units.player.enabled = true
  NS.db.profile.units.target.enabled = false
  NS.db.profile.units.focus.enabled  = false

  local out = slash("toggle")
  for _, unit in ipairs(NS.Units.LIST) do
    assertFalse(NS.Units.IsEnabled(unit), unit .. " must be off after the first toggle")
  end
  assertTrue(contains(out, "All bars hidden"), joined(out))

  out = slash("toggle")
  for _, unit in ipairs(NS.Units.LIST) do
    assertTrue(NS.Units.IsEnabled(unit), unit .. " must be on after the second toggle")
  end
  assertTrue(contains(out, "All bars shown"), joined(out))

  NS.db.profile.units.target.enabled = false
  NS.db.profile.units.focus.enabled  = false
  T.mocks.__fireTimers()
end)

test("/at toggle <unit> flips only that unit", function()
  NS.db.profile.units.player.enabled = true
  NS.db.profile.units.target.enabled = false

  local out = slash("toggle target")
  assertTrue(NS.Units.IsEnabled("target"), "the named unit flips on")
  assertTrue(NS.Units.IsEnabled("player"), "and the others are left alone")
  assertTrue(contains(out, "Target bar shown"), joined(out))

  out = slash("toggle target")
  assertFalse(NS.Units.IsEnabled("target"), "and back off")
  assertTrue(contains(out, "Target bar hidden"), joined(out))
  T.mocks.__fireTimers()
end)

test("/at toggle rejects an unknown unit and changes nothing", function()
  local before = NS.Units.IsEnabled("player")
  local out = slash("toggle wibble")
  assertTrue(contains(out, "unknown unit 'wibble'"), joined(out))
  assertEqual(NS.Units.IsEnabled("player"), before, "a rejected token must not flip anything")
end)

test("/at toggle requests a repaint when SHOWING, not when hiding", function()
  -- A bar that has just been re-enabled holds whatever value it had when it went away; the repaint
  -- is what makes it current. Hiding needs no paint work.
  --
  -- The verb delegates to SetByPath, so the enable row's onChange (settings/General.lua) owns the
  -- republish and the CLI travels the same path as the panel checkbox. One publish per unit
  -- written, coalesced by RequestRepaint into a single armed timer either way.
  NS.db.profile.units.player.enabled = true
  NS.db.profile.units.target.enabled = false
  NS.db.profile.units.focus.enabled  = false
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.REPAINT, function() seen = seen + 1 end)

  T.mocks.__fireTimers()                                    -- drain, so `pending` starts clear
  capture(function() NS.Slash:OnSlash("toggle player") end)  -- -> off
  assertEqual(seen, 0, "hiding schedules no repaint")
  assertEqual(#T.mocks.__timers, 0, "and arms no timer")

  capture(function() NS.Slash:OnSlash("toggle player") end)  -- -> on
  assertEqual(seen, 1, "showing publishes exactly one repaint, from the schema onChange")
  assertEqual(#T.mocks.__timers, 1, "which arms exactly one coalesced timer")

  target:UnregisterMessage(NS.MSG.REPAINT)
  T.mocks.__fireTimers()
end)

-- ── update ─────────────────────────────────────────────────────────────────────────

test("/at update publishes REPAINT and acknowledges", function()
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.REPAINT, function() seen = seen + 1 end)
  local out = slash("update")
  target:UnregisterMessage(NS.MSG.REPAINT)
  assertEqual(seen, 1)
  assertTrue(contains(out, "Forced refresh"), joined(out))
  T.mocks.__fireTimers()
end)

-- ── reset / resetall / resetposition ───────────────────────────────────────────────

test("/at reset with no page prints usage rather than resetting anything", function()
  NS.SetSetting("barWidth", 250)
  local out = slash("reset")
  assertTrue(contains(out, "Usage: /at reset"), joined(out))
  assertEqual(NS.GetSetting("barWidth"), 250, "nothing was reset")
  NS.SetSetting("barWidth", 200)
end)

test("/at reset rejects an unknown page and names the valid ones", function()
  local out = slash("reset bogus")
  assertTrue(contains(out, "Unknown page 'bogus'"), joined(out))
  assertTrue(contains(out, "general, bar, border, font"), joined(out))
end)

test("/at reset <page> restores just that page", function()
  -- Retargeted (spec §9): reset now applies per-unit dotted paths, not the old flat keys.
  NS.SetSetting("units.player.barWidth", 250)
  NS.SetSetting("units.player.borderSize", 20)
  local out = slash("reset bar")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(NS.GetSetting("units.player.borderSize"), 20, "the border page is untouched")
  assertTrue(contains(out, "bar page reset to defaults"), joined(out))
  slash("reset border")
end)

test("/at reset lower-cases the page name", function()
  NS.SetSetting("units.player.barWidth", 250)
  slash("reset BAR")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
end)

test("/at resetall goes through the one shared RestoreAllDefaults helper", function()
  -- The slash verb and the "Reset All Settings" popup must never diverge, so the verb owns no
  -- reset logic of its own — it only delegates.
  local called = 0
  local orig = NS.Helpers.RestoreAllDefaults
  NS.Helpers.RestoreAllDefaults = function() called = called + 1 end
  local out = capture(function() NS.Slash:OnSlash("resetall") end)
  NS.Helpers.RestoreAllDefaults = orig
  assertEqual(called, 1)
  assertTrue(joined(out):find("All settings reset to defaults", 1, true) ~= nil)
end)

test("/at resetall really does restore the defaults end to end", function()
  NS.SetSetting("units.player.barWidth", 250)
  NS.SetSetting("units.player.fontSize", 30)
  slash("resetall")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(NS.GetSetting("units.player.fontSize"), NS.unitDefaults.fontSize)
  T.mocks.__fireTimers()
end)

test("/at resetposition clears the saved anchor and republishes POSITION", function()
  -- Retargeted (spec §9): position now lives per-unit; the guarantee this pins — clear +
  -- republish exactly once — is unchanged, just against the player unit's dotted path.
  NS.db.profile.units.player.position = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 9, y = 9 }
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.POSITION, function() seen = seen + 1 end)
  local out = slash("resetposition")
  target:UnregisterMessage(NS.MSG.POSITION)
  assertEqual(NS.db.profile.units.player.position, nil)
  assertEqual(seen, 1)
  assertTrue(contains(out, "Bar positions reset"), joined(out))
end)

-- ── get / set failure paths ────────────────────────────────────────────────────────

test("/at get with no path prints usage", function()
  assertTrue(contains(slash("get"), "Usage: /at get <path>"))
end)

test("/at get on an unknown path says so instead of printing nil", function()
  assertTrue(contains(slash("get nosuchsetting"), "Setting not found: nosuchsetting"))
end)

test("/at set with no path prints usage and points at /at list", function()
  local out = slash("set")
  assertTrue(contains(out, "Usage: /at set <path> <value>"), joined(out))
  assertTrue(contains(out, "/at list"), joined(out))
end)

test("/at set on an unknown path says so", function()
  assertTrue(contains(slash("set nosuchsetting 5"), "Setting not found: nosuchsetting"))
end)

test("/at set rejects a junk boolean and lists the words it accepts", function()
  local before = NS.GetSetting("locked")
  local out = slash("set locked maybe")
  assertTrue(contains(out, "Invalid value for locked"), joined(out))
  assertTrue(contains(out, "true/false/on/off/1/0/yes/no"), joined(out))
  assertEqual(NS.GetSetting("locked"), before, "a rejected parse must not write")
end)

test("/at set rejects a non-numeric value for a number setting", function()
  -- Retargeted (spec §9): appearance paths are qualified now, so this exercises
  -- units.player.barWidth rather than the no-longer-valid unqualified "barWidth".
  local out = slash("set units.player.barWidth wide")
  assertTrue(contains(out, "Invalid value for units.player.barWidth"), joined(out))
  assertTrue(contains(out, "expected a number"), joined(out))
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
end)

test("/at set writes a colour from `r g b a` and echoes the STORED value", function()
  local out = slash("set units.player.barColor 0.1 0.2 0.3 0.4")
  local c = NS.GetSetting("units.player.barColor")
  assertTrue(math.abs(c.r - 0.1) < 1e-6 and math.abs(c.a - 0.4) < 1e-6,
    "the parsed colour was stored")
  assertTrue(contains(out, "{0.10, 0.20, 0.30, 0.40}"), joined(out))
  slash("reset bar")
  T.mocks.__fireTimers()
end)

test("/at set accepts a bool written as a human word", function()
  slash("set locked yes")
  assertTrue(NS.GetSetting("locked"))
  slash("set locked off")
  assertFalse(NS.GetSetting("locked"))
end)

-- ── /at test ───────────────────────────────────────────────────────────────────────

test("/at test refuses while every bar is disabled and tells the user how to fix it", function()
  local savedHold = NS.testHoldUntil
  local saved = {}
  for _, unit in ipairs(NS.Units.LIST) do
    saved[unit] = NS.db.profile.units[unit].enabled
    NS.db.profile.units[unit].enabled = false
  end
  local out = slash("test")
  for _, unit in ipairs(NS.Units.LIST) do
    NS.db.profile.units[unit].enabled = saved[unit]
  end
  assertTrue(contains(out, "Every bar is disabled"), joined(out))
  assertTrue(contains(out, "/at toggle"), joined(out))
  assertEqual(NS.testHoldUntil, savedHold, "no hold window is armed on the refusal path")
end)

test("/at test paints the given value and arms the hold window", function()
  NS.db.profile.units.player.enabled = true
  local painted
  local sb = NS.statusBar
  rawset(sb, "SetValue", function(_, v) painted = v end)
  local out = slash("test 12345 7")
  rawset(sb, "SetValue", nil)
  assertEqual(painted, 12345)
  assertEqual(NS.testHoldUntil, T.mocks.GetTime() + 7)
  assertTrue(contains(out, "Testing display with value"), joined(out))
  NS.testHoldUntil = nil
end)

test("/at test defaults to 50000 held for 5 seconds", function()
  NS.SetSetting("hidden", false)
  local painted
  local sb = NS.statusBar
  rawset(sb, "SetValue", function(_, v) painted = v end)
  slash("test")
  rawset(sb, "SetValue", nil)
  assertEqual(painted, 50000)
  assertEqual(NS.testHoldUntil, T.mocks.GetTime() + 5)
  NS.testHoldUntil = nil
end)

test("/at test keeps the bar scale usable for a value below the 100k floor", function()
  -- A small test value must not shrink the scale below 100000, or the fake fill reads as full.
  NS.SetSetting("hidden", false)
  local mn, mx
  local sb = NS.statusBar
  rawset(sb, "SetMinMaxValues", function(_, a, b) mn, mx = a, b end)
  slash("test 500")
  rawset(sb, "SetMinMaxValues", nil)
  assertEqual(mn, 0)
  assertEqual(mx, 100000)
  NS.testHoldUntil = nil
end)

-- ── /at profile ────────────────────────────────────────────────────────────────────

-- Leave the DB on the Default profile whatever a test did.
local function backToDefault()
  if NS.db and NS.db.SetProfile then NS.db:SetProfile("Default") end
  T.mocks.__fireTimers()
end

test("/at profile with no subcommand prints the sub-help", function()
  local out = slash("profile")
  assertTrue(contains(out, "Profile commands"), joined(out))
  for _, sub in ipairs({ "list", "current", "use", "new", "copy", "delete", "reset" }) do
    assertTrue(contains(out, "/at profile " .. sub), "sub-help lists " .. sub)
  end
end)

test("/at profile current names the active profile", function()
  assertTrue(contains(slash("profile current"), "Current profile: Default"))
end)

test("/at profile list marks the current profile", function()
  NS.db:SetProfile("Alt")
  T.mocks.__fireTimers()
  local out = slash("profile list")
  backToDefault()
  assertTrue(contains(out, "Available profiles"), joined(out))
  assertTrue(contains(out, "Alt (current)"), joined(out))
  assertTrue(contains(out, "Default"), joined(out))
  assertTrue(joined(out):find("Default %(current%)") == nil, "only one profile is marked current")
end)

test("/at profile use switches the active profile", function()
  local out = slash("profile use Alt")
  assertEqual(NS.db:GetCurrentProfile(), "Alt")
  assertTrue(contains(out, "Switched to profile 'Alt'"), joined(out))
  backToDefault()
end)

test("/at profile use with no name prints usage and switches nothing", function()
  local out = slash("profile use")
  assertEqual(NS.db:GetCurrentProfile(), "Default")
  assertTrue(contains(out, "Usage: /at profile use <name>"), joined(out))
end)

test("/at profile new creates a profile carrying the defaults, not the old values", function()
  NS.SetSetting("barWidth", 456)
  local out = slash("profile new Fresh")
  assertEqual(NS.db:GetCurrentProfile(), "Fresh")
  assertEqual(NS.GetSetting("barWidth"), NS.flatDefaults.barWidth,
    "a new profile starts from defaults")
  assertTrue(contains(out, "Created and switched to new profile 'Fresh'"), joined(out))
  backToDefault()
  slash("reset bar")
  T.mocks.__fireTimers()
end)

test("/at profile new with no name prints usage", function()
  assertTrue(contains(slash("profile new"), "Usage: /at profile new <name>"))
end)

test("/at profile copy pulls another profile's values into the current one", function()
  NS.db:SetProfile("Source")
  T.mocks.__fireTimers()
  NS.SetSetting("units.player.barWidth", 411)
  NS.db:SetProfile("Default")
  T.mocks.__fireTimers()
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth,
    "Default is untouched so far")

  local out = slash("profile copy Source")
  assertEqual(NS.GetSetting("units.player.barWidth"), 411,
    "the source's value landed in the current profile")
  assertEqual(NS.db:GetCurrentProfile(), "Default", "copy does not switch profiles")
  assertTrue(contains(out, "Copied settings from profile 'Source'"), joined(out))
  slash("reset bar")
  T.mocks.__fireTimers()
end)

test("/at profile copy with no name prints usage", function()
  assertTrue(contains(slash("profile copy"), "Usage: /at profile copy <name>"))
end)

test("/at profile delete refuses to delete the profile in use", function()
  local out = slash("profile delete Default")
  assertTrue(contains(out, "Cannot delete the current profile"), joined(out))
  local names = table.concat(NS.db:GetProfiles(), ",")
  assertTrue(names:find("Default", 1, true) ~= nil, "and it is still there")
end)

test("/at profile delete removes a profile that is not in use", function()
  NS.db:SetProfile("Doomed")
  T.mocks.__fireTimers()
  backToDefault()
  local out = slash("profile delete Doomed")
  assertTrue(contains(out, "Deleted profile 'Doomed'"), joined(out))
  local names = table.concat(NS.db:GetProfiles(), ",")
  assertTrue(names:find("Doomed", 1, true) == nil, "it is gone from the list")
end)

test("/at profile delete with no name prints usage", function()
  assertTrue(contains(slash("profile delete"), "Usage: /at profile delete <name>"))
end)

test("/at profile reset restores the current profile's defaults in place", function()
  NS.SetSetting("barWidth", 478)
  local out = slash("profile reset")
  assertEqual(NS.GetSetting("barWidth"), NS.flatDefaults.barWidth)
  assertEqual(NS.db:GetCurrentProfile(), "Default", "reset does not switch profiles")
  assertTrue(contains(out, "Profile reset to defaults"), joined(out))
  T.mocks.__fireTimers()
end)

test("/at profile rejects an unknown subcommand and reprints the sub-help", function()
  local out = slash("profile frobnicate")
  assertTrue(contains(out, "Unknown profile subcommand 'frobnicate'"), joined(out))
  assertTrue(contains(out, "Profile commands"), "the sub-help follows the error")
end)

test("/at profile sub-verbs are case-insensitive", function()
  assertTrue(contains(slash("profile CURRENT"), "Current profile: Default"))
end)

test("/at profile degrades gracefully when AceDB is unavailable", function()
  local saved = NS.db
  NS.db = { profile = {}, global = {} }   -- no SetProfile: the no-AceDB fallback shape
  local out = capture(function() NS.Slash:OnSlash("profile list") end)
  NS.db = saved
  assertTrue(joined(out):find("Profile system requires AceDB-3.0", 1, true) ~= nil, joined(out))
end)

test("a profile switch repaints the bar through OnProfileChanged", function()
  -- core/Database.lua wires OnProfileChanged/Copied/Reset to NS.OnProfileChanged, which republishes
  -- POSITION / APPEARANCE / REPAINT so the bar picks up the new profile's look immediately.
  local seen = { pos = 0, app = 0, rep = 0 }
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.POSITION,   function() seen.pos = seen.pos + 1 end)
  local t2 = NS.NewBusTarget()
  t2:RegisterMessage(NS.MSG.APPEARANCE,     function() seen.app = seen.app + 1 end)
  local t3 = NS.NewBusTarget()
  t3:RegisterMessage(NS.MSG.REPAINT,        function() seen.rep = seen.rep + 1 end)

  capture(function() NS.Slash:OnSlash("profile use Switched") end)

  target:UnregisterMessage(NS.MSG.POSITION)
  t2:UnregisterMessage(NS.MSG.APPEARANCE)
  t3:UnregisterMessage(NS.MSG.REPAINT)
  backToDefault()

  assertEqual(seen.pos, 1)
  assertEqual(seen.app, 1)
  assertEqual(seen.rep, 1)
end)

-- ── qualified per-unit slash paths (Task 7 / spec §9) ──────────────────────────────

test("set writes a dotted per-unit path", function()
  slash("set units.target.barWidth 275")
  assertEqual(NS.db.profile.units.target.barWidth, 275)
end)

test("set on one unit leaves the others alone", function()
  local before = NS.db.profile.units.player.barWidth
  slash("set units.focus.barWidth 315")
  assertEqual(NS.db.profile.units.player.barWidth, before)
  assertEqual(NS.db.profile.units.focus.barWidth, 315)
end)

test("an unqualified appearance key is rejected", function()
  -- Deliberate clean break (spec §9): paths are fully qualified, KickCD-style.
  local out = slash("set barWidth 250")
  assertTrue(contains(out, "Setting not found"),
    "expected an unknown-setting error, got: " .. joined(out))
end)

test("a global key still uses its flat path", function()
  slash("set showOnlyInCombat true")
  assertEqual(NS.db.profile.showOnlyInCombat, true)
  slash("set showOnlyInCombat false")
end)

test("get echoes a dotted path", function()
  NS.db.profile.units.target.barWidth = 275
  local out = slash("get units.target.barWidth")
  assertTrue(contains(out, "units.target.barWidth"), "got: " .. joined(out))
  assertTrue(contains(out, "275"), "got: " .. joined(out))
end)

test("list groups the appearance pages by unit", function()
  local out = slash("list")
  assertTrue(contains(out, "[bar / player]"), "no player group header; got: " .. joined(out))
  assertTrue(contains(out, "[bar / target]"), "no target group header")
  assertTrue(contains(out, "[bar / focus]"),  "no focus group header")
  assertTrue(contains(out, "[general]"), "globals must still list under a plain page header")
end)

test("reset bar resets every unit", function()
  NS.db.profile.units.player.barWidth = 111
  NS.db.profile.units.target.barWidth = 222
  NS.db.profile.units.focus.barWidth  = 333
  slash("reset bar")
  assertEqual(NS.db.profile.units.player.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.target.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.focus.barWidth,  NS.unitDefaults.barWidth)
end)

test("resetposition clears all three positions", function()
  for _, u in ipairs(NS.Units.LIST) do
    NS.db.profile.units[u].position = { point = "TOP", relPoint = "TOP", x = 1, y = 1 }
  end
  slash("resetposition")
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.db.profile.units[u].position, nil, u .. " kept its position")
  end
end)

test("toggle round-trips the enabled set", function()
  local before = {}
  for _, unit in ipairs(NS.Units.LIST) do before[unit] = NS.Units.IsEnabled(unit) end
  slash("toggle")
  slash("toggle")
  -- Not an identity: an all-off/all-on pair converges on all-on by design (see the toggle tests
  -- above), so assert the reachable invariant -- every bar ends up enabled.
  for _, unit in ipairs(NS.Units.LIST) do
    assertTrue(NS.Units.IsEnabled(unit), unit .. " is on after an off/on round trip")
  end
  for _, unit in ipairs(NS.Units.LIST) do
    NS.db.profile.units[unit].enabled = before[unit]
  end
end)

-- ── Mirrored-unit annotation on get / set / list ──────────────────────────

-- NS.GetSetting resolves the raw profile path and never consults NS.Units.Get, so `/at get|set`
-- on a mirrored unit read and write its STORED value, not the resolved one. That is deliberate
-- and stays that way -- but silent, it means `/at set units.focus.barWidth 400` echoes a
-- confident confirmation while the focus bar does not move (it is rendering the player's width).
local NOTE = "(mirrored"

test("/at get annotates a row whose unit is currently mirroring the player", function()
  NS.db.profile.units.focus.mirror = true
  local out = slash("get units.focus.barWidth")
  assertTrue(contains(out, "units.focus.barWidth"), joined(out))
  assertTrue(contains(out, NOTE),
    "a mirrored unit's value must say so, or the CLI silently lies: " .. joined(out))
end)

test("/at get does NOT annotate an unmirrored unit, or the player", function()
  NS.db.profile.units.focus.mirror = false
  assertTrue(not contains(slash("get units.focus.barWidth"), NOTE),
    "an unlinked unit reads and writes its own value -- no note")
  assertTrue(not contains(slash("get units.player.barWidth"), NOTE),
    "the player is the mirror SOURCE and is never mirrored")
  NS.db.profile.units.focus.mirror = true
end)

test("/at get does NOT annotate the per-unit rows a mirror never covers", function()
  -- `enabled` and `mirror` carry alwaysPerUnit: they are honoured per-unit even while mirrored,
  -- so a note on them would be a lie in the other direction.
  NS.db.profile.units.focus.mirror = true
  assertTrue(not contains(slash("get units.focus.enabled"), NOTE))
  assertTrue(not contains(slash("get units.focus.mirror"), NOTE))
end)

test("/at set echoes the mirrored note alongside the value it just stored", function()
  NS.db.profile.units.focus.mirror = true
  local out = slash("set units.focus.barWidth 400")
  assertEqual(NS.GetSetting("units.focus.barWidth"), 400, "the stored value is still written")
  assertTrue(contains(out, NOTE),
    "the echo must warn that the bar will not change: " .. joined(out))
  NS.SetByPath("units.focus.barWidth", NS.unitDefaults.barWidth)
end)

test("/at list annotates only the mirrored units' appearance rows", function()
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.focus.mirror  = true
  local out = slash("list")
  local annotated = {}
  for _, line in ipairs(out) do
    if line:find(NOTE, 1, true) then
      annotated[#annotated + 1] = line:match("units%.(%w+)%.") or "?"
    end
  end
  assertTrue(#annotated > 0, "the mirrored focus rows must be annotated")
  for _, unit in ipairs(annotated) do
    assertEqual(unit, "focus", "only the mirrored unit's rows carry the note")
  end
  NS.db.profile.units.target.mirror = true
end)

test("the mirrored note keeps the Ka0s colour scheme intact and stays subordinate", function()
  NS.db.profile.units.focus.mirror = true
  local out = capture(function() NS.Slash:OnSlash("get units.focus.barWidth") end)
  local line = out[1]
  -- Gold key + white value untouched (slash-commands-§5), note in subordinate grey, no colon.
  assertTrue(line:find("|cFFFFFF00units.focus.barWidth|r = |cFFFFFFFF", 1, true) ~= nil, line)
  assertTrue(line:find("|cff808080(mirrored", 1, true) ~= nil, "the note is grey: " .. line)
  assertTrue(stripColor(line):find(":%s*$") == nil, "no trailing colon: " .. line)
end)

-- ── /at perf ──────────────────────────────────────────────────────────────────────────
--
-- The perf probe's slash surface (core/Perf.lua, issue #17). These assert the DISPATCH — that each
-- sub-verb reaches the right probe call and says so — rather than re-testing the probe's accounting,
-- which tests/test_perf.lua owns.

local P = NS.Perf

-- Every perf sub-verb that resumes republishes REPAINT and arms a coalescing timer; left armed it
-- poisons later suites (see the same note in tests/test_perf.lua).
local function perfReset()
  P.on = false
  P.run = false
  P.armed, P.recording = nil, nil
  if P.suspended then P.Resume() end
  P.Reset()
  NS.CancelPendingRepaint()
  for i = #T.mocks.__timers, 1, -1 do T.mocks.__timers[i] = nil end
end

test("/at perf (bare) reports status and prints usage", function()
  perfReset()
  local out = slash("perf")
  assertTrue(contains(out, "perf "), "leads with the phase")
  assertTrue(contains(out, "usage: /at perf"), "then the usage block")
  assertTrue(contains(out, "suspend"), "documents the suspend arm")
end)

test("/at perf start starts a capture", function()
  perfReset()
  local out = slash("perf start")
  assertTrue(P.run, "experiment running")
  assertFalse(P.on, "but sampling nothing until a window is armed")
  assertTrue(contains(out, "STARTED"), "acknowledges: " .. joined(out))
  perfReset()
end)

test("/at perf start resets the counters from the previous capture", function()
  perfReset()
  P.Note("paintBar", 99)
  slash("perf start")
  assertEqual(P.__buckets().paintBar, nil, "a new capture starts clean")
  perfReset()
end)

test("/at perf finish refuses when no run is active", function()
  perfReset()
  local out = slash("perf finish")
  assertTrue(contains(out, "no perf run is active"), "says so rather than saving an empty record")
end)

test("/at perf finish saves the record to the perf ring", function()
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start")
  slash("perf finish")
  assertEqual(type(_G.AbsorbTrackerPerfDB), "table", "the ring exists")
  assertEqual(#_G.AbsorbTrackerPerfDB.runs, 1, "one capture stored")
  assertFalse(P.on, "capture stopped")
  _G.AbsorbTrackerPerfDB = nil
end)

test("/at perf finish lifts a suspend left over from the capture", function()
  -- Otherwise stopping a capture would silently leave the addon disabled for the whole session.
  perfReset()
  slash("perf start")
  slash("perf suspend")
  local out = slash("perf finish")
  assertFalse(P.suspended, "suspend lifted")
  assertTrue(contains(out, "suspend lifted"), "and says so: " .. joined(out))
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
end)

test("/at perf suspend and resume flip the probe's inert state", function()
  perfReset()
  local out = slash("perf suspend")
  assertTrue(P.suspended, "suspended")
  assertTrue(contains(out, "SUSPENDED"), "acknowledges: " .. joined(out))
  out = slash("perf resume")
  assertFalse(P.suspended, "resumed")
  assertTrue(contains(out, "RESUMED"), "acknowledges: " .. joined(out))
  perfReset()
end)

test("/at perf suspend twice reports the no-op rather than pretending", function()
  perfReset()
  slash("perf suspend")
  local out = slash("perf suspend")
  assertTrue(contains(out, "already suspended"), joined(out))
  perfReset()
end)

test("/at perf resume without a suspend reports the no-op", function()
  perfReset()
  local out = slash("perf resume")
  assertTrue(contains(out, "not suspended"), joined(out))
end)

test("/at perf report prints without stopping the capture", function()
  perfReset()
  slash("perf start")
  slash("perf report")
  assertTrue(P.run, "still running")
  perfReset()
end)

test("/at perf routes output to the debug console, not chat", function()
  -- The console is ungated (D:Add ignores NS.State.debug), which is what makes perf usable with
  -- logging off. If these lines went to chat instead they would be lost in combat spam.
  perfReset()
  local before = #NS.DebugLog.buffer
  slash("perf report")
  assertTrue(#NS.DebugLog.buffer > before, "report lines landed in the console buffer")
end)

test("/at perf dump emits parseable JSON carrying the schema stamp", function()
  perfReset()
  local before = #NS.DebugLog.buffer
  slash("perf dump")
  local line = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before, "something was written")
  assertTrue(line:find('"schema":1', 1, true) ~= nil, "carries the schema: " .. line)
  assertTrue(line:find('"source":"ingame"', 1, true) ~= nil, "and the source")
end)

test("/at perf with an unknown sub falls back to the usage block", function()
  perfReset()
  local out = slash("perf wibble")
  assertTrue(contains(out, "usage: /at perf"), joined(out))
end)

test("/at debug on|off still toggles logging with perf present", function()
  -- Guards the sub-verb split: `perf` must not have swallowed the existing on/off contract.
  perfReset()
  slash("debug on")
  assertTrue(NS.State.debug, "logging on")
  slash("debug off")
  assertFalse(NS.State.debug, "logging off")
end)

test("perf is a top-level verb in the help index", function()
  local out = slash("help")
  assertTrue(contains(out, "/at perf"), "listed in its own right: " .. joined(out))
  assertTrue(contains(out, "/at debug"), "and debug is still there")
end)

test("perf is registered in NS.COMMANDS, so the About page lists it too", function()
  -- PrintHelp and the About page both iterate NS.COMMANDS; a verb wired only into the dispatcher
  -- would work but stay invisible in both.
  local found
  for _, entry in ipairs(NS.COMMANDS) do
    if entry[1] == "perf" then found = entry end
  end
  assertTrue(found ~= nil, "perf has a COMMANDS row")
  assertTrue(found[2] ~= nil and found[2] ~= "", "with a description")
end)

test("/at debug no longer swallows a perf argument", function()
  -- `perf` used to be a sub-verb of debug. `/at debug perf` must now fall through to debug's own
  -- handling rather than silently doing perf work.
  perfReset()
  local before = P.run
  slash("debug perf")
  assertEqual(P.run, before, "debug did not start a perf run")
end)

test("/at perf start accepts an optional label, appended to the timestamp", function()
  -- Captures accumulate in a ring across sessions; without a label two runs from the same
  -- afternoon are near-impossible to tell apart when reading SavedVariables later.
  perfReset()
  slash("perf start solo run")
  assertTrue(P.label:find("solo run", 1, true) ~= nil, "label kept: " .. tostring(P.label))
  assertTrue(#P.label > #"solo run", "timestamp still present: " .. tostring(P.label))
  P.on = false
end)

test("/at perf start without a label still stamps the capture", function()
  perfReset()
  slash("perf start")
  assertTrue(P.label ~= nil and P.label ~= "", "auto-stamped: " .. tostring(P.label))
  P.on = false
end)

test("/at perf start label reaches the saved record", function()
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start full addon set")
  slash("perf finish")
  local rec = _G.AbsorbTrackerPerfDB.runs[1]
  assertTrue(rec.label:find("full addon set", 1, true) ~= nil, "label persisted: " .. rec.label)
  _G.AbsorbTrackerPerfDB = nil
end)

test("/at perf measure a arms Experiment A", function()
  perfReset()
  slash("perf start")
  local out = slash("perf measure a")
  assertEqual(P.armed, "active", "armed")
  assertFalse(P.suspended, "addon left running for the A arm")
  assertTrue(contains(out, "ARMED"), "acknowledges: " .. joined(out))
  assertTrue(contains(out, "combat"), "and says it waits for combat")
  perfReset()
end)

test("/at perf measure b arms Experiment B and suspends", function()
  perfReset()
  slash("perf start")
  slash("perf measure b")
  assertEqual(P.armed, "suspended", "armed")
  assertTrue(P.suspended, "and the addon is inert without a separate command")
  perfReset()
end)

test("/at perf measure refuses outside an experiment", function()
  perfReset()
  local out = slash("perf measure a")
  assertTrue(contains(out, "/at perf start"), "points at the fix: " .. joined(out))
end)

test("/at perf measure rejects an unknown window", function()
  perfReset()
  slash("perf start")
  local out = slash("perf measure z")
  assertTrue(contains(out, "unknown window"), joined(out))
  assertTrue(contains(out, "measure a"), "and names the valid ones")
  perfReset()
end)

test("/at perf bare reports the armed window", function()
  perfReset()
  slash("perf start")
  slash("perf measure a")
  local out = slash("perf")
  assertTrue(contains(out, "armed"), "shows the phase: " .. joined(out))
  perfReset()
end)

test("the perf usage block documents the measure workflow", function()
  perfReset()
  local out = slash("perf")
  assertTrue(contains(out, "measure a"), "lists measure a")
  assertTrue(contains(out, "measure b"), "lists measure b")
  assertTrue(contains(out, "suspends the addon first"), "explains what measure b changes")
  assertTrue(contains(out, "without ending the run"), "and what report does")
end)

test("/at perf start prints the workflow steps to chat and console", function()
  -- The ordering is what makes the two experiments comparable; a user who arms B before pulling,
  -- or forgets /reload, loses the capture.
  perfReset()
  local before = #NS.DebugLog.buffer
  local out = slash("perf start")
  assertTrue(contains(out, "next steps"), "steps in chat: " .. joined(out))
  assertTrue(contains(out, "/at perf measure a"), "step 1")
  assertTrue(contains(out, "/at perf measure b"), "step 2")
  assertTrue(contains(out, "/at perf finish"), "step 3")
  assertTrue(contains(out, "/reload"), "step 4")
  assertTrue(#NS.DebugLog.buffer > before, "and the run start reached the console too")
  perfReset()
end)

test("/at perf start announces to the console with debug logging OFF", function()
  perfReset()
  local wasOn = NS.State.debug
  NS.State.debug = false
  local before = #NS.DebugLog.buffer
  slash("perf start")
  NS.State.debug = wasOn
  assertTrue(#NS.DebugLog.buffer > before, "perf output is ungated")
  perfReset()
end)
