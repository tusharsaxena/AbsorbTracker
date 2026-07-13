# Midnight quirks — WoW retail API gotchas

Catalog of WoW Midnight (Interface 12.0.x) behaviors and Blizzard-API conventions that bite the addon. When something breaks at patch time, this is where to look first.

## Secret values from `UnitGetTotalAbsorbs`

`UnitGetTotalAbsorbs("player")` may return WoW's opaque-token "secret" value in combat (and for very large absorb amounts). Lua cannot compare a secret value with a number (`tonumber()` returns nil; `>` / `<` against a number errors).

- **Use `AbbreviateNumbers()` for display.** It accepts secret values directly and returns a formatted string (`"123K"`, `"1.2M"`). Never run the result of `UnitGetTotalAbsorbs` through `tonumber` before display — you'll lose the value.
- **Pass the raw value into `statusBar:SetValue` and `statusBar:SetMinMaxValues`.** Engine-side widget APIs accept secret values directly. This is what `NS.UpdateAbsorbBar` (`modules/Display.lua`) does: it reads the absorb amount, formats the text via `AbbreviateNumbers`, and pushes the raw value into the StatusBar without any Lua-side comparison.

### A secret survives `tostring()` **and `..`**, but **explodes in `table.concat`**

The subtle trap: `AbbreviateNumbers(secretValue)` returns a *secret string*, not a plain one. A secret string passes through `tostring()` unchanged, **and the `..` operator does not raise on it either** — `secret .. ""` silently returns another secret string. What *does* raise is `table.concat`:

```
invalid value (secret) at index N in table for 'concat'
```

This asymmetry is the whole gotcha. The debug lines in `OnAbsorbChanged` (`core/AbsorbTracker.lua`) and `UpdateAbsorbBar` (`modules/Display.lua`) log `AbbreviateNumbers(UnitGetTotalAbsorbs("player"))`. In combat that argument is a secret string, and `NS.DebugPrint` finishes by `table.concat`-ing its args — so **with `/at debug on`, entering combat raised on every absorb event and every repaint.** (Historically the repaint ran on a *repeating* AceTimer; the erroring callback stopped rescheduling and the bar froze until `/reload`. The repaint path is now event-driven — `NS.RequestRepaint` (`modules/Timer.lua`) — but the same secret-value trap applies to any repaint, whatever triggers it.)

The guard lives at the concat boundary, not the call sites: `NS.SafeToString` (`core/Util.lua`) substitutes the sentinel `"<secret>"` for any value that a real `table.concat` would reject (secrets show as `<secret>` in the debug console). Detection **must probe `table.concat`, not `..`** — `NS.IsConcatSafe(v)` runs `pcall(function() return table.concat({ v }) end)`, because a probe built on `..` reports a secret as *safe* (the operator propagates instead of raising) and lets it slip straight through to the real concat. Both `NS.Print` (chat) and `NS.DebugPrint` (console) route every arg through `SafeToString`, so no addon line can be killed by a secret. `nil`/`boolean` are handled up front (they are never secret but `table.concat` rejects them too). The debug lines remain gated behind `NS.State.debug` so the probe cost is zero when debug is off.

**Rule of thumb:** never feed a value read from a combat-protected API into `..`, `table.concat`, or `string.format`. Hand it straight to an engine-side widget/`AbbreviateNumbers` for display, or run it through `NS.SafeToString` before it touches a string operation.

## `SetBackdrop` is a no-op when the table identity is unchanged

WoW's `Frame:SetBackdrop(info)` ignores the call when `info` is the same table identity as the previously-set backdrop, *even if its fields changed*. AbsorbTracker reuses one `NS.backdropInfo` table (built at file load in `modules/Bar.lua`) to avoid GC, mutates its fields in `NS.UpdateBarAppearance` (`modules/Display.lua`), and then calls:

```lua
bar:SetBackdrop(nil)            -- force-clear
bar:SetBackdrop(backdropInfo)   -- re-apply with current fields
```

Don't try to "optimize" by skipping the `SetBackdrop(nil)`. The backdrop will look stale until the next `/reload`.

## `InCombatLockdown()` lags `PLAYER_REGEN_DISABLED` — use `UnitAffectingCombat` for the visibility gate

The `showOnlyInCombat` bar-visibility gate (`NS.ShouldShowBar`, `modules/Display.lua`) must key off `UnitAffectingCombat("player")`, **not** `InCombatLockdown()`.

`InCombatLockdown()` reports the *secure-frame lockdown* state, which is a distinct thing from "the player is in combat" — and in this client the two are not simultaneous at the entering-combat edge. When `PLAYER_REGEN_DISABLED` fires (`addon:OnEnterCombat`), `InCombatLockdown()` still returns **false**; secure lockdown engages a fraction of a second later. Debug capture of the transition:

```
[OnEnterCombat] fired | InCombatLockdown: false
[ApplyVisibility] decision: HIDE | InCombatLockdown: false | showOnlyInCombat: true
[UpdateAbsorbBar] Absorb: <secret> | MaxHP: 734K   ← same second, now NOT skipped → lockdown flipped true
```

Gating on `InCombatLockdown()` therefore hid the bar at the exact moment it should appear: `OnEnterCombat`'s `NS.ApplyVisibility()` read the stale `false` and called `bar:Hide()`. The bar never recovered for the rest of the fight, because the repaint path (`NS.UpdateAbsorbBar`) only updates the bar's *value* — it never re-runs the show/hide decision — so nothing re-showed the frame once lockdown flipped true. Absorb values kept painting underneath a hidden frame.

`UnitAffectingCombat("player")` is true from the instant combat starts (already true at `PLAYER_REGEN_DISABLED`) and false at `PLAYER_REGEN_ENABLED`, which is exactly the predicate a *display* gate wants. The bar is a plain, non-secure frame, so this query carries no taint concern.

**Rule of thumb:** `InCombatLockdown()` answers "are secure actions locked?" (use it to defer protected API calls like `Settings.OpenToCategory`, below). `UnitAffectingCombat("player")` answers "is the player in combat?" (use it for display/visibility logic). They are not interchangeable at the combat-entry edge.

## Combat lockdown taints `Settings.OpenToCategory`

`Settings.OpenToCategory(categoryID)` is part of the protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI behavior.

`NS.OpenOptionsPanel` (`settings/Panel.lua`) **defers** the open to combat end when `InCombatLockdown()` is true, per Ka0s standard §6.2 (defer-and-replay, not refuse):

```lua
if InCombatLockdown() then
    if not NS.State.panelOpenPending then
        NS.State.panelOpenPending = true
        NS.addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            NS.addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
            NS.State.panelOpenPending = nil
            NS.OpenOptionsPanel()               -- replay once lockdown has cleared
        end)
        print("In combat — settings will open when you leave combat.")
    end
    return
end
Settings.OpenToCategory(mainCategoryID)
expandMainCategory()
```

(The `print` is the `local print = NS.Print` shadow at the top of `settings/Panel.lua`, so the chat output gets the cyan `[AT]` prefix.)

`PLAYER_REGEN_ENABLED` fires when combat *ends* — lockdown is already released — so the replayed `Settings.OpenToCategory` runs taint-free. The `NS.State.panelOpenPending` session flag makes it idempotent: hammering `/at config` mid-pull registers exactly one one-shot replay, and the handler unregisters itself on the first fire. `NS.State` is session-only, so a `/reload` during combat clears any pending open. This replaced the earlier refuse-with-notice behavior when the addon was brought into line with §6.2.

## `Settings.OpenToCategory` wants a numeric ID, not a category object

`Settings.RegisterCanvasLayoutCategory(panel, name)` returns a category *object* with a `:GetID()` method; `Settings.RegisterCanvasLayoutSubcategory(parent, panel, name)` returns the same shape. `Settings.OpenToCategory` accepts the numeric ID directly — passing the object produces a range error.

`settings/Panel.lua` captures `mainCategory:GetID()` at parent registration into `mainCategoryID`; `OpenOptionsPanel` calls `Settings.OpenToCategory(mainCategoryID)` so `/at config` always lands on the parent (about page) and then calls `expandMainCategory()` to expand the sub-page tree so every sub-page is visible at once. `expandMainCategory` reaches into `SettingsPanel:GetCategoryList()` private API; the whole call is wrapped in `pcall` so a future Blizzard refactor that renames or removes those internals degrades gracefully (the panel still opens, the tree just doesn't auto-expand).

## Interface line — track the current retail build

`AbsorbTracker.toc` declares a single retail build number:

```
## Interface: 120007
```

The value is `(major * 10000) + (minor * 100) + patch` for the current Live Servers (Retail) patch. AbsorbTracker targets the current Midnight build. **When a new patch ships, replace the number with the new build** so the addon reads as up-to-date in the AddOn list. The `## Interface:` line accepts a comma-separated list on retail clients 10.0+ if you ever need to declare compatibility with several builds at once, but the addon tracks a single current build.

If a patch breaks the addon, note the regression in the README's troubleshooting section.

## `BackdropTemplate` is mandatory for backdrop frames

WoW retail (10.0+) split backdrop functionality off the base Frame and into the `BackdropTemplate` mixin. Frames that need `SetBackdrop` / `SetBackdropColor` / `SetBackdropBorderColor` must declare the template at creation:

```lua
CreateFrame("Frame", "AbsorbTrackerFrame", UIParent, "BackdropTemplate")
```

`modules/Bar.lua` does this for the bar; the canonical upstream `AceGUI-3.0-SharedMediaWidgets` lib at `libs/AceGUI-3.0-SharedMediaWidgets/` does the same for the LSM dropdown widgets. If a future custom widget needs a backdrop and forgets the template, the addon will error on `SetBackdrop`.

## Class color sources

Two different paths for the same concept:

- **Bar / border** use `C_ClassColor.GetClassColor(classFile)` directly — Blizzard's official class-color API, returns a `ColorMixin` with `:GetRGBA()`.
- **Background** uses a hard-coded per-class table multiplied by `0.2` to produce a darkened variant. The per-class table mirrors WoW's official class colors (DEATHKNIGHT through WARRIOR); the result is cached in `playerBgClassColor` since the player class doesn't change at runtime.

Why the asymmetry: a bar fill at full class brightness atop a background also at full class brightness washes out the value text. The 0.2 multiplier on the background keeps the absorb fill readable. Picking a fixed darken factor was preferred over computing a perceptually-uniform delta because the result is independent of which class the player is — every class gets the same readability profile.

Both paths resolve at *call* time inside `NS.GetBarColor` / `NS.GetBgColor` / `NS.GetBorderColor` (`core/Data.lua`). Class change / respec / profile switch all "just work" without explicit refresh wiring — the next paint reads the current toggle and produces the right color. See [scope.md](./scope.md#resolved-decisions).

## `UNIT_ABSORB_AMOUNT_CHANGED` fires often during heavy combat

The event can fire many times per second during raid encounters with stacking absorbs (Power Word: Shield + trinket procs + Discipline absorbs + …). The `OnAbsorbChanged` handler in `core/AbsorbTracker.lua` records a debug line (gated behind `NS.State.debug`) then calls `NS.RequestRepaint()` — it does not repaint directly, so a burst of events can't over-render the StatusBar and the string-format calls.

`NS.RequestRepaint()` (`modules/Timer.lua`) is the coalescing repaint scheduler and the source of truth for visual updates. It runs on **AceTimer** — a trailing-edge one-shot: if a repaint is already queued, further calls are a no-op; otherwise it schedules `NS.addon:ScheduleTimer(NS.UpdateAbsorbBar, throttleWindow)` (Ka0s standard §3.1 — a one-shot AceTimer, not a raw `C_Timer`), which self-clears once it fires. `throttleWindow` is user-configurable (0.05 – 1 s; default 0.1 s). There is no repeating ticker and no polling — idle = zero repaints. See [data-flow.md](./data-flow.md#absorb-update-path).

## When an event you depend on gets removed in retail

If Blizzard removes an event the addon listens for (it has happened in past retail patches — `LEARNED_SPELL_IN_TAB` was replaced by `LEARNED_SPELL_IN_SKILL_LINE`), the failure mode is that the AceEvent registration succeeds but the event never fires. AbsorbTracker only listens for `UNIT_ABSORB_AMOUNT_CHANGED` and `PLAYER_ENTERING_WORLD` (both registered via `self:RegisterEvent(...)` in `addon:OnEnable`, `core/AbsorbTracker.lua`), plus the AceAddon lifecycle events `ADDON_LOADED` → `OnInitialize` and `PLAYER_LOGIN` → `OnEnable` — all stable retail events. If a future patch deprecates one, the replacement should be wired by patching the `RegisterEvent` calls in `core/AbsorbTracker.lua`; nothing else needs to change.
