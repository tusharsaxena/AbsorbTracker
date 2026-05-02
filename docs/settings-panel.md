# Settings panel

How the addon registers its multi-page Blizzard Settings UI. The schema-driven content of each page is documented in [schema.md](./schema.md); this doc is about the *registration shell* — `OptionsPanel.lua` plus the per-page `Options/<page>.lua` declarations.

## Five pages plus an about page

```
┌─ Ka0s Absorb Tracker (about page: logo + Notes + slash command list) ┐
│   ├─ General  (default — /at config opens here)                      │
│   ├─ Bar                                                             │
│   ├─ Border                                                          │
│   ├─ Font                                                            │
│   └─ Profiles  (only if AceDBOptions is present)                     │
└──────────────────────────────────────────────────────────────────────┘
```

The parent and every sub-page register as **canvas-layout categories**: a custom Blizzard `Frame` is registered with `Settings.RegisterCanvasLayoutCategory` (parent) / `Settings.RegisterCanvasLayoutSubcategory` (each sub-page) and Blizzard renders it in its own settings panel slot. The schema-driven sub-pages (General / Bar / Border / Font) lay out their schema rows as **AceGUI widgets** (`CheckBox` / `Slider` / `Dropdown` / `ColorPicker`) inside an AceGUI `ScrollFrame` parented to the page's `body` frame.

Profiles is the only page that still uses AceConfig — it routes `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` into an AceGUI `SimpleGroup` parented to the canvas body, so the AceDBOptions UI lands inside our shell with the same header.

## Unified header

Every page (about + sub-pages) builds the same header via `Helpers.CreatePanel(name, title, opts)`:

- `GameFontNormalHuge` title in **breadcrumb** form: `"Ka0s Absorb Tracker  |  <Page>"` for sub-pages; the about page passes `opts.isMain = true` to render the unprefixed `"Ka0s Absorb Tracker"`. The Blizzard left-tree label (driven by `panel.name`) stays unprefixed so the tree indents under the parent without visual repetition.
- `Options_HorizontalDivider` atlas underneath the title, tinted to the title's font color.
- Optional **Defaults** button (width `PANEL_DEFAULTS_W = 110`) at TOPRIGHT — General / Bar / Border / Font opt in via `opts.defaultsButton = true`. About page and Profiles deliberately omit it (about page has no settings; Profiles has its own destructive controls inside the AceDBOptions UI).
- Layout constants: `PADDING_X = 16`, `HEADER_TOP = 20`, `HEADER_HEIGHT = 54`. The body frame anchors `(0, -(HEADER_HEIGHT + 8))` below TOPLEFT.

`CreatePanel` returns a `ctx` table threaded through the rest of the helpers: `{ panel, body, scroll = nil, refreshers = {}, lastGroup = nil, pageKey }`.

## File-load registration vs. PLAYER_LOGIN registration

`OptionsPanel.lua` runs at file-load time (early), but `AddonTable.db` doesn't exist until PLAYER_LOGIN. The shell separates the two phases:

1. **File-load.** Each `Options/<page>.lua` calls `AddonTable.RegisterOptionsPage(key, name, builder, opts?)` to enqueue itself. The builder is a closure that will run later.
2. **PLAYER_LOGIN.** `Events.lua` calls `AddonTable.CreateOptionsPanel()`, which:
   - Validates the assembled schema via `AddonTable.ValidateSchema()` (chat-prints any malformed rows; never blocks).
   - Builds the about-page canvas (`Helpers.CreatePanel(..., { isMain = true })`) and registers it via `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`.
   - Walks the queue, calling `builder(mainCategory)` on each entry. Each builder constructs its own canvas via `Helpers.CreatePanel`, defers the AceGUI render to the panel's first `OnShow` (the body has 0 width at PLAYER_LOGIN; AceGUI lays out against current width), and returns the result of `Settings.RegisterCanvasLayoutSubcategory(mainCategory, panel, name)`.
   - If the builder returns `nil` (e.g. `Options/Profiles.lua` when AceDBOptions is missing), the page is silently skipped.
   - Captures the sub-category flagged `isDefault = true` (typically General) into `defaultCategoryID` for `OpenOptionsPanel`.

## `RegisterOptionsPage(key, name, builder, opts)`

```lua
AddonTable.RegisterOptionsPage("bar", "Bar", function(mainCategory)
    local H   = AddonTable.Helpers
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

-- General opts in to isDefault so /at config opens it:
AddonTable.RegisterOptionsPage("general", "General", buildGeneral, { isDefault = true })
```

- `key` — short identifier used in `pageKey` (the schema's `page` filter) and in the panel frame's global name.
- `name` — display name shown in the Blizzard Settings tree AND used as the `<Page>` half of the breadcrumb header.
- `builder(mainCategory)` — must return the sub-category from `Settings.RegisterCanvasLayoutSubcategory`, or `nil` to skip registration.
- `opts.isDefault = true` — flags the page that `/at config` should open. Typically `General`. If no page is flagged, `OpenOptionsPanel` falls back to the parent (about page).

## `Helpers.RenderSchema(ctx, pageKey, afterGroup?)`

The two-column layout engine. Walks `AddonTable.SchemaForPage(pageKey)` and emits each row as an AceGUI widget through `Helpers.RenderField`, packing pairs of rows into 50%-width Flow rows. Section breaks (whenever `row.group` changes) emit a full-width `Heading` widget (`GameFontNormalLarge`) flanked by side dividers, with `SECTION_TOP_SPACER = 10` / `SECTION_BOTTOM_SPACER = 6` around it. Every two-column row is followed by a `ROW_VSPACER = 8` spacer for breathing room.

A row marked `solo = true` flushes any in-progress two-column row first, then renders alone (left half of its own row, right half empty). Used for visually-grouping pivots like a texture row that sits above its color-picker pair.

The optional `afterGroup` map is `{ [groupName] = function(ctx) ... end }`. Each callback fires once, immediately after the group's last schema row is rendered (and before the next group's heading). General uses this to inject `Helpers.InlineButtonPair` ("Reset Position" + "Reset All Settings") under the **Master controls** group.

## Widget makers and refresher closures

Each row dispatches to a maker by `row.type`:

| Type | Widget | Notes |
|------|--------|-------|
| `bool` | `CheckBox` | Honors `inverse = true` (widget shows `not value`). |
| `number` | `Slider` | Snaps to `step` on `OnMouseUp`. |
| `string` | `Dropdown` (or `LSM30_Statusbar` / `_Border` / `_Font` when `dialogControl` is set and the LSM widget is loaded) | Falls back to plain `Dropdown` if the LSM widget didn't load. |
| `color` | `ColorPicker` | Honors `hasAlpha`; greys out when `disabledIf`'s sibling toggle is on. |

Every maker registers a **refresher closure** in `ctx.refreshers`. The closure re-reads from `db.profile` and pushes the value back into the widget (via `widget:SetValue` / `SetColor`, which AceGUI does NOT fire `OnValueChanged` for — so no recursion). After every widget write, `Helpers.RefreshAllPanels()` runs every refresher on every panel ctx, so paired controls re-sync immediately (e.g. flipping `useClassColorBar` greys the `barColor` picker on the same frame).

Tooltips on every widget go through `Helpers.AttachTooltip`, which `SetCallback`s `OnEnter` / `OnLeave` to drive `GameTooltip` anchored on `widget.frame`. Label = `row.label`, body = `row.desc`.

### Live color preview

The `ColorPicker` maker treats `OnValueChanged` (fires during drag) as the primary write. Each fire goes through a 50ms throttle so a sustained drag doesn't repaint the bar 60×/s. `OnValueConfirmed` (fires only on cancel, with the original color) commits immediately so the bar snaps back to the pre-drag color without waiting on the throttle window.

## Always-visible scrollbar

`Helpers.PatchAlwaysShowScrollbar(scroll)` rebinds the AceGUI `ScrollFrame`'s `FixScroll`/`MoveScroll`/`OnRelease` so the scrollbar never auto-hides. Short pages (General) keep the same right-edge gutter as long pages (Bar) — the thumb just greys out and locks at value 0 when content fits the viewport. The patch restores stock behavior on widget release so the AceGUI pool returns to a clean state for the next acquirer.

## Profile change refresh

When AceDB fires `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset`, the active profile flips. `AddonTable.RefreshOptionsPanel()` (called from `OnProfileChanged` after the bar repaint chain) routes to `Helpers.RefreshAllPanels()`, which walks every panel ctx and runs every registered refresher closure. Each refresher re-reads its row's value from `db.profile` and pushes it into the widget — values that didn't survive the profile flip update; values that did are no-ops.

The same `RefreshAllPanels` runs after every `/at set` write (via `SlashCommands.lua`) and after every panel widget's `set()` (via the local `set()` in `OptionsPanel.lua` — see [Widget makers](#widget-makers-and-refresher-closures) above), so panel-driven and slash-driven mutations both keep open panels in sync.

## `OpenOptionsPanel` and the combat-lockdown gate

```lua
function AddonTable.OpenOptionsPanel()
    if InCombatLockdown() then
        AddonTable.Print("Cannot open settings panel during combat. Try again after combat ends.")
        return
    end
    Settings.OpenToCategory(defaultCategoryID or mainCategoryID)
end
```

`Settings.OpenToCategory` is part of Blizzard's protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI. The combat-lockdown early-return is mandatory; don't try to clever-defer the call.

`defaultCategoryID` is the sub-category flagged `isDefault = true` (General). If no default was registered, falls back to `mainCategoryID` — the about page. Always flag *some* page as the default.

## LSM swatch dropdowns

Texture / border / font select fields use `dialogControl = "LSM30_Statusbar"` (or `_Border` / `_Font`) on their schema row. `Helpers.RenderField` → `makeDropdown` reads `dialogControl` and creates the matching AceGUI widget directly:

```lua
local widgetType = row.dialogControl or "Dropdown"
if widgetType ~= "Dropdown" and not AceGUI:GetWidgetVersion(widgetType) then
    widgetType = "Dropdown"   -- LSM widget didn't load; fall back to plain dropdown
end
local dd = AceGUI:Create(widgetType)
```

The LSM30_* widgets live at `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/widget.lua`. Each renders entries with an inline preview swatch (statusbar / border / font face). The widget type names match the upstream `AceGUI-3.0-SharedMediaWidgets` lib so dropping in the real lib later is a clean swap.

## About page (top-level "Ka0s Absorb Tracker")

`buildMainContent(ctx)` (called from the parent panel's first `OnShow`) renders three blocks into the AceGUI scroll:

1. **Logo.** `media/screenshots/absorbracker.logo.v2.tga` at native 300×300, anchored TOPLEFT inside a full-width SimpleGroup.
2. **TOC `Notes` blurb** — full-width `Label` with `GameFontHighlight`, left-justified.
3. **Slash Commands section** — a full-width `Heading` widget (`GameFontNormalLarge`) followed by one `Label` row per entry in `AddonTable.SlashCommands`, formatted `|cffffff00/at <cmd>|r  |cffffffff—|r  <desc>`. The list stays in lockstep with `/at help` because both walk the same `AddonTable.SlashCommands` array.

## See also

- [schema.md](./schema.md) — what a row in `AddonTable.Schema` looks like and how it drives both the panel and the slash CLI.
- [profiles.md](./profiles.md) — how profile changes drive `RefreshOptionsPanel`.
- [midnight-quirks.md](./midnight-quirks.md) — patch-day breakage catalog.
