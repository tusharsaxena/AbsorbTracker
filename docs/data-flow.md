# Data flow

How values move through the addon at runtime: the two-phase bootstrap (`OnInitialize` → `OnEnable`), the absorb-update path (event → ticker → render), the settings-write path, and the profile-change refresh chain.

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
    ├─▶ NS.UpdateAbsorbBar()           -- initial value paint
    ├─▶ NS.RestartUpdateTicker(true)   -- force-start the AceTimer ticker
    │
    ├─▶ self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "OnAbsorbChanged")
    ├─▶ self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    │
    └─▶ if NS.CreateOptionsPanel then
            NS.CreateOptionsPanel()    -- registers parent + sub-pages
        end
```

Events are AceEvent registrations (`self:RegisterEvent`), not a hidden `CreateFrame` frame. The `if NS.CreateOptionsPanel then ... end` guard is the [forward-reference pattern](./module-map.md#forward-references) — in practice the call always succeeds because all files load synchronously before `OnEnable` fires, but the nil-check keeps the load-order coupling soft.

## Absorb-update path

```
[player gets a shield]
        │
        ▼
UNIT_ABSORB_AMOUNT_CHANGED ─────► OnAbsorbChanged: debug line only
   (AceEvent → addon:OnAbsorbChanged)   (gated on NS.State.debug; no paint)
                                                   │
                                                   ▼
                        AceTimer repeating callback fires
                          every updateInterval seconds
                       (NS.addon:ScheduleRepeatingTimer)
                                                   │
                                                   ▼
                                NS.UpdateAbsorbBar()
                                                   │
                                ┌──────────────────┼──────────────────┐
                                ▼                  ▼                  ▼
                  UnitGetTotalAbsorbs    UnitHealthMax       statusBar:SetValue
                                                              valueText:SetText
                                                              (AbbreviateNumbers)
```

**The decoupling between event and visual update is intentional.** Events can fire many times per second during heavy combat, but the user-configurable `updateInterval` controls actual draw rate. `UNIT_ABSORB_AMOUNT_CHANGED` is registered only so the debug console can capture the exact moment the engine reports a change — and even that read is gated behind `NS.State.debug`, so it costs nothing when debug is off. The visual update is the ticker's job.

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
                                interval:  RestartUpdateTicker()
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
    ├─▶ NS.UpdateAbsorbBar()        -- repaint absorb value against new profile
    │
    ├─▶ NS.ResetTickerInterval()    -- clear tracked interval so the next
    ├─▶ NS.RestartUpdateTicker(true)--   call rebuilds with the new value
    │
    └─▶ if NS.RefreshOptionsPanel then
            NS.RefreshOptionsPanel()  -- routes to Helpers.RefreshAllPanels
        end
```

`Helpers.RefreshAllPanels` walks every registered panel ctx and runs every refresher closure each widget maker registered. Each refresher re-reads its row's value from `db.profile` and pushes it back into the AceGUI widget via `SetValue` / `SetColor` (which AceGUI does NOT fire `OnValueChanged` for — so no recursion). The Profiles sub-page is driven by `AceConfigDialog:Open(...)` and re-pulls its own state on the next show.

## Other events

| Event | Handler | What it does |
|-------|---------|--------------|
| `PLAYER_ENTERING_WORLD` | `addon:OnEnterWorld` | Force `UpdateAbsorbBar`. Handles zone transitions where the engine may have stale state. |
| `UNIT_ABSORB_AMOUNT_CHANGED` (player only) | `addon:OnAbsorbChanged` | Debug line only, and only when `NS.State.debug` is on. The ticker is the source of truth for visual updates — this prevents per-tick spam from over-driving frame updates. |

## Performance budget

The hot path is one AceTimer repeating callback (`NS.addon:ScheduleRepeatingTimer(NS.UpdateAbsorbBar, interval)`) firing every `updateInterval` seconds (default 1.0s, range 0.1 – 10s). Per fire:

1. `UnitGetTotalAbsorbs("player")` + `UnitHealthMax("player")` — engine reads, microseconds each.
2. `AbbreviateNumbers(value)` — string format. (The extra `DebugPrint` allocations are gated behind `NS.State.debug`, so they cost nothing when debug is off.)
3. `statusBar:SetValue` + `valueText:SetText` — both fire on every ticker tick. Frame updates with unchanged values are cheap (Blizzard-side no-op for matching state), so the addon doesn't try to dedupe in Lua.

The ticker itself is guarded: `RestartUpdateTicker` cancels via `NS.addon:CancelTimer` and only rebuilds when the interval actually changed (or the caller passes `forceRestart`), so a steady-state `/at set updateInterval` of the same value doesn't churn the timer.

`UpdateBarAppearance` is heavier (calls `SetBackdrop(nil)` + `SetBackdrop(info)` + texture / font sets) but only runs on settings change or profile change — never per ticker fire.

## Saved variables

Only `AbsorbTrackerDB` is declared in the TOC. With AceDB it holds the full profile structure (`profiles`, `profileKeys`, `char` map, etc.), with per-bar appearance/position under `db.profile` and the persisted schema-version stamp at `db.global.schemaVersion` (account-wide, so `NS:RunMigrations` has one version to walk regardless of the active profile). Without AceDB, `NS:InitDB` builds a minimal `{ profile = AbsorbTrackerDB, global = {} }` shim so `GetSetting` / `SetSetting` reads and writes stay consistent across the two modes. Either way, `NS:RunMigrations` runs once at init and backfills any missing profile key from `NS.flatDefaults`.
