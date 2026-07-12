# Data flow

How values move through the addon at runtime: the bootstrap on PLAYER_LOGIN, the absorb-update path (event → ticker → render), the settings-write path, and the profile-change refresh chain.

## Bootstrap (PLAYER_LOGIN)

`Events.lua` registers a hidden frame for three events. PLAYER_LOGIN is the bootstrap:

```
PLAYER_LOGIN
    │
    ├─▶ Try LibStub("AceDB-3.0"):New("AbsorbTrackerDB", NS.defaults, true)
    │     ├─ success → NS.db = the AceDB instance
    │     └─ failure → fallback shim:
    │                  NS.db = { profile = AbsorbTrackerDB }
    │                  seed missing keys from flatDefaults
    │
    ├─▶ NS.ClearLSMCache()             -- handle late-loading LSM
    │
    ├─▶ NS.RestoreBarPosition()        -- re-apply saved position or center
    ├─▶ NS.UpdateBarAppearance()       -- size, textures, colors, border, font
    ├─▶ NS.UpdateAbsorbBar()           -- initial value paint
    │
    ├─▶ NS.RestartUpdateTicker()       -- start the periodic ticker
    │
    └─▶ if NS.CreateOptionsPanel then
            NS.CreateOptionsPanel()    -- registers parent + 5 sub-pages
        end
```

The `if NS.CreateOptionsPanel then ... end` guard is the [forward-reference pattern](./module-map.md#forward-references). In practice the call always succeeds because all files load synchronously before any event fires, but the nil-check keeps the load-order coupling soft.

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
                                NS.UpdateAbsorbBar()
                                                   │
                                ┌──────────────────┼──────────────────┐
                                ▼                  ▼                  ▼
                  UnitGetTotalAbsorbs    UnitHealthMax       statusBar:SetValue
                                                              valueText:SetText
                                                              (AbbreviateNumbers)
```

**The decoupling between event and visual update is intentional.** Events can fire many times per second during heavy combat, but the user-configurable `updateInterval` controls actual draw rate. `UNIT_ABSORB_AMOUNT_CHANGED` is registered only so debug logs can capture the exact moment the engine reports a change; the visual update is the ticker's job.

## Settings-write path

```
Slash:  /at set <path> <value>             Panel widget OnValueChanged
            │                                          │
            ▼                                          ▼
ParseSchemaValue(row, text)            local set(row, value)
            │                          (settings/Widgets.lua — file-local)
            │                                          │
            └────────────────┬─────────────────────────┘
                             ▼
                  NS.SetByPath(path, value)
                             │
                  ┌──────────┴───────────┐
                  ▼                      ▼
       SetSetting(path, v)      fire row.onChange
       db.profile[path] = v     default: UpdateBarAppearance()
                                interval: RestartUpdateTicker()
                                hidden:   UpdateBarAppearance()
                                          + UpdateAbsorbBar()
                             │
                             ▼
                   (slash path returns to caller; panel widget's
                    local set() then runs Helpers.RefreshAllPanels
                    so paired controls re-sync — paired disabledIf
                    state, refreshers re-pull every widget value)
                             │
                             ▼
                   GetBarColor / GetBgColor / GetBorderColor
                   re-read live values on the next paint
                   (no caching — class color toggles "just work")
```

The slash and panel paths converge on `SetByPath`. The panel's local `set(row, value)` (in `settings/Widgets.lua`) calls `SetByPath` then `Helpers.RefreshAllPanels`; the slash dispatcher (`SlashCommands.lua`) calls `SetByPath` then `RefreshOptionsPanel` (which itself routes to `Helpers.RefreshAllPanels`). Color getters resolve `useClassColor*` at call time, so no explicit "switch class color on" wiring is needed — the next paint reads the current toggle state and produces the right color.

(`AceConfigDialog` is **not** in this path. It's used only inside the Profiles sub-page, where `settings/Profiles.lua` opens the AceDBOptions UI; for every other sub-page the AceGUI widget callbacks call directly into the local `set()` defined in `settings/Widgets.lua`.)

## Profile-change refresh

When AceDB fires one of its profile callbacks, the active `db.profile` flips. The bar and panel both need to re-render against the new values:

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
| `PLAYER_ENTERING_WORLD` | inline handler | Force `UpdateAbsorbBar`. Handles zone transitions where the engine may have stale state. |
| `UNIT_ABSORB_AMOUNT_CHANGED` (player only) | inline handler | `DebugPrint` only. The ticker is the source of truth for visual updates — this prevents per-tick spam from over-driving frame updates. |

## Performance budget

The hot path is one `C_Timer.NewTicker` callback firing every `updateInterval` seconds (default 1.0s, range 0.1 – 10s). Per fire:

1. `UnitGetTotalAbsorbs("player")` + `UnitHealthMax("player")` — engine reads, microseconds each.
2. `AbbreviateNumbers(value)` — string format.
3. `statusBar:SetValue` + `valueText:SetText` — both fire on every ticker tick. Frame updates with unchanged values are cheap (Blizzard-side no-op for matching state), so the addon doesn't try to dedupe in Lua.

`UpdateBarAppearance` is heavier (calls `SetBackdrop(nil)` + `SetBackdrop(info)` + texture / font sets) but only runs on settings change or profile change — never per ticker fire.

## Saved variables

Only `AbsorbTrackerDB` is declared in the TOC. With AceDB it holds the full profile structure (`profiles`, `profileKeys`, `defaults`, `char` map, etc.). Without AceDB it's a flat table that *is* the single profile — `Events.lua` seeds missing keys from `flatDefaults` to keep `GetSetting` reads consistent across the two modes.
