-- tests/degraded_env.lua — builds a SECOND addon environment with LibKa0s absent.
--
-- LibKa0s is vendored, so it can go missing: a partial unzip, a user pruning libs/, a packager that
-- dropped the folder. Every setup file in the addon carries a degradation stub for that case, and
-- the only honest way to exercise those stubs is a real load without the library — a hand-stub after
-- the fact cannot reproduce a file that failed to finish loading.
--
-- Returned as a builder rather than kept private to one suite because more than one suite needs the
-- same environment: tests/test_perf.lua (the probe stub and the schema-completeness guard) and
-- tests/test_helpers.lua (the settings stub's reset veto and its member set). It is NOT part of the
-- vendored kit under tests/_kit/ — that folder must stay byte-identical to LibKa0s/testkit — and it
-- is not a suite, so tests/run.lua does not list it; callers dofile it like tests/wow_mock.lua.
--
-- Nothing here calls InitDB or CreateOptionsPanel, so the shared suite's SavedVariables globals are
-- untouched.
return function()
  local Loader     = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  -- A fresh loader table per dofile, so this environment sets its own addonName.
  Loader.addonName = "AbsorbTracker"
  local mocks2, NS2 = buildMocks(), {}
  -- libs/LibKa0s/*.lua deliberately not loaded: nothing registers any of the majors, and the mock's
  -- LibStub returns nil for each exactly as the real client would. So this environment exercises
  -- every setup file's degradation path at once, as a load rather than as a hand-stub.
  --
  -- The list is the TOC's, in the TOC's order, and it is the WHOLE list. Both halves matter:
  --
  --   * Whole, because the load-order hazard this environment exists to catch is a page file that
  --     calls a helper at FILE LOAD (settings/Bar.lua evaluates LSMValues inside a schema-row
  --     literal). A list that stopped before the page files — as this one did until M6 — would
  --     stay green straight through a total load failure, because the schema simply would not be
  --     built and nothing here looked at it. tests/test_perf.lua's count assertion is the guard.
  --   * The TOC's own order, because core/PerfSetup.lua loads BEFORE core/DebugLogSetup.lua, which
  --     is exactly why PerfSetup's NS.DebugLog lookups have to stay lazy. A list that inverted the
  --     pair would let a hoisted lookup pass here and fail in the client.
  Loader.loadAll(Loader.tocFiles("AbsorbTracker.toc"), NS2, mocks2)
  return NS2, mocks2
end
