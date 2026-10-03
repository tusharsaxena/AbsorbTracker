local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- settings/Slash.lua, the /at profile sub-dispatcher: list/current/use/new/copy/delete/reset, the
-- bare-name switch, the log lines each profile act leaves, and the AceDB-absent fallback. Peeled
-- out of tests/test_slashcmds.lua when that file neared layout-§1's 1500-line cap; it runs
-- straight after it. The disabled-gate and degraded cases for `profile` stay there, beside the
-- other verbs' gate cases.

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

-- ── /at profile ────────────────────────────────────────────────────────────────────

-- Leave the DB on the Default profile whatever a test did.
local function backToDefault()
  if NS.db and NS.db.SetProfile then NS.db:SetProfile("Default") end
  T.mocks.__fireTimers()
end

-- Make sure `name` is a stored profile without leaving it active. AceDB's SetProfile creates a
-- missing profile, which is exactly what the verb itself must never do, so the setup does it here.
local function ensureProfile(name)
  NS.db:SetProfile(name)
  backToDefault()
end

local function profileSet()
  local names = NS.db:GetProfiles()
  table.sort(names)
  return table.concat(names, ",")
end

test("/at profile with no subcommand lists the profiles, then prints the sub-help", function()
  -- Spec S3 step 2: bare `profile` is CliProfile("") (the library's list, current marked, the hint
  -- row) and then this addon's own sub-help, in that order.
  -- red under: the old sub-help-only answer, or the two printed the other way round.
  local out = slash("profile")
  local listAt, helpAt
  for i, line in ipairs(out) do
    if line:find("Profiles$") and not listAt then listAt = i end
    if line:find("Profile commands", 1, true) then helpAt = i end
  end
  assertTrue(listAt ~= nil, "the library's list header prints: " .. joined(out))
  assertTrue(contains(out, "Default (current)"), "the current profile is marked: " .. joined(out))
  assertTrue(contains(out, "/at profile <name> switches profile"), "the hint row: " .. joined(out))
  assertTrue(helpAt ~= nil and helpAt > listAt, "the sub-help follows the list: " .. joined(out))
  for _, sub in ipairs({ "<name>", "list", "current", "use", "new", "copy", "delete", "reset" }) do
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
  ensureProfile("Alt")
  local out = slash("profile use Alt")
  assertEqual(NS.db:GetCurrentProfile(), "Alt")
  assertTrue(contains(out, "Switched to profile 'Alt'."), joined(out))
  backToDefault()
end)

test("/at profile use of an unknown name refuses it and creates nothing", function()
  -- D3: `use` routes through the library's ProfileSwitch, so a typo no longer becomes a profile.
  -- red under: the old `use`, which handed any name to AceDB's SetProfile (and AceDB creates it).
  local before = profileSet()
  local out = slash("profile use Ghost")
  assertEqual(NS.db:GetCurrentProfile(), "Default", "nothing switched")
  assertEqual(profileSet(), before, "no profile was created")
  assertTrue(contains(out, "No profile named 'Ghost'."), joined(out))
  assertTrue(contains(out, "Default (current)"), "the list follows the refusal: " .. joined(out))
end)

test("/at profile use reaches a profile named like a sub-verb", function()
  -- The escape hatch: `/at profile list` is the sub-verb, so `use` is how a profile named `list`
  -- is reached.
  ensureProfile("list")
  local out = slash("profile use list")
  assertEqual(NS.db:GetCurrentProfile(), "list", joined(out))
  backToDefault()
  NS.db:DeleteProfile("list", true)
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
  ensureProfile("Alt")
  local lines = debugLines(function() slash("profile use Alt") end)
  backToDefault()
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Profile] changed \226\134\146 Alt", 1, true) ~= nil, lines[1])
end)

test("/at profile <word> that is neither a sub-verb nor a profile is refused and creates nothing", function()
  -- Spec S3 step 2: a first word that is not a sub-verb goes to CliProfile, so an unknown word is
  -- the library's unknown-profile refusal, followed by the list.
  -- red under: the old `Unknown profile subcommand` line, or a fallback that called SetProfile.
  local before = profileSet()
  local out = slash("profile frobnicate")
  assertEqual(NS.db:GetCurrentProfile(), "Default", "nothing switched")
  assertEqual(profileSet(), before, "no profile was created")
  assertTrue(contains(out, "No profile named 'frobnicate'."), joined(out))
  assertTrue(contains(out, "Default (current)"), "the list follows the refusal: " .. joined(out))
  assertFalse(contains(out, "Unknown profile subcommand"), joined(out))
end)

test("/at profile <name> switches to an existing profile and the profile handler runs", function()
  -- red under: the bare-name form not reaching CliProfile, or a switch that skips AceDB's callback
  -- (the handler's `[Profile] changed` line is how the adopt path shows it ran).
  ensureProfile("Alt")
  local out
  local lines = debugLines(function() out = slash("profile Alt") end)
  local current = NS.db:GetCurrentProfile()
  backToDefault()
  assertEqual(current, "Alt", joined(out))
  assertTrue(contains(out, "Switched to profile 'Alt'."), joined(out))
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Profile] changed \226\134\146 Alt", 1, true) ~= nil, lines[1])
end)

test("/at profile <name> keeps case and inner spaces, and strips one pair of quotes", function()
  ensureProfile("Raid Night")
  local out = slash("profile \"Raid Night\"")
  assertEqual(NS.db:GetCurrentProfile(), "Raid Night", joined(out))
  backToDefault()
  out = slash("profile 'Raid Night'")
  assertEqual(NS.db:GetCurrentProfile(), "Raid Night", joined(out))
  backToDefault()
  out = slash("profile Raid Night")
  assertEqual(NS.db:GetCurrentProfile(), "Raid Night", "unquoted, the spaces are kept: " .. joined(out))
  backToDefault()
  NS.db:DeleteProfile("Raid Night", true)
end)

test("/at profile <name> in the wrong case is refused with a did-you-mean", function()
  -- AceDB names are case-sensitive; the verb never folds one onto another, and never creates it.
  ensureProfile("Alt")
  local before = profileSet()
  local out = slash("profile ALT")
  assertEqual(NS.db:GetCurrentProfile(), "Default", joined(out))
  assertEqual(profileSet(), before, "no profile was created")
  assertTrue(contains(out, "No profile named 'ALT'."), joined(out))
  assertTrue(contains(out, "Did you mean 'Alt'?"), joined(out))
end)

test("/at profile <current name> says so and switches nothing", function()
  local lines = debugLines(function()
    assertTrue(contains(slash("profile Default"), "Already on profile 'Default'."))
  end)
  -- The one line is the library's refusal (Slash minor 18); no [Profile] switch line fires.
  assertEqual(#lines, 1, "no profile event fired: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Cmd] refused profile Default: already current", 1, true) ~= nil, lines[1])
end)

test("/at profile <name> refuses in combat and switches nothing", function()
  ensureProfile("Alt")
  local saved = T.mocks.InCombatLockdown
  T.mocks.InCombatLockdown = function() return true end
  local ok, out = pcall(slash, "profile Alt")
  T.mocks.InCombatLockdown = saved
  assertTrue(ok, tostring(out))
  assertEqual(NS.db:GetCurrentProfile(), "Default", joined(out))
  assertTrue(contains(out, "Can't switch profiles in combat."), joined(out))
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
  -- `use` switches to an existing profile only (D3), so the target exists before the spies go on.
  ensureProfile("Switched")
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
