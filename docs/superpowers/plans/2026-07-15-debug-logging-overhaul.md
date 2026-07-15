# Debug-Logging Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring AbsorbTracker's debug logging in line with Ka0s debug-logging §8 (coverage), §9 (coalescing), §10 (settings), on one secret-safe sink.

**Architecture:** AT's debug *infrastructure* (console, formatters, `HH:MM:SS | [tag] msg` format, `/at debug` verb) already conforms and is untouched. This plan (a) makes the canonical sink `NS.Debug` secret-safe and retires the redundant `NS.DebugPrint`; (b) adds one gated log line at each key functional flow; (c) replaces the two per-event/per-repaint hot-path logs with combat-session counters flushed as one rollup, plus non-secret value transitions.

**Tech Stack:** Lua 5.1 (WoW), AceAddon/AceEvent/AceTimer/AceDB, headless test harness (`lua tests/run.lua`), `luacheck`.

## Global Constraints

- **Debug format (verbatim):** `<HH:MM:SS> | [<Tag>] <content>` — already produced by `DebugLog.FormatPlain`/`FormatColored`; do not change.
- **Sink signature:** `NS.Debug(tag, fmt, ...)` — gate `if not (NS.State and NS.State.debug) then return end` is the FIRST line (zero-alloc when off). Format strings are `%s`-only; every vararg passes through `NS.SafeToString`.
- **Tags:** short Titlecase single words — `Init`, `Set`, `Combat`, `Bar`, `Absorb`, `World`, `Profile`, `Cfg`, `Migrate`, `Debug`.
- **Secret-safety:** never compare/branch on a value that may be a combat "secret" without first checking `NS.IsConcatSafe(v)` (true = plain/readable, false = secret → skip the compare). Every logged arg still funnels through `NS.SafeToString`.
- **§9 coalescing:** no per-event / per-repaint / per-tick log lines. Counter maintenance and summary string-building live behind the debug-on gate.
- **§10 settings:** log every mutation once at the `NS.SetByPath` seam as `[Set] <path> = <value>`; no downstream re-echo.
- **Green gate every commit:** `lua tests/run.lua` (all pass), `luacheck .` (0/0), `luac -p <changed>.lua`.
- **No version bump. No new SavedVariables.**

---

## File Structure

- `core/DebugLog.lua` — `NS.Debug` becomes secret-safe (Task 1).
- `core/Util.lua` — `NS.DebugPrint` removed (Task 1).
- `settings/Schema.lua` — `[Set]` line in `SetByPath` (Task 2).
- `core/AbsorbTracker.lua` — `[Init]`, `[World]`, `[Profile]` (Task 3); `[Combat]` counters/rollup + `[Absorb]` transitions (Task 4).
- `settings/Panel.lua` — `[Cfg]` opened/refused (Task 3).
- `core/Database.lua` — `[Migrate]` when a migration runs (Task 3).
- `modules/Display.lua` — drop per-repaint logs; `NS.NoteRepaint()`; `[Bar]` transition (Task 4).
- `tests/test_util.lua`, `tests/test_debuglog.lua`, `tests/test_slash.lua`, `tests/test_visibility.lua` — updated/added coverage per task.
- Docs (Task 5).

---

## Task 1: Secret-safe `NS.Debug` sink; retire `NS.DebugPrint`

**Files:**
- Modify: `core/DebugLog.lua` (the `NS.Debug` function, ~lines 252-257)
- Modify: `core/Util.lua` (remove `NS.DebugPrint`, ~lines 50-62)
- Modify: `core/AbsorbTracker.lua:73-76` and `modules/Display.lua:80-99` (convert the 3 `NS.DebugPrint` call sites to `NS.Debug`)
- Test: `tests/test_util.lua` (rewrite the DebugPrint test), `tests/test_debuglog.lua`

**Interfaces:**
- Produces: `NS.Debug(tag, fmt, ...)` — secret-safe; every vararg through `NS.SafeToString`; `%s`-only format strings; appends via `NS.DebugLog:Add`.
- Removes: `NS.DebugPrint` (no longer exists after this task).

- [ ] **Step 1: Rewrite the sink test** in `tests/test_util.lua` — replace the `"DebugPrint routes the first arg…"` test with:

```lua
test("NS.Debug routes the first arg as the [tag] and tolerates a secret arg", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  local ok = pcall(NS.Debug, "Absorb", "value=%s", secretMock)
  NS.State.debug = false
  assertTrue(ok, "NS.Debug must not raise on a secret arg")
  assertTrue(#NS.DebugLog.buffer > before, "a console line should still be appended")
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(last:find("[Absorb]", 1, true) ~= nil, "the first arg is the console [tag]")
  assertTrue(last:find("value=<secret>", 1, true) ~= nil, "a secret arg renders as <secret>")
end)

test("NS.Debug is a no-op when debug is off", function()
  NS.State.debug = false
  local before = #NS.DebugLog.buffer
  NS.Debug("Absorb", "value=%s", 123)
  assertEqual(#NS.DebugLog.buffer, before)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `lua tests/run.lua`
Expected: FAIL — current `NS.Debug` calls `fmt:format(...)` on the raw secret and raises (or the format lacks SafeToString), and `NS.DebugPrint` test may still reference the old function.

- [ ] **Step 3: Make `NS.Debug` secret-safe** — in `core/DebugLog.lua`, replace the `NS.Debug` body with:

```lua
-- Global debug sink (Ka0s debug-logging §4). Zero-alloc when off. Every vararg passes through
-- NS.SafeToString so a combat "secret" (absorb total) logs as <secret> instead of raising in
-- string.format — so call sites use %s for every placeholder.
function NS.Debug(tag, fmt, ...)
    if not (NS.State and NS.State.debug) then return end
    local n = select("#", ...)
    local msg = fmt
    if n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
        msg = fmt:format(unpack(parts))
    end
    D:Add(tag, msg)
end
```

- [ ] **Step 4: Remove `NS.DebugPrint`** — in `core/Util.lua`, delete the entire `NS.DebugPrint` function (the block from its doc-comment through `end`, ~lines 50-62). Leave `NS.SafeToString`, `NS.IsConcatSafe`, `NS.Print`, `Util.print` intact.

- [ ] **Step 5: Convert the 3 call sites to `NS.Debug`** so the addon still loads (these are refactored further in Tasks 3-4):

In `core/AbsorbTracker.lua` `OnAbsorbChanged` (~line 73-76), replace the `NS.DebugPrint(...)` call with:
```lua
        NS.Debug("Absorb", "value=%s", AbbreviateNumbers(UnitGetTotalAbsorbs("player") or 0))
```
In `modules/Display.lua` `UpdateAbsorbBar` (~line 80-81), replace the skipped-line `NS.DebugPrint(...)` with:
```lua
        NS.Debug("Bar", "repaint skipped: not visible")
```
In `modules/Display.lua` (~line 96-99), replace the absorb `NS.DebugPrint(...)` block with:
```lua
    if NS.State and NS.State.debug then
        NS.Debug("Absorb", "paint %s / %s", AbbreviateNumbers(totalAbsorb), AbbreviateNumbers(maxHealth))
    end
```

- [ ] **Step 6: Run tests + lint + syntax**

Run: `lua tests/run.lua && luacheck . && luac -p core/DebugLog.lua core/Util.lua core/AbsorbTracker.lua modules/Display.lua`
Expected: all tests PASS; luacheck `0 warnings / 0 errors`; luac silent.

- [ ] **Step 7: Commit**

```bash
git add core/DebugLog.lua core/Util.lua core/AbsorbTracker.lua modules/Display.lua tests/test_util.lua
git commit -m "Debug: make NS.Debug sink secret-safe; retire NS.DebugPrint"
```

---

## Task 2: `[Set]` logging at the `SetByPath` seam (§10)

**Files:**
- Modify: `settings/Schema.lua` (`NS.SetByPath`, ~lines 93-98)
- Test: `tests/test_slash.lua`

**Interfaces:**
- Consumes: `NS.Debug`, `NS.FindSchemaRow(path)`, `NS.FormatSchemaValue(row, v)` (existing).

- [ ] **Step 1: Write the failing test** in `tests/test_slash.lua`:

```lua
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
```

- [ ] **Step 2: Run to verify failure**

Run: `lua tests/run.lua`
Expected: FAIL — no `[Set]` line is emitted.

- [ ] **Step 3: Add the log line** — in `settings/Schema.lua`, change `NS.SetByPath` to:

```lua
function NS.SetByPath(path, value)
    NS.SetSetting(path, value)
    local row = NS.FindSchemaRow(path)
    -- §10: log every settings mutation once, at this single write seam.
    NS.Debug("Set", "%s = %s", path, row and NS.FormatSchemaValue(row, value) or tostring(value))
    if row then fireOnChange(row, value) end
end
```

- [ ] **Step 4: Run tests**

Run: `lua tests/run.lua && luacheck . && luac -p settings/Schema.lua`
Expected: PASS; 0/0; silent.

- [ ] **Step 5: Commit**

```bash
git add settings/Schema.lua tests/test_slash.lua
git commit -m "Debug: log [Set] path = value at the SetByPath seam (§10)"
```

---

## Task 3: Lifecycle / config / migration / profile coverage (§8)

**Files:**
- Modify: `core/AbsorbTracker.lua` (`OnEnable`, `OnEnterWorld`, `NS.OnProfileChanged`)
- Modify: `settings/Panel.lua` (`NS.OpenOptionsPanel`)
- Modify: `core/Database.lua` (`NS:RunMigrations`)
- Test: `tests/test_slash.lua` (Cfg), `tests/test_database.lua` (Migrate)

**Interfaces:**
- Consumes: `NS.Debug`, `NS.ShouldShowBar()`, `NS.db` (AceDB; may be a plain fallback table headlessly).

- [ ] **Step 1: Write the `[Cfg] refused` test** in `tests/test_slash.lua`:

```lua
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
```

- [ ] **Step 2: Write the `[Migrate]` test** in `tests/test_database.lua`:

```lua
test("RunMigrations logs [Migrate] only when a version bump happens", function()
  NS.State.debug = true
  NS.db.global.schemaVersion = 1               -- force a v1->v2 migration
  local before = #NS.DebugLog.buffer
  NS:RunMigrations()
  local afterMigrate = #NS.DebugLog.buffer
  assertTrue(afterMigrate > before, "a [Migrate] line is logged when migrating")
  assertTrue(NS.DebugLog.buffer[afterMigrate]:find("[Migrate]", 1, true) ~= nil, "tag is Migrate")
  -- Idempotent: running again at v2 logs nothing new.
  NS:RunMigrations()
  assertEqual(#NS.DebugLog.buffer, afterMigrate)
  NS.State.debug = false
end)
```

- [ ] **Step 3: Run to verify failure**

Run: `lua tests/run.lua`
Expected: FAIL — no `[Cfg]` / `[Migrate]` lines exist yet.

- [ ] **Step 4: Add `[Cfg]` lines** — in `settings/Panel.lua` `NS.OpenOptionsPanel`, add a log in each branch:

```lua
function NS.OpenOptionsPanel()
    if InCombatLockdown() then
        NS.Debug("Cfg", "open refused (in combat)")
        print("|cffaaaaaacannot open settings during combat \226\128\148 Blizzard's category-switch is protected|r")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    if not mainCategoryID then return end
    NS.Debug("Cfg", "opened")
    Settings.OpenToCategory(mainCategoryID)
    expandMainCategory()
end
```

- [ ] **Step 5: Add `[Migrate]` line** — in `core/Database.lua` `NS:RunMigrations`, inside the `if g.schemaVersion < 2 then` block, before `g.schemaVersion = 2`:

```lua
    if g.schemaVersion < 2 then
        if profile then profile.updateInterval = nil end
        NS.Debug("Migrate", "v%s \226\134\146 v2", g.schemaVersion)
        g.schemaVersion = 2
    end
```

- [ ] **Step 6: Add `[Init]`, `[World]`, `[Profile]`** — in `core/AbsorbTracker.lua`:

At the end of `addon:OnEnable` (after `CreateOptionsPanel`), add the boot summary:
```lua
    NS.Debug("Init", "enabled \226\128\148 schema v%s, profile %s, bar %s",
        (NS.db and NS.db.global and NS.db.global.schemaVersion) or "?",
        (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "default",
        NS.ShouldShowBar() and "shown" or "hidden")
```
In `addon:OnEnterWorld`, add as the first line:
```lua
    NS.Debug("World", "entering world")
```
In `NS.OnProfileChanged`, add as the first line:
```lua
    NS.Debug("Profile", "changed \226\134\146 %s",
        (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?")
```

- [ ] **Step 7: Run tests + lint + syntax**

Run: `lua tests/run.lua && luacheck . && luac -p core/AbsorbTracker.lua settings/Panel.lua core/Database.lua`
Expected: PASS; 0/0; silent.

- [ ] **Step 8: Commit**

```bash
git add core/AbsorbTracker.lua settings/Panel.lua core/Database.lua tests/test_slash.lua tests/test_database.lua
git commit -m "Debug: cover lifecycle/config/migration/profile flows (§8)"
```

---

## Task 4: Hot-path coalescing — `[Combat]` counters/rollup, `[Absorb]` transitions, `[Bar]` visibility (§9)

**Files:**
- Modify: `core/AbsorbTracker.lua` (`OnAbsorbChanged`, `OnEnterCombat`, `OnLeaveCombat`; add module-local counters + `NS.NoteRepaint`)
- Modify: `modules/Display.lua` (`UpdateAbsorbBar` — remove per-repaint logs, call `NS.NoteRepaint`; `NS.ApplyVisibility` — `[Bar]` transition)
- Test: `tests/test_visibility.lua`

**Interfaces:**
- Consumes: `NS.Debug`, `NS.IsConcatSafe(v)`, `UnitGetTotalAbsorbs`, `NS.ShouldShowBar()`.
- Produces: `NS.NoteRepaint()` — called by `Display.UpdateAbsorbBar` on each actual repaint; increments the debug repaint counter (gated).

- [ ] **Step 1: Write the rollup + transition tests** in `tests/test_visibility.lua`:

```lua
test("combat rollup: OnLeaveCombat logs one [Combat] left summary with counts", function()
  local mocks = T.mocks
  NS.State.debug = true
  NS.addon:OnEnterCombat()                 -- resets counters
  NS.addon:OnAbsorbChanged(nil, "player")  -- +1 event
  NS.addon:OnAbsorbChanged(nil, "player")  -- +1 event
  NS.NoteRepaint()                         -- +1 repaint
  local before = #NS.DebugLog.buffer
  NS.addon:OnLeaveCombat()
  NS.State.debug = false
  local line
  for i = #NS.DebugLog.buffer, before, -1 do
    local l = NS.DebugLog.buffer[i]
    if l and l:find("[Combat]", 1, true) and l:find("left", 1, true) then line = l break end
  end
  assertTrue(line ~= nil, "a [Combat] left summary is logged")
  assertTrue(line:find("2 events", 1, true) ~= nil, "counts absorb events")
  assertTrue(line:find("1 repaints", 1, true) ~= nil, "counts repaints")
  mocks.__fireTimers()
end)

test("OnAbsorbChanged is silent on an unchanged value (no per-event spam)", function()
  local mocks = T.mocks
  local savedAbs = mocks.UnitGetTotalAbsorbs
  NS.State.debug = true
  mocks.UnitGetTotalAbsorbs = function() return 5000 end
  NS.addon:OnEnterCombat()
  NS.addon:OnAbsorbChanged(nil, "player")   -- establishes last=5000 (may log one transition)
  local before = #NS.DebugLog.buffer
  NS.addon:OnAbsorbChanged(nil, "player")   -- 5000 -> 5000: no transition, no line
  assertEqual(#NS.DebugLog.buffer, before)  -- silent when the value is unchanged
  mocks.UnitGetTotalAbsorbs = savedAbs
  NS.State.debug = false
  mocks.__fireTimers()
end)

test("[Absorb] transition logs on a non-secret 0->nonzero change", function()
  local mocks = T.mocks
  local savedAbs = mocks.UnitGetTotalAbsorbs
  NS.State.debug = true
  NS.addon:OnEnterCombat()
  mocks.UnitGetTotalAbsorbs = function() return 0 end
  NS.addon:OnAbsorbChanged(nil, "player")   -- establishes last = 0
  mocks.UnitGetTotalAbsorbs = function() return 5000 end
  local before = #NS.DebugLog.buffer
  NS.addon:OnAbsorbChanged(nil, "player")   -- 0 -> 5000 transition
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before and last:find("[Absorb]", 1, true) ~= nil
    and last:find("shield up", 1, true) ~= nil, "logs shield-up transition")
  mocks.UnitGetTotalAbsorbs = savedAbs
  NS.State.debug = false
  mocks.__fireTimers()
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `lua tests/run.lua`
Expected: FAIL — `NS.NoteRepaint` is undefined; no rollup/transition lines; `OnAbsorbChanged` still logs per-event (from Task 1's temporary line).

- [ ] **Step 3: Add counters + coalescing to `core/AbsorbTracker.lua`** — near the top of the file (after the `local addon` setup), add module-locals and the repaint hook:

```lua
-- Debug coalescing (§9): per-combat counters + last non-secret absorb, all maintained only when
-- debug is on. Reset at combat start, flushed as one [Combat] rollup at combat end.
local dbgAbsorbEvents, dbgRepaints = 0, 0
local dbgLastAbsorb   -- last NON-secret absorb value seen (nil until a non-secret read)

-- Called by modules/Display.lua on each actual repaint. Gated: counts nothing when debug is off.
function NS.NoteRepaint()
    if NS.State and NS.State.debug then dbgRepaints = dbgRepaints + 1 end
end
```

Replace `addon:OnAbsorbChanged` with a counting + non-secret-transition version:
```lua
function addon:OnAbsorbChanged(_, unit)
    if unit ~= "player" then return end
    if NS.State and NS.State.debug then
        dbgAbsorbEvents = dbgAbsorbEvents + 1
        local v = UnitGetTotalAbsorbs("player") or 0
        -- Only compare when the value is NOT a combat secret (IsConcatSafe == readable).
        if NS.IsConcatSafe(v) then
            local prev = dbgLastAbsorb
            if prev ~= nil and prev == 0 and v ~= 0 then
                NS.Debug("Absorb", "shield up: %s \226\134\146 %s", prev, AbbreviateNumbers(v))
            elseif prev ~= nil and prev ~= 0 and v == 0 then
                NS.Debug("Absorb", "shield gone: %s \226\134\146 0", AbbreviateNumbers(prev))
            end
            dbgLastAbsorb = v
        end
    end
    NS.RequestRepaint()
end
```

Replace `addon:OnEnterCombat` / `addon:OnLeaveCombat`:
```lua
function addon:OnEnterCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
    if NS.State and NS.State.debug then
        dbgAbsorbEvents, dbgRepaints = 0, 0
        NS.Debug("Combat", "entered")
    end
end

function addon:OnLeaveCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
    if NS.State and NS.State.debug then
        local v = UnitGetTotalAbsorbs("player") or 0
        if NS.IsConcatSafe(v) then
            NS.Debug("Combat", "left: %s events, %s repaints, final=%s",
                dbgAbsorbEvents, dbgRepaints, AbbreviateNumbers(v))
        else
            NS.Debug("Combat", "left: %s events, %s repaints", dbgAbsorbEvents, dbgRepaints)
        end
    end
end
```

- [ ] **Step 4: Update `modules/Display.lua`** — remove the two per-repaint `NS.Debug` lines added in Task 1 and call the counter instead. In `UpdateAbsorbBar`, delete the `NS.Debug("Bar", "repaint skipped: not visible")` line (the not-visible early return stays, just no log), and delete the `if NS.State and NS.State.debug then NS.Debug("Absorb", "paint …") end` block; at the end of `UpdateAbsorbBar` (after `valueText:SetText(...)`), add:
```lua
    if NS.NoteRepaint then NS.NoteRepaint() end
```
In `NS.ApplyVisibility`, add a transition-only `[Bar]` log:
```lua
local dbgLastShown   -- module-local: last applied visibility, for transition-only logging
function NS.ApplyVisibility()
    local show = NS.ShouldShowBar()
    if NS.State and NS.State.debug and show ~= dbgLastShown then
        local reason = NS.GetSetting("hidden") and "hidden toggle"
            or (NS.GetSetting("showOnlyInCombat") and "showOnlyInCombat") or "always"
        NS.Debug("Bar", "%s (%s)", show and "shown" or "hidden", reason)
    end
    dbgLastShown = show
    if show then NS.bar:Show() else NS.bar:Hide() end
end
```
(Note: this replaces the existing 3-line `NS.ApplyVisibility`. `ShouldShowBar` is called once and reused.)

- [ ] **Step 5: Run tests + lint + syntax**

Run: `lua tests/run.lua && luacheck . && luac -p core/AbsorbTracker.lua modules/Display.lua`
Expected: PASS (including the 3 new tests); 0/0; silent.

- [ ] **Step 6: Commit**

```bash
git add core/AbsorbTracker.lua modules/Display.lua tests/test_visibility.lua
git commit -m "Debug: coalesce hot path into [Combat] rollup + [Absorb] transitions (§9)"
```

---

## Task 5: Documentation sync

**Files:**
- Modify: `docs/file-index.md`, `docs/ARCHITECTURE.md`, `docs/midnight-quirks.md`, `docs/common-tasks.md` (test-suite table if suite counts changed), and any debug section.

- [ ] **Step 1: Update the docs** to describe: the secret-safe `NS.Debug(tag, fmt, ...)` sink and the removal of `NS.DebugPrint`; the tag set; §8 coverage points; the §9 per-combat coalescing (counters + rollup, no per-event lines) with the in-combat `<secret>` constraint; the §10 `[Set]` line at `SetByPath`. Frame as conformance to debug-logging §8/§9/§10 (no deviation). Update any `NS.DebugPrint` mention and correct changed line counts in `file-index.md`. Correct the test-suite table in `docs/common-tasks.md` if per-suite counts changed.

- [ ] **Step 2: Verify no stale `NS.DebugPrint` references remain**

Run: `grep -rn "DebugPrint" core modules settings docs README.md | grep -v "docs/audits/\|docs/reviews/\|docs/superpowers/"`
Expected: no matches (or only historical mentions in frozen bundles, which are excluded).

- [ ] **Step 3: Final green gate**

Run: `lua tests/run.lua && luacheck .`
Expected: all PASS; 0/0.

- [ ] **Step 4: Commit**

```bash
git add docs/
git commit -m "Docs: sync debug-logging overhaul (§8/§9/§10, secret-safe sink)"
```

---

## Notes for the implementer

- **`AbbreviateNumbers` on a secret** would itself return a secret; that's fine — it only ever reaches `NS.Debug`, which `SafeToString`s it to `<secret>`. The `NS.IsConcatSafe(v)` guards ensure we never *compare* a secret; the `AbbreviateNumbers(v)` calls inside those guarded branches only run on non-secret `v`.
- **`dbgLastAbsorb` / `dbgLastShown`** are debug-only session state; they are never persisted and reset naturally (`dbgLastAbsorb` only updates on non-secret reads; combat counters reset at `OnEnterCombat`).
- **Why `NS.IsConcatSafe` and not `issecretvalue`:** it is the project's existing version-agnostic secret probe (tests the exact `table.concat` operation that rejects a secret), is already unit-tested, and works with the existing `secretMock` in the harness — no new mock stub needed. This supersedes the spec's `issecretvalue` mention.
- **Test harness:** `tests/wow_mock.lua` provides `UnitGetTotalAbsorbs` (default `0`), `UnitAffectingCombat`, `InCombatLockdown`, `date`, `__timers`/`__fireTimers`, and `secretMock`. Override `mocks.UnitGetTotalAbsorbs` per-test for value scenarios.
```
