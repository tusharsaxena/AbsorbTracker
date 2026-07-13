# Proposed Changes — Ka0s Absorb Tracker

Companion to [`01_FINDINGS.md`](./01_FINDINGS.md). This doc is the design — high-level themes plus per-finding LLD sketches.

## HLD — themes

### T1. Pin to the modern WoW retail API surface
**Rationale:** The addon already uses `C_AddOns.GetAddOnMetadata` in one helper (`OptionsPanel.lua`'s `getMetadata`) and the bare-global `GetAddOnMetadata` in another (`SlashCommands.lua`'s `getVersion`). On Midnight, the bare global is removed. Both helpers should prefer `C_AddOns.*` and only fall back to the legacy name. Same priority order, both helpers.

**Alternatives considered:** A single shared `AddonTable.GetMetadata(field)` in `Utils.lua`. Rejected for now because the two existing helpers are short and the duplicated pair is two call sites; consolidating is a follow-up if a third caller appears. (Fold into T2 if `Utils.lua` is opened anyway.)

**Trade-off:** None — strictly safer order. Covers F-001.

### T2. Honor the documented `SetByPath` single-write seam
**Rationale:** `CLAUDE.md` and `docs/data-flow.md` claim "the slash and panel paths converge on `SetByPath`." They don't today: the panel's `set` and color-picker `commit` open-code `SetSetting + FireSchemaOnChange`. Behavior is identical now, but a future change to `SetByPath` (validation hook, change-notify event, telemetry) would silently miss the panel path.

**Alternatives considered:**
1. Update the docs to say "panel path uses SetSetting + FireSchemaOnChange directly" — rejected: the docs reflect the right architecture; the code is the wrong half.
2. Make `SetByPath` itself call `RefreshAllPanels` so the panel `set` becomes a one-liner — rejected: refresh is panel-layer behavior; pulling it into `Schema.lua` couples Schema to OptionsPanel.

**Chosen:** Panel `set()` calls `SetByPath` and follows up with `Helpers.RefreshAllPanels()`. The color picker `commit` does the same. Net: one place writes, one place fires onChange (inside `SetByPath`), the panel adds its own refresh on top.

**Trade-off:** One extra function-call frame per panel write. Negligible.

Covers F-003.

### T3. Harden the AceDB-missing fallback so future contributors can't trip the alias bug
**Rationale:** The seed loop in `Events.lua` aliases `flatDefaults` color tables into `AbsorbTrackerDB`. Today nothing mutates the saved-variable in place, so the bug is dormant. The seed loop should deep-copy the same way `Schema.ApplyDefault` does.

**Alternatives considered:** Move the seed loop into `Schema.lua` and reuse the `ApplyDefault` deep-copy — rejected because `ApplyDefault` also fires `onChange`, which would re-run `UpdateBarAppearance` once per default key during bootstrap. Inline the deep-copy at the seed site instead.

**Trade-off:** A few extra table allocations once at login if AceDB is missing. AceDB ships in-tree, so this path is documented as not-exercised-in-practice.

Covers F-002.

### T4. Make `/at test` actually test
**Rationale:** Today the test paint lasts at most one ticker tick. Two viable shapes:

1. **Pause the ticker for N seconds while the test value is up.** Cancel the ticker, paint, schedule a `C_Timer.After(N, RestartUpdateTicker)`. Simple, but pauses real updates.
2. **Suppress just the next `UpdateAbsorbBar` call.** Set a "test mode until time T" flag; `UpdateAbsorbBar` early-returns if now < T. Cleaner — only the absorb-update path is paused, the ticker keeps running.

**Chosen:** Shape 2 (a `testHoldUntil` timestamp on `AddonTable`). Default hold = 5 s, configurable via the second argument: `/at test 50000 [hold-secs]`. Print the duration in the chat ack so the user knows.

**Trade-off:** Adds one branch to `UpdateAbsorbBar`. Worth it — the existing feature is broken.

Covers F-004 and F-013 (also nudge "the bar is hidden" hint into the same handler).

### T5. Split `OptionsPanel.lua` along its existing seams
**Rationale:** The file already has natural seams:
- Layout constants + header builder + `CreatePanel`.
- Widget makers (`makeCheckbox` / `makeSlider` / `makeDropdown` / `makeColorPicker`).
- `RenderField` + `RenderSchema` + `Section` + `InlineButtonPair`.
- The `PatchAlwaysShowScrollbar` ScrollFrame patch.
- About-page builder + slash-list rendering.
- Page registration shell (`RegisterOptionsPage` / `CreateOptionsPanel` / `OpenOptionsPanel` / `expandMainCategory`).

**Alternatives considered:**
1. Leave it — rejected: 958 lines and growing every time a widget type is added.
2. Split into 5+ files — rejected as over-engineering for a small addon.

**Chosen split:**
- `OptionsPanel.lua` (~250 lines): registration shell, `OpenOptionsPanel`, `expandMainCategory`, `CreateOptionsPanel`, `RegisterOptionsPage`, the `pendingPages` queue, the `PARENT_TITLE` constant, and the public `RefreshOptionsPanel` / `Helpers` table that the `Options/*.lua` files consume.
- `Panel/Helpers.lua` (~250 lines): `Helpers.CreatePanel`, `Helpers.Section`, `Helpers.InlineButtonPair`, `Helpers.AttachTooltip`, `Helpers.RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels`, layout constants, header builder, the `renderedPanels` registry. Also hosts the new `Helpers.LSMValues(mediaType)`.
- `Panel/Widgets.lua` (~280 lines): `makeCheckbox` / `makeSlider` / `makeDropdown` / `makeColorPicker`, `RenderField`, `RenderSchema`, the `applyWidth` / `snapToStep` / `addSpacer` private helpers. Calls into `AddonTable.SetByPath` (after T2) plus `Helpers.RefreshAllPanels`.
- `Panel/ScrollPatch.lua` (~110 lines): the `PatchAlwaysShowScrollbar` AceGUI ScrollFrame override and the `ensureScroll` factory it pairs with.
- `Panel/About.lua` (~80 lines): `buildMainContent` and the about-page constants (`LOGO_PATH`, the four `MAIN_*` sizing constants).

**Trade-off:** TOC grows by four entries; added load-order constraint between `Helpers` and the rest. The split aligns with the documented "Helpers toolkit" boundary in `docs/module-map.md`, so docs stay accurate.

Covers F-005. Also creates the right home for F-006 (`lsmValues` → `Helpers.LSMValues`).

### T6. Sweep dead/duplicated/redundant code
Single low-priority pass over the small nits, batched so reviewers don't see noise commits:
- F-006 — extract `lsmValues` into `Helpers.LSMValues` (lands inside T5's `Panel/Helpers.lua` if T5 ships, otherwise a Helper on `AddonTable`).
- F-008 — drop the unused `local UpdateAbsorbBar = …` in `Timer.lua`.
- F-009 — drop `AddonTable.min = math.min` in `Core.lua`.
- F-010 — drop the redundant intra-function locals in `Display.UpdateAbsorbBar`.
- F-011 — replace `GetTime() and GetTime() or 0` with `GetTime() or 0` (both sites in `OptionsPanel.lua`).
- F-007 — guard expensive DebugPrint argument construction at the call site for the per-ticker path.
- F-014 — leave as-is unless touching the file for another reason; flagged for awareness.
- F-015 — keep `Helpers.AttachTooltip` exported (the docs list it as a public Helper); add a one-line comment marking intent.
- F-016 — punctuation pass on chat output; no behavior change.
- F-017 — either document the aliases or drop them. Default: drop, since neither README nor `/at help` advertises them.

### T7. Color-picker throttle redesign — optional
**Rationale:** F-012 is a perf nit, not a bug. The throttle works; it just allocates more than necessary. A single re-armed ticker is cleaner. Worth doing only if `Panel/Widgets.lua` is being touched anyway (T5).

**Alternatives:**
1. Keep current code — fine.
2. Single `C_Timer.NewTicker(0.05, …)` started lazily, polled for pending args, cancelled when the picker closes. Cleaner code, ~zero per-event garbage.
3. Drop the throttle entirely — rejected: a sustained drag at 60 fps would slam `UpdateBarAppearance` (which itself calls `SetBackdrop(nil)` + `SetBackdrop(info)`).

**Chosen:** Defer to T5's widget-file refactor. If T5 doesn't ship, leave T7 unaddressed.

Covers F-012.

---

## LLD — per-finding sketches

### F-001 — fix `getVersion` API ordering
**File:** `SlashCommands.lua`
**Function:** `getVersion` (lines 87-95).

Before:
```lua
local function getVersion()
    if GetAddOnMetadata then
        return GetAddOnMetadata(AddonName, "Version") or "?"
    end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(AddonName, "Version") or "?"
    end
    return "?"
end
```

After:
```lua
local function getVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(AddonName, "Version") or "?"
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(AddonName, "Version") or "?"
    end
    return "?"
end
```

Risk: none — bare-global path stays as a fallback for any client that doesn't expose `C_AddOns`.

### F-002 — deep-copy default tables in the AceDB-missing seed loop
**File:** `Events.lua`
**Function:** PLAYER_LOGIN handler, inside `if not AddonTable.db then ... end` (lines 47-57).

After:
```lua
if not AddonTable.db then
    AbsorbTrackerDB = AbsorbTrackerDB or {}
    AddonTable.db = { profile = AbsorbTrackerDB }
    for key, defaultVal in pairs(flatDefaults) do
        if AddonTable.db.profile[key] == nil then
            if type(defaultVal) == "table" then
                local copy = {}
                for k, v in pairs(defaultVal) do copy[k] = v end
                AddonTable.db.profile[key] = copy
            else
                AddonTable.db.profile[key] = defaultVal
            end
        end
    end
end
```

Risk: minimal — only the fallback shim path is touched; AceDB path is unchanged.

### F-003 — panel writes route through `SetByPath`
**File:** `OptionsPanel.lua` (or `Panel/Widgets.lua` if T5 ships).
**Function:** `set` (line 412), `commit` inside `makeColorPicker` (line 572).

Before (`set`):
```lua
local function set(row, value)
    AddonTable.SetSetting(row.path, value)
    if AddonTable.FireSchemaOnChange then
        AddonTable.FireSchemaOnChange(row, value)
    end
    Helpers.RefreshAllPanels()
end
```

After:
```lua
local function set(row, value)
    AddonTable.SetByPath(row.path, value)
    Helpers.RefreshAllPanels()
end
```

Before (color-picker `commit`):
```lua
local function commit(r, g, b, a)
    AddonTable.SetSetting(row.path, { r = r, g = g, b = b, a = a or 1 })
    if AddonTable.FireSchemaOnChange then
        AddonTable.FireSchemaOnChange(row, AddonTable.GetSetting(row.path))
    end
end
```

After:
```lua
local function commit(r, g, b, a)
    AddonTable.SetByPath(row.path, { r = r, g = g, b = b, a = a or 1 })
end
```

Note: the original color-picker `commit` does NOT call `RefreshAllPanels`, on purpose (a sustained drag would refresh every widget every 50 ms). Preserve that distinction — only the click-confirm path through the regular `set` triggers a refresh.

Risk: low. `SetByPath` performs `SetSetting + fireOnChange`, which matches the original two-step composition exactly. The `if AddonTable.FireSchemaOnChange then` guard was already redundant: the reverse load-order coupling makes it impossible to reach the panel widgets before Schema.lua is loaded.

### F-004 + F-013 — `/at test` test-hold and hidden-bar warning
**Files:** `SlashCommands.lua`, `Display.lua`.

Add `AddonTable.testHoldUntil = 0` to `Core.lua` (or initialize-on-first-write in `Display.UpdateAbsorbBar`).

`Display.UpdateAbsorbBar` early-out (after the `hidden` early-out, before the engine-read):
```lua
if (AddonTable.testHoldUntil or 0) > GetTime() then
    return
end
```

`SlashCommands.runTest`:
```lua
function runTest(rest)
    local args = {}
    for w in (rest or ""):gmatch("%S+") do args[#args + 1] = w end
    local n    = tonumber(args[1]) or 50000
    local hold = tonumber(args[2]) or 5

    if AddonTable.GetSetting("hidden") then
        print("Bar is hidden; run /at toggle to show it before testing.")
        return
    end

    print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
    if AddonTable.valueText and AddonTable.statusBar then
        AddonTable.valueText:SetText(AbbreviateNumbers(n))
        AddonTable.statusBar:SetMinMaxValues(0, math.max(n, 100000))
        AddonTable.statusBar:SetValue(n)
    end
    AddonTable.testHoldUntil = GetTime() + hold
end
```

`README.md` and the SlashCommands in-line description string update from `/at test [value]` to `/at test [value] [hold-secs]`. The README's update can wait until the next release — flagged as docs-debt in T6.

Risk: low. The hold timer is read by exactly one place (`UpdateAbsorbBar`), and the timer flag is per-session, not saved.

### F-005 — split `OptionsPanel.lua`
**Files:** `OptionsPanel.lua` (shrunk), new `Panel/Helpers.lua`, `Panel/Widgets.lua`, `Panel/ScrollPatch.lua`, `Panel/About.lua`. Updated `AbsorbTracker.toc` load order.

TOC additions, in order, immediately after the existing `OptionsPanel.lua` line:
```
OptionsPanel.lua
Panel\Helpers.lua
Panel\ScrollPatch.lua
Panel\Widgets.lua
Panel\About.lua
Options\General.lua
…
```

Inter-file contract:
- `OptionsPanel.lua` exports `Helpers` (empty `{}` initially) on `AddonTable` so later files can decorate it. Same publish-then-decorate pattern the addon already uses for the schema registry.
- `Panel/Helpers.lua` decorates `AddonTable.Helpers` with `CreatePanel`, `Section`, `InlineButtonPair`, `AttachTooltip`, `LSMValues`, `RestoreDefaults`, `RestoreAllDefaults`, `RefreshAllPanels`.
- `Panel/ScrollPatch.lua` decorates `AddonTable.Helpers.PatchAlwaysShowScrollbar` and exports the file-local `ensureScroll`. (Or keep `ensureScroll` as a Helper too — it's the right home given it's used by Section + InlineButtonPair + RenderSchema.)
- `Panel/Widgets.lua` decorates `AddonTable.Helpers.RenderField` and `AddonTable.Helpers.RenderSchema`.
- `Panel/About.lua` exports `AddonTable.Helpers.BuildMainContent` (renamed from the file-local `buildMainContent`); `OptionsPanel.lua`'s `registerMain` calls it.

Documentation impact: `docs/file-index.md` and `docs/module-map.md` need refreshed file lists (no API changes). `docs/settings-panel.md` already calls out the helper toolkit shape; adding "Helpers spans Panel/Helpers.lua / Panel/Widgets.lua / Panel/ScrollPatch.lua" is a one-paragraph note.

Risk: medium-low. The split is mechanical — moves bytes between files without changing any function body or signature. No new behavior.

### F-006 — `lsmValues` extracted to a Helper
**Files:** `Panel/Helpers.lua` (post-T5) or `OptionsPanel.lua` (if T5 hasn't shipped).

Add to Helpers:
```lua
function Helpers.LSMValues(mediaType)
    return function()
        local LSM = AddonTable.GetLSM()
        local list, out = LSM and LSM:HashTable(mediaType) or {}, {}
        for k in pairs(list) do out[k] = k end
        return out
    end
end
```

In `Options/Bar.lua`, `Options/Border.lua`, `Options/Font.lua`: drop the local `lsmValues` and replace each call with `AddonTable.Helpers.LSMValues("statusbar")` etc. Preserve the file-load-time evaluation by keeping the call site in the schema row.

Risk: trivial.

### F-007 — guard DebugPrint on the per-ticker path
**File:** `Display.lua` (line 92), `Timer.lua` (lines 14, 31), `Settings.lua` (line 50).

Two equivalent shapes:

Shape A (per call site, minimal change):
```lua
if AddonTable.DEBUG then
    DebugPrint("UpdateAbsorbBar - Absorb:", AbbreviateNumbers(totalAbsorb), …)
end
```

Shape B (change `DebugPrint` to lazy):
```lua
function AddonTable.DebugPrint(fmt, ...)
    if not AddonTable.DEBUG then return end
    if select("#", ...) == 0 then
        print(fmt)
    else
        print(fmt:format(...))
    end
end
```

Shape A is mechanical and zero-risk; Shape B is a nicer API change but a bigger blast radius (every call site adapts to the format-string pattern). Recommend **A** for the hot-path lines (`Display.lua:92`); leave the cold-path lines (`Settings.lua:50`, `Timer.lua:14/31`) untouched since they don't fire often enough to matter.

Risk: trivial; cosmetic at the cold sites.

### F-008 / F-009 / F-010 / F-011 — dead-code sweep
- `Timer.lua:6`: drop the line `local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar`. The single caller already references `AddonTable.UpdateAbsorbBar` directly.
- `Core.lua:7`: drop `AddonTable.min = math.min`.
- `Display.lua:80-81`: drop the two intra-function `local GetSetting = …` / `local DebugPrint = …` lines.
- `OptionsPanel.lua:582`: change to `local now = GetTime() or 0`.
- `OptionsPanel.lua:593`: change to `lastCommit = GetTime() or 0`. (`GetTime` does not return nil on retail; the `or 0` is also unnecessary, but harmless — keep for "uninitialized = 0" symmetry with line 579.)

Risk: zero.

### F-012 — color-picker throttle (optional)
**File:** `Panel/Widgets.lua` (post-T5). Skip if T5 doesn't ship.

Replace the ad-hoc closure-allocating throttle with a single re-armed C_Timer:
```lua
local pending
local timer
local function throttledCommit(r, g, b, a)
    pending = pending or {}
    pending[1], pending[2], pending[3], pending[4] = r, g, b, a
    if timer then return end
    timer = C_Timer.NewTimer(0.05, function()
        timer = nil
        local p = pending
        pending = nil
        if p then commit(p[1], p[2], p[3], p[4]) end
    end)
end
```

Risk: low. Reuses one table for the pending-args carrier and one timer object.

### F-013 — folded into F-004 above.

### F-014 — defer.

### F-015 — defer (one-line intent comment if the file is being touched).

### F-016 — chat-output punctuation sweep.
**File:** `SlashCommands.lua`. Pick one rule (e.g. "no terminal punctuation on status lines, period on errors") and apply across all `print(...)` call sites. Mechanical.

Risk: zero.

### F-017 — drop the undocumented profile aliases.
**File:** `SlashCommands.lua:278, 285, 300`. Change `if sub == "use" or sub == "set" then` to `if sub == "use" then`, etc. Add a single line at the top of `runProfile` that maps `set→use`, `create→new`, `remove→delete` if you want to keep them; otherwise drop the alternatives.

Risk: zero — neither the README nor `/at help` ever named the aliases.

---

## Cross-finding rollup

| Theme | Findings covered |
|-------|------------------|
| T1 | F-001 |
| T2 | F-003 |
| T3 | F-002 |
| T4 | F-004, F-013 |
| T5 | F-005, F-006 (lsmValues home) |
| T6 | F-007, F-008, F-009, F-010, F-011, F-016, F-017 |
| T7 | F-012 |
| (deferred) | F-014, F-015 |
