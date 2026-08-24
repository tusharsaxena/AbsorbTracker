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

test("bare /at prints the help index: header + one row per command", function()
  local out = capture(function() NS.Slash:OnSlash("") end)
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
  NS.SetByPath("barWidth", 200)
  NS.State.debug = false
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before, "a [Set] line should be appended")
  assertTrue(last:find("[Set]", 1, true) ~= nil, "tag is Set")
  assertTrue(last:find("barWidth = 200", 1, true) ~= nil, "logs path = value")
end)

-- -- the `L` trap -----------------------------------------------------------------------------

test("the schema CLI's list header the library renders is prose, not its own STRINGS key",
  function()
  -- settings/Slash.lua:424's descriptor omits `L`. `/at list` is the shortest path from a user
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
