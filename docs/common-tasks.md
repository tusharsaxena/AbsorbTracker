# Common tasks

Recipes for the routine modifications. For deeper context on any module, see [module-map.md](./module-map.md) and the per-topic docs.

## Add a new setting

The schema-driven design makes this a one-row change. The widget on the relevant Settings sub-page AND the `/at set <path>` CLI come for free.

1. **Pick a `path` and a default.** The `path` is the `db.profile` key (and the `/at set <path>` argument). The default goes in `Core.lua`'s `defaults.profile`:

   ```lua
   -- Core.lua
   AddonTable.defaults = {
       profile = {
           -- ...
           myNewKnob = 42,
       },
   }
   ```

2. **Append a schema row** in the `Options/<page>.lua` file for the page where the widget should appear:

   ```lua
   -- Options/Bar.lua (for example)
   local AddonName, AddonTable = ...
   local flatDefaults = AddonTable.flatDefaults

   AddonTable.RegisterSchemaRows({
       -- ... existing rows ...
       { path = "myNewKnob", page = "bar", group = "Size", order = 50,
         type = "number", label = "My New Knob", default = flatDefaults.myNewKnob,
         min = 0, max = 100, step = 1 },
   })
   ```

   Use `flatDefaults.myNewKnob` for the `default` field — `Core.lua` is the single source of truth for default values.

3. **Override `onChange` if the side effect isn't `UpdateBarAppearance`.** Most settings just need to repaint, which is the default. For settings that need different reactions:

   ```lua
   onChange = function(v) AddonTable.RestartUpdateTicker() end,
   ```

That's it. The widget renders on the Bar sub-page on the next `/reload`; `/at set myNewKnob 75` works immediately; `/at get myNewKnob` and `/at list` show the new row; `/at reset bar` and `/at resetall` reset it via `ApplyDefault`.

See [schema.md](./schema.md) for the full row grammar (knobs like `inverse`, `disabledIf`, `dialogControl`, `fmt`).

## Add a new sub-page

When a logical group of settings outgrows an existing page (or doesn't fit any of General / Bar / Border / Font), add a new `Options/<NewPage>.lua`.

1. **Create `Options/<NewPage>.lua`** with the standard shape:

   ```lua
   local AddonName, AddonTable = ...
   local flatDefaults = AddonTable.flatDefaults

   AddonTable.RegisterSchemaRows({
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

       local H   = AddonTable.Helpers
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

       local rendered = false
       ctx.panel:SetScript("OnShow", function()
           if rendered then return end
           rendered = true
           H.RenderSchema(ctx, "newpage")
       end)

       return Settings.RegisterCanvasLayoutSubcategory(
           mainCategory, ctx.panel, "New Page")
   end

   if AddonTable.RegisterOptionsPage then
       AddonTable.RegisterOptionsPage("newpage", "New Page", build)
   end
   ```

2. **Add the file to `AbsorbTracker.toc`** after `OptionsPanel.lua`. Registration order in the queue determines tree order, so place the line where the page should appear in the Settings tree:

   ```
   Options/General.lua
   Options/Bar.lua
   Options/Border.lua
   Options/Font.lua
   Options/NewPage.lua
   Options/Profiles.lua
   ```

3. **Add the corresponding defaults** to `Core.lua`'s `defaults.profile`.

4. **Update `/at reset` to accept the new page key.** The allowed-pages set is `RESET_PAGES` in `SlashCommands.lua` (currently `general / bar / border / font`). Add `newpage`. The schema's `ValidateSchema` allowed-pages set in `Schema.lua` also needs the new key.

The Blizzard Settings tree shows the new sub-page under "Ka0s Absorb Tracker" on next `/reload`.

## Troubleshoot the LSM dropdowns

If the texture / border / font dropdowns only show Blizzard's built-in fallback constants (`Blizzard Raid Bar`, `Blizzard Tooltip`, `Friz Quadrata TT`) and not the full SharedMedia catalog:

1. **Confirm LSM is loaded** in-game with `/dump LibStub("LibSharedMedia-3.0", true)`. A non-nil result means the lib is present.
2. **Confirm `ClearLSMCache` ran.** It should fire once at PLAYER_LOGIN; if the addon loaded before another addon registered fresh LSM entries, the cache stays warm with the pre-registration view. Force a re-cache with `/reload`.
3. **Confirm `dialogControl` is set on the schema row.** Without `dialogControl = "LSM30_Statusbar"` (or `_Border` / `_Font`), `Helpers.RenderField` creates a plain AceGUI `Dropdown` instead of the swatch widget.
4. **Confirm the upstream widget lib is loaded.** `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/widget.xml` includes `prototypes.lua` (`AceGUISharedMediaWidgets-1.0` LibStub library) plus per-widget files that register `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Font` via `AceGUI:RegisterWidgetType`. If the xml or any included file got skipped (TOC drift), `makeDropdown` detects the missing version via `AceGUI:GetWidgetVersion(...)` and falls back to plain `Dropdown` — the option still renders, just without the swatch.
5. **If the Border dropdown shows a 42×42 preview tile to the left of the text**, the `LSMPatch.lua` `PLAYER_LOGIN` hook didn't fire. Check that `LSMPatch.lua` is listed in `AbsorbTracker.toc` after `Utils.lua`, and that `LibStub("AceGUI-3.0", true)` returns non-nil at PLAYER_LOGIN.

If the dropdowns show *some* entries but not all, check that the contributing addon registers its assets with `LibStub("LibSharedMedia-3.0"):Register("statusbar", "name", path)` — some addons declare assets differently and the registration call gets missed.

## Bump the Interface line

When a new retail patch ships:

1. Open `AbsorbTracker.toc`.
2. Replace the number on the `## Interface:` line with the new build (e.g. `120007` → `120008`). The value is `(major * 10000) + (minor * 100) + patch` for the current Live Servers patch.
3. Test in-game on the new patch — see [smoke-tests.md](./smoke-tests.md) for the full manual QA recipe.
4. Commit. **Don't bump the addon version** — Interface compatibility is independent of addon version. The user decides when to cut a release.

If the new patch *breaks* the addon, note the regression in README's troubleshooting section.

See also: [`/wow-addon:bump-interface` skill](../../.claude/skills/) for the automated version of this.

## See also

- [schema.md](./schema.md) — schema row grammar.
- [settings-panel.md](./settings-panel.md) — sub-page registration mechanics.
- [midnight-quirks.md](./midnight-quirks.md) — patch-day breakage catalog.
