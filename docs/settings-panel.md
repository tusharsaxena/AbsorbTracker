# Settings panel

How the addon registers its multi-page Blizzard Settings UI. The schema-driven content of each page is documented in [schema.md](./schema.md); this doc is about the *registration shell* — `settings/Panel.lua` + the four `settings/*.lua` toolkit slices, plus the per-page `settings/<page>.lua` declarations.

## Source layout

The settings UI is split across five toolkit files (all under `settings/`), plus the per-page declarations:

| File | Role |
|------|------|
| `settings/Panel.lua` | Registration shell. Publishes empty `NS.Helpers = {}` and `NS.PARENT_TITLE`; owns `pendingPages`, `NS.RegisterOptionsPage`, `NS.CreateOptionsPanel`, `NS.OpenOptionsPanel`, `NS.RefreshOptionsPanel`. Stashes `NS.AceGUI` once (see below). |
| `settings/Helpers.lua` | Toolkit core. `CreatePanel` / `Section` / `InlineButtonPair` / `EnsureScroll` / `AttachTooltip` / `AddSpacer` / `LSMValues` / `RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels`, plus the layout constants (`PADDING_X` / `HEADER_HEIGHT` / `ROW_VSPACER` / `SECTION_HEADING_H`) and the panel registry. |
| `settings/ScrollPatch.lua` | `Helpers.PatchAlwaysShowScrollbar` — the always-visible scrollbar override. |
| `settings/Widgets.lua` | `Helpers.RenderField` (dispatches by `row.type`) + `Helpers.RenderSchema` (two-column layout) + the four widget makers (CheckBox / Slider / Dropdown / ColorPicker). |
| `settings/About.lua` | `Helpers.BuildMainContent` — top-level "Ka0s Absorb Tracker" page (logo + Notes + slash command list). |

Each `settings/*.lua` slice begins with `local addonName, NS = ...` then `local Helpers = NS.Helpers`, and decorates that shared table. The TOC loads them in order immediately after `settings/Panel.lua`, before any `settings/<page>.lua` (`General` / `Bar` / `Border` / `Font` / `Profiles`) consumes the toolkit.

### The `NS.AceGUI` upvalue

`NS.CreateOptionsPanel` (in `settings/Panel.lua`) does `NS.AceGUI = LibStub("AceGUI-3.0", true)` **once**, before any page builder runs, and bails with a chat notice if AceGUI isn't present. Every toolkit function, widget maker, and the about-page builder then read that stashed field (`local AceGUI = NS.AceGUI`) rather than re-`LibStub`-ing on each call. Because it's set at the top of `CreateOptionsPanel` and every builder fires below that line, the field is always populated by the time a builder or refresher touches it.

## Five pages plus an about page

```
┌─ Ka0s Absorb Tracker (about page: logo + Notes + slash command list) ┐
│   ├─ General                                                         │
│   ├─ Bar                                                             │
│   ├─ Border                                                          │
│   ├─ Font                                                            │
│   └─ Profiles  (only if AceDBOptions is present)                     │
└──────────────────────────────────────────────────────────────────────┘
```

`/at config` opens the parent page and expands the sub-page tree so every sub-page is visible at once. The user clicks the page they want from the tree.

The parent and every sub-page register as **canvas-layout categories**: a custom Blizzard `Frame` is registered with `Settings.RegisterCanvasLayoutCategory` (parent) / `Settings.RegisterCanvasLayoutSubcategory` (each sub-page) and Blizzard renders it in its own settings panel slot. The schema-driven sub-pages (General / Bar / Border / Font) lay out their schema rows as **AceGUI widgets** (`CheckBox` / `Slider` / `Dropdown` / `ColorPicker`) inside an AceGUI `ScrollFrame` parented to the page's `body` frame.

Profiles is the only page that still uses AceConfig — it routes `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` into an AceGUI `SimpleGroup` parented to the canvas body, so the AceDBOptions UI lands inside our shell with the same header.

## Unified header

Every page (about + sub-pages) builds the same header via `Helpers.CreatePanel(name, title, opts)`:

- `GameFontNormalHuge` title in **breadcrumb** form: `"Ka0s Absorb Tracker ▸ <Page>"` for sub-pages, where the separator is the inline-atlas escape `|A:common-icon-forwardarrow:16:16|a` (a real texture, not a font glyph — font-agnostic and locale-safe). The about page passes `opts.isMain = true` to render the unprefixed `"Ka0s Absorb Tracker"`. The Blizzard left-tree label (driven by `panel.name`) stays unprefixed so the tree indents under the parent without visual repetition.
- `Options_HorizontalDivider` atlas underneath the title, tinted to the title's font color (read off the title FontString rather than hardcoded so a theme retune tracks automatically).
- Optional **Defaults** button (width `DEFAULTS_W = 110`) at TOPRIGHT — General / Bar / Border / Font opt in via `opts.defaultsButton = true`. About page and Profiles deliberately omit it (about page has no settings; Profiles has its own destructive controls inside the AceDBOptions UI).
- Layout constants: `PADDING_X = 16`, `HEADER_TOP = 20`, `HEADER_HEIGHT = 54`. The body frame anchors `(0, -(HEADER_HEIGHT + 8))` below TOPLEFT.

`CreatePanel` returns a `ctx` table threaded through the rest of the helpers: `{ panel, body, scroll = nil, refreshers = {}, lastGroup = nil, pageKey }`. Every ctx is appended to the `renderedPanels` registry so `RefreshAllPanels` can re-run its refreshers.

## File-load registration vs. enable-time registration

`settings/Panel.lua` runs at file-load time (early), but `NS.db` doesn't exist until the AceAddon lifecycle has run `NS:InitDB`. The shell separates the two phases:

1. **File-load.** Each `settings/<page>.lua` calls `NS.RegisterOptionsPage(key, name, builder)` to enqueue itself. The builder is a closure that will run later. (The schema rows themselves also register at file-load via `NS.RegisterSchemaRows` — see [schema.md](./schema.md).)
2. **Enable.** `addon:OnEnable` (in `core/AbsorbTracker.lua`, at PLAYER_LOGIN timing) calls `NS.CreateOptionsPanel()` as the last step of its login sequence, which:
   - Stashes `NS.AceGUI` (bails with a chat notice if AceGUI is unavailable).
   - Validates the assembled schema via `NS.ValidateSchema()` (chat-prints any malformed rows or unresolvable paths; never blocks).
   - Builds the about-page canvas (`Helpers.CreatePanel(..., { isMain = true })`) and registers it via `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, deferring the body render to the panel's first `OnShow`.
   - Walks `pendingPages`, calling `builder(mainCategory)` on each entry. Each builder constructs its own canvas via `Helpers.CreatePanel`, defers the AceGUI render to the panel's first `OnShow` (the body has 0 width at enable time; AceGUI lays out against current width), and returns the result of `Settings.RegisterCanvasLayoutSubcategory(mainCategory, panel, name)`.
   - If the builder returns `nil` (e.g. `settings/Profiles.lua` when AceDBOptions is missing), the page is silently skipped.

## `RegisterOptionsPage(key, name, builder)`

```lua
NS.RegisterOptionsPage("bar", "Bar", function(mainCategory)
    local H   = NS.Helpers
    local ctx = H.CreatePanel("AbsorbTrackerBarPanel", "Bar", {
        pageKey         = "bar",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Bar setting on this profile to its addon default.",
    })
    if ctx.panel.defaultsBtn then
        ctx.panel.defaultsBtn:SetCallback("OnClick", function()
            H.RestoreDefaults("bar", ctx)
        end)
    end

    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "bar")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "Bar")
end)
```

- `key` — short identifier used in `pageKey` (the schema's `page` filter) and in the panel frame's global name.
- `name` — display name shown in the Blizzard Settings tree AND used as the `<Page>` half of the breadcrumb header.
- `builder(mainCategory)` — must return the sub-category from `Settings.RegisterCanvasLayoutSubcategory`, or `nil` to skip registration.

## `Helpers.RenderSchema(ctx, pageKey, afterGroup?)`

The two-column layout engine. Walks `NS.SchemaForPage(pageKey)` and emits each row as an AceGUI widget through `Helpers.RenderField`, packing pairs of rows into 50%-width Flow rows (each pair wrapped in a full-width `SimpleGroup` so AceGUI gives both children exactly half the width). Section breaks (whenever `row.group` changes) emit a full-width `Heading` widget (`GameFontNormalLarge`) flanked by side dividers, with `SECTION_TOP_SPACER = 10` / `SECTION_BOTTOM_SPACER = 6` around it. Every two-column row is followed by a `ROW_VSPACER = 8` spacer for breathing room. A final `scroll:DoLayout()` runs after the last row.

A row marked `solo = true` flushes any in-progress two-column row first, then renders alone (left half of its own row, right half empty). Used for visually-grouping pivots like a texture row that sits above its color-picker pair.

The optional `afterGroup` map is `{ [groupName] = function(ctx) ... end }`. Each callback fires once, immediately after the group's last schema row is rendered (and before the next group's heading), then is nilled out (one-shot). General uses this to inject `Helpers.InlineButtonPair` ("Reset Position" + "Reset All Settings") under the **Master controls** group.

## Widget makers and refresher closures

Each row dispatches to a maker by `row.type`:

| Type | Widget | Notes |
|------|--------|-------|
| `bool` | `CheckBox` | Honors `inverse = true` (widget shows `not value`). |
| `number` | `Slider` | Snaps to `step` on `OnMouseUp`. |
| `string` | `Dropdown` (or `LSM30_Statusbar` / `_Border` / `_Font` when `dialogControl` is set and the LSM widget is loaded) | Falls back to plain `Dropdown` if the LSM widget didn't load. |
| `color` | `ColorPicker` | Honors `hasAlpha`; greys out when `disabledIf`'s sibling toggle is on. |

Each maker reads via `NS.GetSetting(row.path)` and writes via `NS.SetByPath(row.path, value)` — the documented single-write seam (`SetSetting` + `fireOnChange` in one call; see [schema.md](./schema.md)). Every maker also registers a **refresher closure** in `ctx.refreshers`. The closure re-reads the value and pushes it back into the widget (via `widget:SetValue` / `SetColor`, which AceGUI does NOT fire `OnValueChanged` for — so no recursion). After every widget write, `Helpers.RefreshAllPanels()` runs every refresher on every panel ctx, so paired controls re-sync immediately (e.g. flipping `useClassColorBar` greys the `barColor` picker on the same frame).

Tooltips on every widget go through `Helpers.AttachTooltip`, which `SetCallback`s `OnEnter` / `OnLeave` (or `HookScript`s them on a plain Blizzard frame) to drive `GameTooltip` anchored on `widget.frame`. Label = `row.label`, body = `row.desc`.

### Live color preview

The `ColorPicker` maker treats `OnValueChanged` (fires during drag) as the live-preview write and `OnValueConfirmed` (fires only on cancel, with the original color) as the immediate commit. Each drag fire goes through a **50 ms throttle** so a sustained drag doesn't repaint the bar 60×/s; cancel commits immediately so the bar snaps back to the pre-drag color without waiting on the throttle window.

The throttle is a single re-armed **AceTimer** one-shot — `timer = NS.addon:ScheduleTimer(fn, 0.05)` (Ka0s standard §3.1, **not** a raw `C_Timer.NewTimer`). A reused `pendingArgs` table holds the latest RGBA, so a 60 Hz drag produces O(1) garbage instead of 60 closures + 60 arg tables per second; the one-shot self-clears (`timer = nil` inside the callback) so there's no `CancelTimer`. The throttled commit path intentionally does **not** call `RefreshAllPanels` — traversing every panel widget every 50 ms during a drag would be wasteful.

## Always-visible scrollbar

`Helpers.PatchAlwaysShowScrollbar(scroll)` (in `settings/ScrollPatch.lua`, called from `Helpers.EnsureScroll` right after the AceGUI `ScrollFrame` is created) rebinds the AceGUI `ScrollFrame`'s `FixScroll` / `MoveScroll` / `OnRelease` so the scrollbar never auto-hides. Short pages (General) keep the same right-edge gutter as long pages (Bar) — the thumb just greys out (vertex color `0.5,0.5,0.5,0.6`) and locks at value 0 when content fits the viewport. The patch restores stock behavior on widget release so the AceGUI pool returns to a clean state for the next acquirer.

## Profile change refresh

When AceDB fires `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` (registered in `NS:InitDB`, `core/Database.lua`), the active profile flips and `NS.OnProfileChanged` runs the bar repaint chain, then calls `NS.RefreshOptionsPanel()`. That routes to `Helpers.RefreshAllPanels()`, which walks every panel ctx in `renderedPanels` and runs every registered refresher closure. Each refresher re-reads its row's value via `NS.GetSetting` and pushes it into the widget — values that didn't survive the profile flip update; values that did are no-ops.

The same `RefreshAllPanels` runs after every `/at set`, `/at reset`, and `/at resetall` write (via `settings/Slash.lua` → `NS.SetByPath` / `RefreshOptionsPanel`) and after every panel widget's `set()` (via the local `set()` in `settings/Widgets.lua` — see [Widget makers](#widget-makers-and-refresher-closures) above), so panel-driven and slash-driven mutations both keep open panels in sync.

## `OpenOptionsPanel` and the combat-lockdown gate

```lua
function NS.OpenOptionsPanel()
    if InCombatLockdown() then
        if not NS.State.panelOpenPending then
            NS.State.panelOpenPending = true
            NS.addon:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                NS.addon:UnregisterEvent("PLAYER_REGEN_ENABLED")
                NS.State.panelOpenPending = nil
                NS.OpenOptionsPanel()               -- replay once lockdown clears
            end)
            print("In combat — settings will open when you leave combat.")
        end
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    if not mainCategoryID then return end
    Settings.OpenToCategory(mainCategoryID)
    expandMainCategory()
end
```

`Settings.OpenToCategory` is part of Blizzard's protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI. Per Ka0s standard §6.2 the gate **defers** rather than refuses: a one-shot `PLAYER_REGEN_ENABLED` handler replays the open the moment combat ends (lockdown already released, so the replay is taint-free), and the `NS.State.panelOpenPending` session flag keeps it to a single queued open no matter how often `/at config` is pressed mid-pull. (`print` here is the file-local `local print = NS.Print`, so the notice carries the cyan `[AT]` prefix.)

`/at config` (dispatched through `NS.COMMANDS` in `settings/Slash.lua`) always opens the **parent** category (the about page) and then calls `expandMainCategory()` to expand the Blizzard Settings left-tree entry so every sub-page is visible. `expandMainCategory` walks `SettingsPanel:GetCategoryList():GetCategoryEntry(mainCategory):SetExpanded(true)` — `SettingsPanel` internals are private API, so the whole call is wrapped in `pcall`; if any of those calls disappears in a future patch, the panel still opens, just without the tree-expansion side effect.

The user picks the sub-page they want from the expanded tree. There is no "default sub-page" mechanism — the parent always opens, the tree always expands.

## LSM swatch dropdowns

Texture / border / font select fields use `dialogControl = "LSM30_Statusbar"` (`settings/Bar.lua`), `"LSM30_Border"` (`settings/Border.lua`), or `"LSM30_Font"` (`settings/Font.lua`) on their schema row. `Helpers.RenderField` → `makeDropdown` reads `dialogControl` and creates the matching AceGUI widget directly:

```lua
local widgetType = row.dialogControl or "Dropdown"
if widgetType ~= "Dropdown" and not AceGUI:GetWidgetVersion(widgetType) then
    widgetType = "Dropdown"   -- LSM widget didn't load; fall back to plain dropdown
end
local dd = AceGUI:Create(widgetType)
```

The LSM30_* widgets are the canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65 lib, vendored folder-per-lib at `libs/AceGUI-3.0-SharedMediaWidgets/` and loaded via `widget.xml`. `LSM30_Statusbar` / `LSM30_Font` use upstream's `GetBaseFrame` (no preview tile); `LSM30_Border` uses `GetBaseFrameWithWindow`, which adds a 42×42 `displayButton` border-preview tile pinned to the widget's TOPLEFT. That tile clashes with our canvas-layout panel — `NS.ApplyLSMBorderPatch` (in `core/LSMPatch.lua`) is called from `addon:OnEnable`, by which point every addon's libs have loaded and the `LSM30_Border` registry slot is stable. It wraps whatever constructor AceGUI currently holds, re-registers the wrapper at `currentVersion + 1` (via `RegisterWidgetType`, to win the version race), and per-instance hides `displayButton` and re-anchors `frame.label` / `frame.DLeft` to the frame's left edge so the empty 42px slot collapses. The fixup lives in addon code (`RegisterWidgetType`, Ka0s standard §3.5) rather than as an edit to the vendored lib, so a future r66+ refresh is a clean drop-in.

The dropdown's `values` table is supplied by `Helpers.LSMValues(mediaType)`, which returns a deferred closure that pulls the live `NS.GetLSM():HashTable(mediaType)` at dropdown-render time. Schema rows in `settings/Bar.lua` / `Border.lua` / `Font.lua` set `values = NS.Helpers.LSMValues("statusbar")` (etc.) at file-load — the closure is then invoked by `makeDropdown`'s `valuesHash()` every time the dropdown re-renders, so newly-registered LSM media show up without an addon reload.

## About page (top-level "Ka0s Absorb Tracker")

`Helpers.BuildMainContent(ctx)` (defined in `settings/About.lua`, called from the main panel's first `OnShow` in `settings/Panel.lua`'s `registerMain`) renders three blocks into the AceGUI scroll:

1. **Logo.** `NS.Constants.LOGO_PATH` (`media/logos/absorbracker.logo.v2.tga`) at native 300×300, anchored TOPLEFT inside a full-width SimpleGroup.
2. **TOC `Notes` blurb** — full-width `Label` with `GameFontHighlight`, left-justified. The Notes string is read through `NS.Compat.GetAddOnMetadata` (Ka0s standard §11 — the single deprecated-API shim).
3. **Slash Commands section** — a full-width `Heading` widget (`GameFontNormalLarge`) followed by one `Label` row per entry in `NS.SlashCommands`, formatted `|cffffff00/at <cmd>|r  |cffffffff—|r  <desc>`. `NS.SlashCommands` is an alias for `NS.COMMANDS` (`settings/Slash.lua`), so the about list stays in lockstep with `/at help` — both walk the same ordered `{name, desc, fn}` table.

## See also

- [schema.md](./schema.md) — what a row in `NS.Schema` looks like and how it drives both the panel and the slash CLI.
- [profiles.md](./profiles.md) — how profile changes drive `RefreshOptionsPanel`.
- [midnight-quirks.md](./midnight-quirks.md) — patch-day breakage catalog.
