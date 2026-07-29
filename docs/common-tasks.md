# Common tasks

Recipes for the routine modifications. For deeper context on any module, see [module-map.md](./module-map.md) and the per-topic docs.

## Add a new setting (General page — a flat, unit-agnostic global)

This recipe is for a **flat** setting like `locked` / `showOnlyInCombat` / `throttleWindow` — one that governs all three bars at once and belongs on the General page. For a Bar/Border/Font appearance setting that should exist per unit, see [Add a per-unit setting](#add-a-per-unit-setting) below instead.

The schema-driven design makes a flat setting a one-row change. The widget on the General sub-page AND the `/at set <path>` CLI come for free.

1. **Pick a `path` and a default.** The `path` is the `db.profile` key (and the `/at set <path>` argument). The default goes in `defaults/Profile.lua`'s `NS.defaults.profile`, alongside the four existing flat globals (not inside `units`):

   ```lua
   -- defaults/Profile.lua
   NS.defaults.profile = {
       -- ... locked, showOnlyInCombat, throttleWindow ...
       myNewKnob = 42,
       units = { ... },
   }
   ```

   `NS.flatDefaults` is an alias for `NS.defaults.profile`, so General's schema rows can read per-key defaults from it. `NS:RunMigrations` (core/Database.lua) backfills any missing profile key from `NS.defaults.profile` on load, so existing profiles pick up the new key automatically.

2. **Append a schema row** in `settings/General.lua`:

   ```lua
   -- settings/General.lua
   local addonName, NS = ...
   local flatDefaults = NS.flatDefaults

   NS.RegisterSchemaRows({
       -- ... existing rows ...
       { path = "myNewKnob", page = "general", group = "Master controls", order = 50,
         type = "number", label = "My New Knob", default = flatDefaults.myNewKnob,
         min = 0, max = 100, step = 1 },
   })
   ```

   Use `flatDefaults.myNewKnob` for the `default` field — `defaults/Profile.lua` is the single source of truth for default values.

3. **Override `onChange` if the side effect isn't the default appearance refresh.** Most settings just need to re-apply appearance — the default `onChange` publishes the `APPEARANCE` message (→ `UpdateBarAppearance`). For settings that need a different reaction:

   ```lua
   onChange = function(v) NS.SomeOtherReaction(v) end,
   ```

That's it. The widget renders on the General sub-page on the next `/reload`; `/at set myNewKnob 75` works immediately; `/at get myNewKnob` and `/at list` show the new row; `/at reset general` and `/at resetall` reset it via `ApplyDefault`. Every write — panel widget, `/at set`, and `/at reset` — funnels through `NS.SetByPath`, which calls `SetSetting` then fires the row's `onChange`.

`NS.ValidateSchema` (run once at panel-registration time) will warn in chat if the new row's `path` doesn't resolve against `NS.defaults.profile` — a cheap guard against typos between step 1 and step 2.

See [schema.md](./schema.md) for the full row grammar (knobs like `disabledIf`, `dialogControl`, `fmt`, `solo`).

## Add a per-unit setting

Bar/Border/Font settings are per-unit (player/target/focus) rather than a single flat schema row. Use this recipe instead of "Add a new setting" above when the new knob is a bar-appearance value that should exist for all three units (and mirror the same way the existing fifteen do).

1. **Add the key to `defaults/Profile.lua`'s `appearance()` factory** (not `NS.defaults.profile` directly — `appearance()` is called once per unit so no table gets shared across units):

   ```lua
   -- defaults/Profile.lua
   local function appearance()
       return {
           -- ... existing keys ...
           myNewKnob = 42,
       }
   end
   ```

2. **Add the key to `NS.Units.APPEARANCE_KEYS`** (`core/Units.lua`) — mirror resolution (`NS.Units.Get`) and `CopyFromPlayer` both walk this list, so a key left off it silently never mirrors or copies:

   ```lua
   -- core/Units.lua
   Units.APPEARANCE_KEYS = {
       "barTexture", "bgTexture", "border", "borderSize", "borderColor",
       "font", "fontSize", "fontFlags", "barWidth", "barHeight",
       "barColor", "bgColor", "useClassColorBar", "useClassColorBg", "useClassColorBorder",
       "myNewKnob",
   }
   ```

3. **Add the row inside the relevant page's `addUnitRows(unit)`** (`settings/Bar.lua`, `Border.lua`, or `Font.lua`) — the loop that already calls it once per `NS.Units.LIST` entry picks the new row up automatically:

   ```lua
   -- settings/Bar.lua, inside addUnitRows(unit)
   {
       path    = p .. "myNewKnob",   -- p = "units." .. unit .. "."
       page    = "bar",
       unit    = unit,
       group   = "Size",
       order   = 50,
       type    = "number",
       label   = "My New Knob",
       default = unitDefaults.myNewKnob,
       min = 0, max = 100, step = 1,
   },
   ```

That's it. `NS.Units.Get(unit, "myNewKnob")` reads it mirror-resolved; `/at set units.target.myNewKnob 10` and `/at get units.focus.myNewKnob` work immediately; `/at reset bar` and the panel's Bar-page Defaults button reset it across all three units; `Helpers.RenderUnitPanel` renders it on whichever unit is selected in the Unit dropdown, and hides it while that unit mirrors the player.

`NS.ValidateSchema` will warn in chat if the path (`units.<unit>.myNewKnob`) doesn't resolve against `NS.defaults.profile` — a cheap guard against forgetting step 1 or getting the factory vs. `NS.defaults.profile` distinction backwards.

## Add a new sub-page

When a logical group of settings outgrows an existing page (or doesn't fit any of General / Bar / Border / Font), add a new `settings/<NewPage>.lua`.

1. **Create `settings/<NewPage>.lua`** with the standard shape:

   ```lua
   local addonName, NS = ...
   local flatDefaults = NS.flatDefaults

   NS.RegisterSchemaRows({
       { path = "newKnob1", page = "newpage", group = "Section",
         order = 10, type = "bool",
         label = "New Knob 1", desc = "...",
         default = flatDefaults.newKnob1 },
       -- ...
   })

   local function build(mainCategory)
       if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
           return nil
       end

       local H   = NS.Helpers
       local ctx = H.CreatePanel("AbsorbTrackerNewPagePanel", "New Page", {
           pageKey         = "newpage",
           defaultsButton  = true,
           defaultsTooltip = "Restore every New Page setting on this profile to its addon default.",
       })
       -- Parked, not wired: the button does not exist until the panel's first
       -- OnShow (Helpers.EnsureDefaultsButton), which attaches this.
       ctx.panel.defaultsOnClick = function()
           H.RestoreDefaults("newpage", ctx)
           end)
       end

       -- Defer the AceGUI render until the panel is visible: build runs at
       -- PLAYER_LOGIN when ctx.body has 0 width, and AceGUI lays children out
       -- against the container's current width.
       local rendered = false
       ctx.panel:SetScript("OnShow", function()
           if rendered then return end
           rendered = true
           H.RenderSchema(ctx, "newpage")
       end)

       return Settings.RegisterCanvasLayoutSubcategory(
           mainCategory, ctx.panel, "New Page")
   end

   if NS.RegisterOptionsPage then
       NS.RegisterOptionsPage("newpage", "New Page", build)
   end
   ```

2. **Add the file to `AbsorbTracker.toc`** in the `# Settings` block, after `settings/Panel.lua` and the toolkit files it depends on (`Helpers`, `ScrollPatch`, `Widgets`). Registration order in the queue determines tree order, so place the line where the page should appear in the Settings tree:

   ```
   settings\General.lua
   settings\Bar.lua
   settings\Border.lua
   settings\Font.lua
   settings\NewPage.lua
   settings\Profiles.lua
   ```

3. **Add the corresponding defaults** to `defaults/Profile.lua`'s `NS.defaults.profile`.

4. **Update the two allowed-page sets so the new key is valid.**
   - `RESET_PAGES` in `settings/Slash.lua` (currently `general / bar / border / font`) — add `newpage` so `/at reset newpage` works. Also add it to the `PAGE_ORDER` list there if you want `/at list` to group its rows.
   - `_validPages` in `settings/Schema.lua` — add `newpage`, otherwise `ValidateSchema` warns that every row on the page has an "invalid `page`".

The Blizzard Settings tree shows the new sub-page under "Ka0s Absorb Tracker" on next `/reload`.

## Troubleshoot the LSM dropdowns

If the texture / border / font dropdowns only show Blizzard's built-in fallback constants (`Blizzard Raid Bar`, `Blizzard Tooltip`, `Friz Quadrata TT`) and not the full SharedMedia catalog:

1. **Confirm LSM is loaded** in-game with `/dump LibStub("LibSharedMedia-3.0", true)`. A non-nil result means the lib is present.
2. **Confirm `NS.ClearLSMCache` ran.** It fires once in `OnEnable` (core/AbsorbTracker.lua, PLAYER_LOGIN timing); if the addon loaded before another addon registered fresh LSM entries, the cache stays warm with the pre-registration view. Force a re-cache with `/reload`. `NS.GetLSM` / `NS.ClearLSMCache` live in `core/Data.lua`.
3. **Confirm `dialogControl` is set on the schema row.** Without `dialogControl = "LSM30_Statusbar"` (or `_Border` / `_Font`), the panel renderer creates a plain AceGUI `Dropdown` instead of the swatch widget. LSM-backed rows also set `values = NS.Helpers.LSMValues("statusbar")` (or `"border"` / `"font"`).
4. **Confirm the upstream widget lib is loaded.** `libs/AceGUI-3.0-SharedMediaWidgets/widget.xml` includes `prototypes.lua` (`AceGUISharedMediaWidgets-1.0` LibStub library) plus per-widget files that register `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Font` via `AceGUI:RegisterWidgetType`. If the xml or any included file got skipped (TOC drift), the dropdown builder detects the missing version via `AceGUI:GetWidgetVersion(...)` and falls back to a plain `Dropdown` — the option still renders, just without the swatch.
5. **If the Border dropdown shows a 42×42 preview tile to the left of the text**, `NS.ApplyLSMBorderPatch` (core/LSMPatch.lua) didn't run. It's called in `OnEnable` after `NS.ClearLSMCache` / `NS.GetLSM`. Check that `core/LSMPatch.lua` is listed in `AbsorbTracker.toc`, and that `LibStub("AceGUI-3.0", true)` returns non-nil by the time `OnEnable` fires.

If the dropdowns show *some* entries but not all, check that the contributing addon registers its assets with `LibStub("LibSharedMedia-3.0"):Register("statusbar", "name", path)` — some addons declare assets differently and the registration call gets missed.

## Bump the Interface line

When a new retail patch ships:

1. Open `AbsorbTracker.toc`.
2. Replace the number on the `## Interface:` line with the new build (e.g. `120007` → `120008`). The value is `(major * 10000) + (minor * 100) + patch` for the current Live Servers patch.
3. Test in-game on the new patch — see [smoke-tests.md](./smoke-tests.md) for the full manual QA recipe.
4. Commit. **Don't bump the addon version** — Interface compatibility is independent of addon version. The user decides when to cut a release.

If the new patch *breaks* the addon, note the regression in README's troubleshooting section.

See also: the `/wow-addon:bump-interface` skill for the automated version of this.

## Run the test gate

This addon has a headless test harness under `tests/` — any doc claiming "no automated tests" is stale. Run the green gate before you consider a change done:

```sh
lua tests/run.lua      # suites: schema / database / compat / util / debuglog / slash / timer / perf / visibility / bus / data / display / helpers / slashcmds / widgets / units (count: docs/test-cases.md)
luacheck .             # must be 0 warnings / 0 errors
luac -p <changed.lua>  # bytecode-parse each file you touched
```

`tests/run.lua` loads every source file in TOC order through `tests/loader.lua` against the `tests/wow_mock.lua` WoW stub, runs `NS:InitDB()`, then executes the `test_*.lua` suites.

**When behavior changes, extend the suite.** The existing suites are:

| Suite | Covers |
|-------|--------|
| `tests/test_schema.lua` | schema shape, `ValidateSchema` (errors / resolved / missing), `SetByPath`, `ApplyDefault`, formatters/parsers |
| `tests/test_database.lua` | `InitDB`, `RunMigrations` idempotency, flat + per-unit backfill, schemaVersion v1→v2→v3 migration (v3 lifts pre-v3 flat keys onto `profile.units.player`), the per-profile lift across **every** saved profile, and the `OnProfileChanged` lift for a profile restored after the upgrade |
| `tests/test_compat.lua` | `Compat.GetAddOnMetadata` wrapper + fallback |
| `tests/test_util.lua` | `NS.Print` / `NS.Debug` (secret-safe sink) prefixing and gating, `NS.SafeToString` secret-value handling |
| `tests/test_debuglog.lua` | `NS.Debug` sink, `FormatPlain` / `FormatColored`, on/off state |
| `tests/test_slash.lua` | `NS.COMMANDS` dispatch, unknown-verb path, `/at` verbs |
| `tests/test_timer.lua` | `NS.RequestRepaint` coalescing + `throttleWindow` delay, event-handler repaint wiring |
| `tests/test_visibility.lua` | `NS.ShouldShowBar` / `NS.ApplyVisibility` four-step ladder (per-unit `enabled` / `showOnlyInCombat` / target-focus `UnitExists`), `OnEnterCombat` + `OnLeaveCombat` + `OnUnitSwap` visibility+repaint, and the options-ui-§2 guarantee that `OnLeaveCombat` never auto-opens `/at config` (no defer-and-replay) |
| `tests/test_bus.lua` | `NS.bus` / `NS.NewBusTarget` / `NS.MSG` catalogue, per-target subscribe + unregister, two receivers of one message both firing (anti-pattern #33), and `REPAINT`/`APPEARANCE`/`VISIBILITY`/`POSITION` routing to their consumers (each fanning out over `NS.ForEachUnit`) |
| `tests/test_data.lua` | `GetSetting` / `SetSetting` (profile read, dotted-path resolution, `flatDefaults` fallback, no-DB degradation), the per-unit LSM texture/border/font fetchers and their fallbacks, `ClearLSMCache`, `Helpers.LSMValues`, and the per-unit class-colour resolvers |
| `tests/test_display.lua` | `NS.ForEachUnit`, `NS.DefaultPosition`, `RestoreBarPosition`, `UpdateBarAppearance` (size, backdrop insets, nil-then-set refresh, lock, font, mirror-resolved reads), `UpdateAbsorbBar` (hidden / `testHoldUntil` early-outs, max-health scaling, `NoteRepaint`) — all per unit |
| `tests/test_helpers.lua` | `CreatePanel` + the panel registry, the lazy Defaults-button declaration, `RestoreDefaults` / `RestoreAllDefaults` (every unit's position cleared) / `RefreshAllPanels` |
| `tests/test_slashcmds.lua` | The remaining `/at` verbs: lock/unlock/toggle, update, reset (all units)/resetall/resetposition (all units), get/set failure paths (fully-qualified only), `test`, and the full `/at profile` sub-dispatcher |
| `tests/test_widgets.lua` | Schema-row → AceGUI widget translation: the four widget makers, `SessionCheckbox`, `RenderField` dispatch, `RenderRows`/`RenderSchema` layout (`skipRender` rows omitted), and the real pages driven through their deferred `OnShow` |
| `tests/test_perf.lua` | `core/Perf.lua`: bucket accounting, `EncodeJSON` (sorted keys, escaping, formatting), `BuildRecord` (derived fps figures, the zero-delta guard when only one arm was sampled), the `AbsorbTrackerPerfDB` ring (schema stamp, `RING_MAX` trimming, isolation from the AceDB tree), `FormatReport`, the brackets (silent when off), and suspend/resume (the `ShouldShowBar` step-0 gate, event teardown/restore, `RequestRepaint` no-op, `CancelPendingRepaint`) |
| `tests/test_units.lua` | `core/Units.lua`: `LIST`/`LABEL`, `IsEnabled`/`IsMirrored`/`SourceUnit` (player never mirrored), the mirror-resolved `Get`, `Set` (writes the unit's own config), `Position`/`SetPosition` (never mirrored), `CopyFromPlayer` (deep-copy + mirror clear, `position`/`enabled` untouched), `DeepCopy` |

Add a new setting or page? `test_schema.lua`'s integrity invariants already require a label, a desc, a
default that agrees with `defaults.profile`, and (for numbers) a `min`/`max` bracketing that default —
so a half-wired row fails the gate on its own. New slash verb? Add a `test_slash.lua` (core dispatch) or
`test_slashcmds.lua` (verb behaviour) case. New core behavior? Prefer a new `tests/test_<area>.lua` wired into `tests/run.lua`.

## Measure performance

Neither harness is part of the green gate. Full protocol and caveats: [performance.md](./performance.md).

```sh
lua tests/perf.lua                                   # offline: counters asserted, timings reported
lua tests/perf.lua --label after-my-change \
    --out docs/perf-runs/2026-08-01-offline-mine.json
```

In-game, as a sub-verb of the debug suite:

```
/at perf start       # begin a run (works with logging off)
/at perf measure a   # arm Experiment A - records while in combat
/at perf measure b   # arm Experiment B - same, and suspends the addon for you
/at perf finish      # end the run, save to AbsorbTrackerPerfDB, print the summary
/at perf cancel      # or abandon it - discards the run unsaved and restores the addon
/reload                    # flush SavedVariables
```

Experiments are combat-gated, so the walk between pulls is never measured. There is no manual
suspend verb: `measure b` owns it, which is what keeps the two experiments differing by the addon
and nothing else.

Captures land in the `AbsorbTrackerPerfDB` global inside
`WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` (note: the file is named after the **addon**,
not after the saved-variable globals). Record schema: [perf-runs/README.md](./perf-runs/README.md).

**If you add a bracket to a hot path**, use the gated idiom exactly — anything else costs work when
capture is off, and `tests/perf.lua`'s `probeOverhead*` scenarios will fail:

```lua
local Perf = NS.Perf                       -- load-time upvalue, at the top of the file
local t0 = Perf.on and debugprofilestop()
-- ... work ...
if t0 then Perf.Note("myBucket", debugprofilestop() - t0) end
```

Add the bucket name to `NS.Perf.BUCKET_ORDER` or it records but never prints.

## See also

- [schema.md](./schema.md) — schema row grammar.
- [settings-panel.md](./settings-panel.md) — sub-page registration mechanics.
- [midnight-quirks.md](./midnight-quirks.md) — patch-day breakage catalog.
