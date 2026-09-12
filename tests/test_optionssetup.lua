local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- settings/OptionsSetup.lua as a FILE: the descriptor's half of the reset contract, and the
-- degradation stub. The panel toolkit itself is LibKa0s-Options-1.0 and is tested in that repo;
-- tests/test_helpers.lua covers this addon reaching it through NS.Helpers. What is left, and what
-- lives here, is the one thing that file owns twice over — "what must a global reset never touch" —
-- plus the stub's member set, which is a load-order argument and therefore only provable by loading.

local Helpers = NS.Helpers
local loadDegraded = dofile("tests/degraded_env.lua")

-- ── the Profiles reset veto, on both paths ─────────────────────────────────────────
--
-- settings/OptionsSetup.lua's stub is the one degradation stub in this addon that is
-- LOAD-COMPLETING rather than member-answering, and it keeps its own reset loop, because losing the
-- panel is survivable and losing `/at resetall` is not. That second loop must veto exactly what the
-- live one vetoes: resetting an AceDBOptions-supplied row deletes user data.

-- Which schema rows a build's "reset everything" leaves alone, as sorted paths. ApplyDefault is
-- looked up on the namespace at call time by both paths, so swapping it in observes the veto
-- without writing anything.
--
-- Two probe rows are appended for the duration, because no SHIPPING row is on the profiles page
-- today — that page's controls are AceDBOptions'. The veto exists for the row that gets added
-- there next, so the probe is what makes this case non-vacuous.
local function vetoedByResetAll(ns, restoreAll)
  local n = #ns.Schema
  table.insert(ns.Schema, { page = "profiles", path = "__probe.onProfilesPage", type = "toggle" })
  table.insert(ns.Schema, { page = "general", path = "__probe.onGeneralPage", type = "toggle" })
  -- A SESSION-ONLY row, which is the one kind the walk must still sweep: its storage is its own
  -- set() rather than the db, so a profile reset cannot reach it (options-ui-§12). This addon ships
  -- none today, so the probe is what keeps the rule under test.
  table.insert(ns.Schema, { page = "general", path = "__probe.sessionOnly", type = "toggle",
                            sessionOnly = true, get = function() return false end,
                            set = function() end })

  local touched = {}
  local orig = ns.ApplyDefault
  ns.ApplyDefault = function(row) touched[row.path] = true end
  local ok, err = pcall(restoreAll)
  ns.ApplyDefault = orig

  local vetoed = {}
  for _, row in ipairs(ns.Schema) do
    if not touched[row.path] then vetoed[#vetoed + 1] = row.path end
  end
  for i = #ns.Schema, n + 1, -1 do ns.Schema[i] = nil end
  if not ok then error(err) end
  table.sort(vetoed)
  return table.concat(vetoed, ",")
end

test("the live and degraded builds veto exactly the same rows from Reset All", function()
  -- One rule — enforced in two places: the descriptor's skipRestoreAll, which the library calls, and
  -- the stub's own loop, which runs with no library at all. They must not be able to drift.
  --
  -- The rule has two clauses now (options-ui-§12). A global reset must not touch AceDBOptions-
  -- supplied rows, because that deletes user data; and it must not touch anything else that lives in
  -- the PROFILE either, because the reset IS a profile reset and writing each row's default first
  -- would refresh the panel once per row for values about to be discarded whole. What survives the
  -- veto is the sessionOnly rows, which a profile reset cannot reach.
  -- red under: a predicate that vetoes only the profiles page, or one that vetoes everything.
  local NS2 = loadDegraded()
  local live = vetoedByResetAll(NS, Helpers.RestoreAllDefaults)
  local degraded = vetoedByResetAll(NS2, NS2.Helpers.RestoreAllDefaults)

  assertTrue(live:find("__probe.onProfilesPage", 1, true) ~= nil,
    "the profiles row must be vetoed — resetting it deletes the player's profiles")
  assertTrue(live:find("__probe.onGeneralPage", 1, true) ~= nil,
    "an ordinary profile-backed row must be vetoed; the profile reset covers it")
  assertFalse(live:find("__probe.sessionOnly", 1, true) ~= nil,
    "a sessionOnly row must still be swept — a profile reset cannot reach it")
  assertEqual(degraded, live, "the degraded reset vetoes a different row set than the live one")
  T.mocks.__fireTimers()
end)

-- Run one build's Reset All against a probe sessionOnly row -- the one kind of row both walks
-- still reset -- and report what the reset did to it: the stored value and each onChange value.
-- The probe binds its own session storage, so the write never reaches a profile.
local function resetAllProbe(ns, restoreAll)
  local path = "__probe.resetAllSession"
  local store = { value = false }
  ns.RegisterSessionSetting(path, {
    get = function() return store.value end,
    set = function(v) store.value = v end,
  })
  local changes = {}
  local n = #ns.Schema
  table.insert(ns.Schema, { page = "general", path = path, type = "bool", default = true,
                            sessionOnly = true, onChange = function(v) changes[#changes + 1] = v end })
  local ok, err = pcall(restoreAll)
  for i = #ns.Schema, n + 1, -1 do ns.Schema[i] = nil end
  if not ok then error(err) end
  return store.value, changes
end

test("Reset All resets a sessionOnly row and fires its onChange once, on both builds", function()
  -- Characterization for #30: the live walk reaches the row through the descriptor's applyDefault
  -- (libs/LibKa0s/Options.lua), the degraded stub through its own loop. Both end in
  -- NS.ApplyDefault, and both must write the default and react to it exactly once.
  local NS2 = loadDegraded()
  for label, pair in pairs({ live = { NS, Helpers.RestoreAllDefaults },
                             degraded = { NS2, NS2.Helpers.RestoreAllDefaults } }) do
    local value, changes = resetAllProbe(pair[1], pair[2])
    assertEqual(value, true, label .. ": the sessionOnly row is back at its default")
    assertEqual(#changes, 1, label .. ": one onChange for the reset row")
    assertEqual(changes[1], true, label .. ": and it receives the default")
  end
  T.mocks.__fireTimers()
end)

-- The degraded build's Reset All, observed through a spy on its NS.Debug: with no library the sink
-- is a no-op stub and there is no buffer to read. The seam and the profile handler both look
-- NS.Debug up at call time, so the spy sees what the live console would.
local function degradedResetAllLines(NS2, db)
  local lines = {}
  NS2.Debug = function(tag, fmt, ...) lines[#lines + 1] = ("[%s] " .. fmt):format(tag, ...) end
  NS2.State.debug, NS2.db = true, db
  local ok, err = pcall(resetAllProbe, NS2, NS2.Helpers.RestoreAllDefaults)
  NS2.State.debug, NS2.db = false, nil
  if not ok then error(err, 0) end
  return lines
end

test("the degraded Reset All logs one line in total, the profile handler's", function()
  -- debug-logging-§10, on the path with no library to bracket for it: the stub brackets its own
  -- walk, so the probe session row it writes first is muted, and the profile reset is logged once
  -- by OnProfileReset. The fake db is AceDB-shaped: ResetProfile fires the handler, as AceDB does.
  -- red under: the stub's walk outside NS.Bulk.Run, which logs the session row as well.
  -- N is the rows the reset changed, counted before the stub's own db:ResetProfile(): one row is
  -- moved off its default first. red under: a count of every row the profile stores.
  local NS2 = loadDegraded()
  local profile = NS2.Units.DeepCopy(NS2.defaults.profile)
  profile.schemaVersion = 3
  profile.units.player.barWidth = profile.units.player.barWidth + 1
  local db = { profile = profile, global = {} }
  function db.GetCurrentProfile() return "Default" end
  function db.ResetProfile(self) NS2.OnProfileReset("OnProfileReset", self) end
  -- The handler's repaint reaches this build's Display reactor, which traces each bar's visibility
  -- as `[Bar]`. Reactor lines are not settings lines and §10 keeps them, so only the `[Set]` and
  -- `[Profile]` lines are counted.
  local lines = {}
  for _, line in ipairs(degradedResetAllLines(NS2, db)) do
    if line:find("^%[Set%]") or line:find("^%[Profile%]") then lines[#lines + 1] = line end
  end
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertEqual(lines[1], "[Set] reset profile 'Default' to defaults (1 rows)")
  T.mocks.__fireTimers()
end)

test("the degraded Reset All with no AceDB logs its own one line with the rows it wrote", function()
  -- The no-AceDB fallback db has no ResetProfile, so no handler runs and the bracket's own line is
  -- the only record: `[Set] reset all: N rows`, N being the probe session row the walk wrote.
  local NS2 = loadDegraded()
  local lines = degradedResetAllLines(NS2, { profile = {}, global = {} })
  assertEqual(#lines, 1, "exactly one line: " .. table.concat(lines, " | "))
  assertEqual(lines[1], "[Set] reset all: 1 rows")
end)

-- ── the stub's member set ──────────────────────────────────────────────────────────

test("the degraded stub publishes LSMValues, the one member reached at file load", function()
  -- settings/Appearance.lua call it inside schema-row literals, so a nil aborts the file and
  -- takes that page's rows out of the schema. tests/test_perf.lua counts the rows; this names why.
  local NS2 = loadDegraded()
  assertEqual(type(NS2.Helpers.LSMValues), "function")
  assertEqual(type(NS2.Helpers.LSMValues("statusbar")), "function", "and it returns a values fn")
end)

test("the degraded stub publishes the five composers, the other load-time members", function()
  -- settings/General.lua and settings/Appearance.lua call these inside NS.RegisterSchemaRows, at
  -- FILE LOAD, so a nil aborts the file and takes that page's rows out of the schema exactly as a
  -- nil LSMValues does. tests/test_perf.lua compares the whole path set; this names the members and
  -- pins the line the stub draws through them.
  --
  -- WHAT THEY REPRODUCE is the STORED surface: the path the live composer derives (so `prefix` and
  -- `keys` are honored), the type, and the caller's default. WHAT THEY DO NOT is every label,
  -- tooltip, range, media source and layout flag -- each of those is read by a widget or by the
  -- library's CLI, and a library-less build has neither (settings/Slash.lua's own stub answers
  -- every schema verb with "unavailable"). Copying them would be copying strings whose single
  -- source is the whole point, for nobody to read.
  -- red under: a stub composer returning {}, or one that stops honoring `keys`.
  local NS2 = loadDegraded()
  for _, name in ipairs({ "ColorPair", "FontGroup", "BorderGroup", "BarGroup", "MasterControls" }) do
    assertEqual(type(NS2.Helpers[name]), "function", name .. " is reached at file load")
  end

  local rows = NS2.Helpers.BorderGroup({
    prefix = "units.player.", page = "appearance", group = "Border",
    keys = { borderStyle = "border" }, defaults = { borderSize = 12 },
  })
  assertEqual(#rows, 4, "the canonical border block is four rows")
  assertEqual(rows[1].path, "units.player.border", "`keys` must move the stored path, not the leaf")
  assertEqual(rows[2].default, 12, "and `defaults` must reach the row a reset reads")
  assertEqual(rows[3].type, "color")
  assertEqual(rows[4].path, "units.player.useClassColorBorder")
  assertEqual(rows[1].label, nil, "the stub deliberately carries no label: nothing degraded reads one")

  local master, tail = NS2.Helpers.MasterControls({
    page = "general", addonName = "Absorb Tracker", debugConsolePath = "state.debugConsole",
  })
  assertEqual(#master, 6, "the canonical master set is six schema rows")
  assertEqual(master[6].path, "state.debugConsole", "the console path is verbatim and unprefixed")
  assertEqual(master[6].sessionOnly, true)
  assertEqual(type(tail), "function", "the afterGroup hook is a no-op, not a nil")
end)

test("the degraded stub keeps no private copy of the library's layout constants", function()
  -- Measured, not assumed: dropping each of these from the stub and re-running the degraded load
  -- leaves #NS.Schema unchanged, because every reader (settings/About.lua, settings/UnitPanel.lua)
  -- sits behind an AceGUI the degraded build never gets. Their values are lib.LAYOUT's, and a host
  -- copy of a library value is the copy that goes stale. The live instance still answers all three
  -- (tests/test_helpers.lua) — they come from the library there, which is the point.
  local NS2 = loadDegraded()
  for _, name in ipairs({
    "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL",
    -- The chrome band's three, new at LibKa0s v1.23.0 (options-ui-§13/§14). Measured the same way
    -- and absent for the same reason as the three above: settings/UnitPanel.lua DOES read BANNER_H
    -- now -- it sizes the block it hands PageHeader -- but only from inside a render, and a
    -- library-less build never renders one (RenderUnitPanel bails on a nil NS.AceGUI). The four
    -- CALLABLE members of that band are in the stub -- tests/test_surface_parity.lua holds them
    -- there.
    "CHROME_GAP", "TAB_H", "BANNER_H",
  }) do
    assertEqual(NS2.Helpers[name], nil, name .. " is a copy of lib.LAYOUT with no degraded reader")
  end
end)

test("PARENT_TITLE reaches the library through the descriptor, not the namespace", function()
  -- The brand string's two former cross-file readers (settings/Panel.lua, settings/Helpers.lua) are
  -- inside the library now and receive it as descriptor.parentTitle. Nothing on NS reads it, so
  -- publishing it there would advertise a seam with no consumer.
  assertEqual(NS.PARENT_TITLE, nil, "NS.PARENT_TITLE is a file-scope local now")
  assertEqual(T.mocks.__mainPanel.name, "Ka0s Absorb Tracker",
    "and the brand still reaches the canvas the library registers")
end)

-- ── the LSM30_Border patch, promoted to the library ────────────────────────────────

test("the live arm patches LSM30_Border through the library, not through a private copy", function()
  -- `lib.__PatchLSM30Border()` is LibKa0s-Options-1.0's since minor 15, and the reason it is the
  -- library's is that AceGUI's widget registry is PROCESS-GLOBAL. Five Ka0s addons each carrying
  -- their own registration means five wrappers stacked in one client, whose outermost belongs to
  -- whichever addon loaded last; one lib-level member behind lib.__lsmBorderPatched means one
  -- registration no matter how many copies of the library are vendored.
  --
  -- WHY A WHOLE SECOND LOAD, and why the registry is seeded first. The call happens once, at
  -- settings/OptionsSetup.lua's file load, and the shared environment in tests/run.lua made it long
  -- before any case runs -- with an EMPTY WidgetRegistry, which models AGSMW being absent, so it
  -- registered nothing and returned false. The wrap only exists to be seen when there is a
  -- constructor to wrap. So this builds a second full environment the way tests/test_debuglog.lua
  -- does, puts a stand-in LSM30_Border in the registry before the addon loads, and then asks the
  -- registry what came out.
  --
  -- core/LSMPatch.lua is gone, last of the five private copies. This case never saw it in the
  -- first place: it only published NS.ApplyLSMBorderPatch, which OnEnable called, and nothing here
  -- fires OnEnable. So what the registry held below was always the library's doing alone, which is
  -- what made it safe to delete the private copy on the strength of a green suite.
  -- red under: dropping the lib.__PatchLSM30Border() call from the live arm.
  local Loader     = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  Loader.addonName = "AbsorbTracker"
  local mocks2, NS2 = buildMocks(), {}

  -- The stand-in for AceGUI-3.0-SharedMediaWidgets' own constructor, at its own version. Identity
  -- is what the assertion reads, so it needs no behavior beyond being a distinguishable function.
  local upstream = function() return { frame = {} } end
  local AceGUI = mocks2.LibStub("AceGUI-3.0")
  AceGUI:RegisterWidgetType("LSM30_Border", upstream, 20)

  Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS2, mocks2)
  Loader.loadAll(Loader.tocFiles("AbsorbTracker.toc"), NS2, mocks2)

  assertFalse(AceGUI.WidgetRegistry["LSM30_Border"] == upstream,
    "settings/OptionsSetup.lua's live arm never called lib.__PatchLSM30Border()")
  assertEqual(AceGUI:GetWidgetVersion("LSM30_Border"), 21,
    "the wrapper must register one version above what it wrapped, to win the race")

  -- The sentinel is set, so a second caller in the same session -- a sibling addon's copy of the
  -- library, which LibStub hands the same instance -- registers nothing.
  local lib = mocks2.LibStub("LibKa0s-Options-1.0")
  assertFalse(lib.__PatchLSM30Border(), "the second call must be a no-op")
  assertEqual(AceGUI:GetWidgetVersion("LSM30_Border"), 21, "and must leave the registration alone")
end)
