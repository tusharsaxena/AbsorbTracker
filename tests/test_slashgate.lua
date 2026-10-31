local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- settings/Slash.lua: /at enable, /at disable and the disabled gate, the list of verbs that still
-- answer while the addon is off (slash-commands-§2).
--
-- Peeled out of tests/test_slashcmds.lua, which reached two of the three release runs anti-pattern
-- #53 allows in the layout-§1 band. The cases moved verbatim and in their original order, and the
-- runner loads this file straight after test_slashcmds. The helpers below are repeated rather than
-- exported, because a suite file returns nothing the runner reads.

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

-- ── /at enable | /at disable (slash-commands-§2) ────────────────────────────────────

test("/at enable and /at disable write the Enable row's OWN path, through the one seam", function()
  -- THE RESERVED PAIR, and they are ALIASES rather than a second switch. The failure this case
  -- exists to prevent is not "the verb does nothing" — it is a verb that keeps its own flag beside
  -- the checkbox, so the panel says on and the addon is off (or the other way round) and neither
  -- surface is wrong about itself.
  --
  -- Asserted at the SEAM, not at the value: a handler that wrote `db.profile.enabled` directly
  -- would leave `enabled` reading the same and silently skip the row's onChange — NS.SyncEnabledHold
  -- (settings/General.lua) — so the addon would never stand down after `/at disable`.
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
  -- either state. In this addon `enabled` moves the stand-down latch's `disabled` hold, and
  -- StandDown takes down only the features — the unit-event frames, the AceEvent registrations and
  -- the bus — never the dispatcher, which is what makes that true here.
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

-- The verbs that keep answering with the addon off. Thirteen of the fifteen are slash-commands-§2's
-- own list, which LibKa0s-Slash-1.0 applies for us from minor 12 (`diagnostics` from minor 16); `resetposition` and `profile` are
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
  -- debug-logging-§14's report, live from Slash minor 16. Inert until the verb ships (DR-AT-03):
  -- the case below walks NS.COMMANDS, and a row nothing dispatches asserts nothing.
  diagnostics = true,
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
  -- promoted to the live list without argument; any of §2's thirteen losing its answer.
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
  -- (options-ui-§15's exemption) — so they are feature verbs, and the launcher menu's Locked entry
  -- runs these same handlers. Asserted at the SEAM as well as the value: the refusal must not reach
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
  -- onChange moves the latch, whose StandDown publishes VISIBILITY), and catching the setup would
  -- read as the verb acting.
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

test("/at profile <name> switches while the addon is disabled", function()
  -- `profile` is on this addon's liveVerbs (settings/Slash.lua), so the bare-name form answers with
  -- the addon off: the player who disabled it to get out from under a profile can switch away.
  -- red under: `profile` dropped from liveVerbs, which answers the refusal line instead.
  ensureProfile("Alt")
  local out = slashWhileDisabled("profile Alt")
  local current = NS.db:GetCurrentProfile()
  backToDefault()
  NS.SetByPath("enabled", true)
  assertFalse(contains(out, REFUSAL), joined(out))
  assertEqual(current, "Alt", joined(out))
  assertTrue(contains(out, "Switched to profile 'Alt'."), joined(out))
end)
