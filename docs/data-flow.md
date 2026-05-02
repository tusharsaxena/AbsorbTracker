# Data flow

How values move through the addon at runtime: the bootstrap on PLAYER_LOGIN, the absorb-update path (event → ticker → render), the settings-write path, and the profile-change refresh chain.

## Bootstrap (PLAYER_LOGIN)

`Events.lua` registers a hidden frame for three events. PLAYER_LOGIN is the bootstrap:

```
PLAYER_LOGIN
    │
    ├─▶ Try LibStub("AceDB-3.0"):New("AbsorbTrackerDB", AddonTable.defaults, true)
    │     ├─ success → AddonTable.db = the AceDB instance
    │     └─ failure → fallback shim:
    │                  AddonTable.db = { profile = AbsorbTrackerDB }
    │                  seed missing keys from flatDefaults
    │
    ├─▶ AddonTable.ClearLSMCache()             -- handle late-loading LSM
    │
    ├─▶ AddonTable.RestoreBarPosition()        -- re-apply saved position or center
    ├─▶ AddonTable.UpdateBarAppearance()       -- size, textures, colors, border, font
    ├─▶ AddonTable.UpdateAbsorbBar()           -- initial value paint
    │
    ├─▶ AddonTable.RestartUpdateTicker()       -- start the periodic ticker
    │
    └─▶ if AddonTable.CreateOptionsPanel then
            AddonTable.CreateOptionsPanel()    -- registers parent + 5 sub-pages
        end
```

The `if AddonTable.CreateOptionsPanel then ... end` guard is the [forward-reference pattern](./module-map.md#forward-references). In practice the call always succeeds because all files load synchronously before any event fires, but the nil-check keeps the load-order coupling soft.

## Absorb-update path

```
[player gets a shield]
        │
        ▼
UNIT_ABSORB_AMOUNT_CHANGED ─────► DebugPrint only (no visual update)
                                                   │
                                                   ▼
                                C_Timer.NewTicker fires
                                  every updateInterval seconds
                                                   │
                                                   ▼
                                AddonTable.UpdateAbsorbBar()
                                                   │
                                ┌──────────────────┼──────────────────┐
                                ▼                  ▼                  ▼
                  UnitGetTotalAbsorbs    UnitHealthMax       statusBar:SetValue
                                                              valueText:SetText
                                                              (AbbreviateNumbers)
```

**The decoupling between event and visual update is intentional.** Events can fire many times per second during heavy combat, but the user-configurable `updateInterval` controls actual draw rate. `UNIT_ABSORB_AMOUNT_CHANGED` is registered only so debug logs can capture the exact moment the engine reports a change; the visual update is the ticker's job.

`AddonTable.lastAbsorb` short-circuits redundant ticker fires — when the new value matches the cached one, the function returns early without touching frames. Resetting `lastAbsorb = -1` (done by the `hidden` toggle's `onChange` and by `PLAYER_ENTERING_WORLD`) forces the next call to repaint.

## Settings-write path

```
Slash:  /at set <path> <value>             Panel widget set callback
            │                                          │
            ▼                                          ▼
ParseSchemaValue(row, text)            AceConfigDialog → row.set
            │                                          │
            └────────────────┬─────────────────────────┘
                             ▼
                  AddonTable.SetByPath(path, value)
                             │
                  ┌──────────┼─────────────┐
                  ▼          ▼             ▼
       SetSetting(path,v)  fire row.onChange
       db.profile[path]
       = v                  default: UpdateBarAppearance()
                            interval: RestartUpdateTicker()
                            hidden:   UpdateBarAppearance()
                                      + lastAbsorb=-1
                                      + UpdateAbsorbBar()
                             │
                             ▼
                   GetBarColor / GetBgColor / GetBorderColor
                   re-read live values, push to frames
```

The slash and panel paths converge on `SetByPath`. Color getters resolve `useClassColor*` at call time, so no explicit "switch class color on" wiring is needed — the next paint reads the current toggle state and produces the right color.

## Profile-change refresh

When AceDB fires one of its profile callbacks, the active `db.profile` flips. The bar and panel both need to re-render against the new values:

```
OnProfileChanged / OnProfileCopied / OnProfileReset
    │
    ▼
AddonTable.OnProfileChanged()
    │
    ├─▶ AddonTable.RestoreBarPosition()     -- new profile may have a different saved position
    ├─▶ AddonTable.UpdateBarAppearance()    -- size, textures, colors, border, font
    ├─▶ AddonTable.UpdateAbsorbBar()        -- repaint with cleared lastAbsorb
    │
    ├─▶ AddonTable.ResetTickerInterval()    -- clear tracked interval so the next
    ├─▶ AddonTable.RestartUpdateTicker(true)--   call rebuilds with the new value
    │
    └─▶ if AddonTable.RefreshOptionsPanel then
            AddonTable.RefreshOptionsPanel()  -- AceConfigRegistry:NotifyChange per page
        end
```

`AceConfigRegistry:NotifyChange` is per-namespace, so it's called once per registered sub-page (`AbsorbTracker-general`, `AbsorbTracker-bar`, ...). Closure-based widget callbacks already read live from `db.profile`, so the underlying values are already correct as soon as `db.profile` flips — `NotifyChange` just makes the on-screen widgets re-pull.

## Other events

| Event | Handler | What it does |
|-------|---------|--------------|
| `PLAYER_ENTERING_WORLD` | `OnPlayerEnteringWorld` | Reset `lastAbsorb = -1` and force `UpdateAbsorbBar`. Handles zone transitions where the engine may have stale state. |
| `UNIT_ABSORB_AMOUNT_CHANGED` (player only) | `OnUnitAbsorbChanged` | `DebugPrint` only. The ticker is the source of truth for visual updates — this prevents per-tick spam from over-driving frame updates. |

## Performance budget

The hot path is one `C_Timer.NewTicker` callback firing every `updateInterval` seconds (default 1.0s, range 0.1 – 10s). Per fire:

1. `UnitGetTotalAbsorbs("player")` + `UnitHealthMax("player")` — engine reads, microseconds each.
2. `AbbreviateNumbers(value)` — string format.
3. `statusBar:SetValue` + `valueText:SetText` — frame updates only when value changes (the `lastAbsorb` short-circuit elides frame mutation when the value is unchanged).

`UpdateBarAppearance` is heavier (calls `SetBackdrop(nil)` + `SetBackdrop(info)` + texture / font sets) but only runs on settings change or profile change — never per ticker fire.

## Saved variables

Only `AbsorbTrackerDB` is declared in the TOC. With AceDB it holds the full profile structure (`profiles`, `profileKeys`, `defaults`, `char` map, etc.). Without AceDB it's a flat table that *is* the single profile — `Events.lua` seeds missing keys from `flatDefaults` to keep `GetSetting` reads consistent across the two modes.
