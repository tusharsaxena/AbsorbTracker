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

-- ── the stub's member set ──────────────────────────────────────────────────────────

test("the degraded stub publishes LSMValues, the one member reached at file load", function()
  -- settings/{Bar,Border,Font}.lua call it inside schema-row literals, so a nil aborts the file and
  -- takes that page's rows out of the schema. tests/test_perf.lua counts the rows; this names why.
  local NS2 = loadDegraded()
  assertEqual(type(NS2.Helpers.LSMValues), "function")
  assertEqual(type(NS2.Helpers.LSMValues("statusbar")), "function", "and it returns a values fn")
end)

test("the degraded stub keeps no private copy of the library's layout constants", function()
  -- Measured, not assumed: dropping each of these from the stub and re-running the degraded load
  -- leaves #NS.Schema unchanged, because every reader (settings/About.lua, settings/UnitPanel.lua)
  -- sits behind an AceGUI the degraded build never gets. Their values are lib.LAYOUT's, and a host
  -- copy of a library value is the copy that goes stale. The live instance still answers all three
  -- (tests/test_helpers.lua) — they come from the library there, which is the point.
  local NS2 = loadDegraded()
  for _, name in ipairs({ "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL" }) do
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
