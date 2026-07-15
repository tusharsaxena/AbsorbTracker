# Data flow

How values move through the addon at runtime: the two-phase bootstrap (`OnInitialize` → `OnEnable`), the absorb-update path (event → coalescing repaint scheduler → render), the settings-write path, and the profile-change refresh chain.

## Bootstrap (AceAddon lifecycle)

`core/AbsorbTracker.lua` promotes `NS` into an AceAddon (`AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")`) and stores the object at `NS.addon`. AceAddon then drives two lifecycle callbacks in order — `OnInitialize` at `ADDON_LOADED` timing, `OnEnable` at `PLAYER_LOGIN` timing.

### `addon:OnInitialize` — DB + command registration

```
OnInitialize (ADDON_LOADED)
    │
    ├─▶ LSM:Register("font", "JetBrains Mono", NS.Constants.FONT_MONO)
    │        -- vendored monospace for the debug console
    │
    ├─▶ NS:InitDB()                     -- core/Database.lua
    │     ├─ AceDB:New("AbsorbTrackerDB", NS.defaults, true) → NS.db
    │     │     └─ RegisterCallback OnProfileChanged / OnProfileCopied /
    │     │        OnProfileReset → NS.OnProfileChanged (guarded for headless)
    │     ├─ fallback when AceDB absent:
    │     │     NS.db = { profile = AbsorbTrackerDB, global = {} }
    │     └─ NS:RunMigrations()          -- idempotent; v1 backfills missing
    │                                    --   profile keys from flatDefaults
    │
    └─▶ NS.Slash:Register()             -- settings/Slash.lua registers the
                                        --   /at + /absorbtracker chat commands
```

The flat→profile migration lives in `NS:RunMigrations` (`core/Database.lua`), not in the bootstrap body. Its v1 step walks `NS.flatDefaults` and copies any key still missing from `db.profile` (deep-copying table defaults so a saved-variable mutation can't reach back into the defaults). Because it only fills absent keys, it is a no-op on the second run — this single versioned step absorbs both the legacy pre-AceDB flat-SavedVariables shape and the no-AceDB fallback.

### `addon:OnEnable` — the login body

`OnEnable` reproduces the old `PLAYER_LOGIN` sequence exactly (minus the DB init, which moved earlier into `OnInitialize`):

```
OnEnable (PLAYER_LOGIN timing)
    │
    ├─▶ NS.ClearLSMCache()             -- drop cached LSM ref (late-loading libs)
    ├─▶ NS.GetLSM()                    -- re-fetch LibSharedMedia
    ├─▶ NS.ApplyLSMBorderPatch()       -- suppress upstream LSM30_Border tile
    │
    ├─▶ NS.RestoreBarPosition()        -- re-apply saved position or center
    ├─▶ NS.UpdateBarAppearance()       -- size, textures, colors, border, font
    ├─▶ NS.UpdateAbsorbBar()           -- initial value paint (direct, not via RequestRepaint)
    │
    ├─▶ [private frame] RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player") ─▶ OnAbsorbChanged
    ├─▶ [private frame] RegisterUnitEvent("UNIT_MAXHEALTH", "player")             ─▶ OnMaxHealthChanged
    ├─▶ self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    ├─▶ self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    ├─▶ self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
    │
    └─▶ if NS.CreateOptionsPanel then
            NS.CreateOptionsPanel()    -- registers parent + sub-pages
        end
```

The two `UNIT_*` events go through a **private `CreateFrame` frame** with `RegisterUnitEvent(event, "player")`, not AceEvent — a documented §9.1 deviation ([ARCHITECTURE.md → Standards Deviations](./ARCHITECTURE.md#standards-deviations)). These events fire for *every* unit the client knows about; AceEvent-3.0 shares one frame and cannot `RegisterUnitEvent`, so a plain `RegisterEvent` would pay a C→Lua dispatch per unit only to discard all but `"player"`. The private frame filters at the C layer instead. The three global, payload-free events stay on AceEvent (`self:RegisterEvent`). The `if NS.CreateOptionsPanel then ... end` guard is the [forward-reference pattern](./module-map.md#forward-references) — in practice the call always succeeds because all files load synchronously before `OnEnable` fires, but the nil-check keeps the load-order coupling soft.

## Absorb-update path

```
[player gets a shield]                [max health changes]         [zone transition]
        │                                     │                            │
        ▼                                     ▼                            ▼
UNIT_ABSORB_AMOUNT_CHANGED           UNIT_MAXHEALTH                PLAYER_ENTERING_WORLD
(player only; unit frame →           (player only; unit frame →    (AceEvent →
 addon:OnAbsorbChanged)               addon:OnMaxHealthChanged)     addon:OnEnterWorld)
        │  (also a debug line,               │                            │
        │   gated on NS.State.debug)         │                            │
        └─────────────────┬───────────────────────────────────────────────┘
                           ▼
                  NS.RequestRepaint()
                           │
                           ▼
        pending? ──yes──► coalesce (no-op; a repaint is already queued)
           │no
           ▼
   NS.addon:ScheduleTimer(fn, throttleWindow)   -- trailing-edge one-shot AceTimer
                           │
                           ▼ (fires once, ~throttleWindow seconds later)
                NS.UpdateAbsorbBar()
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
  UnitGetTotalAbsorbs    UnitHealthMax       statusBar:SetValue
                                              valueText:SetText
                                              (AbbreviateNumbers)
```

**Repaints are purely event-driven — there is no polling ticker.** `NS.RequestRepaint()` (`modules/Timer.lua`) is a coalescing scheduler: if a repaint is already queued, a burst of events (heavy combat stacking absorbs) collapses into that single pending repaint instead of scheduling another. The one-shot AceTimer fires once per `throttleWindow` (default 0.1s) and calls `NS.UpdateAbsorbBar()`, then clears itself so the next event starts a fresh cycle. Idle = zero repaints. Login (`OnEnable`) and profile change (`NS.OnProfileChanged`) call `NS.UpdateAbsorbBar()` directly for an immediate paint, bypassing the throttle.

## Settings-write path

```
Slash:  /at set <path> <value>             Panel widget OnValueChanged
            │                                          │
            ▼                                          ▼
setSetting(rest) → ParseSchemaValue      local set(row, value)
            │                          (settings/Widgets.lua — file-local)
            │                                          │
            └────────────────┬─────────────────────────┘
                             ▼
                  NS.SetByPath(path, value)
                             │
                  ┌──────────┴───────────┐
                  ▼                      ▼
       SetSetting(path, v)      fireOnChange(row, v)
       db.profile[path] = v     default:  UpdateBarAppearance()
                                hidden:    UpdateBarAppearance()
                                           + UpdateAbsorbBar()
                             │
                             ▼
                   (slash path → NS.RefreshOptionsPanel;
                    panel set() → Helpers.RefreshAllPanels
                    so paired controls re-sync — disabledIf state,
                    refreshers re-pull every widget value)
                             │
                             ▼
                   GetBarColor / GetBgColor / GetBorderColor
                   re-read live values on the next paint
                   (no caching — class color toggles "just work")
```

The slash and panel paths converge on `NS.SetByPath` (`settings/Schema.lua`) — the single write seam that does `SetSetting` + `fireOnChange`. `fireOnChange` runs `row.onChange` or, absent one, the default `UpdateBarAppearance()`. The panel's local `set(row, value)` (in `settings/Widgets.lua`) calls `SetByPath` then `Helpers.RefreshAllPanels`; the slash dispatcher (`settings/Slash.lua`, `setSetting`) calls `SetByPath` then `NS.RefreshOptionsPanel` (which itself routes to `Helpers.RefreshAllPanels`). Color getters resolve `useClassColor*` at call time, so no explicit "switch class color on" wiring is needed — the next paint reads the current toggle state and produces the right color.

The color-picker widget takes a separate throttled route: mid-drag it writes through `SetByPath` on an `NS.addon:ScheduleTimer` (AceTimer one-shot) window and deliberately skips `RefreshAllPanels` to avoid churning the panel every frame of a drag.

(`AceConfigDialog` is **not** in this path. It's used only inside the Profiles sub-page, where `settings/Profiles.lua` opens the AceDBOptions UI; for every other sub-page the AceGUI widget callbacks call directly into the local `set()` defined in `settings/Widgets.lua`.)

## Profile-change refresh

When AceDB fires one of its profile callbacks, the active `db.profile` flips. The callbacks were wired inside `NS:InitDB` (`core/Database.lua`); all three land on `NS.OnProfileChanged` (`core/AbsorbTracker.lua`), which re-renders the bar and the panel against the new values:

```
OnProfileChanged / OnProfileCopied / OnProfileReset
    │
    ▼
NS.OnProfileChanged()
    │
    ├─▶ NS.RestoreBarPosition()     -- new profile may have a different saved position
    ├─▶ NS.UpdateBarAppearance()    -- size, textures, colors, border, font
    ├─▶ NS.UpdateAbsorbBar()        -- repaint absorb value against new profile (direct paint)
    │
    └─▶ if NS.RefreshOptionsPanel then
            NS.RefreshOptionsPanel()  -- routes to Helpers.RefreshAllPanels
        end
```

`Helpers.RefreshAllPanels` walks every registered panel ctx and runs every refresher closure each widget maker registered. Each refresher re-reads its row's value from `db.profile` and pushes it back into the AceGUI widget via `SetValue` / `SetColor` (which AceGUI does NOT fire `OnValueChanged` for — so no recursion). The Profiles sub-page is driven by `AceConfigDialog:Open(...)` and re-pulls its own state on the next show.

## Visibility composition

`NS.ShouldShowBar()` (`modules/Display.lua`) is the single source of truth for whether the bar is on screen: the master `hidden` toggle wins outright (`hidden == true` → hidden regardless of combat), otherwise `showOnlyInCombat and not UnitAffectingCombat("player")` hides it (the gate keys off actual player combat, **not** `InCombatLockdown()`, which lags the `PLAYER_REGEN_DISABLED` transition — see `docs/midnight-quirks.md`). `NS.ApplyVisibility()` calls `NS.ShouldShowBar()` and shows/hides `NS.bar` accordingly (the bar is a plain, non-secure frame, so this is taint-free even mid-combat). `NS.UpdateBarAppearance()` ends with a call to `NS.ApplyVisibility()`, and `NS.UpdateAbsorbBar()` early-returns (skipping the paint) when `NS.ShouldShowBar()` is false — so both the settings-write path and the repaint path stay consistent with the combat gate without each caller re-deriving it.

## Other events

| Event | Handler | What it does |
|-------|---------|--------------|
| `PLAYER_ENTERING_WORLD` | `addon:OnEnterWorld` | `NS.ApplyVisibility()` + `NS.RequestRepaint()`. Handles zone transitions where the engine may have stale state (and re-evaluates the combat-visibility gate on load/reload). |
| `UNIT_ABSORB_AMOUNT_CHANGED` (player only — private `RegisterUnitEvent` frame, C-level filter) | `addon:OnAbsorbChanged` | Debug line (gated on `NS.State.debug`) then `NS.RequestRepaint()`. |
| `UNIT_MAXHEALTH` (player only — private `RegisterUnitEvent` frame, C-level filter) | `addon:OnMaxHealthChanged` | `NS.RequestRepaint()`. The bar shows absorb as a fraction of max health, so a max-health change (buffs, stamina, level) must repaint even when the absorb value itself is unchanged. |
| `PLAYER_REGEN_DISABLED` (enter combat) | `addon:OnEnterCombat` | `NS.ApplyVisibility()` + `NS.RequestRepaint()` — re-evaluates the `showOnlyInCombat` gate so the bar appears (and repaints fresh) the moment combat starts. |
| `PLAYER_REGEN_ENABLED` (leave combat) | `addon:OnLeaveCombat` | `NS.ApplyVisibility()` + `NS.RequestRepaint()` — nothing else. Per options-ui-§2 the settings panel **refuses** to open in combat (`settings/Panel.lua` prints a grey notice and returns) rather than deferring, so there is no combat-deferred `/at config` for `OnLeaveCombat` to replay. It is the sole handler of `PLAYER_REGEN_ENABLED`, and its only job is re-evaluating the `showOnlyInCombat` visibility gate and repainting. |

## Performance budget

The hot path is `NS.RequestRepaint()` (`modules/Timer.lua`) — a coalescing repaint scheduler, not a polling loop. A burst of `UNIT_ABSORB_AMOUNT_CHANGED` events during combat collapses into a single pending one-shot AceTimer (`NS.addon:ScheduleTimer(fn, throttleWindow)`, default 0.1s, range 0.05 – 1s); repeat calls while one is already pending are a no-op. Idle = zero repaints. Per fire of the resulting `NS.UpdateAbsorbBar()`:

1. `UnitGetTotalAbsorbs("player")` + `UnitHealthMax("player")` — engine reads, microseconds each.
2. `AbbreviateNumbers(value)` — string format. (`NS.Debug` no longer logs per-repaint — `UpdateAbsorbBar` bumps a debug-gated repaint counter via `NS.NoteRepaint()`, coalesced into the one `[Combat]` rollup line at `OnLeaveCombat`; any remaining debug work is gated behind `NS.State.debug`, so it costs nothing when debug is off.)
3. `statusBar:SetValue` + `valueText:SetText` — both fire on every repaint. Frame updates with unchanged values are cheap (Blizzard-side no-op for matching state), so the addon doesn't try to dedupe in Lua.

There is no repeating ticker to guard: the one-shot timer self-clears (`pending = nil`) inside its own callback, so there's nothing to cancel between repaints.

`UpdateBarAppearance` is heavier (calls `SetBackdrop(nil)` + `SetBackdrop(info)` + texture / font sets) but only runs on settings change or profile change — never per repaint.

## Saved variables

Only `AbsorbTrackerDB` is declared in the TOC. With AceDB it holds the full profile structure (`profiles`, `profileKeys`, `char` map, etc.), with per-bar appearance/position under `db.profile` and the persisted schema-version stamp at `db.global.schemaVersion` (account-wide, so `NS:RunMigrations` has one version to walk regardless of the active profile). Without AceDB, `NS:InitDB` builds a minimal `{ profile = AbsorbTrackerDB, global = {} }` shim so `GetSetting` / `SetSetting` reads and writes stay consistent across the two modes. Either way, `NS:RunMigrations` runs once at init and backfills any missing profile key from `NS.flatDefaults`.
