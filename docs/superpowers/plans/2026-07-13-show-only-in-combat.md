# "Show only in combat" Visibility — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `showOnlyInCombat` toggle (default off) that hides the absorb bar out of combat and shows it in combat (issue #13).

**Architecture:** A `NS.ShouldShowBar()` predicate composes the master `hidden` toggle with the new combat gate; `NS.ApplyVisibility()` applies it. `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED` re-apply visibility on combat transitions, and `OnLeaveCombat` becomes the single owner of `PLAYER_REGEN_ENABLED` (draining the combat-deferred `/at config` flag) to avoid an AceEvent single-handler-per-event collision.

**Tech Stack:** Lua, Ace3 (AceAddon/AceEvent), AceDB schema, headless Lua test harness (`tests/run.lua`), luacheck.

## Global Constraints

- **Standard:** Ka0s WoW Addon Standard — no deviation. Combat events via AceEvent (`self:RegisterEvent`), never a raw event frame (library-stack-§1/architecture-§2). Settings are schema rows through the existing registry. The options-ui-§2 combat-deferred-config-open contract must be preserved (opens on combat end, idempotent).
- **Green gate before every commit:** `lua tests/run.lua` (all pass, exit 0) **and** `luacheck .` (0 warnings / 0 errors). Syntax-check a file with `luac -p <file>`.
- **Default is `false`** — behavior with the toggle off must be byte-for-byte today's behavior.
- **`hidden` is the master toggle** — it always wins over `showOnlyInCombat`.
- **The bar is a plain non-secure `Frame`** — `Show()`/`Hide()` in combat is taint-free; do not add secure-frame handling.
- **No `schemaVersion` bump** — the new key is additive and seeded by the existing `RunMigrations` v1 `flatDefaults` backfill. **Never** bump the addon version (TOC/README). **Never** auto-stage/commit/push beyond this plan's commit steps.
- **Commit trailer** on every commit:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
  ```

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `defaults/Profile.lua` | Modify | Add `showOnlyInCombat = false` default. |
| `settings/General.lua` | Modify | Add the `showOnlyInCombat` schema row (Master controls, order 15). |
| `modules/Display.lua` | Modify | Add `NS.ShouldShowBar()` / `NS.ApplyVisibility()`; rewire `UpdateBarAppearance` + `UpdateAbsorbBar` guard through them. |
| `core/AbsorbTracker.lua` | Modify | Register `PLAYER_REGEN_DISABLED`/`ENABLED`; add `OnEnterCombat`/`OnLeaveCombat`; add `ApplyVisibility` to `OnEnterWorld`. |
| `settings/Panel.lua` | Modify | `OpenOptionsPanel` in-combat branch sets the pending flag only (no event registration). |
| `tests/test_visibility.lua` | Create | `ShouldShowBar` truth table + combat-handler tests. |
| `tests/run.lua` | Modify | `dofile("tests/test_visibility.lua")`. |
| Docs (Task 3) | Modify | README + `docs/*.md` + counts. |

---

## Task 1: The setting + visibility resolution

**Files:**
- Modify: `defaults/Profile.lua:26` (after `throttleWindow`)
- Modify: `settings/General.lua:39-40` (between the `hidden` and `locked` rows)
- Modify: `modules/Display.lua:50-55` and `:64-67`
- Create: `tests/test_visibility.lua`
- Modify: `tests/run.lua`

**Interfaces:**
- Consumes: `NS.GetSetting` / `NS.SetSetting`, `InCombatLockdown()`, `NS.bar`.
- Produces:
  - `NS.ShouldShowBar()` → boolean. `false` if `hidden`; else `false` if `showOnlyInCombat` and not `InCombatLockdown()`; else `true`.
  - `NS.ApplyVisibility()` → `NS.bar:Show()` when `ShouldShowBar()`, else `NS.bar:Hide()`.
  - profile setting `showOnlyInCombat` (bool, default `false`).

- [ ] **Step 1: Register the new test suite in `tests/run.lua`**

After the `dofile("tests/test_timer.lua")` line, add:

```lua
dofile("tests/test_visibility.lua")
```

- [ ] **Step 2: Write the failing `ShouldShowBar` truth-table tests**

Create `tests/test_visibility.lua`:

```lua
local T = _G.AT_TEST
local NS = T.NS
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

-- Run `body` with specific hidden / showOnlyInCombat / in-combat state, then restore everything.
-- The loader binds WoW globals live through the mock table, so swapping mocks.InCombatLockdown is
-- seen by addon code (same pattern as tests/test_slash.lua).
local function withState(hidden, combatOnly, inCombat, body)
  local savedHidden     = NS.GetSetting("hidden")
  local savedCombatOnly = NS.GetSetting("showOnlyInCombat")
  local savedICL        = T.mocks.InCombatLockdown
  NS.SetSetting("hidden", hidden)
  NS.SetSetting("showOnlyInCombat", combatOnly)
  T.mocks.InCombatLockdown = function() return inCombat end
  local ok, err = pcall(body)
  NS.SetSetting("hidden", savedHidden)
  NS.SetSetting("showOnlyInCombat", savedCombatOnly)
  T.mocks.InCombatLockdown = savedICL
  if not ok then error(err) end
end

test("ShouldShowBar: hidden master toggle wins even in combat", function()
  withState(true, false, true, function()
    assertFalse(NS.ShouldShowBar(), "hidden=true is never shown")
  end)
end)

test("ShouldShowBar: default (not hidden, not combat-only) is shown", function()
  withState(false, false, false, function()
    assertTrue(NS.ShouldShowBar(), "default visibility is shown")
  end)
end)

test("ShouldShowBar: combat-only + in combat is shown", function()
  withState(false, true, true, function()
    assertTrue(NS.ShouldShowBar(), "showOnlyInCombat + in combat -> shown")
  end)
end)

test("ShouldShowBar: combat-only + out of combat is hidden", function()
  withState(false, true, false, function()
    assertFalse(NS.ShouldShowBar(), "showOnlyInCombat + out of combat -> hidden")
  end)
end)
```

- [ ] **Step 3: Run the suite to verify the new tests fail**

Run: `lua tests/run.lua`
Expected: FAIL — `attempt to call a nil value (field 'ShouldShowBar')`. Suite exits non-zero.

- [ ] **Step 4: Add the `showOnlyInCombat` default in `defaults/Profile.lua`**

Change the `throttleWindow` line (line 26):

```lua
    throttleWindow = 0.1,
```
to:
```lua
    throttleWindow = 0.1,
    showOnlyInCombat = false,
```

- [ ] **Step 5: Add `ShouldShowBar` / `ApplyVisibility` and rewire the paint paths in `modules/Display.lua`**

Replace the `UpdateBarAppearance` visibility block (lines 50–54):

```lua
    if NS.GetSetting("hidden") then
        bar:Hide()
    else
        bar:Show()
    end
```
with:
```lua
    NS.ApplyVisibility()
```

Change the `UpdateAbsorbBar` early-return guard (lines 64–67):

```lua
    if NS.GetSetting("hidden") then
        NS.DebugPrint("UpdateAbsorbBar", "Skipped: bar is hidden")
        return
    end
```
to:
```lua
    if not NS.ShouldShowBar() then
        NS.DebugPrint("UpdateAbsorbBar", "Skipped: bar not visible")
        return
    end
```

Add the two functions immediately above `function NS.UpdateAbsorbBar()` (i.e. after the `end` closing `UpdateBarAppearance`, before the `-- Repaint the absorb value.` comment):

```lua
-- Effective bar visibility. The `hidden` master toggle wins; then the combat gate. The bar is a
-- plain (non-secure) frame, so Show/Hide is taint-free even mid-combat.
function NS.ShouldShowBar()
    if NS.GetSetting("hidden") then return false end
    if NS.GetSetting("showOnlyInCombat") and not InCombatLockdown() then return false end
    return true
end

function NS.ApplyVisibility()
    if NS.ShouldShowBar() then NS.bar:Show() else NS.bar:Hide() end
end
```

- [ ] **Step 6: Add the schema row in `settings/General.lua`**

Insert this row between the `hidden` row (its closing `},`) and the `locked` row (`{ path = "locked", ...`):

```lua
    {
        path    = "showOnlyInCombat",
        page    = "general",
        group   = "Master controls",
        order   = 15,
        type    = "bool",
        label   = "Show only in combat",
        desc    = "When on, the bar is hidden except while you're in combat.",
        default = flatDefaults.showOnlyInCombat,
        onChange = function()
            NS.ApplyVisibility()
            if NS.ShouldShowBar() then NS.UpdateAbsorbBar() end
        end,
    },
```

- [ ] **Step 7: Run the suite — all green**

Run: `lua tests/run.lua`
Expected: PASS — all tests pass, including the four new `ShouldShowBar` tests and the existing `ValidateSchema` tests (which now resolve `showOnlyInCombat` against defaults). Suite exits 0.

- [ ] **Step 8: Syntax + lint**

Run: `luac -p modules/Display.lua && luac -p settings/General.lua && luacheck .`
Expected: clean parse; `0 warnings / 0 errors`.

- [ ] **Step 9: Commit**

```bash
git add defaults/Profile.lua settings/General.lua modules/Display.lua tests/test_visibility.lua tests/run.lua
git commit -m "$(cat <<'EOF'
Add showOnlyInCombat setting + bar visibility resolution

New showOnlyInCombat toggle (default off). NS.ShouldShowBar composes the
hidden master toggle with the combat gate; NS.ApplyVisibility applies it,
and UpdateBarAppearance / UpdateAbsorbBar now route through them.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
EOF
)"
```

---

## Task 2: Combat wiring + deferred-config centralization

**Files:**
- Modify: `core/AbsorbTracker.lua` (`OnEnable`, `OnEnterWorld`, new `OnEnterCombat`/`OnLeaveCombat`)
- Modify: `settings/Panel.lua` (`OpenOptionsPanel` in-combat branch)
- Modify: `tests/test_visibility.lua` (append combat-handler tests)

**Interfaces:**
- Consumes: `NS.ApplyVisibility` / `NS.ShouldShowBar` (Task 1), `NS.RequestRepaint`, `NS.OpenOptionsPanel`, `NS.State.panelOpenPending`, `InCombatLockdown()`.
- Produces:
  - `addon:OnEnterCombat(event)` — `ApplyVisibility()` + `RequestRepaint()`.
  - `addon:OnLeaveCombat(event)` — `ApplyVisibility()` + `RequestRepaint()` + drains `NS.State.panelOpenPending` via `NS.OpenOptionsPanel()`.
  - `OpenOptionsPanel` in-combat branch sets `NS.State.panelOpenPending = true` (no event registration).

- [ ] **Step 1: Append the failing combat-handler tests to `tests/test_visibility.lua`**

Add at the end of `tests/test_visibility.lua`:

```lua
local assertEqual = T.assertEqual

-- ── Combat wiring (core/AbsorbTracker.lua) ──────────────────────────────────────────
test("OnEnterCombat applies visibility and requests a repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local applied = 0
  local origApply = NS.ApplyVisibility
  NS.ApplyVisibility = function() applied = applied + 1 end
  NS.addon:OnEnterCombat()
  assertEqual(applied, 1)
  assertEqual(#mocks.__timers, 1)   -- a repaint was requested
  NS.ApplyVisibility = origApply
  mocks.__fireTimers()
end)

test("OnLeaveCombat replays a pending deferred config open and clears the flag", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local opened = 0
  local origOpen, origApply = NS.OpenOptionsPanel, NS.ApplyVisibility
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  NS.ApplyVisibility = function() end
  NS.State.panelOpenPending = true
  NS.addon:OnLeaveCombat()
  assertEqual(opened, 1)
  assertTrue(NS.State.panelOpenPending == nil, "pending flag is cleared")
  NS.OpenOptionsPanel, NS.ApplyVisibility = origOpen, origApply
  mocks.__fireTimers()
end)

test("OnLeaveCombat does not open config when none is pending", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local opened = 0
  local origOpen, origApply = NS.OpenOptionsPanel, NS.ApplyVisibility
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  NS.ApplyVisibility = function() end
  NS.State.panelOpenPending = nil
  NS.addon:OnLeaveCombat()
  assertEqual(opened, 0)
  NS.OpenOptionsPanel, NS.ApplyVisibility = origOpen, origApply
  mocks.__fireTimers()
end)
```

- [ ] **Step 2: Run the suite to verify the new tests fail**

Run: `lua tests/run.lua`
Expected: FAIL — `attempt to call a nil value (method 'OnEnterCombat')`. Suite exits non-zero.

- [ ] **Step 3: Wire combat events + handlers in `core/AbsorbTracker.lua`**

In `OnEnable`, after the `PLAYER_ENTERING_WORLD` registration (line 32), add:

```lua
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
```

Change `OnEnterWorld` (lines 55–57) to apply visibility first:

```lua
function addon:OnEnterWorld()
    NS.ApplyVisibility()
    NS.RequestRepaint()
end
```

Add the two combat handlers immediately after `OnEnterWorld` (before the `NS.OnProfileChanged` comment):

```lua
-- Combat transitions re-evaluate bar visibility (the `showOnlyInCombat` gate) and repaint so the
-- bar is fresh if it just appeared. OnLeaveCombat is also the single owner of PLAYER_REGEN_ENABLED:
-- it replays a combat-deferred /at config (settings/Panel.lua sets the flag), which keeps AceEvent's
-- one-handler-per-event rule from colliding with the visibility handler.
function addon:OnEnterCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
end

function addon:OnLeaveCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
    if NS.State and NS.State.panelOpenPending then
        NS.State.panelOpenPending = nil
        if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
    end
end
```

- [ ] **Step 4: Simplify the deferred-open in `settings/Panel.lua`**

Replace the in-combat branch of `NS.OpenOptionsPanel` (the `if InCombatLockdown() then ... return end` block, currently lines 112–123):

```lua
    if InCombatLockdown() then
        if not NS.State.panelOpenPending then
            NS.State.panelOpenPending = true
            NS.addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                NS.addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
                NS.State.panelOpenPending = nil
                NS.OpenOptionsPanel()
            end)
            print("In combat \226\128\148 settings will open when you leave combat.")
        end
        return
    end
```
with:
```lua
    if InCombatLockdown() then
        -- Settings UI is protected during combat; opening it taints the panel for the session.
        -- Per Ka0s standard options-ui-§2, queue the open and let core/AbsorbTracker.lua's OnLeaveCombat
        -- (the single owner of PLAYER_REGEN_ENABLED) replay it. The flag makes it idempotent —
        -- hammering /at config mid-pull queues exactly one open.
        if not NS.State.panelOpenPending then
            NS.State.panelOpenPending = true
            print("In combat \226\128\148 settings will open when you leave combat.")
        end
        return
    end
```

(Adjust the now-stale comment block above the function accordingly if it references the one-shot registration.)

- [ ] **Step 5: Run the suite — all green**

Run: `lua tests/run.lua`
Expected: PASS — the three new combat tests pass, and the existing `test_slash.lua` combat-defer test still passes (it asserts the flag + message + idempotency, all preserved). Suite exits 0.

- [ ] **Step 6: Syntax + lint**

Run: `luac -p core/AbsorbTracker.lua && luac -p settings/Panel.lua && luacheck .`
Expected: clean parse; `0 warnings / 0 errors`.

- [ ] **Step 7: Commit**

```bash
git add core/AbsorbTracker.lua settings/Panel.lua tests/test_visibility.lua
git commit -m "$(cat <<'EOF'
Wire combat transitions to bar visibility; centralize deferred config

Register PLAYER_REGEN_DISABLED/ENABLED so the showOnlyInCombat gate
re-applies on combat transitions. OnLeaveCombat is now the single owner of
PLAYER_REGEN_ENABLED and replays a combat-deferred /at config from a flag,
avoiding the AceEvent one-handler-per-event collision.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
EOF
)"
```

---

## Task 3: Docs sync

**Files:**
- Modify: `README.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/scope.md`, `docs/data-flow.md`
- Modify (counts): `CLAUDE.md`, `docs/agent-context.md`, `docs/common-tasks.md`, `docs/module-map.md`, `docs/file-index.md`
- **Do not touch** `docs/audits/**`, `docs/reviews/**`, `docs/superpowers/**`. **No version bump.**

**Interfaces:**
- Consumes: the implemented behavior from Tasks 1–2 and the real test total printed by the suite.
- Produces: docs describing the `showOnlyInCombat` toggle, the combat-visibility flow, and the correct test count. No code.

- [ ] **Step 1: Capture the real test total**

Run: `lua tests/run.lua`
Expected: PASS. Read the final `N passed, 0 failed, N total` line; use `N` verbatim in Step 3 (do not guess — Tasks 1–2 added seven tests to the prior 53).

- [ ] **Step 2: Find stale references**

Run:
```bash
grep -rn "53 tests\|53 passed\|(53\|showOnlyInCombat\|show only in combat\|update throttle" CLAUDE.md README.md docs/ | grep -v -e docs/audits/ -e docs/reviews/ -e docs/superpowers/
```
Expected: the current `53` count references (to update to `N`) and any existing combat-visibility mentions.

- [ ] **Step 3: Update the docs**

- **`README.md`**
  - General-panel bullet — add the new control: "Show Bar, **show only in combat**, drag lock, update throttle (0.05–1s), …".
  - Testing table — `53 passed` → `N passed`, and add "combat-visibility" to the suite description.
  - Add a FAQ or Troubleshooting row: *"Why does my bar disappear out of combat?"* → "You have **Show only in combat** enabled (General panel, or `/at set showOnlyInCombat false`). The master **Show Bar** toggle still hides it entirely."
  - **Do not** add a Version History row and **do not** change the version.
- **`docs/schema.md`** — add a `showOnlyInCombat` row (bool, default `false`, General page, Master controls, order 15, label "Show only in combat", `onChange` applies visibility).
- **`docs/settings-panel.md`** — note the Master controls layout: `[Show Bar] [Show only in combat]` / `[Lock Position]` / button pair.
- **`docs/scope.md`** — visibility model: two composing inputs (`hidden` master wins; `showOnlyInCombat` gates on `InCombatLockdown()`).
- **`docs/data-flow.md`** — `PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED` → `OnEnterCombat`/`OnLeaveCombat` → `ApplyVisibility` + `RequestRepaint`; note `OnLeaveCombat` owns `PLAYER_REGEN_ENABLED` and replays the deferred `/at config`.
- **`CLAUDE.md`, `docs/agent-context.md`, `docs/common-tasks.md`, `docs/module-map.md`, `docs/file-index.md`** — update the `53` test count to `N`. In `file-index.md`, add a row for `tests/test_visibility.lua` (its line count via `wc -l`, "7 tests — ShouldShowBar truth table + combat-handler wiring"), and correct the line counts for `modules/Display.lua`, `core/AbsorbTracker.lua`, `settings/General.lua`, `settings/Panel.lua`, `defaults/Profile.lua` (use `wc -l` on each). In `module-map.md`'s Test-harness paragraph, add `test_visibility.lua` to the enumerated suite list.

- [ ] **Step 4: Verify no stale count/reference remains**

Run:
```bash
grep -rn "53 tests\|53 passed" CLAUDE.md README.md docs/ | grep -v -e docs/audits/ -e docs/reviews/ -e docs/superpowers/
```
Expected: no output.

- [ ] **Step 5: Confirm the green gate is still clean**

Run: `lua tests/run.lua && luacheck .`
Expected: suite passes (exit 0); `0 warnings / 0 errors`. (Docs-only task — confirms nothing regressed.)

- [ ] **Step 6: Commit**

```bash
git add README.md CLAUDE.md docs/
git commit -m "$(cat <<'EOF'
Docs: document the show-only-in-combat visibility toggle

Update README General panel + FAQ, schema / settings-panel / scope /
data-flow, and the test count and file index for the new
tests/test_visibility.lua suite.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PcWTCf2c84PTVyE37tqyfS
EOF
)"
```

---

## Self-Review

**Spec coverage:**
- `showOnlyInCombat` setting, default off, Master controls order 15 (spec §1) → Task 1 Steps 4/6.
- `ShouldShowBar`/`ApplyVisibility` composition + paint rewiring (spec §2) → Task 1 Step 5, tested Step 2.
- Combat events + handlers + `OnEnterWorld` (spec §3) → Task 2 Step 3, tested Step 1.
- Deferred-config centralization / AceEvent collision fix (spec §4) → Task 2 Steps 3–4, tested by the OnLeaveCombat drain test + the preserved `test_slash.lua` combat test.
- Additive migration, no schemaVersion bump (spec §5) → Task 1 Step 4 (backfill seeds it; no migration step).
- Panel layout `[Show Bar][Show only in combat]` / `[Lock]` / buttons (spec §1) → order 15 + verified `Widgets.lua` pairing; asserted structurally, documented in Task 3.
- Tests (spec §7) → Task 1 + Task 2 suites in `tests/test_visibility.lua`.
- Docs (spec §8) → Task 3.
- Standards no-deviation (spec §Standards) → Global Constraints.

**Placeholder scan:** none — every code/test step shows complete content; the only deferred value is the test total `N` (Task 3 Step 1 reads it from the suite output) and per-file line counts (Task 3 Step 3 computes them with `wc -l`), neither guessable ahead of run.

**Type consistency:** `NS.ShouldShowBar()` (no args → bool), `NS.ApplyVisibility()` (no args), `addon:OnEnterCombat()` / `addon:OnLeaveCombat()`, `NS.State.panelOpenPending`, `NS.OpenOptionsPanel()`, and setting path `showOnlyInCombat` are used identically across `Display.lua`, `AbsorbTracker.lua`, `Panel.lua`, `General.lua`, and the tests. `OnLeaveCombat` (the new owner of `PLAYER_REGEN_ENABLED`) and the `Panel.lua` flag-set land in the same task (Task 2), so there is no window where the deferred-open is broken.
