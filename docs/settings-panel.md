# Settings panel

How the addon registers its multi-page Blizzard Settings UI. The schema-driven content of each page is documented in [schema.md](./schema.md); this doc is about the *registration shell* — `settings/Panel.lua` + the four `settings/*.lua` toolkit slices, plus the per-page `settings/<page>.lua` declarations.

## Source layout

The settings UI is split across five toolkit files (all under `settings/`), plus the per-page declarations:

| File | Role |
|------|------|
| `settings/Panel.lua` | Registration shell. Publishes empty `NS.Helpers = {}` and `NS.PARENT_TITLE`; owns `pendingPages`, `NS.RegisterOptionsPage`, `NS.CreateOptionsPanel`, `NS.OpenOptionsPanel`, `NS.RefreshOptionsPanel`. Stashes `NS.AceGUI` once (see below). |
| `settings/Helpers.lua` | Toolkit core. `CreatePanel` / `Section` / `InlineButtonPair` / `EnsureScroll` / `AttachTooltip` / `AddSpacer` / `LSMValues` / `RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels`, plus the layout constants (`PADDING_X` / `HEADER_HEIGHT` / `ROW_VSPACER` / `SECTION_HEADING_H`) and the panel registry. `RenderUnitPanel(ctx, pageKey)` and `ClearScroll(ctx)` (full rebuild on unit switch / mirror toggle / copy) live here too — the Unit dropdown + mirror header for Bar/Border/Font. |
| `settings/ScrollPatch.lua` | `Helpers.PatchAlwaysShowScrollbar` — the always-visible scrollbar override. |
| `settings/Widgets.lua` | `Helpers.RenderField` (dispatches by `row.type`) + `Helpers.RenderRows` (two-column layout over an explicit row list, skipping `skipRender` rows) + the thin `Helpers.RenderSchema(ctx, pageKey, ...)` wrapper (`RenderRows(ctx, NS.SchemaForPage(pageKey, ctx.unit), ...)`) + the four widget makers (CheckBox / Slider / Dropdown / ColorPicker). |
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

**Bar / Border / Font are per-unit; General and About are not.** Bar/Border/Font render through `Helpers.RenderUnitPanel(ctx, pageKey)`, which draws a **Unit** dropdown (Player/Target/Focus) above the schema rows and filters them to the selected unit. General shows no Unit dropdown either — its three globals are unit-agnostic, and its three `units.<unit>.enabled` toggles are all rendered at once rather than filtered — and About has no settings at all.

Profiles is the only page that still uses AceConfig — it routes `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` into an AceGUI `SimpleGroup` parented to the canvas body, so the AceDBOptions UI lands inside our shell with the same header.

## Unified header

Every page (about + sub-pages) builds the same header via `Helpers.CreatePanel(name, title, opts)`:

- `GameFontNormalHuge` title in **breadcrumb** form: `"Ka0s Absorb Tracker ▸ <Page>"` for sub-pages, where the separator is the inline-atlas escape `|A:common-icon-forwardarrow:16:16|a` (a real texture, not a font glyph — font-agnostic and locale-safe). The about page passes `opts.isMain = true` to render the unprefixed `"Ka0s Absorb Tracker"`. The Blizzard left-tree label (driven by `panel.name`) stays unprefixed so the tree indents under the parent without visual repetition.
- `Options_HorizontalDivider` atlas underneath the title, tinted to the title's font color (read off the title FontString rather than hardcoded so a theme retune tracks automatically).
- Optional **Defaults** button (width `DEFAULTS_W = 110`) at TOPRIGHT — General / Bar / Border / Font opt in via `opts.defaultsButton = true`. About page and Profiles deliberately omit it (about page has no settings; Profiles has its own destructive controls inside the AceDBOptions UI).
- Layout constants: `PADDING_X = 16`, `HEADER_TOP = 20`, `HEADER_HEIGHT = 54`. The body frame anchors `(0, -(HEADER_HEIGHT + 8))` below TOPLEFT.

`CreatePanel` returns a `ctx` table threaded through the rest of the helpers: `{ panel, body, scroll = nil, refreshers = {}, lastGroup = nil, pageKey }` (per-unit pages additionally carry `ctx.unit` and the transient `ctx.__rendering` re-entry guard). Every ctx is appended to the `renderedPanels` registry so `RefreshAllPanels` can re-run its refreshers.

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
    -- Parked, not wired: the button does not exist until the panel's first
    -- OnShow (Helpers.EnsureDefaultsButton), which attaches this.
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults("bar", ctx)
    end

    -- No `rendered` one-shot guard: RenderUnitPanel does a full rebuild (ClearScroll +
    -- re-render) every call — on first OnShow, AND every subsequent unit switch / mirror
    -- toggle / copy — so re-running it on a later OnShow is intentional, not a bug.
    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        H.RenderUnitPanel(ctx, "bar")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "Bar")
end)
```

- `key` — short identifier used in `pageKey` (the schema's `page` filter) and in the panel frame's global name.
- `name` — display name shown in the Blizzard Settings tree AND used as the `<Page>` half of the breadcrumb header.
- `builder(mainCategory)` — must return the sub-category from `Settings.RegisterCanvasLayoutSubcategory`, or `nil` to skip registration.

## `Helpers.RenderUnitPanel(ctx, pageKey)` — Bar / Border / Font

The per-unit page renderer. On every call (first `OnShow`, a unit-dropdown switch, a mirror-checkbox toggle, or a Copy click) it does a **full rebuild**: `Helpers.ClearScroll(ctx)` releases every AceGUI child and resets the section-heading tracker + `ctx.refreshers`, then:

1. Draws a **Unit** dropdown (`AceGUI:Create("Dropdown")`, labeled "Unit", listing `NS.Units.LABEL` in `NS.Units.LIST` order). Changing it sets `ctx.unit` and re-runs `RenderUnitPanel` — the dropdown's own selection therefore also survives a rebuild.
2. For target/focus (never for player, which is the mirror source and has no header), draws a mirror header row: a **"Use same styling as Player"** checkbox (writes `units.<unit>.mirror` via `NS.SetByPath`, re-renders on change) side-by-side with a **"Copy styling from Player"** button (`NS.Units.CopyFromPlayer(unit)` — a one-shot deep-copy of the fifteen appearance keys that also clears `mirror`, followed by publishing `NS.MSG.APPEARANCE` and a re-render). While mirrored, a hint label reads *"Linked to Player – uncheck to customize."* (en dash).
3. Splits the page's rows for the selected unit via `NS.PartitionUnitRows(NS.SchemaForPage(pageKey, ctx.unit))` into `perUnitRows` (`alwaysPerUnit = true` — e.g. "Enable this bar") and `styledRows` (everything else). `perUnitRows` always render; `styledRows` render only when the unit is **not** mirrored — mirroring hides every appearance widget because editing them would silently edit the player's bar, not the mirrored unit's.

Both row groups render through `Helpers.RenderRows` (below) — the same two-column layout engine General's unit-agnostic `Helpers.RenderSchema` uses.

4. Registers one final **header refresher** on `ctx.refreshers`. **This is not decoration.** The mirror checkbox and the Copy button in step 2 are built inline, not through `Helpers.RenderField`, so neither registers a refresher of its own — without this one, `Helpers.RefreshAllPanels` structurally could not update them and nothing re-ran the step-3 partition. `Helpers.RestoreDefaults("bar", ctx)` resets `units.focus.mirror` to its default `true` and then runs only the refreshers, so the header checkbox would still read unchecked and the appearance rows would stay on screen over a now-mirrored unit (same after `/at set units.focus.mirror true`, and after a profile switch). It self-corrected on the next `OnShow`, which is what made it present as "the panel lied to me once".

   The refresher is **two-tier**, and the split is the whole point. `settings/Widgets.lua`'s `set` calls `RefreshAllPanels` after *every* schema write, so this closure runs on every checkbox click, slider drag and LSM pick on the page:

   - **Always** — re-sync the header checkbox in place via `cb:SetValue(NS.Units.IsMirrored(unit))`. Cheap; tears nothing down.
   - **Only when the mirror state changed** since this render (`mirrored` is captured in a local at render time) — call `RenderUnitPanel` again, because a mirror flip is the only thing that can invalidate the step-3 partition.

   An unconditional re-render would rebuild the entire page on every ordinary appearance write, and the *mechanism* is the risk rather than the waste: `ClearScroll` releases the very widget whose `OnValueChanged` / `OnMouseUp` is still on the stack — an `LSM30_*` dropdown with an open pullout, a slider mid-drag — and takes scroll position and tooltips with it. `makeColorPicker` already declines to call `RefreshAllPanels` for exactly this class of reason.

   Registered **last**, so the row refreshers ahead of it have already run; `RefreshAllPanels` iterates the pre-render table, so a closure registered by a re-render is never re-invoked in the same pass. `RenderUnitPanel` additionally sets `ctx.__rendering` for the duration of a render and returns immediately if it is already set, so a refresh fired from *inside* a render cannot recurse.

## `Helpers.RenderRows(ctx, rows, afterGroup?, pairWith?)` / `Helpers.RenderSchema(ctx, pageKey, afterGroup?, pairWith?)`

The two-column layout engine. `RenderRows` takes an **explicit row list** (what `RenderUnitPanel` passes it, pre-filtered and partitioned) and emits each row — except any carrying `skipRender` (e.g. the mirror flag itself, drawn bespoke by the header above) — as an AceGUI widget through `Helpers.RenderField`, packing pairs of rows into 50%-width Flow rows (each pair wrapped in a full-width `SimpleGroup` so AceGUI gives both children exactly half the width). `RenderSchema` is a thin wrapper: `RenderRows(ctx, NS.SchemaForPage(pageKey, ctx.unit), afterGroup, pairWith)` — used by General, which has no per-unit rows and never sets `ctx.unit`, so the `unit` filter is a no-op there. Section breaks (whenever `row.group` changes) emit a full-width `Heading` widget (`GameFontNormalLarge`) flanked by side dividers, with `SECTION_TOP_SPACER = 10` / `SECTION_BOTTOM_SPACER = 6` around it. Every two-column row is followed by a `ROW_VSPACER = 8` spacer for breathing room. A final `scroll:DoLayout()` runs after the last row.

A row marked `solo = true` flushes any in-progress two-column row first, then renders alone (left half of its own row, right half empty). Used for visually-grouping pivots like a texture row that sits above its color-picker pair.

The optional `afterGroup` map is `{ [groupName] = function(ctx) ... end }`. Each callback fires once, immediately after the group's last schema row is rendered (and before the next group's heading), then is nilled out (one-shot). General uses this to inject `Helpers.InlineButtonPair` ("Reset Position" + "Reset All Settings") under the **Master controls** group.

The optional `pairWith` map (fourth argument) is `{ [path] = function(ctx, rowGroup) ... end }`. It attaches a **non-schema** widget as the right partner of a named schema path's row, fired one-shot and only when that path is the lone widget on its current row (so the pair stays 50/50 and never overflows to three-wide). General uses it to inject the **Debug console** checkbox — `Helpers.SessionCheckbox` wired to `NS.DebugLog:ConsoleCheckbox()` — beside `units.focus.enabled`.

On the General page, the **Master controls** group renders **five** schema rows, interleaved so each per-unit enable toggle leads a row with a flat global on its right: `units.player.enabled` ("Enable Player Bar", 10), `locked` ("Lock Position", 15), `units.target.enabled` ("Enable Target Bar", 20), `showOnlyInCombat` ("Show only in combat", 25), `units.focus.enabled` ("Enable Focus Bar", 30). The 50/50 pairing therefore packs them as:

```
[Enable Player Bar]   [Lock Position]
[Enable Target Bar]   [Show only in combat]
[Enable Focus Bar]    [Debug console]            <- pairWith partner
[Reset Position]      [Reset All Settings]       <- afterGroup, Helpers.InlineButtonPair
```

**The odd row count is load-bearing.** Five schema rows pair off as 2 + 2 + 1, leaving Enable Focus Bar alone on the third row — which is the only condition under which `pairWith` will attach the Debug console beside it. Add or remove a Master controls row and the console silently drops to a row of its own.

**The pairing is a pure product of row order**, since `RenderRows` fills left-then-right in the order `SchemaForPage` returns. Re-numbering any one `order` re-columns the whole group; `tests/test_widgets.lua` asserts the pairs by label, and `tests/test_schema.lua` asserts the full five-path sequence, so a stray renumber fails the suite rather than the eye.

The enable toggles are the only unit-scoped rows on General. They keep their `unit` tag but the page renders with `ctx.unit` nil, so `SchemaForPage(page, nil)` returns all three rather than filtering — which is exactly what puts all three on screen at once. They also keep `alwaysPerUnit = true`, which is what stops `/at get units.focus.enabled` from carrying the "(mirrored)" note.

The **Debug console** checkbox toggles the **visibility of the console window only** — the same as the bare `/at debug`. It deliberately does **not** change the debug logging flag (`NS.State.debug`); that stays on `/at debug on|off` and the window's own header toggle. It is **not** a schema row: `Helpers.SessionCheckbox` reads/writes window visibility through `NS.DebugLog` (`get` = `D:IsShown()`, `set` = `D:Show()`/`D:Hide()`) rather than a persisted path, so ticking it never lands in the saved profile. Whenever the window's visibility changes by any route — this checkbox, bare `/at debug`, the header Close button, or Esc (`UISpecialFrames`) — the console frame's `OnShow`/`OnHide` hooks call `NS.Helpers.RefreshAllPanels`, so an open settings panel's checkbox stays in sync.

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
        -- Refuse under lockdown (options-ui-§2): one grey NS.PREFIX notice, then return.
        -- No Settings.OpenToCategory, no PLAYER_REGEN_ENABLED defer-and-replay.
        print("|cffaaaaaacannot open settings during combat \226\128\148 Blizzard's category-switch is protected|r")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    if not mainCategoryID then return end
    Settings.OpenToCategory(mainCategoryID)
    expandMainCategory()
end
```

`Settings.OpenToCategory` is part of Blizzard's protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI. Per Ka0s standard options-ui-§2 the gate **refuses** rather than defers: `OpenOptionsPanel` prints a single grey, `[AT]`-tagged notice (canonical text *"cannot open settings during combat — Blizzard's category-switch is protected"*, grey hex `aaaaaa`) and returns, never touching the protected category-switch under lockdown. It does **not** defer-and-replay — `addon:OnLeaveCombat` (`core/AbsorbTracker.lua`) only re-applies visibility and repaints now, with no queued open to replay — because a panel that auto-opens the instant combat ends steals focus during post-pull recovery; the user re-runs `/at config` when ready. The gate lives inside `OpenOptionsPanel` (not just the slash dispatcher), so `/run` scripts and any internal caller are refused too. (`print` here is the file-local `local print = NS.Print`, so the notice carries the cyan `[AT]` prefix.)

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
