local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- The panel toolkit as THIS addon is wired to it. The toolkit itself is LibKa0s-Options-1.0 and is
-- tested in that repo; what these cases pin is that AbsorbTracker still reaches it correctly through
-- NS.Helpers (settings/OptionsSetup.lua) — the CreatePanel factory + registry,
-- and the reset/refresh trio (RestoreDefaults / RestoreAllDefaults / RefreshAllPanels) that both
-- the Defaults buttons and the /at reset* verbs run through.
--
-- The widget-building half (EnsureScroll / Section / InlineButtonPair / RenderSchema) needs a live
-- AceGUI-3.0, which is absent headlessly, so it is covered by the in-game smoke tests instead —
-- see docs/smoke-tests.md.
--
-- The rendered pages themselves -- the per-unit Appearance page and the General page's inline
-- buttons -- are in tests/test_panelpages.lua, peeled from here near the layout-§1 cap (R-14).

local Helpers = NS.Helpers

-- ── CreatePanel + the panel registry ───────────────────────────────────────────────

test("CreatePanel returns a ctx wired to a panel, a body and an empty refresher list", function()
  local ctx = Helpers.CreatePanel("ATTestPanelA", "Test A", { pageKey = "general" })
  assertTrue(ctx.panel ~= nil, "ctx carries the canvas frame")
  assertTrue(ctx.body ~= nil, "and its body child")
  assertEqual(ctx.pageKey, "general")
  assertEqual(#ctx.refreshers, 0)
  assertEqual(ctx.scroll, nil, "the AceGUI scroll frame stays lazy until first render")
end)

-- ── the Blizzard canvas contract (LibKa0s-Options-1.0 minor 5) ─────────────────────
--
-- Blizzard's Settings window calls OnCommit on apply, OnRefresh on re-show, and OnDefault from its
-- own FOOTER defaults control — which is a different widget from the header Defaults button this
-- addon builds, and is not per-page. The library stamps all three in CreatePanel as of minor 5, so
-- this addon gained a working footer control without a line of its own changing. These cases are
-- what notice if a re-vendor takes it away again: nothing in this repo would otherwise, because
-- every page's header button keeps working and looks equivalent to the user.
--
-- RAWGET throughout, and that is the point rather than a style choice. The frame mock synthesizes a
-- no-op for any PascalCase key, so `type(panel.OnDefault) == "function"` is true whether or not a
-- single line ever set it.

test("the canvas frame carries OnCommit, OnDefault and OnRefresh from the library", function()
  local ctx = Helpers.CreatePanel("ATTestPanelCanvas1", "Canvas 1", { defaultsButton = true })
  assertEqual(type(rawget(ctx.panel, "OnCommit")),  "function", "OnCommit")
  assertEqual(type(rawget(ctx.panel, "OnDefault")), "function", "OnDefault")
  assertEqual(type(rawget(ctx.panel, "OnRefresh")), "function", "OnRefresh")
end)

test("OnDefault reaches a defaultsOnClick parked AFTER the panel is built", function()
  -- The ordering is the whole reason the library forwards rather than assigns, and it is this
  -- addon's shape that makes it matter: both pages that own a defaults button --
  -- settings/General.lua and settings/Appearance.lua -- park their handler after CreatePanel
  -- returns, because the button does not exist until first OnShow. A re-vendor that turned the
  -- forwarder back into an assignment would capture nil in both, silently, and only the footer
  -- control would notice — in game. (The three pages this comment used to name, Bar, Border and
  -- Font, are the ones settings/Appearance.lua replaced.)
  local ctx = Helpers.CreatePanel("ATTestPanelCanvas2", "Canvas 2", { defaultsButton = true })
  local ran = 0
  ctx.panel.defaultsOnClick = function() ran = ran + 1 end
  rawget(ctx.panel, "OnDefault")()
  assertEqual(ran, 1, "the footer control must reach the page's parked defaults action")
end)

test("a page that parks no defaults action still has a callable, inert OnDefault", function()
  -- The footer control is not per-page, so it can be clicked while the landing page is open.
  local ctx = Helpers.CreatePanel("ATTestPanelCanvas3", "Canvas 3", {})
  assertNil(rawget(ctx.panel, "defaultsOnClick"))
  rawget(ctx.panel, "OnDefault")()   -- must not raise
end)

test("CreatePanel names the panel with the plain title for the Blizzard left tree", function()
  -- The header FontString gets the "Ka0s Absorb Tracker > Page" breadcrumb, but panel.name (what
  -- Blizzard renders in the category tree) must stay unprefixed or the tree reads doubled up.
  local ctx = Helpers.CreatePanel("ATTestPanelB", "Test B", {})
  assertEqual(ctx.panel.name, "Test B")
end)

test("CreatePanel starts the panel hidden", function()
  local ctx = Helpers.CreatePanel("ATTestPanelC", "Test C", {})
  assertFalse(ctx.panel:IsShown(), "Blizzard shows the canvas when its category is selected")
end)

test("CreatePanel only DECLARES the Defaults button, never builds it", function()
  -- options-ui-§5 / anti-pattern #42: the widget must be created on first OnShow, after every
  -- addon (including UI skinners hooking AceGUI:RegisterAsWidget) has loaded. Building it here
  -- would be a load-order race that renders the button unskinned.
  local ctx = Helpers.CreatePanel("ATTestPanelD", "Test D", { defaultsButton = true })
  assertTrue(ctx.panel.wantsDefaultsButton, "the intent is recorded")
  assertEqual(ctx.panel.defaultsBtn, nil, "but no widget exists yet")
end)

test("CreatePanel records no Defaults intent when the page did not ask for one", function()
  local ctx = Helpers.CreatePanel("ATTestPanelE", "Test E", {})
  assertFalse(ctx.panel.wantsDefaultsButton)
end)

test("CreatePanel carries the defaults tooltip through to the lazy builder", function()
  local ctx = Helpers.CreatePanel("ATTestPanelF", "Test F",
    { defaultsButton = true, defaultsTooltip = "Reset this page" })
  assertEqual(ctx.panel.defaultsTooltip, "Reset this page")
end)

test("EnsureDefaultsButton builds the button once, then is idempotent", function()
  local ctx = Helpers.CreatePanel("ATTestPanelG", "Test G",
    { defaultsButton = true, defaultsTooltip = "Reset this page" })
  local clicked = 0
  ctx.panel.defaultsOnClick = function() clicked = clicked + 1 end

  Helpers.EnsureDefaultsButton(ctx.panel)
  local btn = ctx.panel.defaultsBtn
  assertTrue(btn ~= nil, "the first call builds it")
  assertEqual(btn.text, "Defaults")
  assertTrue(btn.callbacks.OnClick ~= nil, "the handler parked on the panel got wired to it")
  assertTrue(btn.callbacks.OnEnter ~= nil, "and the tooltip is attached")

  Helpers.EnsureDefaultsButton(ctx.panel)
  assertEqual(ctx.panel.defaultsBtn, btn, "a second call reuses the same widget")

  btn.callbacks.OnClick(btn, "OnClick")
  assertEqual(clicked, 1)
end)

test("EnsureDefaultsButton is a safe no-op without AceGUI, and on a nil panel", function()
  local ctx = Helpers.CreatePanel("ATTestPanelG2", "Test G2", { defaultsButton = true })
  -- Nils the handle the toolkit itself reads, not NS.AceGUI. Since the extraction NS.Helpers IS
  -- the LibKa0s-Options instance and it stashes AceGUI on itself (Ka0s standard library-stack-§4, one lookup
  -- rather than one per builder); NS.AceGUI is the copy it hands the host for its own page files.
  -- In game the two are always the same object, so this is the same scenario read at the seam the
  -- code under test actually uses.
  local saved = Helpers.AceGUI
  Helpers.AceGUI = nil
  local ok = pcall(Helpers.EnsureDefaultsButton, ctx.panel)
  Helpers.AceGUI = saved
  assertTrue(ok, "must not raise when AceGUI is absent")
  assertEqual(ctx.panel.defaultsBtn, nil, "and must not half-build anything")
  assertTrue(pcall(Helpers.EnsureDefaultsButton, nil), "must not raise on a nil panel")
end)

test("EnsureDefaultsButton leaves a panel that never wanted one alone", function()
  local ctx = Helpers.CreatePanel("ATTestPanelH", "Test H", {})
  Helpers.EnsureDefaultsButton(ctx.panel)
  assertEqual(ctx.panel.defaultsBtn, nil)
end)

-- ── RestoreDefaults ────────────────────────────────────────────────────────────────

test("RestoreDefaults resets every row on the named page", function()
  local rows = NS.SchemaForPage("appearance")
  assertTrue(#rows > 0, "the Appearance page has schema rows to reset")
  for _, row in ipairs(rows) do
    if row.type == "number" then T.rawSet(row.path, (row.default or 0) + 1) end
  end
  Helpers.RestoreDefaults("appearance")
  for _, row in ipairs(rows) do
    if row.type == "number" then
      assertEqual(NS.GetSetting(row.path), row.default, row.path .. " is back at its default")
    end
  end
end)

test("RestoreDefaults leaves other pages untouched", function()
  -- The per-panel Defaults button must be page-scoped; a stray global reset here would silently
  -- wipe settings the user never asked about. Border and Font are tabs on the Appearance page now,
  -- not pages, so the pair that proves the scoping is General against Appearance: a General reset
  -- must not touch a unit's styling, and an Appearance reset must not touch the throttle.
  T.rawSet("units.player.borderSize", 20)
  Helpers.RestoreDefaults("general")
  assertEqual(NS.GetSetting("units.player.borderSize"), 20,
    "an Appearance value survives a General-page reset")

  T.rawSet("throttleWindow", 0.85)
  Helpers.RestoreDefaults("appearance")
  assertEqual(NS.GetSetting("throttleWindow"), 0.85,
    "a General value survives an Appearance-page reset")

  Helpers.RestoreDefaults("appearance")
  Helpers.RestoreDefaults("general")
end)

test("RestoreDefaults runs the ctx refreshers so open widgets re-read", function()
  local ctx = Helpers.CreatePanel("ATTestPanelI", "Test I", { pageKey = "appearance" })
  local ran = 0
  ctx.refreshers[1] = function() ran = ran + 1 end
  ctx.refreshers[2] = function() ran = ran + 1 end
  Helpers.RestoreDefaults("appearance", ctx)
  assertEqual(ran, 2)
end)

test("RestoreDefaults survives a refresher that throws", function()
  -- Refreshers touch live AceGUI widgets; one dead widget must not abort the rest of the reset.
  local ctx = Helpers.CreatePanel("ATTestPanelJ", "Test J", { pageKey = "appearance" })
  local ran = 0
  ctx.refreshers[1] = function() error("boom") end
  ctx.refreshers[2] = function() ran = ran + 1 end
  assertTrue(pcall(Helpers.RestoreDefaults, "appearance", ctx),
    "RestoreDefaults must not propagate")
  assertEqual(ran, 1, "the refresher after the failing one still ran")
  ctx.refreshers[1] = function() end
end)

test("RestoreDefaults on a page with no rows is a harmless no-op", function()
  assertTrue(pcall(Helpers.RestoreDefaults, "nosuchpage"))
end)

test("the Defaults button fires each reset row's onChange exactly once", function()
  -- Characterization for #30: the page reset reaches every row through the descriptor's
  -- applyDefault, and must neither skip a row's reaction nor double it.
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved, calls, got = row.onChange, 0, nil
  row.onChange = function(v) calls = calls + 1; got = v end
  T.rawSet("units.player.barWidth", 250)
  local ok, err = pcall(Helpers.RestoreDefaults, "appearance")
  row.onChange = saved
  if not ok then error(err) end
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(calls, 1, "one onChange per reset row")
  assertEqual(got, NS.unitDefaults.barWidth, "and it receives the default")
end)

-- ── the bulk bracket (debug-logging-§10, LibKa0s-Options-1.0 minor 16) ─────────────
--
-- A bulk reset through the settings helper is ONE `[Set] <act> <scope>: N rows` line, never one
-- `[Set]` per row, and N is the rows the act actually wrote: a row already at its default is not
-- counted. The library brackets its walks through the descriptor's bulkBegin / bulkEnd; the seam
-- (NS.SetByPath) mutes its per-row line inside and tallies the writes that CHANGED a stored value.
-- The library's own `count` is not N: it counts every row whose applyDefault returned, changed or
-- not, and General's `state.debugConsole` (no default, so nothing written) among them.

-- The debug lines one act appends, with debug on for its duration.
local function linesOf(fn)
  local before = #NS.DebugLog.buffer
  NS.State.debug = true
  local ok, err = pcall(fn)
  NS.State.debug = false
  if not ok then error(err, 0) end
  local out = {}
  for i = before + 1, #NS.DebugLog.buffer do out[#out + 1] = NS.DebugLog.buffer[i] end
  return out
end

-- Put `pageKey` at its defaults, then move its first `k` number rows off them, unlogged.
local function dirtyPage(pageKey, k)
  Helpers.RestoreDefaults(pageKey)
  local moved = 0
  for _, row in ipairs(NS.SchemaForPage(pageKey)) do
    if moved < k and row.type == "number" and row.default ~= nil then
      T.rawSet(row.path, row.default + 1)
      moved = moved + 1
    end
  end
  assertEqual(moved, k, pageKey .. " has " .. k .. " number rows to move")
end

for _, page in ipairs({ "appearance", "general" }) do
  test("the " .. page .. " page's Defaults logs one [Set] line counting the rows it changed",
    function()
    -- red under: a descriptor with no bulkBegin / bulkEnd, where every row logs `path = value`,
    -- or a count of rows walked rather than rows changed.
    dirtyPage(page, 2)
    local lines = linesOf(function() Helpers.RestoreDefaults(page) end)
    assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
    local want = ("[Set] reset %s: 2 rows"):format(page)
    assertTrue(lines[1]:find(want, 1, true) ~= nil, "want '" .. want .. "', got " .. lines[1])
    T.mocks.__fireTimers()
  end)

  test("the " .. page .. " page's Defaults at defaults already logs 0 rows", function()
    -- The line still names the act, so a press is visible in the log even when it changed nothing.
    Helpers.RestoreDefaults(page)
    local lines = linesOf(function() Helpers.RestoreDefaults(page) end)
    assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
    local want = ("[Set] reset %s: 0 rows"):format(page)
    assertTrue(lines[1]:find(want, 1, true) ~= nil, "want '" .. want .. "', got " .. lines[1])
    T.mocks.__fireTimers()
  end)
end

test("a nested bulk act logs exactly one line, the outer act's, summing every level", function()
  -- debug-logging-§10 is one line per act. A host act that wraps two library page resets is one
  -- act: the depth counter holds the line until the outermost bracket closes.
  -- red under: bulkEnd logging at every level instead of when the depth returns to zero.
  dirtyPage("appearance", 2)
  dirtyPage("general", 1)
  local lines = linesOf(function()
    NS.Bulk.Run("reset", "both pages", function()
      Helpers.RestoreDefaults("appearance")
      Helpers.RestoreDefaults("general")
    end)
  end)
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Set] reset both pages: 3 rows", 1, true) ~= nil, lines[1])
  T.mocks.__fireTimers()
end)

test("a nested bulk act that includes a profile reset logs only the handler's line", function()
  -- Any level that reports info.profileReset silences the whole act's bulk line.
  local lines = linesOf(function()
    NS.Bulk.Run("reset", "everything", function() Helpers.RestoreAllDefaults() end)
  end)
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("[Set] reset profile '", 1, true) ~= nil, lines[1])
  T.mocks.__fireTimers()
end)

test("a page reset that raises still unmutes the seam", function()
  -- The library runs the walk inside a pcall and always calls bulkEnd, so a raising row cannot
  -- leave every later write unlogged. The error still reaches the caller.
  -- red under: a bulkEnd that does not release the mute.
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved = row.onChange
  row.onChange = function() error("boom") end
  local ok = pcall(Helpers.RestoreDefaults, "appearance")
  row.onChange = saved
  assertFalse(ok, "the raising row's error reaches the caller")
  local lines = linesOf(function() NS.SetByPath("units.player.barWidth", 222) end)
  assertEqual(#lines, 1, "the next single write logs again")
  assertTrue(lines[1]:find("[Set] units.player.barWidth = 222", 1, true) ~= nil, lines[1])
  Helpers.RestoreDefaults("appearance")
  T.mocks.__fireTimers()
end)

test("a bulk act that raises logs its one line marked as stopped by an error", function()
  -- debug-logging-§10's one line is still owed when the act dies half way: it says how many rows
  -- the act DID change, and that it did not finish. Still exactly one line, the mute still
  -- released, and the error still reaches the caller unchanged.
  -- red under: a bulkEnd that ignores its `err`, so a half-done act reads as a finished one.
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth)
  local ok, err
  local lines = linesOf(function()
    ok, err = pcall(NS.Bulk.Run, "reset", "probe", function()
      NS.SetByPath("units.player.barWidth", NS.unitDefaults.barWidth + 7)
      error("boom", 0)
    end)
  end)
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth)
  assertFalse(ok, "the walk's error reaches the caller")
  assertEqual(err, "boom", "re-raised unchanged")
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  local want = "[Set] reset probe: 1 rows (stopped by an error)"
  assertTrue(lines[1]:find(want, 1, true) ~= nil, "want '" .. want .. "', got " .. lines[1])
  local after = linesOf(function() NS.SetByPath("units.player.barWidth", 222) end)
  assertEqual(#after, 1, "the next single write logs again")
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth)
  T.mocks.__fireTimers()
end)

test("a library page reset that raises logs its one line marked as stopped by an error", function()
  -- The same marker on the library's bracket: RestoreDefaults hands bulkEnd the raised value.
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved = row.onChange
  row.onChange = function() error("boom") end
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth + 3)
  local ok
  local lines = linesOf(function() ok = pcall(Helpers.RestoreDefaults, "appearance") end)
  row.onChange = saved
  assertFalse(ok, "the raising row's error reaches the caller")
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertTrue(lines[1]:find("%[Set%] reset appearance: %d+ rows %(stopped by an error%)$") ~= nil,
    lines[1])
  Helpers.RestoreDefaults("appearance")
  T.mocks.__fireTimers()
end)

-- ── the profile reset's count (debug-logging-§10) ──────────────────────────────────
--
-- `[Set] reset profile '<name>' to defaults (N rows)`: N is the rows the reset CHANGED, counted
-- just before an addon-driven db:ResetProfile() (NS.ResetProfileCounted), never the schema size.
-- A reset the addon did not drive (an AceDBOptions button, a /run) has no count and says none.

local function resetLine(n)
  local line = ("[Set] reset profile '%s' to defaults"):format(NS.db:GetCurrentProfile())
  return n and (line .. (" (%d rows)"):format(n)) or line
end

-- Put the active profile back at its defaults, unlogged. A reset the addon did not drive.
local function cleanProfile()
  NS.db:ResetProfile()
  T.mocks.__fireTimers()
end

test("Reset All on a clean profile logs (0 rows)", function()
  -- red under: a count of every row the profile stores (the schema size).
  cleanProfile()
  local lines = linesOf(function() Helpers.RestoreAllDefaults() end)
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertEqual(lines[1]:match("%[Set%].*$"), resetLine(0))
  T.mocks.__fireTimers()
end)

test("a reset the addon did not drive logs the reset line with no count", function()
  -- An AceDBOptions Reset Profile press or a /run calls db:ResetProfile() straight: nothing counted
  -- before the profile was replaced, so the line carries no `(N rows)` rather than a made-up one.
  cleanProfile()
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth + 1)
  local lines = linesOf(function() NS.db:ResetProfile() end)
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertEqual(lines[1]:match("%[Set%].*$"), resetLine(nil))
  T.mocks.__fireTimers()
end)

test("a counted reset that never reached the handler leaks no count into a later reset", function()
  -- The pending count is cleared when the handler takes it, AND when the counted reset returns or
  -- raises without the handler taking it (AceDB's noCallbacks, a reset that aborts). Otherwise the
  -- next, unrelated reset would carry a stale number.
  -- red under: a pending count cleared only by the handler.
  cleanProfile()
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth + 1)
  local silent = { ResetProfile = function() end }
  local raising = { ResetProfile = function() error("aborted", 0) end }
  NS.ResetProfileCounted(silent)
  local ok, err = pcall(NS.ResetProfileCounted, raising)
  assertFalse(ok, "an aborted reset's error reaches the caller")
  assertEqual(err, "aborted")
  local lines = linesOf(function() NS.db:ResetProfile() end)
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertEqual(lines[1]:match("%[Set%].*$"), resetLine(nil))
  T.mocks.__fireTimers()
end)

test("Reset All logs exactly one line in total, the profile handler's", function()
  -- debug-logging-§10: a whole-profile reset is logged ONCE, by the profile-event handler, worded
  -- by the event, and no bulk bracket adds a second line. The library says which case it is through
  -- bulkEnd's info.profileReset. A probe sessionOnly row with a default makes the walk write one
  -- row under the mute first, so the case is not vacuous: that write must not log either, nor count.
  -- N is the two rows moved off their defaults first, not the rows the profile stores.
  -- red under: bulkEnd logging `[Set] reset all: N rows` when info.profileReset is true,
  -- OnProfileReset still sharing the switch handler's `[Profile] changed` line, or an N that is the
  -- schema size.
  cleanProfile()
  T.rawSet("units.player.barWidth", NS.unitDefaults.barWidth + 1)
  T.rawSet("units.target.fontSize", NS.unitDefaults.fontSize + 1)
  -- The probe carries its own get/set, the shape a sessionOnly row's storage takes since
  -- LibKa0s-Schema-1.0, and is REGISTERED (indexed) rather than written into the array, because the
  -- seam only writes a path it can find. Removed and re-indexed afterwards.
  local path, store = "__probe.bulkSession", { value = false }
  NS.RegisterSchemaRows({ { page = "general", group = "Probe", path = path, type = "bool",
                            default = true, sessionOnly = true, onChange = function() end,
                            get = function() return store.value end,
                            set = function(v) store.value = v end } })
  local ok, lines = pcall(linesOf, function() Helpers.RestoreAllDefaults() end)
  NS.Schema[#NS.Schema] = nil
  NS.SchemaRuntime.Reindex()
  if not ok then error(lines, 0) end
  assertEqual(store.value, true, "the session row was still written")
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertEqual(lines[1]:match("%[Set%].*$"), resetLine(2))
  T.mocks.__fireTimers()
end)

-- ── RestoreAllDefaults ─────────────────────────────────────────────────────────────

test("RestoreAllDefaults resets every schema row that is not on the profiles page", function()
  -- Retargeted (spec §9): schema rows now live at dotted per-unit paths, not flat keys.
  T.rawSet("units.player.barWidth", 333)
  T.rawSet("units.player.borderSize", 30)
  T.rawSet("units.player.fontSize", 30)
  Helpers.RestoreAllDefaults()
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(NS.GetSetting("units.player.borderSize"), NS.unitDefaults.borderSize)
  assertEqual(NS.GetSetting("units.player.fontSize"), NS.unitDefaults.fontSize)
  T.mocks.__fireTimers()
end)

test("RestoreAllDefaults clears the saved bar position so the bar recenters", function()
  -- `position` is written by dragging, not by a schema row, so ApplyDefault never touches it. The
  -- explicit clear here is what keeps the popup and `/at resetall` from diverging (they once did).
  -- Retargeted (spec §9): position is now per-unit; check every unit, not just one flat field.
  for _, u in ipairs(NS.Units.LIST) do
    NS.db.profile.units[u].position = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 5, y = 5 }
  end
  Helpers.RestoreAllDefaults()
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.db.profile.units[u].position, nil, u .. " kept its position")
  end
  T.mocks.__fireTimers()
end)

test("RestoreAllDefaults publishes POSITION so the bar moves immediately", function()
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.POSITION, function() seen = seen + 1 end)
  Helpers.RestoreAllDefaults()
  target:UnregisterMessage(NS.MSG.POSITION)
  assertEqual(seen, 1)
  T.mocks.__fireTimers()
end)

test("RestoreAllDefaults skips the profiles page (resetting it would delete user data)", function()
  local touched = {}
  local origApply = NS.ApplyDefault
  NS.ApplyDefault = function(row) touched[#touched + 1] = row.page end
  local ok, err = pcall(Helpers.RestoreAllDefaults)
  NS.ApplyDefault = origApply
  if not ok then error(err) end
  for _, page in ipairs(touched) do
    assertTrue(page ~= "profiles", "no profiles-page row may be reset")
  end
  T.mocks.__fireTimers()
end)

-- ── RefreshAllPanels ───────────────────────────────────────────────────────────────

test("RefreshAllPanels runs the refreshers of every registered panel", function()
  local a = Helpers.CreatePanel("ATTestPanelK", "Test K", {})
  local b = Helpers.CreatePanel("ATTestPanelL", "Test L", {})
  local ranA, ranB = 0, 0
  a.refreshers[1] = function() ranA = ranA + 1 end
  b.refreshers[1] = function() ranB = ranB + 1 end
  Helpers.RefreshAllPanels()
  assertEqual(ranA, 1)
  assertEqual(ranB, 1)
  a.refreshers[1] = function() end
  b.refreshers[1] = function() end
end)

test("RefreshAllPanels isolates a throwing refresher from the rest", function()
  local bad = Helpers.CreatePanel("ATTestPanelM", "Test M", {})
  local good = Helpers.CreatePanel("ATTestPanelN", "Test N", {})
  local ran = 0
  bad.refreshers[1] = function() error("dead widget") end
  good.refreshers[1] = function() ran = ran + 1 end
  assertTrue(pcall(Helpers.RefreshAllPanels), "one dead panel must not break the others")
  assertEqual(ran, 1)
  bad.refreshers[1] = function() end
  good.refreshers[1] = function() end
end)

test("NS.RefreshOptionsPanel delegates to RefreshAllPanels", function()
  local ctx = Helpers.CreatePanel("ATTestPanelO", "Test O", {})
  local ran = 0
  ctx.refreshers[1] = function() ran = ran + 1 end
  NS.RefreshOptionsPanel()
  assertEqual(ran, 1)
  ctx.refreshers[1] = function() end
end)

-- ── Shared layout constants ────────────────────────────────────────────────────────

test("the cross-slice layout constants are published for the widget/about slices", function()
  -- Widgets.lua and About.lua read these off Helpers rather than keeping private copies, so the
  -- panel spacing stays in lockstep. A nil here silently collapses every row to zero height.
  assertEqual(type(Helpers.ROW_VSPACER), "number")
  assertEqual(type(Helpers.SECTION_HEADING_H), "number")
  assertEqual(type(Helpers.BUTTON_PAIR_REL), "number")
  assertTrue(Helpers.BUTTON_PAIR_REL < 0.5,
    "the paired-button width is inset under 0.5 so the right button clears the scroll clip")
end)

-- -- the `L` trap -----------------------------------------------------------------------------

test("the Defaults button the library renders is prose, not its own STRINGS key", function()
  -- LibKa0s-Options-1.0 takes NO `L` override (its `L` is lib.LAYOUT, a geometry table), so no
  -- descriptor mutation can redden this — see tests/test_ltrap.lua's header for why that is
  -- recorded rather than faked. What it does pin is the one library-owned string this addon puts
  -- on screen through Options: EnsureDefaultsButton sets lib.STRINGS.DEFAULTS_LABEL on the widget,
  -- and this reads it back off the built button.
  local ctx = Helpers.CreatePanel("ATTestPanelLTrap", "Test L", { defaultsButton = true })
  Helpers.EnsureDefaultsButton(ctx.panel)
  local btn = ctx.panel.defaultsBtn
  assertTrue(btn ~= nil, "the Defaults button must have been built")
  local text = btn.text
  assertTrue(type(text) == "string" and text ~= "", "the Defaults button must render a label")
  assertNil(text:match("^[A-Z][A-Z0-9_]+$"),
    "the Defaults button resolved to prose, not to its own key (got '" .. text .. "')")
  -- Non-vacuity: the assertion above is only worth something if this string really is the
  -- library's, so pin the coupling rather than the literal "Defaults".
  local lib = T.mocks.LibStub("LibKa0s-Options-1.0", true)
  assertEqual(text, lib.STRINGS.DEFAULTS_LABEL,
    "the rendered label must be the library's own string, not a host copy")
end)
