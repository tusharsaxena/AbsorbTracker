local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- settings/Slash.lua, second half: the verbs tests/test_slash.lua does not reach — lock/unlock,
-- toggle, the three reset verbs, update, test, enable/disable and the disabled gate, the whole
-- /at profile sub-dispatcher, and the get/set failure paths. `/at perf` used to live here too and
-- now has its own file, tests/test_perfcmds.lua, peeled off when this one crossed layout-§1's
-- 1500-line cap: it is the one verb here whose behavior belongs to another module. Together with
-- test_slash.lua and test_perfcmds.lua this covers every entry in NS.COMMANDS.

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

test("the About page renders one row per verb, through the same formatter as /at help", function()
  -- The property this has always been about: the panel's command list and `/at help` cannot drift.
  -- It used to be asserted as table identity, but About.lua renders NS.Slash:LandingRows() now, so
  -- identity alone no longer carries it — the rows themselves do.
  local rows = NS.Slash:LandingRows()
  assertEqual(#rows, #NS.COMMANDS, "one row per verb")
  for i, entry in ipairs(NS.COMMANDS) do
    assertTrue(rows[i]:find("/at " .. entry[1], 1, true) ~= nil, entry[1] .. ": " .. rows[i])
  end
  -- The NS.SlashCommands alias is gone: About.lua renders LandingRows(), the rows above are what
  -- carry the no-drift property, and nothing in the addon read the alias by the time it was
  -- removed. Asserted as absent so a reflex re-add has to argue for itself.
  assertEqual(NS.SlashCommands, nil, "the alias is gone, not resurrected")
end)

test("the About rows carry the help colors, without the chat indent", function()
  -- Decision D3, and the only place in this repo where its visible change is pinned at all: the
  -- panel rows are the gold/white pair `/at help` prints, minus the indent a chat line needs to sit
  -- under a header.
  local rows = NS.Slash:LandingRows()
  assertEqual(rows[1], "|cFFFFFF00/at help|r \226\128\148 |cFFFFFFFFList available commands|r")
  assertTrue(rows[1]:sub(1, 1) ~= " ", "a panel row starts at the margin")
  -- The chat form is the same row with the indent, after the [AT] tag every line carries.
  local want = "  " .. rows[1]
  local help = capture(function() NS.Slash:OnSlash("help") end)
  assertEqual(help[2]:sub(-#want), want, "the chat form is that row, indented: " .. help[2])
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

-- `/at reset` takes a PATH and resets one setting. The page-shaped form this addon used to carry
-- was removed deliberately (a user-visible change, not an extraction artifact), so these describe
-- the new behavior rather than being retargeted onto it. The capability did not go anywhere: the
-- Bar page's Defaults button still resets that page across every unit, pinned in test_helpers.lua.

test("/at reset with no path prints usage rather than resetting anything", function()
  NS.SetByPath("units.player.barWidth", 250)
  local out = slash("reset")
  assertTrue(contains(out, "Usage: /at reset <path>"), joined(out))
  assertEqual(NS.GetSetting("units.player.barWidth"), 250, "nothing was reset")
  NS.Helpers.RestoreDefaults("appearance")
end)

test("/at reset rejects a path that is not a setting", function()
  -- A page name is simply an unknown path now, and says so in the same words any other typo does.
  local out = slash("reset bar")
  assertTrue(contains(out, "Setting not found: bar"), joined(out))
end)

test("/at reset restores one setting and leaves its neighbors alone", function()
  NS.SetByPath("units.player.barWidth", 250)
  NS.SetByPath("units.target.barWidth", 300)
  NS.SetByPath("units.player.borderSize", 20)
  slash("reset units.player.barWidth")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth, "the named one")
  assertEqual(NS.GetSetting("units.target.barWidth"), 300, "not the same key on another unit")
  assertEqual(NS.GetSetting("units.player.borderSize"), 20, "nor another key on the same unit")
  NS.Helpers.RestoreDefaults("appearance")
end)

test("/at reset <path> writes the default and fires the row's onChange exactly once", function()
  -- Characterization for #30: the reset reaches the row's reaction once, with the default.
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved, calls, got = row.onChange, 0, nil
  NS.SetByPath("units.player.barWidth", 250)
  row.onChange = function(v) calls = calls + 1; got = v end
  local ok, err = pcall(slash, "reset units.player.barWidth")
  row.onChange = saved
  if not ok then error(err) end
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(calls, 1, "one onChange per reset")
  assertEqual(got, NS.unitDefaults.barWidth, "and it receives the default")
end)

test("/at reset <path> logs exactly one [Set] line and fires onChange exactly once", function()
  -- #30: a reset is a schema-row write, so it goes through the one helper and its [Set] line
  -- (architecture-§5, debug-logging-§10) like every other write.
  -- red under: NS.ApplyDefault storing the default without running the row's onChange.
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved, calls = row.onChange, 0
  NS.SetByPath("units.player.barWidth", 250)
  row.onChange = function() calls = calls + 1 end
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  local ok, err = pcall(slash, "reset units.player.barWidth")
  NS.State.debug = false
  row.onChange = saved
  if not ok then error(err) end
  local sets = {}
  for i = before + 1, #NS.DebugLog.buffer do
    local line = NS.DebugLog.buffer[i]
    if line:find("[Set]", 1, true) then sets[#sets + 1] = line end
  end
  assertEqual(#sets, 1, "exactly one [Set] line: " .. table.concat(sets, " | "))
  assertTrue(sets[1]:find("units.player.barWidth = " .. NS.unitDefaults.barWidth, 1, true) ~= nil,
    "it names the path and the default: " .. sets[1])
  assertEqual(calls, 1, "and the row's onChange fires once")
end)

test("/at reset does NOT lower-case its argument", function()
  -- The inverse of the rule the page form had. Pages were a closed lower-case set; a path is
  -- case-sensitive, so folding case here would reset a setting the user never named.
  NS.SetByPath("units.player.barWidth", 250)
  local out = slash("reset UNITS.PLAYER.BARWIDTH")
  assertEqual(NS.GetSetting("units.player.barWidth"), 250, "nothing was reset")
  -- Asserted on the ECHOED path, not just the prefix: a reset that lower-cased its argument would
  -- still print "Setting not found" for this input, so a prefix match cannot tell the two apart.
  assertTrue(contains(out, "Setting not found: UNITS.PLAYER.BARWIDTH"), joined(out))
  NS.Helpers.RestoreDefaults("appearance")
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
  T.rawSet("units.player.barWidth", 250)
  T.rawSet("units.player.fontSize", 30)
  slash("resetall")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(NS.GetSetting("units.player.fontSize"), NS.unitDefaults.fontSize)
  T.mocks.__fireTimers()
end)

test("/at resetall says the helpers are missing instead of claiming success", function()
  -- The other half of the guard the case above exercises. On a build where settings/OptionsSetup
  -- never ran, RestoreAllDefaults is absent and the verb resets nothing -- printing the
  -- acknowledgment anyway would claim success for work that did not happen. Same rule, same
  -- shape, as the resetposition verb immediately below.
  local orig = NS.Helpers.RestoreAllDefaults
  NS.Helpers.RestoreAllDefaults = nil
  local out = slash("resetall")
  NS.Helpers.RestoreAllDefaults = orig
  assertEqual(joined(out):find("All settings reset to defaults", 1, true), nil,
    "must NOT acknowledge a reset it could not perform: " .. joined(out))
  assertTrue(contains(out, "Cannot reset settings"), joined(out))
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

test("/at set writes a color from `r g b a` and echoes the STORED value", function()
  local out = slash("set units.player.barColor 0.1 0.2 0.3 0.4")
  local c = NS.GetSetting("units.player.barColor")
  assertTrue(math.abs(c.r - 0.1) < 1e-6 and math.abs(c.a - 0.4) < 1e-6,
    "the parsed color was stored")
  assertTrue(contains(out, "{0.10, 0.20, 0.30, 0.40}"), joined(out))
  NS.Helpers.RestoreDefaults("appearance")
  T.mocks.__fireTimers()
end)

test("/at set accepts a bool written as a human word", function()
  slash("set locked yes")
  assertTrue(NS.GetSetting("locked"))
  slash("set locked off")
  assertFalse(NS.GetSetting("locked"))
end)

-- ── /at test ───────────────────────────────────────────────────────────────────────
--
-- ONE form. `/at test <value> [secs]` paints a fake absorb amount on every visible bar and holds it
-- for a few seconds -- a diagnostic, not a switch. The `[on|off]` form went with the Test mode row
-- itself (options-ui-§15): this addon's unlocked view is its preview, so `/at unlock` / `/at lock`
-- are the switch and a second verb for the same state was the finding (anti-pattern #80).

test("/at test with a word it does not know prints the usage and changes nothing", function()
  local savedHold = NS.testHoldUntil
  local out = slash("test wibble")
  assertEqual(NS.testHoldUntil, savedHold, "no hold")
  assertTrue(contains(out, "/at test"), joined(out))
end)

-- A bare `/at test` used to toggle the mode. It now has nothing to toggle, and prints the usage
-- rather than silently doing nothing, so a player with the old habit is told what changed.
test("bare /at test prints the usage and toggles nothing", function()
  local savedLocked = NS.GetSetting("locked")
  local savedHold = NS.testHoldUntil
  local out = slash("test")
  assertEqual(NS.GetSetting("locked"), savedLocked, "the lock is the switch, and this is not it")
  assertEqual(NS.testHoldUntil, savedHold, "no hold either")
  assertTrue(contains(out, "/at test"), joined(out))
end)

test("the test verb's help line describes the value hold, not a mode", function()
  local desc
  for _, entry in ipairs(NS.COMMANDS) do
    if entry[1] == "test" then desc = entry[2] end
  end
  assertTrue(desc and desc:find("secs", 1, true) ~= nil, "the timed hold is documented: " .. tostring(desc))
  assertFalse(desc:find("on|off", 1, true) ~= nil,
    "the toggle form is gone with the Test mode row (options-ui-§15): " .. desc)
  assertFalse(desc:find("Test mode", 1, true) ~= nil,
    "and the help line must not advertise a mode the addon no longer has: " .. desc)
end)

test("/at test with a value refuses while every bar is disabled and says how to fix it", function()
  local savedHold = NS.testHoldUntil
  local saved = {}
  for _, unit in ipairs(NS.Units.LIST) do
    saved[unit] = NS.db.profile.units[unit].enabled
    NS.db.profile.units[unit].enabled = false
  end
  local out = slash("test 50000")
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

test("/at test with a value and no hold holds it for 5 seconds", function()
  NS.db.profile.units.player.enabled = true
  local painted
  local sb = NS.statusBar
  rawset(sb, "SetValue", function(_, v) painted = v end)
  slash("test 50000")
  rawset(sb, "SetValue", nil)
  assertEqual(painted, 50000)
  assertEqual(NS.testHoldUntil, T.mocks.GetTime() + 5)
  assertEqual(NS.State.testMode, nil, "the numeric form is a hold, and there is no mode to enter")
  NS.ClearPreview()
end)

test("/at test keeps the bar scale usable for a value below the 100k floor", function()
  -- A small test value must not shrink the scale below 100000, or the fake fill reads as full.
  T.rawSet("hidden", false)
  local mn, mx
  local sb = NS.statusBar
  rawset(sb, "SetMinMaxValues", function(_, a, b) mn, mx = a, b end)
  slash("test 500")
  rawset(sb, "SetMinMaxValues", nil)
  assertEqual(mn, 0)
  assertEqual(mx, 100000)
  NS.testHoldUntil = nil
end)

-- The announced duration is a promise: "for 7 s" has to be a scheduled expiry, not a timestamp
-- nobody revisits. Before this, the fake value sat on the bar past the window until the next
-- absorb event or an explicit /at update (preview-mode).
test("/at test schedules the expiry it just announced", function()
  NS.db.profile.units.player.enabled = true
  local before = #T.mocks.__timers
  local out = slash("test 12345 7")
  local armed = T.mocks.__timers[#T.mocks.__timers]
  assertTrue(contains(out, "for 7 s"), joined(out))
  assertEqual(#T.mocks.__timers, before + 1, "the announced window must be armed")
  assertEqual(armed.delay, 7, "the timer fires at the end of the window the user was told about")
  NS.ClearPreview()
end)

test("re-locking the bars clears a live /at test preview", function()
  NS.db.profile.units.player.enabled = true
  local wasLocked = NS.GetSetting("locked")
  slash("unlock")
  slash("test 12345 30")
  assertTrue((NS.testHoldUntil or 0) > T.mocks.GetTime(), "the hold is live before the re-lock")
  slash("lock")
  assertEqual(NS.testHoldUntil, nil, "re-locking returns the bars to live data (preview-mode)")
  NS.SetByPath("locked", wasLocked)
  NS.ClearPreview()
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
  -- The current profile holds a changed value; the new one must not inherit it.
  T.rawSet("units.player.barWidth", 456)
  local out = slash("profile new Fresh")
  assertEqual(NS.db:GetCurrentProfile(), "Fresh")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth,
    "a new profile starts from defaults")
  assertTrue(contains(out, "Created and switched to new profile 'Fresh'"), joined(out))
  backToDefault()
  NS.db:DeleteProfile("Fresh", true)
  NS.Helpers.RestoreDefaults("appearance")
  T.mocks.__fireTimers()
end)

test("/at profile new refuses a name that already exists and leaves it untouched", function()
  NS.db:SetProfile("Keep")
  T.mocks.__fireTimers()
  T.rawSet("units.player.barWidth", 333)
  backToDefault()
  local out = slash("profile new Keep")
  assertEqual(NS.db:GetCurrentProfile(), "Default", "new on an existing name switches nothing")
  assertTrue(contains(out, "Profile 'Keep' already exists"), joined(out))
  assertFalse(contains(out, "Created"), joined(out))
  NS.db:SetProfile("Keep")
  T.mocks.__fireTimers()
  local kept = NS.GetSetting("units.player.barWidth")
  backToDefault()
  NS.db:DeleteProfile("Keep", true)
  -- red under: removing the profileExists guard (new would switch to Keep and reset it)
  assertEqual(kept, 333, "the existing profile keeps its values")
end)

test("/at profile new with no name prints usage", function()
  assertTrue(contains(slash("profile new"), "Usage: /at profile new <name>"))
end)

test("/at profile copy pulls another profile's values into the current one", function()
  NS.db:SetProfile("Source")
  T.mocks.__fireTimers()
  T.rawSet("units.player.barWidth", 411)
  NS.db:SetProfile("Default")
  T.mocks.__fireTimers()
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth,
    "Default is untouched so far")

  local out = slash("profile copy Source")
  assertEqual(NS.GetSetting("units.player.barWidth"), 411,
    "the source's value landed in the current profile")
  assertEqual(NS.db:GetCurrentProfile(), "Default", "copy does not switch profiles")
  assertTrue(contains(out, "Copied settings from profile 'Source'"), joined(out))
  NS.Helpers.RestoreDefaults("appearance")
  T.mocks.__fireTimers()
end)

test("/at profile copy with no name prints usage", function()
  assertTrue(contains(slash("profile copy"), "Usage: /at profile copy <name>"))
end)

test("/at profile copy of a missing profile refuses before AceDB sees the name", function()
  T.rawSet("units.player.barWidth", 377)
  -- Kit 26's AceDB fake raises here as AceDB-3.0 does, so a bare CopyProfile fails the pcall.
  local ok, out = pcall(slash, "profile copy NoSuchProfile")
  local width = NS.GetSetting("units.player.barWidth")
  NS.Helpers.RestoreDefaults("appearance")
  T.mocks.__fireTimers()
  assertTrue(ok, "no raw AceDB error: " .. tostring(out))
  -- red under: dropping the existence check
  assertTrue(contains(out, "Profile 'NoSuchProfile' not found"), joined(out))
  assertFalse(contains(out, "Copied"), joined(out))
  assertEqual(width, 377, "the current profile's values are unchanged")
  assertEqual(NS.db:GetCurrentProfile(), "Default")
end)

test("/at profile copy of the current profile refuses", function()
  local ok, out = pcall(slash, "profile copy Default")
  assertTrue(ok, "no raw AceDB error: " .. tostring(out))
  assertTrue(contains(out, "Cannot copy a profile onto itself"), joined(out))
  assertFalse(contains(out, "Copied"), joined(out))
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

test("/at profile delete of a missing profile says so and deletes nothing", function()
  local before = table.concat(NS.db:GetProfiles(), ",")
  local ok, out = pcall(slash, "profile delete NoSuchProfile")
  assertTrue(ok, "no raw AceDB error: " .. tostring(out))
  -- red under: dropping the existence check (delete printed 'Deleted' for a name it never had)
  assertTrue(contains(out, "Profile 'NoSuchProfile' not found"), joined(out))
  assertFalse(contains(out, "Deleted"), joined(out))
  assertEqual(table.concat(NS.db:GetProfiles(), ","), before, "the profile list is unchanged")
end)

test("/at profile delete with no name prints usage", function()
  assertTrue(contains(slash("profile delete"), "Usage: /at profile delete <name>"))
end)

test("/at profile reset restores the current profile's defaults in place", function()
  T.rawSet("units.player.barWidth", 478)
  local out = slash("profile reset")
  -- red under: reset that switches instead of resetting
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(NS.db:GetCurrentProfile(), "Default", "reset does not switch profiles")
  assertTrue(contains(out, "Profile reset to defaults"), joined(out))
  T.mocks.__fireTimers()
end)

-- ── the profile-event handler's one line (debug-logging-§10) ───────────────────────
--
-- AceDB replacing the whole profile is not a batch through the helper. It is logged ONCE, by the
-- profile-event handler, in words chosen by the event: a reset and a copy are `[Set]` lines, a
-- switch keeps its `[Profile]` line. core/Database.lua wires each event to its own handler.

-- The debug lines one act appends, with debug on for its duration.
local function debugLines(fn)
  local before = #NS.DebugLog.buffer
  NS.State.debug = true
  local ok, err = pcall(fn)
  NS.State.debug = false
  if not ok then error(err, 0) end
  local out = {}
  for i = before + 1, #NS.DebugLog.buffer do out[#out + 1] = NS.DebugLog.buffer[i] end
  return out
end

-- The reset handler's line. N is the rows the reset changed, counted before an addon-driven reset
-- (debug-logging-§10), never the schema size.
local function resetLine(n)
  return ("[Set] reset profile '%s' to defaults (%d rows)"):format(NS.db:GetCurrentProfile(), n)
end

-- Put the active profile back at its defaults, unlogged.
local function cleanProfile()
  NS.db:ResetProfile()
  T.mocks.__fireTimers()
end

test("/at profile reset logs one [Set] line from the reset handler, counting the rows it changed", function()
  -- red under: OnProfileReset still wired to the switch handler, which logs `[Profile] changed`,
  -- or a count of every row the profile stores.
  cleanProfile()
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth + 1)
  local lines = debugLines(function() slash("profile reset") end)
  T.mocks.__fireTimers()
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find(resetLine(1), 1, true) ~= nil, "want '" .. resetLine(1) .. "', got " .. lines[1])
end)

test("/at resetall logs one line in total, the same reset handler's", function()
  cleanProfile()
  local lines = debugLines(function() slash("resetall") end)
  T.mocks.__fireTimers()
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find(resetLine(0), 1, true) ~= nil, "want '" .. resetLine(0) .. "', got " .. lines[1])
end)

test("/at profile new logs the switch line, then a (0 rows) reset line", function()
  -- Two AceDB events, so two lines: SetProfile's switch and the reset that follows it. A freshly
  -- created profile is already at its defaults, so the reset changes nothing and says so.
  local lines = debugLines(function() slash("profile new FreshOne") end)
  T.mocks.__fireTimers()
  local current = NS.db:GetCurrentProfile()
  backToDefault()
  NS.db:DeleteProfile("FreshOne", true)
  assertEqual(current, "FreshOne")
  assertEqual(#lines, 2, "two lines: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Profile] changed \226\134\146 FreshOne", 1, true) ~= nil, lines[1])
  local want = "[Set] reset profile 'FreshOne' to defaults (0 rows)"
  assertTrue(lines[2]:find(want, 1, true) ~= nil, "want '" .. want .. "', got " .. lines[2])
end)

test("a profile copy logs one [Set] line naming both profiles", function()
  -- AceDB hands OnProfileCopied the SOURCE profile's name as its third argument, and so has the
  -- kit's mock since revision 18. The wording is still pinned by calling the handler as AceDB does,
  -- so this case never depends on which fake fires the event.
  local lines = debugLines(function() NS.OnProfileCopied("OnProfileCopied", NS.db, "Raid") end)
  T.mocks.__fireTimers()
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Set] copied profile 'Raid' \226\134\146 'Default'", 1, true) ~= nil,
    lines[1])
end)

test("/at profile copy reaches the copy handler, one line", function()
  -- red under: OnProfileCopied still wired to the switch handler.
  NS.db:SetProfile("CopyFrom")
  backToDefault()
  local lines = debugLines(function() slash("profile copy CopyFrom") end)
  T.mocks.__fireTimers()
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Set] copied profile '", 1, true) ~= nil, lines[1])
end)

test("a profile switch keeps its [Profile] line and logs no [Set] line", function()
  local lines = debugLines(function() slash("profile use Alt") end)
  backToDefault()
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Profile] changed \226\134\146 Alt", 1, true) ~= nil, lines[1])
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
  slash("set locked true")
  assertEqual(NS.db.profile.locked, true)
  slash("set locked false")
end)

test("get echoes a dotted path", function()
  NS.db.profile.units.target.barWidth = 275
  local out = slash("get units.target.barWidth")
  assertTrue(contains(out, "units.target.barWidth"), "got: " .. joined(out))
  assertTrue(contains(out, "275"), "got: " .. joined(out))
end)

test("list groups the appearance page by unit", function()
  local out = slash("list")
  assertTrue(contains(out, "[appearance / player]"),
    "no player group header; got: " .. joined(out))
  assertTrue(contains(out, "[appearance / target]"), "no target group header")
  assertTrue(contains(out, "[appearance / focus]"),  "no focus group header")
  assertTrue(contains(out, "[general]"), "globals must still list under a plain page header")

  -- The old Bar / Border / Font page names must be GONE, not merely unasserted. PAGE_ORDER is what
  -- decides which pages `/at list` shows at all, and a name left in it after the pages collapsed
  -- would print an empty group; a name dropped from it silently loses every row on that page.
  -- Counting the rows is what catches the second half, which no header assertion can.
  for _, dead in ipairs({ "[bar /", "[border /", "[font /" }) do
    assertTrue(not contains(out, dead), dead .. " is not a page any more")
  end
  local rows = 0
  for _, line in ipairs(out) do
    if line:find(" = ") then rows = rows + 1 end
  end
  local expected = #NS.SchemaForPage("general")
  for _, unit in ipairs(NS.Units.LIST) do
    expected = expected + #NS.SchemaForPage("appearance", unit)
  end
  assertEqual(rows, expected, "/at list must print every schema row exactly once")
end)

test("reset takes one fully-qualified path, not a page", function()
  -- What the page form used to do across every unit now belongs to the page's Defaults button;
  -- what the verb does is reset exactly the setting it was handed.
  for _, unit in ipairs(NS.Units.LIST) do
    NS.SetByPath("units." .. unit .. ".barWidth", 111)
  end
  slash("reset units.target.barWidth")
  assertEqual(NS.GetSetting("units.target.barWidth"), NS.unitDefaults.barWidth, "the named unit")
  assertEqual(NS.GetSetting("units.player.barWidth"), 111, "and only that unit")
  assertEqual(NS.GetSetting("units.focus.barWidth"), 111)
  NS.Helpers.RestoreDefaults("appearance")
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
  -- `enabled` and `mirror` carry alwaysPerUnit: they are honored per-unit even while mirrored,
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

test("the mirrored note keeps the Ka0s color scheme intact and stays subordinate", function()
  NS.db.profile.units.focus.mirror = true
  local out = capture(function() NS.Slash:OnSlash("get units.focus.barWidth") end)
  local line = out[1]
  -- Gold key + white value untouched (slash-commands-§5), note in subordinate gray, no colon.
  assertTrue(line:find("|cFFFFFF00units.focus.barWidth|r = |cFFFFFFFF", 1, true) ~= nil, line)
  assertTrue(line:find("|cff808080(mirrored", 1, true) ~= nil, "the note is gray: " .. line)
  assertTrue(stripColor(line):find(":%s*$") == nil, "no trailing colon: " .. line)
end)


-- ── degraded / live dispatcher parity ───────────────────────────────────────
--
-- settings/Slash.lua substitutes a stub for LibKa0s-Slash-1.0 when the vendored library is missing,
-- and that stub carries its own copy of the DISPATCHER: trimmed parsing, verb lowercasing with a
-- case-preserved rest, the alias map, the unknown-verb fallback. Two dispatchers can drift with
-- nothing to notice -- the library's suite covers the library, this file covers the live path, and
-- the degraded cases elsewhere only assert "does not raise".
--
-- So these drive the SAME input through both builds and compare the dispatch OUTCOME: which verb
-- ran, with what rest, and how many lines were printed when no verb ran. Never the formatted
-- strings -- the degraded rows are deliberately plainer, and the library's formatting is pinned
-- upstream (testing-§8: an integration suite over our own wiring, not a copy of the library's).

-- A second, library-free environment, built as a load rather than a hand-stub -- same recipe as
-- tests/test_perf.lua's, which cannot be shared because both are file-local by design. Built once:
-- nothing below mutates it beyond swapping handlers back and forth.
local degradedNS, degradedMocks
local function degradedBuild()
  if not degradedNS then
    local Loader     = dofile("tests/_kit/loader.lua")
    local buildMocks = dofile("tests/wow_mock.lua")
    Loader.addonName = "AbsorbTracker"
    degradedMocks, degradedNS = buildMocks(), {}
    -- libs/ deliberately not loaded, so every LibStub lookup returns nil exactly as it would in an
    -- install whose libs/LibKa0s folder never arrived.
    Loader.loadAll(Loader.tocFiles("AbsorbTracker.toc"), degradedNS, degradedMocks)
    -- Burn the one-shot "the LibKa0s library is missing" banner core/CoreSetup.lua emits on the
    -- build's FIRST chat line. It is a property of the install, not of the dispatch, so counting it
    -- would make every outcome below off by one against the live build.
    local cf = degradedMocks.DEFAULT_CHAT_FRAME
    local old = rawget(cf, "AddMessage")
    cf.AddMessage = function() end
    degradedNS.Slash:OnSlash("")
    cf.AddMessage = old
  end
  return degradedNS, degradedMocks
end

-- Drive one slash line through `env` with every verb handler replaced by a recorder, and describe
-- what the dispatcher DID: the verb it reached, the rest it handed over, and the number of chat
-- lines it printed on its own (help, unknown-verb). Handlers are restored before returning.
local function outcome(env, envMocks, line)
  local saved, ran, gotRest = {}, nil, nil
  for i, entry in ipairs(env.COMMANDS) do
    saved[i] = entry[3]
    entry[3] = function(rest) ran, gotRest = entry[1], rest end
  end
  local out = {}
  local cf  = envMocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(function() env.Slash:OnSlash(line) end)
  cf.AddMessage = old
  for i, entry in ipairs(env.COMMANDS) do entry[3] = saved[i] end
  if not ok then error(err) end
  return ("verb=%s rest=%q lines=%d"):format(tostring(ran), tostring(gotRest), #out)
end

-- Both builds, one input, one comparison.
local function assertParity(line, expected)
  local NS2, mocks2 = degradedBuild()
  local live     = outcome(NS, T.mocks, line)
  local degraded = outcome(NS2, mocks2, line)
  assertEqual(live, expected, "live build, input " .. ("%q"):format(line))
  assertEqual(degraded, live, "degraded build must dispatch identically, input "
    .. ("%q"):format(line))
end

test("parity: both dispatchers fold the verb and preserve the rest's case", function()
  -- The rule that makes `/at set units.Player.barWidth` work: only the verb is case-insensitive.
  assertParity("TOGGLE Target", 'verb=toggle rest="Target" lines=0')
end)

test("parity: both dispatchers resolve the `options` alias to `config`", function()
  -- The alias map is passed into whichever dispatcher answers, but each applies it itself.
  assertParity("options", 'verb=config rest="" lines=0')
end)

test("parity: an unknown verb reaches no handler and prints the same shape in both", function()
  -- One error line plus the help block (header + one row per verb) in either build.
  assertParity("nosuchverb", ("verb=nil rest=\"nil\" lines=%d"):format(#NS.COMMANDS + 2))
end)

test("parity: a bare /at reaches the config handler with an empty rest in both", function()
  -- Slash minor 11: empty and whitespace-only input run `config` rather than printing help.
  assertParity("", 'verb=config rest="" lines=0')
  assertParity("   ", 'verb=config rest="" lines=0')
  -- `help` is where the index went, and it is an ordinary verb in both builds.
  assertParity("help", 'verb=help rest="" lines=0')
end)

-- ── a string value keeps every word ────────────────────────────────────────────────

test("/at set stores a multi-word string value whole", function()
  -- LibKa0s-Slash-1.0 minor 10 hands a string row the whole remainder, trimmed. Through minor 9
  -- it took the first word, so the font-flag entry "OUTLINE, MONOCHROME" could not be set at all:
  -- "OUTLINE," is not one of the row's values and was refused.
  -- red under: Slash.lua minor 9 (the parse splitting a string row's value on whitespace).
  local path = "units.player.fontFlags"
  local before = NS.GetSetting(path)
  local out = slash("set " .. path .. "   OUTLINE, MONOCHROME  ")
  assertEqual(NS.GetSetting(path), "OUTLINE, MONOCHROME", joined(out))
  slash("reset " .. path)
  T.mocks.__fireTimers()
  assertEqual(NS.GetSetting(path), before, "the reset put the shipped value back")
end)

-- ── /at enable | /at disable (slash-commands-§2) ────────────────────────────────────

test("/at enable and /at disable write the Enable row's OWN path, through the one seam", function()
  -- THE RESERVED PAIR, and they are ALIASES rather than a second switch. The failure this case
  -- exists to prevent is not "the verb does nothing" — it is a verb that keeps its own flag beside
  -- the checkbox, so the panel says on and the addon is off (or the other way round) and neither
  -- surface is wrong about itself.
  --
  -- Asserted at the SEAM, not at the value: a handler that wrote `db.profile.enabled` directly
  -- would leave `enabled` reading the same and silently skip the row's onChange — VISIBILITY then
  -- REPAINT (settings/General.lua) — so the bars would keep drawing after `/at disable`.
  --
  -- red under: a second stored key; a session flag; a handler that writes the profile itself; a
  -- verb renamed or re-used for enabling a module or a unit (that is `/at toggle`'s job).
  local real, seen = NS.SetByPath, {}
  NS.SetByPath = function(path, value)
    seen[#seen + 1] = { path = path, value = value }
    return real(path, value)
  end
  local ok, err = pcall(function()
    slash("disable")
    slash("enable")
  end)
  NS.SetByPath = real
  assertTrue(ok, tostring(err))

  assertEqual(#seen, 2, "one write per verb, no more")
  assertEqual(seen[1].path, "enabled", "/at disable writes the Enable row's own path")
  assertEqual(seen[1].value, false)
  assertEqual(seen[2].path, "enabled", "/at enable writes the same path")
  assertEqual(seen[2].value, true)
  assertTrue(NS.GetSetting("enabled"), "and the addon is back on")
end)

test("/at disable echoes the stored value in the set shape, and /at enable undoes it", function()
  -- slash-commands-§5's single-line `path = value` form, read back from the STORE rather than from
  -- the argument, so a coerced or refused write is what the player is told about.
  local out = slash("disable")
  assertFalse(NS.GetSetting("enabled"), "the addon is off")
  assertTrue(contains(out, "enabled = false"), joined(out))

  out = slash("enable")
  assertTrue(NS.GetSetting("enabled"), "and on again")
  assertTrue(contains(out, "enabled = true"), joined(out))
end)

test("the pair is never one-way: the dispatcher still answers while the addon is disabled", function()
  -- slash-commands-§2 makes this a MUST, and the reason is blunt: an addon that unregisters its
  -- chat command or drops its COMMANDS table when disabled has built a switch that only goes one
  -- way — the player turns it off, and the verb that turns it back on no longer exists.
  --
  -- The dispatcher and the settings registration are SETUP, not features: they come up on load in
  -- either state. In this addon `enabled` gates NS.ShouldShowBar's second rung and nothing else —
  -- no file unloads and no event registration changes — which is what makes that true here.
  --
  -- red under: a `return` guard on `enabled` anywhere in Sl:OnSlash or the COMMANDS handlers; an
  -- OnInitialize that registers the chat command conditionally; an `enable` verb that needs the
  -- panel, which is the one place the player was trying not to go.
  slash("disable")
  assertFalse(NS.GetSetting("enabled"), "precondition: the addon is off")

  -- A bare /at is the `config` verb (slash-commands-\194\1674), and it has to keep being that with
  -- the addon off: it is the route to the checkbox the verbs alias.
  local real, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  local ok, err = pcall(slash, "")
  NS.OpenOptionsPanel = real
  assertTrue(ok, "a bare /at raised while disabled: " .. tostring(err))
  assertEqual(opened, 1, "a bare /at still opens the settings panel while disabled")

  local help = slash("help")
  assertTrue(contains(help, "/at enable"), "`/at help` still lists the way back: " .. joined(help))
  assertTrue(contains(help, "/at config"), joined(help))

  assertTrue(contains(slash("version"), "v"), "`/at version` still answers")

  local out = slash("enable")
  assertTrue(NS.GetSetting("enabled"), "and `/at enable` itself works from the off state")
  assertTrue(contains(out, "enabled = true"), joined(out))
end)

test("enable and disable hold no state of their own", function()
  -- The other direction of the alias rule: writing the path by any OTHER route must move what the
  -- verbs report, because there is only one record. Written here through the row's long name, which
  -- slash-commands-§2 says an addon MAY accept as the same write.
  slash("set enabled false")
  assertFalse(NS.GetSetting("enabled"))
  assertTrue(contains(slash("get enabled"), "enabled = false"))

  NS.Helpers.RestoreDefaults("general")
  assertTrue(NS.GetSetting("enabled"), "a page Defaults press moves the same one record")

  slash("enable")
end)


-- ── the disabled gate (slash-commands-§2) ──────────────────────────────────────────────────────
--
-- A disabled addon answers a feature verb instead of acting on it, on ONE tagged line that names
-- `/at enable`. The suite above pins the other half of §2 — that the dispatcher SURVIVES the
-- disabled state — and these two rules pull against each other, which is why the live set is
-- asserted as hard as the refusal: read literally, "refuse while disabled" takes the whole command
-- surface down with it, `enable` included, and the pair becomes one-way again.

-- The verbs that keep answering with the addon off. Twelve of the fourteen are slash-commands-§2's
-- own list, which LibKa0s-Slash-1.0 applies for us from minor 12; `resetposition` and `profile` are
-- this addon's reading, argued at the `liveVerbs` entry in settings/Slash.lua's descriptor. Spelled
-- out HERE rather than read off the production table, because a test that imports the answer it is
-- checking asserts nothing.
--
-- THE SET WIDENED AT STANDARD v2.57.0 AND IT IS THE RESTORED ONE. Minor 12 narrowed it to `enable`,
-- `help` and `disable` and the reversal landed the same day: `/at` on a disabled addon answered
-- with a refusal instead of opening the settings panel, which is the one surface a player uses to
-- switch it back on by hand.
local LIVE_WHILE_DISABLED = {
  help = true, config = true, version = true, enable = true, disable = true,
  debug = true, perf = true,
  get = true, set = true, list = true, reset = true, resetall = true,
  resetposition = true, profile = true,
}

-- The collection's one refusal line, not this addon's: LibKa0s-Slash-1.0 owns the wording
-- (`lib.DISABLED_LINE_FORMAT`) so eleven addons cannot each spell it differently. Matched on the
-- brand and the shape rather than character-for-character, which is what lets the library re-word
-- the sentence around them without eleven suites going red over a comma.
local REFUSAL = NS.Constants.BRAND .. " is disabled"

--- Run one verb with the addon off, with the panel-open call stubbed (a live `config` would
--- otherwise reach the real Settings API mid-suite). Re-disables first, because two of the live
--- verbs — `enable` and `resetall` — turn the addon back on as their whole job.
local function slashWhileDisabled(verb)
  NS.SetByPath("enabled", false)
  local real = NS.OpenOptionsPanel
  NS.OpenOptionsPanel = function() end
  local out = slash(verb)
  NS.OpenOptionsPanel = real
  return out
end

test("every verb is either on the live list or refuses while disabled, and none is unclassified", function()
  -- THE GATE IS ONE PLACE, and this is the case that says so from the outside: it walks the whole
  -- COMMANDS table rather than a list of verbs someone remembered to add. A verb added tomorrow is
  -- gated by DEFAULT (settings/Slash.lua wraps everything not in ALWAYS_LIVE), so the only way this
  -- goes red is a real decision — and then it goes red until someone makes it deliberately.
  --
  -- red under: a per-verb guard, which would drift the moment the next verb is added; a gated verb
  -- promoted to the live list without argument; any of §2's twelve losing its answer.
  for _, entry in ipairs(NS.COMMANDS) do
    local verb = entry[1]
    local out = slashWhileDisabled(verb)
    if verb == "help" then
      -- THE ONE VERB THAT ANSWERS *AND* CARRIES THE LINE, and it is not a refusal of `help`: the
      -- index prints in full, because the player has to be able to SEE `enable` in the list, and
      -- the line sits under the header as a statement about the rows below it -- some of which are
      -- the feature verbs that are refused. Below them it would read as a footnote to the last
      -- command.
      assertTrue(contains(out, "/at enable"), "`/at help` still lists the way back: " .. joined(out))
      assertTrue(#out > 2, "`/at help` prints the whole index, not one line: " .. joined(out))
      assertTrue(contains(out, REFUSAL), "and says the addon is off: " .. joined(out))
    elseif LIVE_WHILE_DISABLED[verb] then
      assertFalse(contains(out, REFUSAL),
        "`/at " .. verb .. "` must keep answering while disabled: " .. joined(out))
    else
      assertEqual(#out, 1, "`/at " .. verb .. "` refuses on ONE line: " .. joined(out))
      assertTrue(contains(out, REFUSAL), "`/at " .. verb .. "`: " .. joined(out))
      assertTrue(contains(out, "/at enable"),
        "the refusal must name the way back: " .. joined(out))
    end
  end
  NS.SetByPath("enabled", true)
end)

test("the refusal is the collection's one line, tagged, and not re-spelled here", function()
  -- slash-commands-§7 fixes the SHAPE of the one line a disabled addon prints: the plain-text brand
  -- name, an em dash with a single space either side, `enable it with` and the command in gold with
  -- its leading slash. No trailing period, no second line, no per-addon wording.
  --
  -- IT IS NO LONGER ROUTED THROUGH NS.L, and that is the standard's call rather than a regression:
  -- the wording is the collection's, not the addon's, so a `deDE.lua` override here would give a
  -- player running four Ka0s addons four different answers to the same question. What the addon
  -- owns is the brand name, which is `NS.Constants.BRAND` and is the same string the LDB object
  -- carries as `label`.
  --
  -- red under: a host-side refusal wrapper spelling its own line; a `brandName` that is the folder
  -- name or the TOC Title; a second line stapled on explaining what the verb would have done.
  local raw = capture(function()
    NS.SetByPath("enabled", false)
    NS.Slash:OnSlash("toggle")
  end)
  assertEqual(#raw, 1, "exactly one line: " .. joined(raw))
  assertTrue(raw[1]:find("[AT]", 1, true) ~= nil, "one TAGGED line: " .. raw[1])
  assertTrue(raw[1]:find(NS.Constants.BRAND .. " is disabled \226\128\148 enable it with", 1, true) ~= nil,
    "the collection's shape: " .. raw[1])
  assertTrue(raw[1]:find("|cFFFFFF00/at enable|r", 1, true) ~= nil,
    "the command is gold and carries its leading slash: " .. raw[1])
  assertTrue(raw[1]:match("%.$") == nil, "no trailing period: " .. raw[1])

  -- The library builds it, and the launcher's click reaches the very same member rather than a
  -- second copy of the sentence.
  assertEqual(NS.Slash.__cli:DisabledLine(), (raw[1]:gsub("^%S+%s", "")),
    "the printed line is cli:DisabledLine() with the tag on the front")

  NS.SetByPath("enabled", true)
end)

test("a refused `toggle` does not touch a single bar's enabled flag", function()
  -- THE HALF A MESSAGE-ONLY CASE PASSES OVER. A verb that printed the refusal and then acted anyway
  -- would satisfy every assertion above; what says it did nothing is the state it did not move.
  --
  -- red under: a gate that prints and falls through; a gate placed after the handler's own work.
  local before = {}
  for _, unit in ipairs(NS.Units.LIST) do before[unit] = NS.Units.IsEnabled(unit) end

  local out = slashWhileDisabled("toggle")
  assertTrue(contains(out, REFUSAL), joined(out))
  for _, unit in ipairs(NS.Units.LIST) do
    assertEqual(NS.Units.IsEnabled(unit), before[unit], unit .. " bar was flipped by a refused verb")
  end

  -- The per-unit form takes the same route and must be refused identically.
  out = slashWhileDisabled("toggle target")
  assertTrue(contains(out, REFUSAL), joined(out))
  assertEqual(NS.Units.IsEnabled("target"), before.target)

  NS.SetByPath("enabled", true)
end)

test("a refused `unlock` leaves the lock exactly where it was", function()
  -- `lock` / `unlock` drive the addon's PREVIEW — the unlocked view is this addon's test mode
  -- (options-ui-§15's exemption) — so they are feature verbs, and the launcher's left click sits on
  -- the same state. Asserted at the SEAM as well as the value: the refusal must not reach
  -- NS.SetByPath at all, or the row's onChange would fire its APPEARANCE and REPAINT for a write
  -- that was refused.
  NS.SetByPath("locked", true)
  local real, seen = NS.SetByPath, 0
  NS.SetByPath = function(path, value)
    if path == "locked" then seen = seen + 1 end
    return real(path, value)
  end
  local out = slashWhileDisabled("unlock")
  NS.SetByPath = real

  assertTrue(contains(out, REFUSAL), joined(out))
  assertEqual(seen, 0, "a refused verb must not reach the write seam")
  assertTrue(NS.GetSetting("locked"), "the bars are still locked")

  NS.SetByPath("enabled", true)
end)

test("a refused `update` publishes nothing on the bus", function()
  -- `update` exists to force a repaint, so "did not act" is exactly "did not publish".
  --
  -- The spy goes on AFTER the addon is disabled: writing `enabled` is itself a publish (the row's
  -- onChange fires VISIBILITY then REPAINT), and catching the setup would read as the verb acting.
  NS.SetByPath("enabled", false)
  local real, sent = NS.bus.SendMessage, {}
  NS.bus.SendMessage = function(self, msg, ...)
    sent[#sent + 1] = msg
    return real(self, msg, ...)
  end
  local out = slash("update")
  NS.bus.SendMessage = real

  assertTrue(contains(out, REFUSAL), joined(out))
  assertEqual(#sent, 0, "a refused verb published: " .. table.concat(sent, ", "))

  NS.SetByPath("enabled", true)
end)

test("a refused `test <value>` paints nothing and arms no hold", function()
  -- The value hold is the one verb whose side effect is a TIMER: a gate that let the handler run
  -- would leave a fake value on a bar for five seconds with no line saying why.
  local real, armed = NS.HoldPreview, 0
  NS.HoldPreview = function(...) armed = armed + 1 return real(...) end
  local painted = NS.bars.player and NS.bars.player.valueText:GetText()
  local out = slashWhileDisabled("test 123456")
  NS.HoldPreview = real

  assertTrue(contains(out, REFUSAL), joined(out))
  assertEqual(armed, 0, "a refused verb armed the preview hold")
  assertEqual(NS.bars.player and NS.bars.player.valueText:GetText(), painted,
    "and it must not have painted the fake value either")

  NS.SetByPath("enabled", true)
end)
