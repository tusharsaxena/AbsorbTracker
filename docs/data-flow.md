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
    │     └─ NS:RunMigrations()          -- idempotent; v3 lifts flat appearance
    │                                    --   keys onto profile.units.player,
    │                                    --   backfills missing keys (flat +
    │                                    --   per-unit), v2 drops updateInterval
    │
    └─▶ NS.Slash:Register()             -- settings/Slash.lua registers the
                                        --   /at + /absorbtracker chat commands
```

The flat→profile migration lives in `NS:RunMigrations` (`core/Database.lua`), not in the bootstrap body, and runs its steps in this order:

1. **v3 lift** (`migrateAllProfiles` → `NS.MigrateProfileToV3`, gated per profile on `profile.schemaVersion < 3`): moves the pre-v3 flat appearance keys (`barWidth`, `barColor`, `position`, ...) onto `profile.units.player`, overwriting whatever the backfill step below would otherwise seed there, clears the flat originals, and stamps that profile at 3. It runs over the active profile **and every profile in the raw saved store** (`db.sv.profiles`, guarded — the no-AceDB shim has none), because the lift is a per-profile mutation: migrating only the active profile would strand every other pre-v3 profile's saved layout forever. **Gated on a version stamp, not on `profile.units == nil`** — under real AceDB-3.0, the very act of reading `NS.db.profile` already triggered AceDB's own `copyDefaults` (its `dbmt.__index` lazily fills every missing key, including the whole new `units` table, straight from `NS.defaults`), so on a real upgrading install `profile.units` is *never* nil by the time this runs — a `units == nil` guard would make the whole block permanently dead, silently orphaning the user's pre-v3 values under brand-new factory defaults. The stamp is the only reliable "does this profile predate v3" signal, because `copyDefaults` only ever fills an *absent* key — which is also why the per-profile default is `1`, not `3` (see [profiles.md](./profiles.md)). `NS.OnProfileChanged` re-runs the same per-profile lift for any profile that only appears after this sweep.
2. **Backfill** (unconditional, idempotent): walks `NS.defaults.profile` and copies any key still missing from `db.profile` — both the four flat globals and, per unit in `NS.Units.LIST`, any missing per-unit appearance key (deep-copying table defaults so a saved-variable mutation can't reach back into the defaults). Because it only fills absent keys, it is a no-op on the second run — this step absorbs the legacy pre-AceDB flat-SavedVariables shape and the no-AceDB fallback.
3. **v2 bump** (`g.schemaVersion < 2`): retires the dead `profile.updateInterval` key (the repaint path moved from a poll ticker to the event-driven `throttleWindow` scheduler) and stamps `schemaVersion = 2`.
4. **v3 bump** (`g.schemaVersion < 3`): stamps the account-wide `schemaVersion = 3`. This is the DB-wide marker; the *per-profile* stamps were already written in step 1.
5. **v4 bump** (`g.schemaVersion < 4`): drops the dead `hidden` master toggle from **every** profile in the store via `dropKeyEverywhere` (same all-profiles reasoning as the v3 lift — a key left on an inactive profile returns the moment the user switches to it), then stamps `schemaVersion = 4`. The per-unit `enabled` flags replaced it, so a surviving `hidden = true` would suppress every bar with no UI left to clear it.

Both version bumps are idempotent and log one `[Migrate]` line only when they actually fire.

### `addon:OnEnable` — the login body

`OnEnable` reproduces the old `PLAYER_LOGIN` sequence exactly (minus the DB init, which moved earlier into `OnInitialize`):

```
OnEnable (PLAYER_LOGIN timing)
    │
    ├─▶ NS.ClearLSMCache()             -- drop cached LSM ref (late-loading libs)
    ├─▶ NS.GetLSM()                    -- re-fetch LibSharedMedia
    ├─▶ NS.ApplyLSMBorderPatch()       -- suppress upstream LSM30_Border tile
    │
    ├─▶ NS.bus:SendMessage(NS.MSG.POSITION)    -- ▶ Display: re-apply saved position or center
    ├─▶ NS.bus:SendMessage(NS.MSG.APPEARANCE)  -- ▶ Display: size, textures, colors, border, font
    ├─▶ NS.bus:SendMessage(NS.MSG.REPAINT)     -- ▶ Timer: coalesced initial value paint
    │
    ├─▶ self:SyncUnitEventFrames()
    │     ├─ [private frame A] RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player","target")
    │     ├─ [private frame A] RegisterUnitEvent("UNIT_MAXHEALTH", "player","target")
    │     ├─ [private frame B] RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "focus")
    │     └─ [private frame B] RegisterUnitEvent("UNIT_MAXHEALTH", "focus")
    │           both frames share one OnEvent stub ─▶ OnAbsorbChanged / OnMaxHealthChanged
    ├─▶ self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    ├─▶ self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    ├─▶ self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
    ├─▶ self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitSwap")
    ├─▶ self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitSwap")
    │
    └─▶ if NS.CreateOptionsPanel then
            NS.CreateOptionsPanel()    -- registers parent + sub-pages
        end
```

The two `UNIT_*` events go through **two private `CreateFrame` frames** with `RegisterUnitEvent`, not AceEvent — a documented §9.1 deviation ([ARCHITECTURE.md → Standards Deviations](./ARCHITECTURE.md#standards-deviations)). These events fire for *every* unit the client knows about; AceEvent-3.0 shares one frame and cannot `RegisterUnitEvent`, so a plain `RegisterEvent` would pay a C→Lua dispatch per unit only to discard all but ours. The private frames filter at the C layer instead. **Two frames are required, not one:** `RegisterUnitEvent` filters at most two unit tokens per registration, and the addon now tracks three (player/target/focus) — frame A takes player+target, frame B takes the leftover focus. The five global, payload-free events (`PLAYER_ENTERING_WORLD`, the combat pair, and the target/focus-swap pair) stay on AceEvent (`self:RegisterEvent`). The `if NS.CreateOptionsPanel then ... end` guard is the [forward-reference pattern](./module-map.md#forward-references) — in practice the call always succeeds because all files load synchronously before `OnEnable` fires, but the nil-check keeps the load-order coupling soft.

## Absorb-update path

```
[a tracked unit gets a shield]       [max health changes]     [target/focus swap]   [zone transition]
        │                                     │                       │                    │
        ▼                                     ▼                       ▼                    ▼
UNIT_ABSORB_AMOUNT_CHANGED           UNIT_MAXHEALTH          PLAYER_TARGET_CHANGED  PLAYER_ENTERING_WORLD
(player/target/focus; two private     (player/target/focus;   / PLAYER_FOCUS_       (AceEvent →
 unit-event frames →                   two private frames →    CHANGED (AceEvent →   addon:OnEnterWorld)
 addon:OnAbsorbChanged)                 addon:OnMaxHealthChanged) addon:OnUnitSwap)
        │  (debug line, player-only,          │                       │                    │
        │   gated on NS.State.debug)          │                       │ also VISIBILITY     │
        └─────────────────┬────────────────────────────────────────────┴────────────────────┘
                           ▼
        NS.bus:SendMessage(NS.MSG.REPAINT)   -- producers publish; never call Display directly
                           │
                           ▼
   [Timer's NS.Timer.__ev subscriber] ─▶ NS.RequestRepaint()
                           │
                           ▼
        pending? ──yes──► coalesce (no-op; a repaint is already queued)
           │no
           ▼
   NS.addon:ScheduleTimer(fn, throttleWindow)   -- trailing-edge one-shot AceTimer
                           │
                           ▼ (fires once, ~throttleWindow seconds later)
                NS.UpdateAbsorbBar()             -- direct intra-concern call (Timer → Display),
                           │                        called once per unit via NS.ForEachUnit
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
  UnitGetTotalAbsorbs(unit) UnitHealthMax(unit) statusBar:SetValue
                                              valueText:SetText
                                              (AbbreviateNumbers)
```

**One coalesced repaint fans out to all three bars — not three separate schedules.** A single `REPAINT` message (however it was triggered — an absorb event on any of the three units, a max-health change, a target/focus swap, or a zone transition) reaches `NS.RequestRepaint()` exactly once; when its one-shot AceTimer fires, `NS.UpdateAbsorbBar` runs once **per unit** via `NS.ForEachUnit` (`modules/Display.lua`), reading each unit's own `UnitGetTotalAbsorbs(unit)` / `UnitHealthMax(unit)`. There is no per-unit throttle bookkeeping — `throttleWindow` and the coalescing pending-flag are both global.

**Repaints are purely event-driven — there is no polling ticker.** Producers never call the display module directly; they publish `NS.MSG.REPAINT` on the bus (architecture-§4, see [ARCHITECTURE.md → Message Bus](./ARCHITECTURE.md#message-bus)). `modules/Timer.lua` owns the sole `REPAINT` subscription (on its own `NS.Timer.__ev` target) and funnels it through `NS.RequestRepaint()`, a coalescing scheduler: if a repaint is already queued, a burst of events (heavy combat stacking absorbs) collapses into that single pending repaint instead of scheduling another. The one-shot AceTimer fires once per `throttleWindow` (default 0.1s) and calls `NS.UpdateAbsorbBar()` for every unit (a direct intra-concern call, Timer → Display), then clears itself so the next event starts a fresh cycle. Idle = zero repaints. Login (`OnEnable`), profile change (`NS.OnProfileChanged`), and the `/at update` verb also publish `REPAINT` — they coalesce through the same throttle rather than painting directly. `/at toggle` publishes nothing itself: it writes through `NS.SetByPath`, and the `hidden` row's `onChange` (`settings/General.lua`) publishes `APPEARANCE` plus — only when the bar is becoming visible — `REPAINT`, so the verb and the panel's **Show Bar** checkbox travel one path.

**Mirror resolution sits between the schema read and the paint, not inside the repaint path itself.** `UpdateAbsorbBar` and `UpdateBarAppearance` never read `db.profile.units` directly — every appearance value comes from `NS.Units.Get(unit, key)` (`core/Units.lua`), which resolves `NS.Units.SourceUnit(unit)` (the player, if `unit` is mirrored; `unit` itself otherwise) *before* reading the config table. So a mirrored target bar's repaint reads the player's texture/color/font settings on every paint — live, not snapshotted — while its absorb value (`UnitGetTotalAbsorbs("target")`) and position stay the target's own, since neither is ever mirrored.

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
       SetSetting(path, v)      fireOnChange(row, v)  -- publishes, never calls Display directly
       NS.SetPath(db.profile,   default:  bus ▶ APPEARANCE
         path, v)  -- walks dotted
         paths (units.<unit>.<key>)
         same as flat ones
                                enabled:   bus ▶ UNITS + APPEARANCE (+ REPAINT when on)
                                combat:    bus ▶ VISIBILITY (+ REPAINT when shown)
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

The slash and panel paths converge on `NS.SetByPath` (`settings/Schema.lua`) — the single write seam that does `SetSetting` + `fireOnChange`. `fireOnChange` runs `row.onChange` or, absent one, the default handler that publishes `NS.MSG.APPEARANCE` on the bus (so the write path signals the display module instead of calling `UpdateBarAppearance` across the module boundary). The panel's local `set(row, value)` (in `settings/Widgets.lua`) calls `SetByPath` then `Helpers.RefreshAllPanels`; the slash dispatcher (`settings/Slash.lua`, `setSetting`) calls `SetByPath` then `NS.RefreshOptionsPanel` (which itself routes to `Helpers.RefreshAllPanels`). Color getters resolve `useClassColor*` at call time, so no explicit "switch class color on" wiring is needed — the next paint reads the current toggle state and produces the right color.

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
    ├─▶ NS.bus:SendMessage(NS.MSG.POSITION)    -- ▶ Display: new profile's saved position
    ├─▶ NS.bus:SendMessage(NS.MSG.APPEARANCE)  -- ▶ Display: size, textures, colors, border, font
    ├─▶ NS.bus:SendMessage(NS.MSG.REPAINT)     -- ▶ Timer: repaint absorb value against new profile
    │
    └─▶ if NS.RefreshOptionsPanel then
            NS.RefreshOptionsPanel()  -- routes to Helpers.RefreshAllPanels
        end
```

`Helpers.RefreshAllPanels` walks every registered panel ctx and runs every refresher closure each widget maker registered. Each refresher re-reads its row's value from `db.profile` and pushes it back into the AceGUI widget via `SetValue` / `SetColor` (which AceGUI does NOT fire `OnValueChanged` for — so no recursion). The Profiles sub-page is driven by `AceConfigDialog:Open(...)` and re-pulls its own state on the next show.

## Visibility composition

`NS.ShouldShowBar(unit)` (`modules/Display.lua`) is the single source of truth for whether a given unit's bar is on screen — a four-step ladder, first `false` wins:

1. the per-unit `NS.Units.IsEnabled(unit)` flag (target/focus ship `false`) — there is no master `hidden` toggle above it any more; schema v4 dropped it, and these three flags ARE the visibility switch,
2. `showOnlyInCombat and not UnitAffectingCombat("player")` (the gate keys off actual player combat, **not** `InCombatLockdown()`, which lags the `PLAYER_REGEN_DISABLED` transition — see `docs/midnight-quirks.md`),
3. for target/focus only, `UnitExists(unit)` — **not** an absorb comparison (`UnitGetTotalAbsorbs` is a secret in restricted content and comparing it to zero raises; the same constraint recorded in `docs/scope.md` for the declined audio-alert feature),
4. otherwise shown.

A disabled unit is also unregistered from its absorb / max-health events entirely (`addon:SyncUnitEventFrames`, driven by the `UNITS` message), so step 1 rarely even gets the chance to reject a paint — the event that would have triggered it never reaches Lua.

`NS.ApplyVisibility(unit)` calls `NS.ShouldShowBar(unit)` and shows/hides that unit's bar frame accordingly (all three bar frames are plain, non-secure frames, so this is taint-free even mid-combat). `NS.UpdateBarAppearance(unit)` ends with a call to `NS.ApplyVisibility(unit)`, and `NS.UpdateAbsorbBar(unit)` early-returns (skipping the paint) when `NS.ShouldShowBar(unit)` is false — so both the settings-write path and the repaint path stay consistent with the same ladder without each caller re-deriving it. The bus handlers (`APPEARANCE`/`VISIBILITY`/`POSITION`) call these per-unit functions once for each of `NS.Units.LIST` via `NS.ForEachUnit`.

## Other events

| Event | Handler | What it does |
|-------|---------|--------------|
| `PLAYER_ENTERING_WORLD` | `addon:OnEnterWorld` | Publishes `VISIBILITY` + `REPAINT`. Handles zone transitions where the engine may have stale state (and re-evaluates the combat-visibility gate on load/reload). |
| `UNIT_ABSORB_AMOUNT_CHANGED` (player, target, focus — two private `RegisterUnitEvent` frames, C-level filter) | `addon:OnAbsorbChanged` | Debug line (player-only, gated on `NS.State.debug`) then publishes `REPAINT`. |
| `UNIT_MAXHEALTH` (player, target, focus — two private `RegisterUnitEvent` frames, C-level filter) | `addon:OnMaxHealthChanged` | Publishes `REPAINT`. Every bar shows absorb as a fraction of max health, so a max-health change (buffs, stamina, level) must repaint even when the absorb value itself is unchanged. |
| `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` (AceEvent, global) | `addon:OnUnitSwap` | Publishes `VISIBILITY` + `REPAINT`. A swap changes both which bars should be visible (step 4 of the ladder, `UnitExists`) and what they should read. |
| `PLAYER_REGEN_DISABLED` (enter combat) | `addon:OnEnterCombat` | Publishes `VISIBILITY` + `REPAINT` — re-evaluates the `showOnlyInCombat` gate so any eligible bar appears (and repaints fresh) the moment combat starts. |
| `PLAYER_REGEN_ENABLED` (leave combat) | `addon:OnLeaveCombat` | Publishes `VISIBILITY` + `REPAINT` — nothing else. Per options-ui-§2 the settings panel **refuses** to open in combat (`settings/Panel.lua` prints a grey notice and returns) rather than deferring, so there is no combat-deferred `/at config` for `OnLeaveCombat` to replay. It is the sole handler of `PLAYER_REGEN_ENABLED`, and its only job is re-evaluating the `showOnlyInCombat` visibility gate and repainting. |

## Performance budget

The hot path is `NS.RequestRepaint()` (`modules/Timer.lua`), reached via the bus — the `UNIT_*` handlers publish `NS.MSG.REPAINT` and Timer's subscriber funnels it into this coalescing repaint scheduler, not a polling loop. The bus hop is a single synchronous CallbackHandler dispatch to one registered target (no allocation), negligible next to the engine reads below. A burst of `UNIT_ABSORB_AMOUNT_CHANGED` events during combat — from any of the three tracked units — collapses into a single pending one-shot AceTimer (`NS.addon:ScheduleTimer(fn, throttleWindow)`, default 0.1s, range 0.05 – 1s); repeat calls while one is already pending are a no-op. Idle = zero repaints. When it fires, `NS.UpdateAbsorbBar()` runs once per unit via `NS.ForEachUnit`; per unit:

1. `UnitGetTotalAbsorbs(unit)` + `UnitHealthMax(unit)` — engine reads, microseconds each.
2. `AbbreviateNumbers(value)` — string format. (`NS.Debug` no longer logs per-repaint — `UpdateAbsorbBar` bumps a debug-gated repaint counter via `NS.NoteRepaint()`, coalesced into the one `[Combat]` rollup line at `OnLeaveCombat` — player events only, deliberately, so the printed count matches what it reports; any remaining debug work is gated behind `NS.State.debug`, so it costs nothing when debug is off.)
3. `statusBar:SetValue` + `valueText:SetText` — both fire on every repaint. Frame updates with unchanged values are cheap (Blizzard-side no-op for matching state), so the addon doesn't try to dedupe in Lua.

There is no repeating ticker to guard: the one-shot timer self-clears (`pending = nil`) inside its own callback, so there's nothing to cancel between repaints.

`UpdateBarAppearance` is heavier (calls `SetBackdrop(nil)` + `SetBackdrop(info)` + texture / font sets) but only runs on settings change or profile change — never per repaint.

## Saved variables

Only `AbsorbTrackerDB` is declared in the TOC. With AceDB it holds the full profile structure (`profiles`, `profileKeys`, `char` map, etc.); `db.profile` holds the four flat globals plus `units.{player,target,focus}` (each unit's own appearance + position table), and the persisted schema-version stamp lives at `db.global.schemaVersion` (account-wide, the DB-wide marker — currently `3`, the version that introduced `profile.units`) with a second, **per-profile** stamp at `db.profile.schemaVersion` gating the per-profile v3 lift (a documented §5.1 deviation — see [profiles.md](./profiles.md)). Without AceDB, `NS:InitDB` builds a minimal `{ profile = AbsorbTrackerDB, global = {} }` shim so `GetSetting` / `SetSetting` reads and writes stay consistent across the two modes. Either way, `NS:RunMigrations` runs once at init and backfills any missing profile key (flat or per-unit) from `NS.defaults.profile`.
