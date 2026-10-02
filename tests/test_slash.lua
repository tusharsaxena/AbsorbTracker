local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertNil

-- settings/Slash.lua captured `local print = NS.Print` at load, so the chat output can't be
-- intercepted by swapping NS.Print. Instead capture at the sink: NS.Print writes to
-- DEFAULT_CHAT_FRAME:AddMessage, so overriding that method on the mock frame records every line.
local function capture(fn)
  local out = {}
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old  -- nil restores the metatable no-op
  if not ok then error(err) end
  return out
end

-- Strip WoW color escapes (`|cAARRGGBB` … `|r`) so assertions match the plain text regardless
-- of the schema-output color scheme (slash-commands-§5): gold key + white value, etc.
local function stripColor(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

test("NS.Print survives AceConsole's embed and stays the [AT]-prefixed printer", function()
  -- Regression (real in-game bug): NewAddon(NS, …, "AceConsole-3.0") embeds AceConsole's :Print
  -- mixin onto NS, clobbering the custom NS.Print core/CoreSetup.lua took off LibKa0s-Core.
  -- core/AbsorbTracker.lua must
  -- reclaim it from the pristine NS.Util.print. Without that, every /at line loses the [AT] tag and
  -- gains a trailing colon (AceConsole renders the message as "|cff33ff99<msg>|r:").
  assertTrue(NS.Print == NS.Util.print,
    "NS.Print must be the custom Util.print, not AceConsole's embedded mixin")
  local out = capture(function() NS.Print("regression check") end)
  assertTrue(out[1]:find("[AT]", 1, true) ~= nil, "carries the [AT] tag: " .. tostring(out[1]))
  assertTrue(stripColor(out[1]):find(":%s*$") == nil, "no trailing colon: " .. tostring(out[1]))
end)

test("bare /at opens the settings panel through the config verb, not the help index", function()
  -- LibKa0s-Slash-1.0 minor 11 (slash-commands-§4): an empty or whitespace-only line runs the
  -- `config` handler, whose NS.OpenOptionsPanel opens the landing page. Spied at the NS seam the
  -- handler reads at call time, so the assertion is the route and not the headless no-op.
  local orig, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  local ok, err = pcall(function()
    for _, line in ipairs({ "", "   ", "\t " }) do
      local before = opened
      local out = capture(function() NS.Slash:OnSlash(line) end)
      assertEqual(opened, before + 1, ("input %q opens the panel once"):format(line))
      assertEqual(#out, 0, ("input %q prints nothing, help included"):format(line))
    end
  end)
  NS.OpenOptionsPanel = orig
  if not ok then error(err) end
end)

test("/at help prints the help index: header + one row per command", function()
  local out = capture(function() NS.Slash:OnSlash("help") end)
  assertEqual(#out, #NS.COMMANDS + 1)
  assertTrue(out[1]:find("slash commands") ~= nil, "first line is the header")
  -- No chat line the addon prints ends in a trailing colon (slash-commands-§4 house style).
  for _, line in ipairs(out) do
    assertTrue(stripColor(line):find(":%s*$") == nil, "no trailing colon: " .. line)
  end
end)

test("unknown verb prints 'unknown command' then the help index", function()
  local out = capture(function() NS.Slash:OnSlash("bogus") end)
  assertTrue(out[1]:find("unknown command 'bogus'") ~= nil, out[1])
  assertEqual(#out, #NS.COMMANDS + 2)  -- error line + header + one row per command
end)

test("/at version prints the addon version (slash-commands-§3)", function()
  -- The standalone `version` verb must exist in NS.COMMANDS and print the running
  -- version on its own line. It reads the TOC through the NS.Version seam, which falls back to
  -- NS.version; headless no metadata API is exposed at all, so this resolves to the constant.
  local hasVersion = false
  for _, entry in ipairs(NS.COMMANDS) do
    if entry[1] == "version" then hasVersion = true break end
  end
  assertTrue(hasVersion, "NS.COMMANDS has a standalone 'version' verb")

  local expected = "v" .. NS.Version()
  local out = capture(function() NS.Slash:OnSlash("version") end)
  assertEqual(#out, 1)
  assertTrue(stripColor(out[1]):find(expected, 1, true) ~= nil,
    "prints the running version: " .. tostring(out[1]))
end)

test("/at get <path> dispatches to the schema read", function()
  -- Appearance paths are fully qualified per unit (spec §9); "player" is the plain default unit.
  local out = capture(function() NS.Slash:OnSlash("get units.player.barWidth") end)
  assertTrue(stripColor(out[1]):find("units.player.barWidth = 200 px") ~= nil, out[1])
end)

test("/at list uses the mandated color scheme (slash-commands-§5)", function()
  local out = capture(function() NS.Slash:OnSlash("list") end)
  -- Header: green (33ff99), no trailing colon.
  assertTrue(out[1]:find("|cff33ff99Available settings|r", 1, true) ~= nil, out[1])
  local sawGroup, sawRow = false, false
  for _, line in ipairs(out) do
    if line:find("|cff3399ff%[%w+%]|r") then sawGroup = true end        -- [page] azure
    if line:find("|cFFFFFF00%S+|r = |cFFFFFFFF") then sawRow = true end   -- gold key + white value
    assertTrue(stripColor(line):find(":%s*$") == nil, "no trailing colon: " .. line)
  end
  assertTrue(sawGroup, "at least one steel-blue [page] group header")
  assertTrue(sawRow, "at least one gold-key / white-value row")
end)

test("/at set <path> <value> writes through the schema and preserves path case", function()
  capture(function() NS.Slash:OnSlash("set units.player.barWidth 250") end)
  assertEqual(NS.GetSetting("units.player.barWidth"), 250)
  capture(function() NS.Slash:OnSlash("set units.player.barWidth 200") end)  -- restore
  assertEqual(NS.GetSetting("units.player.barWidth"), 200)
end)

test("/at set clamps out-of-range numbers to the row max", function()
  capture(function() NS.Slash:OnSlash("set units.player.barWidth 99999") end)
  assertEqual(NS.GetSetting("units.player.barWidth"), 500)  -- barWidth max
  capture(function() NS.Slash:OnSlash("set units.player.barWidth 200") end)
end)

test("/at options is aliased to /at config (no unknown-command error)", function()
  -- config calls NS.OpenOptionsPanel, which is a no-op headlessly (no Settings category); the
  -- point is that 'options' resolves to a known verb rather than the unknown-command path.
  local out = capture(function() NS.Slash:OnSlash("options") end)
  for _, line in ipairs(out) do
    assertTrue(line:find("unknown command") == nil, "options must not be unknown")
  end
end)

test("/at config in combat refuses with a gray notice (options-ui-§2)", function()
  local saved = T.mocks.InCombatLockdown
  T.mocks.InCombatLockdown = function() return true end
  NS.State.panelOpenPending = nil

  local out = capture(function() NS.Slash:OnSlash("config") end)
  assertTrue(out[1] ~= nil and out[1]:find("cannot open settings during combat", 1, true) ~= nil,
    "in combat the open must REFUSE with the canonical gray notice, not defer")
  assertTrue(NS.State.panelOpenPending == nil,
    "refusal must NOT defer-and-replay (no pending flag set)")

  T.mocks.InCombatLockdown = saved
end)

test("OpenOptionsPanel logs [Cfg] refused in combat", function()
  local saved = T.mocks.InCombatLockdown
  T.mocks.InCombatLockdown = function() return true end
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  NS.OpenOptionsPanel()
  NS.State.debug = false
  T.mocks.InCombatLockdown = saved
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before and last:find("[Cfg]", 1, true) ~= nil
    and last:find("refused", 1, true) ~= nil, "a [Cfg] refused line is logged in combat")
end)

test("SetByPath logs one [Set] path = value line (debug-logging-§10)", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  -- A schema row's path: since LibKa0s-Schema-1.0 the seam refuses a path with no row (the legacy
  -- flat `barWidth` this case used to write is one), and a refused write is not a mutation, so it
  -- logs nothing.
  NS.SetByPath("units.player.barWidth", 200)
  NS.State.debug = false
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before, "a [Set] line should be appended")
  assertTrue(last:find("[Set]", 1, true) ~= nil, "tag is Set")
  assertTrue(last:find("units.player.barWidth = 200", 1, true) ~= nil, "logs path = value")
end)

-- -- the `L` trap -----------------------------------------------------------------------------

test("the schema CLI's list header the library renders is prose, not its own STRINGS key",
  function()
  -- The `SlashLib:New` descriptor in settings/Slash.lua omits `L`. `/at list` is the shortest path from a user
  -- keystroke to a library-owned string: BuildListLines opens with Text("LIST_HEADER"), so the
  -- first captured chat line IS the rendered result. Driven through NS.Slash:OnSlash rather than
  -- the instance, because `cli` is a file-local and the dispatcher is the only real accessor.
  -- red under: giving the descriptor an `L` that answers LIST_HEADER with "LIST_HEADER".
  local out = capture(function() NS.Slash:OnSlash("list") end)
  assertTrue(#out > 0, "/at list must print")
  -- Strip the addon's own chat tag and the color escapes so what is left is the library's string.
  local header = out[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*%[%u+%]%s*", "")
  assertTrue(header ~= "", "the list header must not be empty")
  assertNil(header:match("^[A-Z][A-Z0-9_]+$"),
    "the list header resolved to prose, not to its own key (got '" .. header .. "')")
end)

-- -- slash verbs: the sub-verb split (AbsorbTracker#33) -------------------------------------
--
-- `/at debug`, `/at profile` and `/at toggle` each split their own sub-verb off the line, and the
-- library-absent stub's dispatcher splits the top verb. The rule they share is LibKa0s-Slash's
-- SplitVerb contract: the verb is lowercased, the remainder keeps its case and its inner spacing.
-- These cases pin that behavior from the player's side, in both builds, so the split can move to
-- one shared function without a visible change. tests/test_slashcmds.lua is at layout-§1's cap, so
-- they live here.

local function plainSlash(line)
  local out = capture(function() NS.Slash:OnSlash(line) end)
  local plain = {}
  for i, l in ipairs(out) do plain[i] = stripColor(l) end
  return plain
end

local function joinedLines(lines) return table.concat(lines, "\n") end

local function hasLine(lines, needle)
  return joinedLines(lines):find(needle, 1, true) ~= nil
end

-- A library-free build, loaded once (tests/degraded_env.lua), with the one-shot "library missing"
-- banner burnt so it never counts as a verb's output.
local degradedNS, degradedMocks
local function degraded()
  if not degradedNS then
    degradedNS, degradedMocks = dofile("tests/degraded_env.lua")()
    local cf = degradedMocks.DEFAULT_CHAT_FRAME
    local old = rawget(cf, "AddMessage")
    cf.AddMessage = function() end
    degradedNS.Print("burn the banner")
    cf.AddMessage = old
  end
  return degradedNS, degradedMocks
end

-- Every chat line one degraded slash input printed, the build's tag stripped off the front.
local function degradedSlash(line)
  local NS2, mocks2 = degraded()
  local out = {}
  local cf  = mocks2.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = (tostring(msg):gsub("^%S+%s", "")) end
  local ok, err = pcall(function() NS2.Slash:OnSlash(line) end)
  cf.AddMessage = old
  if not ok then error(err) end
  return out
end

-- A duck-typed profile store for the degraded build, which never runs InitDB.
local function withFakeStore(NS2, fn)
  local saved = NS2.db
  NS2.db = {
    profile = {}, global = {},
    GetProfiles = function() return { "Default", "Alt" }, 2 end,
    GetCurrentProfile = function() return "Default" end,
    SetProfile = function() end,
  }
  local ok, err = pcall(fn)
  NS2.db = saved
  if not ok then error(err) end
end

-- Drive one line through `env` with every top-level handler replaced by a recorder; describe the
-- verb reached and the rest handed over.
local function routed(env, envMocks, line)
  local saved, ran, gotRest = {}, nil, nil
  for i, entry in ipairs(env.COMMANDS) do
    saved[i] = entry[3]
    entry[3] = function(rest) ran, gotRest = entry[1], rest end
  end
  local cf  = envMocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function() end
  local ok, err = pcall(function() env.Slash:OnSlash(line) end)
  cf.AddMessage = old
  for i, entry in ipairs(env.COMMANDS) do entry[3] = saved[i] end
  if not ok then error(err) end
  return ("verb=%s rest=%q"):format(tostring(ran), tostring(gotRest))
end

test("slash verbs: /at debug lowercases its sub-verb and keeps the remainder (EVENTS, HOLD)", function()
  -- red under: a runDebug split that stops lowercasing the sub-verb, or one that loses the remainder.
  local lower, upper = plainSlash("debug events"), plainSlash("debug EVENTS")
  assertTrue(hasLine(upper, "Rejected events:"), joinedLines(upper))
  assertEqual(joinedLines(upper), joinedLines(lower), "EVENTS answers as events does")

  NS.db.profile.units.player.enabled = true
  local real, held = NS.HoldPreview, {}
  NS.HoldPreview = function(secs) held[#held + 1] = secs end
  local ok, out = pcall(plainSlash, "debug HOLD 1234 2")
  NS.HoldPreview = real
  NS.ClearPreview()
  assertTrue(ok, tostring(out))
  assertTrue(hasLine(out, "Holding"), joinedLines(out))
  assertEqual(#held, 1, "the hold reached NS.HoldPreview once")
  assertEqual(held[1], 2, "the remainder `1234 2` reached runHold whole")
end)

test("slash verbs: /at profile NEW <MixedCase> lowercases only the verb", function()
  -- red under: a runProfile split that folds the argument, which would make `casepin`.
  local out = plainSlash("profile NEW CasePin")
  local current = NS.db:GetCurrentProfile()
  NS.db:SetProfile("Default")
  T.mocks.__fireTimers()
  NS.db:DeleteProfile("CasePin", true)
  assertEqual(current, "CasePin", joinedLines(out))
  assertTrue(hasLine(out, "Created and switched to new profile 'CasePin'"), joinedLines(out))
  for _, name in ipairs(NS.db:GetProfiles()) do
    assertTrue(name ~= "casepin", "the argument was not folded")
  end
end)

test("slash verbs: the stub's split agrees with the live dispatcher's over a corpus", function()
  -- The stub dispatcher splits the top verb itself; the live one is the library's. Both must reach
  -- the same handler with the same rest.
  -- red under: any drift of the stub's split (a verb not folded, a rest trimmed or re-cased).
  local NS2, mocks2 = degraded()
  for _, line in ipairs({ "DEBUG events", "  profile   Raid Night", "Toggle TARGET", "debug HOLD 5 2",
      "x" }) do
    assertEqual(routed(NS2, mocks2, line), routed(NS, T.mocks, line),
      ("degraded and live route %q alike"):format(line))
  end
end)

test("slash verbs: degraded /at debug events and /at profile current still answer", function()
  -- The host's sub-verbs never went to the library, so they keep working on a degraded load.
  -- red under: a sub-verb split that reaches into the library without a stub behind it.
  local NS2 = degraded()
  local events, current
  withFakeStore(NS2, function()
    events = degradedSlash("debug EVENTS")
    current = degradedSlash("profile CURRENT")
  end)
  assertTrue(hasLine(events, "Rejected events: none"), joinedLines(events))
  assertTrue(hasLine(current, "Current profile: Default"), joinedLines(current))
end)

test("slash verbs: degraded /at profile list lists from the store, plainly", function()
  -- With the library absent there is no shared name list, so `list` prints the store's own.
  -- red under: a `list` that needs the library, or one that drops the header or the marker.
  local NS2 = degraded()
  local out
  withFakeStore(NS2, function() out = degradedSlash("profile list") end)
  assertTrue(hasLine(out, "Available profiles"), joinedLines(out))
  assertTrue(hasLine(out, "Default (current)"), joinedLines(out))
  assertTrue(hasLine(out, "  Alt"), joinedLines(out))
end)

test("slash verbs: the stub's SplitVerb returns what the library's does, over a corpus", function()
  -- The one splitter the stub carries (slash-commands-§1's minimal dispatch) must be the library's
  -- contract exactly; live, the seam is the library's own function.
  -- red under: any drift of the stub split, or a live build that splits with a private copy.
  local lib = T.mocks.LibStub("LibKa0s-Slash-1.0")
  assertTrue(NS.Slash.__SplitVerb == lib.SplitVerb, "live, the split is the library's function")
  local NS2 = degraded()
  local stub = NS2.Slash.__SplitVerb
  assertTrue(type(stub) == "function" and stub ~= lib.SplitVerb, "degraded, the stub's own splitter")
  local corpus = { false, "", "x", "LIST", "use Raid Night", "  a  b ", "HOLD 5 2" }
  for _, input in ipairs(corpus) do
    local arg = input or nil
    local sv, sr = stub(arg)
    local lv, lr = lib.SplitVerb(arg)
    local label = ("input %q"):format(tostring(arg))
    assertEqual(sv, lv, label .. ": verb")
    assertEqual(sr, lr, label .. ": rest")
  end
end)

-- The names printed under `header` (a line ending in it), in order, up to the first non-row line.
local function listedUnder(lines, header)
  local names, inList = {}, false
  for _, line in ipairs(lines) do
    if inList then
      local name = line:match("^%S+   (%S.-)$")
      if not name then break end
      names[#names + 1] = (name:gsub(" %(current%)$", ""))
    elseif line:find(header .. "$") then
      inList = true
    end
  end
  return names
end

test("slash verbs: /at profile list and bare /at profile list the same names in the same order", function()
  -- AbsorbTracker#33: `list` used to walk db:GetProfiles() unsorted while bare `/at profile` printed
  -- the library's sorted list, so the two routes could disagree. Both now read Slash.ProfileNames.
  -- red under: `list` walking the store directly again.
  for _, name in ipairs({ "zeta", "Alpha", "beta" }) do NS.db:SetProfile(name) end
  NS.db:SetProfile("Default")
  T.mocks.__fireTimers()
  local list, bare = plainSlash("profile list"), plainSlash("profile")
  local want = T.mocks.LibStub("LibKa0s-Slash-1.0").ProfileNames(NS.db)
  for _, name in ipairs({ "zeta", "Alpha", "beta" }) do NS.db:DeleteProfile(name, true) end

  local fromList, fromBare = listedUnder(list, "Available profiles"), listedUnder(bare, "Profiles")
  assertEqual(table.concat(fromList, ","), table.concat(want, ","), joinedLines(list))
  assertEqual(table.concat(fromBare, ","), table.concat(fromList, ","), joinedLines(bare))
  local at = {}
  for i, name in ipairs(fromList) do at[name] = i end
  assertTrue(at.Alpha < at.beta and at.beta < at.Default and at.Default < at.zeta,
    "sorted ignoring case: " .. table.concat(fromList, ","))
  assertTrue(hasLine(list, "Default (current)"), joinedLines(list))
end)

test("slash verbs: /at profile list names the current profile even when the store leaves it out", function()
  -- AceDB's GetProfiles appends the current profile itself; a duck-typed store need not.
  -- red under: `list` walking the store directly again.
  local real = NS.db.GetProfiles
  NS.db.GetProfiles = function() return { "Other" }, 1 end
  local ok, out = pcall(plainSlash, "profile list")
  NS.db.GetProfiles = real
  assertTrue(ok, tostring(out))
  assertEqual(table.concat(listedUnder(out, "Available profiles"), ","), "Default,Other",
    joinedLines(out))
  assertTrue(hasLine(out, "Default (current)"), joinedLines(out))
end)
