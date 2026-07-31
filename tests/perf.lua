-- tests/perf.lua — the offline performance runner (issue #17).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- DELIBERATELY OUTSIDE THE GREEN GATE. `lua tests/run.lua` does not invoke this, and nothing about
-- a commit depends on it. Wall-clock numbers on a developer machine are not stable enough to fail
-- a build on, and a perf suite that fails spuriously gets disabled within a week.
--
-- What it DOES assert is the deterministic half — repaint counts, WoW API call counts, and bytes
-- allocated per pass. Those are machine-independent, so a real regression (someone breaks the
-- coalescing throttle, or adds an allocation to the repaint path) fails here loudly while a busy
-- CPU never does. Exit code is non-zero on an assertion failure, so this is CI-usable later even
-- though nothing gates on it today.
--
-- Timings are printed for orientation only. Read them as ratios between scenarios in one run, never
-- as absolute numbers to compare across machines.
--
-- Output is the shared record schema documented in the LibKa0s repo, encoded by the SAME
-- NS.Perf.EncodeJSON the in-game probe uses — the instance mirrors the library's encoder and schema
-- number, so an offline record and an in-game record are guaranteed to be the same shape.

local Loader     = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

-- Each dofile of the kit loader returns a FRESH table, so this runner sets its own addonName rather
-- than inheriting one from tests/run.lua. Addon chunks are called as ("AbsorbTracker", NS) to match
-- the client's `local addonName, NS = ...` header — core/PerfSetup.lua reads that first argument.
Loader.addonName = "AbsorbTracker"

-- ── arguments ───────────────────────────────────────────────────────────────────────────────

local opts = { out = nil, label = "offline" }
do
  local i = 1
  while arg and arg[i] do
    local a = arg[i]
    if a == "--out" then opts.out = arg[i + 1]; i = i + 2
    elseif a == "--label" then opts.label = arg[i + 1] or opts.label; i = i + 2
    else
      io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
      io.stderr:write("usage: lua tests/perf.lua [--out <path>] [--label <text>]\n")
      os.exit(2)
    end
  end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────

local mocks = buildMocks()
local NS = {}

-- Derived from the TOC, not copied from it. This runner is NOT executed by `lua tests/run.lua`, so
-- a hand-maintained list here rots silently while the allocation figures it produces are still
-- treated as the extraction's parity gate. tests/test_loadorder.lua asserts this file still derives.
--
-- The library half IS hand-maintained (the TOC reaches it through an XML the loader cannot read),
-- and it has already rotted once: omitting Core.lua does not fail — Perf simply refuses to register,
-- NS.Perf becomes the degradation stub, and probeOverheadOn quietly measures a stub with no probe in
-- it. Keep this list in LibKa0s.xml's order, and read the figures as suspect if they move without a
-- change that should have moved them.
Loader.loadAll({ "libs/LibKa0s/Core.lua", "libs/LibKa0s/DebugLog.lua", "libs/LibKa0s/Perf.lua",
  "libs/LibKa0s/PerfPanel.lua" }, NS, mocks)
Loader.loadAll(Loader.tocFiles("AbsorbTracker.toc"), NS, mocks)

NS:InitDB()

-- Every unit enabled: the worst realistic case, and the one the user is running.
for _, unit in ipairs(NS.Units.LIST) do
  NS.db.profile.units[unit].enabled = true
end
mocks.__unitExists.target = true
mocks.__unitExists.focus  = true

-- ── the API counting layer ──────────────────────────────────────────────────────────────────
--
-- Wrapped HERE rather than inside tests/wow_mock.lua on purpose: the unit harness must keep
-- measuring the addon, not a counting shim, and a mock that counted for everyone would be one more
-- thing every future test has to reason about. The cost of that choice is that this layer has to
-- know the shape of a bar, which is a fair trade for leaving the gated suite untouched.

local apiCalls = 0

-- One proxy per underlying frame, memoised. The memo is not an optimisation — it is required for
-- correctness under the mock, where `statusBar:CreateFontString(...)` returns the PARENT frame, so
-- `bar.valueText` and `bar.statusBar` are the same table. Wrapping them independently would hand
-- one of them the raw frame and silently drop every call made through it, which is exactly the bug
-- that made this scenario first report 6 calls per pass instead of 9.
local proxies = {}

local function countCalls(frame)
  if not frame then return frame end
  if proxies[frame] then return proxies[frame] end

  local methods = {}
  local proxy = setmetatable({}, {
    __index = function(_, k)
      if methods[k] ~= nil then return methods[k] end
      local v = frame[k]
      if type(v) == "function" then
        local wrapped = function(_, ...) apiCalls = apiCalls + 1; return v(frame, ...) end
        methods[k] = wrapped
        return wrapped
      end
      return v
    end,
    __newindex = function(_, k, v) frame[k] = v end,
  })
  proxies[frame] = proxy
  return proxy
end

-- Wrap the children first, then re-point them through the proxy, then wrap the bar itself — so
-- every frame the repaint path touches (bar:SetAlpha plus the three StatusBar/FontString calls) is
-- counted. NS.bars is what modules/Display.lua reads, so the proxy has to be installed there.
for _, unit in ipairs(NS.Units.LIST) do
  local bar = NS.bars[unit]
  if bar then
    local statusBar = countCalls(bar.statusBar)
    bar.statusBar = statusBar
    bar.valueText = countCalls(bar.valueText)
    NS.bars[unit] = countCalls(bar)
  end
end

-- ── measurement helpers ─────────────────────────────────────────────────────────────────────

local results = {}
local failures = {}

local function assert_(cond, msg)
  if not cond then failures[#failures + 1] = msg end
  return cond
end

--- Run `fn` `iterations` times, reporting wall time, API calls and bytes allocated PER ITERATION.
---
--- The allocation figure is the load-bearing one. A full collect before and after isolates the
--- garbage this path actually produces, and garbage per repaint is what turns a cheap-looking
--- function into a frame-rate problem once it runs at 10 Hz in combat.
local function measure(name, iterations, fn)
  collectgarbage("collect")
  collectgarbage("collect")
  apiCalls = 0
  local kbBefore = collectgarbage("count")
  local t0 = os.clock()
  for i = 1, iterations do fn(i) end
  local elapsed = os.clock() - t0
  local kbAfter = collectgarbage("count")

  local r = {
    name        = name,
    iterations  = iterations,
    totalMs     = elapsed * 1000,
    msPerIter   = (elapsed * 1000) / iterations,
    apiCalls    = apiCalls,
    apiPerIter  = apiCalls / iterations,
    bytesPerIter = ((kbAfter - kbBefore) * 1024) / iterations,
  }
  results[#results + 1] = r
  return r
end

-- ── scenarios ───────────────────────────────────────────────────────────────────────────────

local BURST = 1000

-- 1. Coalescing. The single most important invariant the addon has: a burst of absorb events in
--    combat must collapse into ONE repaint per throttle window, not one per event. If this ever
--    regresses the addon goes from ~10 repaints/s to hundreds.
local coalesced = 0
do
  for _ = 1, BURST do
    NS.addon:OnAbsorbChanged("UNIT_ABSORB_AMOUNT_CHANGED", "player")
  end
  coalesced = #mocks.__timers
  mocks.__fireTimers()
  assert_(coalesced == 1,
    ("coalescing: %d absorb events armed %d repaints, expected exactly 1"):format(BURST, coalesced))
end

-- 2. The absorb event handler itself, with the throttle already armed — the steady-state cost of an
--    event arriving mid-combat. This is the highest-frequency path the addon has at a dummy.
NS.addon:OnAbsorbChanged("UNIT_ABSORB_AMOUNT_CHANGED", "player")   -- arm, so none of the below arm
local absorbEvent = measure("absorbEvent", BURST, function()
  NS.addon:OnAbsorbChanged("UNIT_ABSORB_AMOUNT_CHANGED", "player")
end)
assert_(absorbEvent.bytesPerIter < 64,
  ("absorbEvent allocates %.1f bytes/event; a coalesced event must be near-free")
    :format(absorbEvent.bytesPerIter))
NS.CancelPendingRepaint()

-- 3. A full coalesced repaint pass over all three bars.
local paintPass = measure("paintPass", BURST, function()
  NS.ForEachUnit(function(unit) NS.UpdateAbsorbBar(unit) end)
end)
assert_(paintPass.apiPerIter > 0, "paintPass made no API calls — the counting layer is not attached")
assert_(paintPass.apiPerIter == 12,
  ("paintPass makes %.1f API calls/pass, expected 12 (4 per bar x 3 bars)")
    :format(paintPass.apiPerIter))

-- 4. A full restyle. Heaviest known path: SetBackdrop twice plus four LibSharedMedia fetches per
--    bar. Only runs on settings changes, so its cost matters far less than its frequency does.
local appearance = measure("appearancePass", 200, function()
  NS.ForEachUnit(function(unit) NS.UpdateBarAppearance(unit) end)
end)

-- 5. The settings read path. Every appearance read routes through Units.Get, so a regression here
--    multiplies across every other scenario.
local settingsRead = measure("settingsRead", BURST * 10, function()
  NS.Units.Get("target", "barWidth")
end)
assert_(settingsRead.bytesPerIter < 16,
  ("settingsRead allocates %.1f bytes/read; the hot read path must not allocate")
    :format(settingsRead.bytesPerIter))

-- 6. Probe overhead. The instrumentation must be free when capture is off, or the measurement tool
--    is itself the regression. This compares the same pass with the brackets dormant vs. armed.
local probeOff = measure("probeOverheadOff", BURST, function()
  NS.ForEachUnit(function(unit) NS.UpdateAbsorbBar(unit) end)
end)
NS.Perf.on = true
local probeOn = measure("probeOverheadOn", BURST, function()
  NS.ForEachUnit(function(unit) NS.UpdateAbsorbBar(unit) end)
end)
NS.Perf.on = false
assert_(probeOff.bytesPerIter <= probeOn.bytesPerIter + 1,
  "a dormant bracket allocated more than an armed one — the gating idiom is wrong")
assert_(probeOff.apiPerIter == probeOn.apiPerIter,
  "the probe changed how many API calls a pass makes")

-- ── report ──────────────────────────────────────────────────────────────────────────────────

print(("Ka0s Absorb Tracker \226\128\148 offline perf  (v%s, label '%s')")
  :format(NS.version, opts.label))
print(("%d absorb events coalesced into %d repaint%s")
  :format(BURST, coalesced, coalesced == 1 and "" or "s"))
print()
print(("%-18s %10s %12s %12s %12s"):format("scenario", "iters", "ms/iter", "api/iter", "bytes/iter"))
for _, r in ipairs(results) do
  print(("%-18s %10d %12.5f %12.1f %12.1f")
    :format(r.name, r.iterations, r.msPerIter, r.apiPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only \226\128\148 compare scenarios within a run, never across machines")

if #failures > 0 then
  print()
  print(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
  for _, f in ipairs(failures) do print("  - " .. f) end
end

-- ── record ──────────────────────────────────────────────────────────────────────────────────

if opts.out then
  local buckets = {}
  for _, r in ipairs(results) do
    -- Map the scenario table onto the shared bucket shape: `calls` is the iteration count and
    -- `totalMs` / `maxMs` carry the same meaning as in-game, so one reader handles both sources.
    -- No `within`, deliberately: these scenarios are entry points driven one at a time, each timing
    -- only its own loop, so no scenario's total is contained in another's. The record schema treats
    -- a missing `within` as exactly that — a top-level total, safe to sum.
    buckets[r.name] = {
      calls        = r.iterations,
      totalMs      = r.totalMs,
      maxMs        = r.msPerIter,
      apiPerIter   = r.apiPerIter,
      bytesPerIter = r.bytesPerIter,
    }
  end

  local record = {
    schema    = NS.Perf.SCHEMA,
    -- Self-identifying, exactly as BuildRecord's in-game record is: one reader, one shape.
    addon     = "AbsorbTracker",
    source    = "offline",
    version   = NS.version,
    interface = 0,          -- no client involved
    timestamp = os.time(),
    label     = opts.label,
    buckets   = buckets,
    fps       = {           -- fixed shape; an offline run has no frames to sample
      active    = { seconds = 0, frames = 0, avgFps = 0, msPerFrame = 0 },
      suspended = { seconds = 0, frames = 0, avgFps = 0, msPerFrame = 0 },
      deltaMsPerFrame = 0,
    },
    coalescing = { events = BURST, repaints = coalesced },
    failures   = failures,
  }

  local fh, err = io.open(opts.out, "w")
  if not fh then
    io.stderr:write("cannot write " .. opts.out .. ": " .. tostring(err) .. "\n")
    os.exit(2)
  end
  fh:write(NS.Perf.EncodeJSON(record), "\n")
  fh:close()
  print("wrote " .. opts.out)
end

os.exit(#failures == 0 and 0 or 1)
