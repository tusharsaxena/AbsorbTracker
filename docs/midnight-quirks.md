# Midnight quirks — WoW retail API gotchas

Catalog of WoW Midnight (Interface 12.0.x) behaviors and Blizzard-API conventions that bite the addon. When something breaks at patch time, this is where to look first.

## Secret values from `UnitGetTotalAbsorbs`

`UnitGetTotalAbsorbs("player")` may return WoW's opaque-token "secret" value for very large absorb amounts. Lua cannot compare a secret value with a number (`tonumber()` returns nil; `>` / `<` against a number errors). Two consequences:

- **Use `AbbreviateNumbers()` for display.** It accepts secret values directly and returns a formatted string (`"123K"`, `"1.2M"`). Never run the result of `UnitGetTotalAbsorbs` through `tonumber` before display — you'll lose the value.
- **The `lastAbsorb` short-circuit uses raw equality.** `Display.lua` compares the new value to `AddonTable.lastAbsorb` with `==`. Secret-value equality works for the short-circuit purpose because WoW keeps secret-token identity stable for the same numeric value within a session.

If a future patch tightens secret-value handling so even `==` errors, the short-circuit needs to be replaced with a Blizzard-side helper (probably something in the `C_CurveUtil` family that the engine adds for similar opaque-comparison cases in other addons).

## `SetBackdrop` is a no-op when the table identity is unchanged

WoW's `Frame:SetBackdrop(info)` ignores the call when `info` is the same table identity as the previously-set backdrop, *even if its fields changed*. AbsorbTracker reuses one `AddonTable.backdropInfo` table to avoid GC, mutates its fields in `UpdateBarAppearance`, and then calls:

```lua
bar:SetBackdrop(nil)            -- force-clear
bar:SetBackdrop(backdropInfo)   -- re-apply with current fields
```

Don't try to "optimize" by skipping the `SetBackdrop(nil)`. The backdrop will look stale until the next `/reload`.

## Combat lockdown taints `Settings.OpenToCategory`

`Settings.OpenToCategory(categoryID)` is part of the protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI behavior.

`AddonTable.OpenOptionsPanel` always early-returns when `InCombatLockdown()` is true:

```lua
if InCombatLockdown() then
    AddonTable.Print("settings panel is unavailable during combat")
    return
end
Settings.OpenToCategory(categoryID)
```

Don't try to clever-defer the call into a `PLAYER_REGEN_ENABLED` queue. A user who clicks `/at config` mid-pull and then tabs to another addon's UI mid-call would see weird state. The straight-up refusal with a chat notice is the right call.

## `AceConfigDialog:AddToBlizOptions` returns `(frame, categoryID)`

On modern clients this returns two values: the frame object and the numeric category ID. `Settings.OpenToCategory` wants the **numeric ID**; passing the frame produces a range error. Always capture both return values:

```lua
local frame, categoryID = AceConfigDialog:AddToBlizOptions("AbsorbTracker", "Ka0s Absorb Tracker")
```

`OptionsPanel.lua` captures the parent's category ID and each sub-page's category ID at registration time. `OpenOptionsPanel` uses the page-flagged `isDefault = true` (typically General) so `/at config` lands directly on a populated page instead of the empty parent shell.

## Interface line — three patches, one TOC

`AbsorbTracker.toc` declares:

```
## Interface: 120000, 120001, 120005
```

Comma-separated multi-version lines are supported on retail clients 10.0+; each entry is a patch number. AbsorbTracker is currently compatible with Midnight 12.0.0, 12.0.1, and 12.0.5. **When a new compatible patch ships, append the patch number to this line** — don't replace existing entries; addon authors are expected to keep the list growing as long as the addon is still compatible with each listed patch.

If a patch breaks the addon, drop the broken patch number from the line *and* note the regression in the README's troubleshooting section.

## `BackdropTemplate` is mandatory for backdrop frames

WoW retail (10.0+) split backdrop functionality off the base Frame and into the `BackdropTemplate` mixin. Frames that need `SetBackdrop` / `SetBackdropColor` / `SetBackdropBorderColor` must declare the template at creation:

```lua
CreateFrame("Frame", "AbsorbTrackerFrame", UIParent, "BackdropTemplate")
```

`UI.lua` does this for the bar; the in-tree LSM dropdown widget at `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/widget.lua` does the same for its popup frame. If a future widget needs a backdrop and forgets the template, the addon will error on `SetBackdrop`.

## Class color sources

Two different paths for the same concept:

- **Bar / border** use `C_ClassColor.GetClassColor(classFile)` directly — Blizzard's official class-color API, returns a `ColorMixin` with `:GetRGBA()`.
- **Background** uses a hard-coded per-class table multiplied by `0.2` to produce a darkened variant. The per-class table mirrors WoW's official class colors (DEATHKNIGHT through WARRIOR); the result is cached in `playerBgClassColor` since the player class doesn't change at runtime.

Why the asymmetry: a bar fill at full class brightness atop a background also at full class brightness washes out the value text. The 0.2 multiplier on the background keeps the absorb fill readable. Picking a fixed darken factor was preferred over computing a perceptually-uniform delta because the result is independent of which class the player is — every class gets the same readability profile.

Both paths resolve at *call* time inside `GetBarColor` / `GetBgColor` / `GetBorderColor`. Class change / respec / profile switch all "just work" without explicit refresh wiring — the next paint reads the current toggle and produces the right color. See [scope.md](./scope.md#resolved-decisions).

## `UNIT_ABSORB_AMOUNT_CHANGED` fires often during heavy combat

The event can fire many times per second during raid encounters with stacking absorbs (Power Word: Shield + trinket procs + Discipline absorbs + …). The handler in `Events.lua` is intentionally a `DebugPrint` only — using it to drive `UpdateAbsorbBar` directly would over-render the StatusBar and string format calls.

The periodic `C_Timer.NewTicker` is the source of truth for visual updates. `updateInterval` is user-configurable (0.1 – 10 s; default 1.0 s). See [data-flow.md](./data-flow.md#absorb-update-path).

## When an event you depend on gets removed in retail

If Blizzard removes an event the addon listens for (it has happened in past retail patches — `LEARNED_SPELL_IN_TAB` was replaced by `LEARNED_SPELL_IN_SKILL_LINE`), the failure mode is that the registration on `frame:RegisterEvent(name)` succeeds but the event never fires. AbsorbTracker only listens for `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, and `UNIT_ABSORB_AMOUNT_CHANGED` — all stable retail events. If a future patch deprecates one, the replacement should be wired by patching `Events.lua`'s frame:RegisterEvent calls; nothing else needs to change.
