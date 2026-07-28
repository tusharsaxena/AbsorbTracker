local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

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

-- Strip WoW colour escapes (`|cAARRGGBB` … `|r`) so assertions match the plain text regardless
-- of the schema-output colour scheme (slash-commands-§5): gold key + white value, etc.
local function stripColor(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

test("NS.Print survives AceConsole's embed and stays the [AT]-prefixed printer", function()
  -- Regression (real in-game bug): NewAddon(NS, …, "AceConsole-3.0") embeds AceConsole's :Print
  -- mixin onto NS, clobbering the custom NS.Print from core/Util.lua. core/AbsorbTracker.lua must
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
  -- version on its own line. getVersion() reads Compat metadata with the NS.version
  -- fallback; headless the metadata API is absent, so this resolves to NS.version.
  local hasVersion = false
  for _, entry in ipairs(NS.COMMANDS) do
    if entry[1] == "version" then hasVersion = true break end
  end
  assertTrue(hasVersion, "NS.COMMANDS has a standalone 'version' verb")

  local expected = "v" ..
    (NS.Compat.GetAddOnMetadata(NS.name, "Version") or NS.version or "?")
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

test("/at list uses the mandated colour scheme (slash-commands-§5)", function()
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

test("/at config in combat refuses with a grey notice (options-ui-§2)", function()
  local saved = T.mocks.InCombatLockdown
  T.mocks.InCombatLockdown = function() return true end
  NS.State.panelOpenPending = nil

  local out = capture(function() NS.Slash:OnSlash("config") end)
  assertTrue(out[1] ~= nil and out[1]:find("cannot open settings during combat", 1, true) ~= nil,
    "in combat the open must REFUSE with the canonical grey notice, not defer")
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

test("SetByPath logs one [Set] path = value line (§10)", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  NS.SetByPath("barWidth", 200)
  NS.State.debug = false
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before, "a [Set] line should be appended")
  assertTrue(last:find("[Set]", 1, true) ~= nil, "tag is Set")
  assertTrue(last:find("barWidth = 200", 1, true) ~= nil, "logs path = value")
end)
