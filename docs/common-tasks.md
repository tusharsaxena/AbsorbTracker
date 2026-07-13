# Common tasks

Recipes for the routine modifications. For deeper context on any module, see [module-map.md](./module-map.md) and the per-topic docs.

## Add a new setting

The schema-driven design makes this a one-row change. The widget on the relevant Settings sub-page AND the `/at set <path>` CLI come for free.

1. **Pick a `path` and a default.** The `path` is the `db.profile` key (and the `/at set <path>` argument). The default goes in `defaults/Profile.lua`'s `NS.defaults.profile`:

   ```lua
   -- defaults/Profile.lua
   NS.defaults.profile = {
       -- ...
       myNewKnob = 42,
   }
   ```

   `NS.flatDefaults` is an alias for `NS.defaults.profile`, so every settings page can read per-key defaults from it. `NS:RunMigrations` (core/Database.lua) backfills any missing profile key from `flatDefaults` on load, so existing profiles pick up the new key automatically.

2. **Append a schema row** in the `settings/<page>.lua` file for the page where the widget should appear:

   ```lua
   -- settings/Bar.lua (for example)
   local addonName, NS = ...
   local flatDefaults = NS.flatDefaults

   NS.RegisterSchemaRows({
       -- ... existing rows ...
       { path = "myNewKnob", page = "bar", group = "Size", order = 50,
         type = "number", label = "My New Knob", default = flatDefaults.myNewKnob,
         min = 0, max = 100, step = 1 },
   })
   ```

   Use `flatDefaults.myNewKnob` for the `default` field — `defaults/Profile.lua` is the single source of truth for default values.

3. **Override `onChange` if the side effect isn't `UpdateBarAppearance`.** Most settings just need to repaint, which is the default. For settings that need a different reaction:

   ```lua
   onChange = function(v) NS.SomeOtherReaction(v) end,
   ```

That's it. The widget renders on the Bar sub-page on the next `/reload`; `/at set myNewKnob 75` works immediately; `/at get myNewKnob` and `/at list` show the new row; `/at reset bar` and `/at resetall` reset it via `ApplyDefault`. Every write — panel widget, `/at set`, and `/at reset` — funnels through `NS.SetByPath`, which calls `SetSetting` then fires the row's `onChange`.

`NS.ValidateSchema` (run once at panel-registration time) will warn in chat if the new row's `path` doesn't resolve against `NS.defaults.profile` — a cheap guard against typos between step 1 and step 2.

See [schema.md](./schema.md) for the full row grammar (knobs like `inverse`, `disabledIf`, `dialogControl`, `fmt`, `solo`).

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
       if ctx.panel.defaultsBtn then
           ctx.panel.defaultsBtn:SetCallback("OnClick", function()
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

See also: the [`/wow-addon:bump-interface` skill](../../.claude/skills/) for the automated version of this.

## Run the test gate

This addon has a headless test harness under `tests/` — any doc claiming "no automated tests" is stale. Run the green gate before you consider a change done:

```sh
lua tests/run.lua      # 63 tests: schema / database / compat / util / debuglog / slash / timer / visibility
luacheck .             # must be 0 warnings / 0 errors
luac -p <changed.lua>  # bytecode-parse each file you touched
```

`tests/run.lua` loads every source file in TOC order through `tests/loader.lua` against the `tests/wow_mock.lua` WoW stub, runs `NS:InitDB()`, then executes the `test_*.lua` suites.

**When behavior changes, extend the suite.** The existing suites are:

| Suite | Covers |
|-------|--------|
| `tests/test_schema.lua` | schema shape, `ValidateSchema` (errors / resolved / missing), `SetByPath`, `ApplyDefault`, formatters/parsers |
| `tests/test_database.lua` | `InitDB`, `RunMigrations` idempotency, `flatDefaults` backfill, schemaVersion v1→v2 migration |
| `tests/test_compat.lua` | `Compat.GetAddOnMetadata` wrapper + fallback |
| `tests/test_util.lua` | `NS.Print` / `NS.DebugPrint` prefixing and gating, `NS.SafeToString` secret-value handling |
| `tests/test_debuglog.lua` | `NS.Debug` sink, `FormatPlain` / `FormatColored`, on/off state |
| `tests/test_slash.lua` | `NS.COMMANDS` dispatch, unknown-verb path, `/at` verbs |
| `tests/test_timer.lua` | `NS.RequestRepaint` coalescing + `throttleWindow` delay, event-handler repaint wiring |

Add a new setting or page? Assert its default resolves in `test_schema.lua`. New slash verb? Add a `test_slash.lua` case. New core behavior? Prefer a new `tests/test_<area>.lua` wired into `tests/run.lua`.

## See also

- [schema.md](./schema.md) — schema row grammar.
- [settings-panel.md](./settings-panel.md) — sub-page registration mechanics.
- [midnight-quirks.md](./midnight-quirks.md) — patch-day breakage catalog.
