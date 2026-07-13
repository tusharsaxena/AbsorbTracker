# Event-Driven Coalesced Absorb-Bar Repaint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fixed-interval poll ticker with pure event-driven absorb-bar repaints, coalesced through a trailing-edge throttle.

**Architecture:** `UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_MAXHEALTH`, and `PLAYER_ENTERING_WORLD` call `NS.RequestRepaint()`, which schedules a single one-shot AceTimer (`throttleWindow` seconds) that repaints once and re-arms. No repeating ticker; idle = zero repaints. The `updateInterval` setting is retired for `throttleWindow` via a `schemaVersion` 1→2 migration.

**Tech Stack:** Lua, Ace3 (AceAddon/AceEvent/AceTimer/AceConsole), AceDB schema migrations, headless Lua test harness (`tests/run.lua`), luacheck.

## Global Constraints

- **Standard:** Ka0s WoW Addon Standard — no deviation permitted. §3.1: no raw `C_Timer` for repeating or deferred work — use AceTimer (`NS.addon:ScheduleTimer`). §2.2/§5.1: schema changes go through the versioned, idempotent `NS:RunMigrations` seam.
- **Green gate before every commit:** `lua tests/run.lua` (all pass, exit 0) **and** `luacheck .` (0 warnings / 0 errors). Syntax-check a single file with `luac -p <file>`.
- **Never** bump the addon version (TOC/README). **Never** auto-stage/commit/push beyond the explicit commit steps in this plan.
- **Repaint entry point is unchanged:** `NS.UpdateAbsorbBar()` (`modules/Display.lua`) already self-guards on `hidden` and `testHoldUntil` and reads both `UnitGetTotalAbsorbs("player")` and `UnitHealthMax("player")`. Do not modify it. Every repaint path funnels into it.
- **Frozen bundles:** never edit anything under `docs/audits/` or `docs/reviews/` — they are dated historical records.
- **Commit trailer:** every commit message ends with:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
  ```

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `defaults/Profile.lua` | Modify | Replace `updateInterval = 1.0` default with `throttleWindow = 0.1`. |
| `settings/General.lua` | Modify | Replace the `updateInterval` schema row with a `throttleWindow` row (no `onChange`). |
| `core/Database.lua` | Modify | Add `schemaVersion` 1→2 migration step that drops the orphaned `updateInterval` key. |
| `modules/Timer.lua` | Rewrite | Becomes the coalescing throttle: `NS.RequestRepaint()`. Remove `RestartUpdateTicker`/`ResetTickerInterval` and all ticker state. |
| `core/AbsorbTracker.lua` | Modify | Wire events to `RequestRepaint`; register `UNIT_MAXHEALTH`; remove ticker call sites. |
| `tests/wow_mock.lua` | Modify | Instrument the `ScheduleTimer` mock to record scheduled callbacks + add a fire helper. |
| `tests/test_database.lua` | Modify | Update the 3 version-stamp tests to expect v2; add migration tests. |
| `tests/test_timer.lua` | Create | Coalescing-throttle + event-wiring tests. |
| `tests/run.lua` | Modify | `dofile("tests/test_timer.lua")`. |
| Docs (see Task 4) | Modify | Sync behavior + test-count references. |

---

## Task 1: Retire `updateInterval` for `throttleWindow` + v2 migration

**Files:**
- Modify: `defaults/Profile.lua:26`
- Modify: `settings/General.lua:50-62`
- Modify: `core/Database.lua:53`
- Test: `tests/test_database.lua`

**Interfaces:**
- Consumes: existing `NS:RunMigrations` (reads/writes `NS.db.global.schemaVersion`, backfills missing `NS.flatDefaults` keys into `NS.db.profile`).
- Produces: profile setting `throttleWindow` (number, default `0.1`); `schemaVersion` latest value `2`; the legacy `updateInterval` profile key removed on upgrade.

- [ ] **Step 1: Update the existing version-stamp tests to expect v2, and add migration tests**

In `tests/test_database.lua`, replace the three version tests (currently lines 6–22) with these, then append the two new migration tests after them (keep every other test in the file unchanged):

```lua
-- ── RunMigrations: the schema-migration seam (Ka0s standard §2.2/§5.1) ─────────────
-- The current schema version is 2, so a full migration run leaves the DB stamped at 2.
test("RunMigrations migrates a fresh DB to the current version (2)", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations leaves an already-current (v2) DB unchanged", function()
  NS.db.global.schemaVersion = 2
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations is idempotent across repeated runs", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations(); NS:RunMigrations(); NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations v2 retires the legacy updateInterval profile key", function()
  NS.db.global.schemaVersion = 1
  NS.db.profile.updateInterval = 1.0
  NS:RunMigrations()
  assertEqual(NS.db.profile.updateInterval, nil)
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations backfills throttleWindow from flatDefaults", function()
  NS.db.profile.throttleWindow = nil
  NS:RunMigrations()
  assertEqual(NS.db.profile.throttleWindow, NS.flatDefaults.throttleWindow)
end)
```

- [ ] **Step 2: Run the suite to verify the new/updated tests fail**

Run: `lua tests/run.lua`
Expected: FAIL — the version tests report `expected 2, got 1` and `RunMigrations v2 retires...` / `backfills throttleWindow` fail (no `throttleWindow` default, no v2 step). Suite exits non-zero.

- [ ] **Step 3: Add the `throttleWindow` default (remove `updateInterval`)**

In `defaults/Profile.lua`, replace line 26:

```lua
    updateInterval = 1.0,
```
with:
```lua
    throttleWindow = 0.1,
```

- [ ] **Step 4: Replace the schema row in `settings/General.lua`**

Replace the whole `updateInterval` entry (lines 50–62) with:

```lua
    {
        path    = "throttleWindow",
        page    = "general",
        group   = "Performance",
        order   = 10,
        type    = "number",
        label   = "Update throttle (in sec)",
        desc    = "Fastest the bar repaints during a burst of changes. Lower = snappier but more CPU.",
        default = flatDefaults.throttleWindow,
        min = 0.05, max = 1, step = 0.05, fmt = "%.2f sec",
        solo    = true,
    },
```

Note: no `onChange` — `NS.RequestRepaint` reads `throttleWindow` live at schedule time.

- [ ] **Step 5: Add the v2 migration step in `core/Database.lua`**

Replace the placeholder comment on line 53:

```lua
    -- future: if g.schemaVersion < 2 then ...upgrade...; g.schemaVersion = 2 end
```
with:
```lua
    -- v2 (§2.2/§5.1): the poll ticker became event-driven; the old poll-interval key is dead.
    -- throttleWindow is seeded by the flatDefaults backfill above, so this step only deletes the
    -- orphan. Operates on the active profile, matching the backfill's scope.
    if g.schemaVersion < 2 then
        if profile then profile.updateInterval = nil end
        g.schemaVersion = 2
    end
```

- [ ] **Step 6: Run the suite — all green**

Run: `lua tests/run.lua`
Expected: PASS — all tests pass (the schema `ValidateSchema` tests still resolve every path, now including `throttleWindow`). Suite exits 0.

- [ ] **Step 7: Lint**

Run: `luacheck .`
Expected: `0 warnings / 0 errors`.

- [ ] **Step 8: Commit**

```bash
git add defaults/Profile.lua settings/General.lua core/Database.lua tests/test_database.lua
git commit -m "$(cat <<'EOF'
Retire updateInterval for throttleWindow (schema v2 migration)

Adds the throttleWindow setting (default 0.1s) and a schemaVersion 1->2
migration that drops the orphaned updateInterval key. Prep for the
event-driven repaint path.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
EOF
)"
```

---

## Task 2: Event-driven coalescing repaint

**Files:**
- Rewrite: `modules/Timer.lua`
- Modify: `core/AbsorbTracker.lua:22-61`
- Modify: `tests/wow_mock.lua`
- Create: `tests/test_timer.lua`
- Modify: `tests/run.lua:68`

**Interfaces:**
- Consumes: `NS.addon:ScheduleTimer(fn, delaySeconds)` (AceTimer, returns a handle); `NS.GetSetting("throttleWindow")` (from Task 1); `NS.UpdateAbsorbBar()` (unchanged).
- Produces:
  - `NS.RequestRepaint()` — schedules at most one pending repaint; coalesces further calls until it fires.
  - `addon:OnMaxHealthChanged(event, unit)` — event handler; requests a repaint for `unit == "player"`.
  - Test mock additions: `mocks.__timers` (array of `{ fn = <function>, delay = <number> }` in schedule order) and `mocks.__fireTimers()` (drains and invokes them).
- Removed (no longer exist): `NS.RestartUpdateTicker`, `NS.ResetTickerInterval`.

- [ ] **Step 1: Instrument the timer mock in `tests/wow_mock.lua`**

Add a timer store + fire helper. After line 33 (the `M.wipe` line), add:

```lua
  -- Scheduled one-shot timers, recorded so tests can inspect coalescing and fire them on demand.
  M.__timers = {}
  M.__fireTimers = function()
    local due = M.__timers
    M.__timers = {}
    for _, t in ipairs(due) do t.fn() end
  end
```

Then, in the `AceAddon-3.0` `NewAddon` mock, replace the `ScheduleTimer` stub (line 75):

```lua
      target.ScheduleTimer = function() return {} end
```
with:
```lua
      target.ScheduleTimer = function(_, fn, delay)
        local timer = { fn = fn, delay = delay }
        M.__timers[#M.__timers + 1] = timer
        return timer
      end
```

Leave `ScheduleRepeatingTimer` and `CancelTimer` as they are.

- [ ] **Step 2: Register the new test suite in `tests/run.lua`**

After line 68 (`dofile("tests/test_slash.lua")`) add:

```lua
dofile("tests/test_timer.lua")
```

- [ ] **Step 3: Write the failing throttle + event-wiring tests**

Create `tests/test_timer.lua`:

```lua
local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual

-- ── Coalescing repaint scheduler (modules/Timer.lua) ──────────────────────────────
test("RequestRepaint coalesces multiple requests into one scheduled repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local calls = 0
  local orig = NS.UpdateAbsorbBar
  NS.UpdateAbsorbBar = function() calls = calls + 1 end

  NS.RequestRepaint(); NS.RequestRepaint(); NS.RequestRepaint()
  assertEqual(#mocks.__timers, 1)          -- three requests, one timer
  mocks.__fireTimers()
  assertEqual(calls, 1)                     -- fires exactly one repaint
  NS.RequestRepaint()
  assertEqual(#mocks.__timers, 1)           -- re-arms after firing
  mocks.__fireTimers()                      -- drain so `pending` resets for later tests

  NS.UpdateAbsorbBar = orig
end)

test("RequestRepaint schedules the timer at the throttleWindow delay", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.RequestRepaint()
  assertEqual(mocks.__timers[1].delay, NS.GetSetting("throttleWindow"))
  mocks.__fireTimers()
end)

-- ── Event wiring (core/AbsorbTracker.lua) ─────────────────────────────────────────
test("OnAbsorbChanged requests a repaint for the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnAbsorbChanged(nil, "player")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnAbsorbChanged ignores non-player units", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnAbsorbChanged(nil, "target")
  assertEqual(#mocks.__timers, 0)
end)

test("OnMaxHealthChanged requests a repaint for the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnMaxHealthChanged(nil, "player")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnMaxHealthChanged ignores non-player units", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnMaxHealthChanged(nil, "party1")
  assertEqual(#mocks.__timers, 0)
end)
```

- [ ] **Step 4: Run the suite to verify the new tests fail**

Run: `lua tests/run.lua`
Expected: FAIL — `attempt to call a nil value (field 'RequestRepaint')` and `(method 'OnMaxHealthChanged')`. Suite exits non-zero.

- [ ] **Step 5: Rewrite `modules/Timer.lua` as the coalescing throttle**

Replace the entire file contents with:

```lua
local addonName, NS = ...

-- Coalescing repaint scheduler (Ka0s standard §3.1 — one-shot AceTimer, same pattern as
-- settings/Widgets.lua). Repaints are event-driven (core/AbsorbTracker.lua wires the absorb /
-- max-health / world events to RequestRepaint). This trailing-edge throttle caps the repaint rate
-- to one per `throttleWindow` so a burst of UNIT_ABSORB_AMOUNT_CHANGED events during combat can't
-- cause a repaint storm. Idle = zero repaints; there is no polling fallback.

local pending

function NS.RequestRepaint()
    if pending then return end            -- a repaint is already queued; coalesce into it
    pending = NS.addon:ScheduleTimer(function()
        pending = nil
        NS.UpdateAbsorbBar()
    end, NS.GetSetting("throttleWindow"))
end
```

- [ ] **Step 6: Wire events + remove ticker call sites in `core/AbsorbTracker.lua`**

Apply these edits (line numbers from the current file):

a. In `OnEnable`, remove line 29 (`NS.RestartUpdateTicker(true)   -- force start on login`) and add a `UNIT_MAXHEALTH` registration next to the absorb one. The block becomes:

```lua
    NS.RestoreBarPosition()
    NS.UpdateBarAppearance()
    NS.UpdateAbsorbBar()

    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "OnAbsorbChanged")
    self:RegisterEvent("UNIT_MAXHEALTH", "OnMaxHealthChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
```

b. Replace `OnAbsorbChanged` (and add `OnMaxHealthChanged`) so the absorb event drives a repaint (keeping the gated debug read):

```lua
-- The absorb event drives a coalesced repaint (modules/Timer.lua). Gate the debug read so it
-- costs nothing when debug is off (§12.4).
function addon:OnAbsorbChanged(_, unit)
    if unit ~= "player" then return end
    if NS.State and NS.State.debug then
        NS.DebugPrint("UNIT_ABSORB_AMOUNT_CHANGED -",
            AbbreviateNumbers(UnitGetTotalAbsorbs("player") or 0))
    end
    NS.RequestRepaint()
end

-- The bar shows absorb as a fraction of max health, so a max-health change (buffs, stamina,
-- level) must repaint too even when the absorb value itself is unchanged.
function addon:OnMaxHealthChanged(_, unit)
    if unit == "player" then NS.RequestRepaint() end
end
```

c. In `OnEnterWorld`, route through the throttle:

```lua
function addon:OnEnterWorld()
    NS.RequestRepaint()
end
```

d. In `NS.OnProfileChanged`, remove the two ticker lines (`NS.ResetTickerInterval()` and `NS.RestartUpdateTicker(true)`) so it reads:

```lua
function NS.OnProfileChanged()
    NS.RestoreBarPosition()
    NS.UpdateBarAppearance()
    NS.UpdateAbsorbBar()
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end
```

- [ ] **Step 7: Syntax-check the two rewritten files**

Run: `luac -p modules/Timer.lua && luac -p core/AbsorbTracker.lua`
Expected: no output (both parse clean).

- [ ] **Step 8: Run the suite — all green**

Run: `lua tests/run.lua`
Expected: PASS — all tests pass, including the six new timer/event tests. Suite exits 0.

- [ ] **Step 9: Lint**

Run: `luacheck .`
Expected: `0 warnings / 0 errors`.

- [ ] **Step 10: Commit**

```bash
git add modules/Timer.lua core/AbsorbTracker.lua tests/wow_mock.lua tests/test_timer.lua tests/run.lua
git commit -m "$(cat <<'EOF'
Make absorb-bar repaint event-driven with a coalescing throttle

Repaint on UNIT_ABSORB_AMOUNT_CHANGED + UNIT_MAXHEALTH +
PLAYER_ENTERING_WORLD via a trailing-edge one-shot AceTimer throttle.
Removes the fixed-interval poll ticker (RestartUpdateTicker /
ResetTickerInterval) and all its call sites. Idle = zero repaints.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
EOF
)"
```

---

## Task 3: Sync docs + test-count references

**Files:**
- Modify: `docs/data-flow.md`, `docs/ARCHITECTURE.md`, `docs/schema.md`, `docs/settings-panel.md`
- Modify (test count only): `CLAUDE.md`, `docs/agent-context.md`, `docs/module-map.md`, `docs/common-tasks.md`, `docs/file-index.md`
- Sweep for stale ticker/`updateInterval` references: `docs/scope.md`, `docs/profiles.md`, `docs/smoke-tests.md`, `docs/midnight-quirks.md`
- **Do not touch** `docs/audits/**` or `docs/reviews/**`.

**Interfaces:**
- Consumes: the implemented behavior from Tasks 1–2 and the real test total printed by the suite.
- Produces: docs that describe the event-driven repaint path, the `throttleWindow` setting, and the correct test count. No code.

- [ ] **Step 1: Capture the real test total**

Run: `lua tests/run.lua`
Expected: PASS. Read the final line, e.g. `N passed, 0 failed, N total`. Use that `N` verbatim in Step 3 — do not guess.

- [ ] **Step 2: Find every stale reference**

Run:
```bash
grep -rn "updateInterval\|Update Interval\|RestartUpdateTicker\|ResetTickerInterval\|repeating ticker\|poll\|43 tests\|(43" docs/ CLAUDE.md | grep -v -e docs/audits/ -e docs/reviews/ -e docs/superpowers/
```
Expected: a list of lines in the target docs. Each must be reconciled in Step 3.

- [ ] **Step 3: Update the docs**

For each target doc, make the content match reality:

- **`docs/data-flow.md`** — replace any "repaint every `updateInterval` / repeating ticker" description with the event-driven flow:
  > `UNIT_ABSORB_AMOUNT_CHANGED` / `UNIT_MAXHEALTH` / `PLAYER_ENTERING_WORLD` → `NS.RequestRepaint()` → trailing-edge one-shot AceTimer (`throttleWindow`, default 0.1s, coalesces bursts) → `NS.UpdateAbsorbBar()`. Login and profile-change paint `UpdateAbsorbBar` directly. No polling ticker; idle = zero repaints.
- **`docs/ARCHITECTURE.md`** — in the event-wiring section add `UNIT_MAXHEALTH → OnMaxHealthChanged`; note `OnAbsorbChanged` now calls `RequestRepaint`; in the settings-schema section rename `updateInterval` → `throttleWindow` (number, default 0.1, 0.05–1); remove the `modules/Timer.lua` "repeating ticker" description and replace with "coalescing repaint scheduler (`NS.RequestRepaint`)". Remove mentions of `RestartUpdateTicker`/`ResetTickerInterval`.
- **`docs/schema.md`** — rename the `updateInterval` row to `throttleWindow` with the new label ("Update throttle (in sec)"), default 0.1, range 0.05–1 step 0.05.
- **`docs/settings-panel.md`** — update the Performance-group control from "Update Interval" to "Update throttle" with its new description.
- **`docs/module-map.md`, `docs/file-index.md`, `docs/common-tasks.md`** — update the `modules/Timer.lua` one-line description from a poll ticker to the coalescing repaint scheduler; update the `43 tests` count to `N`.
- **`CLAUDE.md`, `docs/agent-context.md`** — update the `43 tests` count to `N`.
- **`docs/scope.md`, `docs/profiles.md`, `docs/smoke-tests.md`, `docs/midnight-quirks.md`** — only edit if the Step-2 grep flagged a stale `updateInterval`/ticker reference; reword to the event-driven model. In `docs/smoke-tests.md`, if there is a manual test for the update interval, replace it with: "shield gain/loss repaints the bar within ~0.1s; sitting idle with no shield produces no repaints."

- [ ] **Step 4: Verify no stale references remain**

Run:
```bash
grep -rn "updateInterval\|RestartUpdateTicker\|ResetTickerInterval\|repeating ticker\|43 tests" docs/ CLAUDE.md | grep -v -e docs/audits/ -e docs/reviews/ -e docs/superpowers/
```
Expected: no output (all live docs reconciled; frozen bundles and specs excluded).

- [ ] **Step 5: Confirm the green gate is still clean**

Run: `lua tests/run.lua && luacheck .`
Expected: suite passes (exit 0) and `0 warnings / 0 errors`. (Docs-only task — this just confirms nothing regressed.)

- [ ] **Step 6: Commit**

```bash
git add docs/ CLAUDE.md
git commit -m "$(cat <<'EOF'
Sync docs to the event-driven repaint model

Update data-flow / ARCHITECTURE / schema / settings-panel and the
Timer.lua description to the coalescing throttle; rename updateInterval
-> throttleWindow; refresh the test count.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- Event-driven + throttle (spec §Architecture, decision 1/2) → Task 2 (Timer.lua + AbsorbTracker wiring).
- `UNIT_MAXHEALTH` freshness (spec §3) → Task 2 Step 6b, tested Task 2 Step 3.
- Single `throttleWindow` setting (spec decision 3, §4) → Task 1 Steps 3–4.
- No backup ticker (spec §Goal / decision 1) → Task 2 removes ticker entirely; no repeating timer scheduled.
- schemaVersion 1→2 migration dropping `updateInterval` (spec §5) → Task 1 Step 5, tested Step 1.
- `throttleWindow` seeded via backfill (spec §5) → Task 1 Step 5 comment + "backfills throttleWindow" test.
- Immediate login/profile paint stays direct (spec §Architecture) → Task 2 Step 6a/6d keep `NS.UpdateAbsorbBar()`.
- Tests: coalescing + migration + schema-rename resolution (spec §Testing) → Task 1 + Task 2 tests.
- Docs (spec §Docs) → Task 3.
- Standards no-deviation (spec §7) → §3.1 one-shot AceTimer only; §2.2/§5.1 migration seam. Global Constraints enforce it.

**Placeholder scan:** none — every code and test step shows complete content; the only deliberately deferred value is the test total `N` in Task 3, which Step 1 instructs the implementer to read from the suite output (not guessable ahead of run).

**Type consistency:** `NS.RequestRepaint()` (no args), `addon:OnMaxHealthChanged(_, unit)`, `addon:OnAbsorbChanged(_, unit)`, `NS.GetSetting("throttleWindow")`, and the mock's `mocks.__timers` (`{fn, delay}`) / `mocks.__fireTimers()` are used identically in Timer.lua, AbsorbTracker.lua, the mock, and the tests. `RestartUpdateTicker`/`ResetTickerInterval` are removed in the same task (Task 2) that removes their call sites — no dangling reference across tasks.
