# Settings panel

How the addon registers its multi-page Blizzard Settings UI. The schema-driven content of each page is documented in [schema.md](./schema.md); this doc is about the *registration shell* — `LibKa0s-Options-1.0`, the three `settings/*.lua` files that wire the addon into it, and the per-page `settings/<page>.lua` declarations.

## Source layout

**The shell is not this addon's code any more.** `LibKa0s-Options-1.0` — three vendored files, one major — owns the canvas panel factory, the unified header, the page registry, the widget makers, the two-column flow engine and the always-visible scrollbar patch. What stays here is the part that is ours: where a value lives, which rows belong to which page, what a color looks like on disk, and the two pieces that did not generalize.

| File | Role |
|------|------|
| `libs/LibKa0s/Options.lua` | The shell. `CreatePanel` / `EnsureDefaultsButton` / `EnsureScroll` / `ClearScroll` / `RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels` / `LSMValues` / `RegisterOptionsPage` / `CreateOptionsPanel` / `OpenOptionsPanel`, the private page queue and panel registry, and `lib.LAYOUT` (every metric from `PADDING_X` to `BUTTON_PAIR_REL`). |
| `libs/LibKa0s/OptionsWidgets.lua` | `RenderField` (dispatches by `row.type`) + `RenderRows` (two-column layout over an explicit row list, skipping `skipRender` rows) + the thin `RenderSchema(ctx, pageKey, ...)` wrapper + the five widget makers (CheckBox / Slider / Dropdown / EditBox / ColorPicker) + `Section` / `AddSpacer` / `AttachTooltip` / `InlineButtonPair` / `SessionCheckbox`. |
| `libs/LibKa0s/OptionsScroll.lua` | `PatchAlwaysShowScrollbar` — the always-visible scrollbar override. |
| `settings/OptionsSetup.lua` | The descriptor, and the degradation stub. Holds the brand string as a file-scope `PARENT_TITLE` local passed in as `descriptor.parentTitle` (there is no `NS.PARENT_TITLE`), builds `NS.Helpers = lib:New(descriptor)`, and publishes the four thin wrappers `NS.RegisterOptionsPage` / `NS.CreateOptionsPanel` / `NS.OpenOptionsPanel` / `NS.RefreshOptionsPanel`. |
| `settings/UnitPanel.lua` | The two pieces that did not generalize: `Helpers.RenderUnitPanel(ctx, pageKey)` (Unit dropdown + mirror header for Bar/Border/Font, full rebuild per call) and `Helpers.ResetAllPositions()`. |
| `settings/About.lua` | `Helpers.BuildMainContent` — top-level "Ka0s Absorb Tracker" page (logo + Notes + slash command list). |

`NS.Helpers` **is** the library instance, not a table decorated from a copy of it. `settings/UnitPanel.lua` and `settings/About.lua` begin with `local addonName, NS = ...` then `local Helpers = NS.Helpers` and hang their members on that same table, so a page file calls `H.RenderUnitPanel` and `H.RenderSchema` without knowing or caring which side owns which. That identity is deliberate twice over: decoration only works because the library's own members live on the table being decorated, and a test that swaps a member out to spy on it (`tests/test_helpers.lua` does exactly that with `ResetAllPositions`) is swapping the one the library's own callers see.

TOC order under `# Settings` is `settings/Schema.lua` → `Slash.lua` → `OptionsSetup.lua` → `UnitPanel.lua` → `About.lua` → `General` / `Bar` / `Border` / `Font` / `Profiles`. `OptionsSetup.lua` must load before every page file, because those call `NS.Helpers.LSMValues` inside schema-row literals at **file load** — see [the degradation stub](#the-degradation-stub) below.

### The descriptor

`settings/OptionsSetup.lua` hands the library one table of callbacks. The library never learns a settings path, a page name or a database:

| Field | What this addon supplies |
|------|------|
| `parentTitle` / `mainPanelName` | `"Ka0s Absorb Tracker"` and `"AbsorbTrackerMainPanel"`. |
| `print` / `debug` | `NS.Print` (cyan `[AT]` prefix) and `NS.Debug`. |
| `get` / `set` / `applyDefault` | `NS.GetSetting` / `NS.SetByPath` / `NS.ApplyDefault` — so a panel write takes exactly the path a `/at set` takes. |
| `rowsForPage(pageKey, filter)` / `allRows` | `NS.SchemaForPage` and `NS.Schema`. `filter` is `ctx.unit`, passed through uninterpreted — that is what makes a per-unit page render only the selected unit's rows while General (`ctx.unit` nil) gets every unit's. |
| `skipRestoreAll` | Skips `row.page == "profiles"`: those rows are AceDBOptions-supplied and resetting them would delete user data, which is not what "restore defaults" means to anyone. |
| `afterRestoreAll` | `Helpers.ResetAllPositions` — `position` is written by dragging, not by a schema row, so `ApplyDefault` never touches it and a target bar dragged off-screen would survive a Reset All. |
| `scheduleTimer` | `NS.addon:ScheduleTimer` (Ka0s standard library-stack-§1, not a raw `C_Timer`), backing the color picker's 50 ms drag throttle. The library takes it as a descriptor field because embedding AceTimer would be its second dependency-budget breach. |
| `getLSM` / `validate` | `NS.GetLSM` and `NS.ValidateSchema`. |
| `onAceGUI` | `function(AceGUI) NS.AceGUI = AceGUI end` — see below. |
| `buildMain` | Forwards to `NS.Helpers.BuildMainContent`, resolved at call time because `settings/About.lua` loads *after* `OptionsSetup.lua`. |
| `colorDecode` / `colorEncode` | The `{r=, g=, b=, a=}` named-key shape `core/Data.lua`'s color resolvers read. Written out rather than left to the library's identical default, because the shape is a real contract with the rest of the addon and a silent default is a poor place for it to live. |

### The `NS.AceGUI` upvalue

The library resolves AceGUI through LibStub — once at `:New`, again in `CreateOptionsPanel` — and pushes the result out through the descriptor's `onAceGUI` hook, which this addon stores as `NS.AceGUI`. `settings/UnitPanel.lua` and `settings/About.lua` read that stashed field rather than re-`LibStub`-ing on each call. Because the hook fires inside `CreateOptionsPanel` before any page builder runs, the field is always populated by the time a builder or refresher touches it. If AceGUI is absent, `CreateOptionsPanel` prints `lib.STRINGS.NO_ACEGUI` and returns; `RenderUnitPanel` independently bails on a nil `NS.AceGUI`.

### The degradation stub

If `libs/LibKa0s/` is absent, `settings/OptionsSetup.lua` returns early with a hand-built `NS.Helpers`. **It is load-completing, not member-answering** — and that breaks the pattern every other setup file in this addon follows, on purpose.

`core/CoreSetup.lua` and `core/DebugLogSetup.lua` degrade to a table that answers each member with an honest "not installed" line. That calculus does not survive contact with this one, and the reason is not importance — it is *when* the missing code is reached. `settings/Bar.lua` evaluates `NS.Helpers.LSMValues("statusbar")` inside a schema-row literal, at **file load**; `Border.lua` and `Font.lua` do the same. With `LSMValues` nil that is `attempt to call field 'LSMValues' (a nil value)`, so `settings/Bar.lua` never finishes loading, so `NS.RegisterSchemaRows` never runs for the bar page, so a third of `NS.Schema` is missing — and `/at list`, `/at set units.player.barWidth`, `/at reset` and the profile defaults all break with it. The addon would not degrade; it would half-load, and nothing would say so.

So the stub publishes every member a page file touches at load time. Verified to be exactly three — `LSMValues`, `SECTION_HEADING_H` (`settings/About.lua`) and `RestoreAllDefaults` (the `StaticPopup` body in `settings/General.lua`, a table literal evaluated at load) — plus the two layout constants `ROW_VSPACER` and `BUTTON_PAIR_REL`. `RestoreAllDefaults` is real, not a no-op: the rows are the schema's and the schema loaded fine, so a reset still works with no panel at all. Losing the panel is survivable; losing the reset would not be. Everything else is reached from `CreateOptionsPanel` or from a page builder, both user-triggered, so those are no-ops, and `NS.CreateOptionsPanel` / `NS.OpenOptionsPanel` print one honest MISSING line.

`RenderUnitPanel` is deliberately **absent** from the stub: `settings/UnitPanel.lua` loads after this file and publishes the real one either way, and it already bails on a nil `NS.AceGUI`. A no-op here would read as though the degraded build had its own, which it does not.

Note what is also not here: no copy of a widget maker, no copy of the flow engine, no copy of the header. Hand-copying the code whose drift the extraction exists to end is the one duplicate [testing.md](./testing.md) §8 most specifically forbids. The guard is `tests/test_perf.lua`'s `loadDegraded()`, which loads the whole TOC without the library and asserts `#NS.Schema` against the fully-loaded environment. That case is the only thing standing between this stub and a silent half-load.

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

**Bar / Border / Font are per-unit; General and About are not.** Bar/Border/Font render through `Helpers.RenderUnitPanel(ctx, pageKey)` (`settings/UnitPanel.lua`), which draws a **Unit** dropdown (Player/Target/Focus) above the schema rows and filters them to the selected unit. General shows no Unit dropdown either — its three globals are unit-agnostic, and its three `units.<unit>.enabled` toggles are all rendered at once rather than filtered — and About has no settings at all.

Profiles is the only page that still uses AceConfig — it routes `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` into an AceGUI `SimpleGroup` parented to the canvas body, so the AceDBOptions UI lands inside our shell with the same header.

## Unified header

Every page (about + sub-pages) builds the same header via `Helpers.CreatePanel(name, title, opts)`:

- `GameFontNormalHuge` title in **breadcrumb** form: `"Ka0s Absorb Tracker ▸ <Page>"` for sub-pages, where the separator is the inline-atlas escape `|A:common-icon-forwardarrow:16:16|a` (a real texture, not a font glyph — font-agnostic and locale-safe). The about page passes `opts.isMain = true` to render the unprefixed `"Ka0s Absorb Tracker"`. The Blizzard left-tree label (driven by `panel.name`) stays unprefixed so the tree indents under the parent without visual repetition.
- `Options_HorizontalDivider` atlas underneath the title, tinted to the title's font color (read off the title FontString rather than hardcoded so a theme retune tracks automatically).
- Optional **Defaults** button (width `DEFAULTS_W = 110`) at TOPRIGHT — General / Bar / Border / Font opt in via `opts.defaultsButton = true`. It calls `Helpers.RestoreDefaults(pageKey, ctx)`, which reverts that page's rows across all three units; `/at reset` takes a single setting path, not a page name. As of `LibKa0s-Options-1.0` minor 5 it is no longer the only way in: `CreatePanel` also stamps the Blizzard canvas callbacks `OnCommit` / `OnRefresh` / `OnDefault` on the panel, and `OnDefault` **forwards** (rather than assigns) to whatever `panel.defaultsOnClick` holds at click time — which is what lets every page park its handler *after* `CreatePanel` returns and still be reached by Blizzard's own footer defaults control. That control is not per-page, so a page that parks nothing gets a callable no-op instead of an error. No page file changed for any of this; `tests/test_helpers.lua` pins it so a re-vendor cannot take it away unnoticed. About page and Profiles deliberately omit it (about page has no settings; Profiles has its own destructive controls inside the AceDBOptions UI).
- Layout constants: `PADDING_X = 16`, `HEADER_TOP = 20`, `HEADER_HEIGHT = 54`. The body frame anchors `(0, -(HEADER_HEIGHT + 8))` below TOPLEFT. These live in `lib.LAYOUT` and are **not** reachable as `Helpers.*`; the three the instance does republish are `SECTION_HEADING_H`, `ROW_VSPACER` and `BUTTON_PAIR_REL`, because a host draws its own rows against those.

`CreatePanel` returns a `ctx` table threaded through the rest of the helpers: `{ panel, body, scroll = nil, refreshers = {}, lastGroup = nil, pageKey }` (per-unit pages additionally carry `ctx.unit` and the transient `ctx.__rendering` re-entry guard). Every ctx is appended to the library's panel registry so `RefreshAllPanels` can re-run its refreshers. The registry itself is private; the addon-visible handles are the test seams `Helpers.__panels()` and `Helpers.__panelFor(pageKey)`, which exist because a suite otherwise has no handle on a live ctx — and a real bug shipped here precisely because one page's ctx was unreachable and therefore never asserted on.

## File-load registration vs. enable-time registration

`settings/OptionsSetup.lua` runs at file-load time (early), but `NS.db` doesn't exist until the AceAddon lifecycle has run `NS:InitDB`. The shell separates the two phases:

1. **File-load.** Each `settings/<page>.lua` calls `NS.RegisterOptionsPage(key, name, builder)` to enqueue itself on the library's private page queue. The builder is a closure that will run later. (The schema rows themselves also register at file-load via `NS.RegisterSchemaRows` — see [schema.md](./schema.md).)
2. **Enable.** `addon:OnEnable` (in `core/AbsorbTracker.lua`, at PLAYER_LOGIN timing) calls `NS.CreateOptionsPanel()` as the last step of its login sequence, which is a one-line delegate to the library's own. In order, the library:
   - Re-resolves AceGUI through LibStub and hands it out via `onAceGUI` (bails with a chat notice if it is unavailable). Re-resolved rather than trusting the handle taken at `:New` time, because an AceGUI absent at load may be present by PLAYER_LOGIN, and this is the one place that can report it.
   - Runs the descriptor's `validate` hook — `NS.ValidateSchema()`, which chat-prints any malformed rows or unresolvable paths and never blocks.
   - Builds the about-page canvas (`CreatePanel(..., { isMain = true })`) and registers it via `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`, deferring the body render — the descriptor's `buildMain`, which forwards to `Helpers.BuildMainContent` — to the panel's first `OnShow`.
   - Walks the queued pages, calling `builder(mainCategory)` on each entry. Each builder constructs its own canvas via `Helpers.CreatePanel`, defers the AceGUI render to the panel's first `OnShow` (the body has 0 width at enable time; AceGUI lays out against current width), and returns the result of `Settings.RegisterCanvasLayoutSubcategory(mainCategory, panel, name)`.
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

The per-unit page renderer, and one of the two things `settings/UnitPanel.lua` keeps. It did not generalize: it reads `NS.Units` and the mirror partition, which no other Ka0s addon has. Everything it stands on — `ClearScroll`, `EnsureScroll`, `RenderRows`, `AttachTooltip` — is the library's, reached through the same `NS.Helpers` table.

On every call (first `OnShow`, a unit-dropdown switch, a mirror-checkbox toggle, or a Copy click) it does a **full rebuild**: `Helpers.ClearScroll(ctx)` releases every AceGUI child and resets the section-heading tracker + `ctx.refreshers`, then:

1. Draws a **Unit** dropdown (`AceGUI:Create("Dropdown")`, labeled "Unit", listing `NS.Units.LABEL` in `NS.Units.LIST` order). Changing it sets `ctx.unit` and re-runs `RenderUnitPanel` — the dropdown's own selection therefore also survives a rebuild.
2. For target/focus (never for player, which is the mirror source and has no header), draws a mirror header row: a **"Use same styling as Player"** checkbox (writes `units.<unit>.mirror` via `NS.SetByPath`, re-renders on change) side-by-side with a **"Copy styling from Player"** button (`NS.Units.CopyFromPlayer(unit)` — a one-shot deep-copy of the fifteen appearance keys that also clears `mirror`, followed by publishing `NS.MSG.APPEARANCE` and a re-render). While mirrored, a hint label reads *"Linked to Player – uncheck to customize."* (en dash).
3. Splits the page's rows for the selected unit via `NS.PartitionUnitRows(NS.SchemaForPage(pageKey, ctx.unit))` into `perUnitRows` (`alwaysPerUnit = true` — e.g. "Enable this bar") and `styledRows` (everything else). `perUnitRows` always render; `styledRows` render only when the unit is **not** mirrored — mirroring hides every appearance widget because editing them would silently edit the player's bar, not the mirrored unit's.

Both row groups render through `Helpers.RenderRows` (below) — the same two-column layout engine General's unit-agnostic `Helpers.RenderSchema` uses.

4. Registers one final **header refresher** on `ctx.refreshers`. **This is not decoration.** The mirror checkbox and the Copy button in step 2 are built inline, not through `Helpers.RenderField`, so neither registers a refresher of its own — without this one, `Helpers.RefreshAllPanels` structurally could not update them and nothing re-ran the step-3 partition. `Helpers.RestoreDefaults("bar", ctx)` resets `units.focus.mirror` to its default `true` and then runs only the refreshers, so the header checkbox would still read unchecked and the appearance rows would stay on screen over a now-mirrored unit (same after `/at set units.focus.mirror true`, and after a profile switch). It self-corrected on the next `OnShow`, which is what made it present as "the panel lied to me once".

   The refresher is **two-tier**, and the split is the whole point. `libs/LibKa0s/OptionsWidgets.lua`'s file-local `set` calls `RefreshAllPanels` after *every* schema write, so this closure runs on every checkbox click, slider drag and LSM pick on the page:

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

The **Debug console** checkbox toggles the **visibility of the console window only** — the same as the bare `/at debug`. It deliberately does **not** change the debug logging flag (`NS.State.debug`); that stays on `/at debug on|off` and the window's own header toggle. It is **not** a schema row: `Helpers.SessionCheckbox` reads/writes window visibility through `NS.DebugLog` (`get` = `D:IsShown()`, `set` = `D:Show()`/`D:Hide()`) rather than a persisted path, so ticking it never lands in the saved profile. Whenever the window's visibility changes by any route — this checkbox, bare `/at debug`, the header Close button, or Esc (`UISpecialFrames`) — the console frame's `OnShow`/`OnHide` hooks fire `LibKa0s-DebugLog-1.0`'s `onVisibilityChanged` descriptor hook, which `core/DebugLogSetup.lua` points at `NS.Helpers.RefreshAllPanels` — so an open settings panel's checkbox stays in sync. `ConsoleCheckbox()` itself returns a plain `{ label, tooltip, get, set }` table: a data contract the library hands over and this addon assembles into a widget, so neither side reaches into the other.

## Widget makers and refresher closures

Each row dispatches to a maker by `row.type`:

| Type | Widget | Notes |
|------|--------|-------|
| `bool` | `CheckBox` | Reads and writes the stored value directly. |
| `number` | `Slider` | Snaps to `step` on `OnMouseUp`. |
| `string` | `Dropdown` (or `LSM30_Statusbar` / `_Border` / `_Font` when `dialogControl` is set and the LSM widget is loaded) | Falls back to plain `Dropdown` if the LSM widget didn't load. |
| `color` | `ColorPicker` | Honors `hasAlpha`; grays out when `disabledIf`'s sibling toggle is on. |

The library has a fifth maker — `EditBox`, selected by `dialogControl = "EditBox"` on a string row, committing on `OnEnterPressed` only. No schema row in this addon uses it.

Each maker reads via `NS.GetSetting(row.path)` and writes via `NS.SetByPath(row.path, value)` — the documented single-write seam (`SetSetting` + `fireOnChange` in one call; see [schema.md](./schema.md)). Every maker also registers a **refresher closure** in `ctx.refreshers`. The closure re-reads the value and pushes it back into the widget (via `widget:SetValue` / `SetColor`, which AceGUI does NOT fire `OnValueChanged` for — so no recursion). After every widget write, `Helpers.RefreshAllPanels()` runs every refresher on every panel ctx, so paired controls re-sync immediately (e.g. flipping `useClassColorBar` grays the `barColor` picker on the same frame).

Tooltips on every widget go through `Helpers.AttachTooltip`, which `SetCallback`s `OnEnter` / `OnLeave` (or `HookScript`s them on a plain Blizzard frame) to drive `GameTooltip` anchored on `widget.frame`. Label = `row.label`, body = `row.desc`.

### Live color preview

The `ColorPicker` maker treats `OnValueChanged` (fires during drag) as the live-preview write and `OnValueConfirmed` (fires only on cancel, with the original color) as the immediate commit. Each drag fire goes through a **50 ms throttle** so a sustained drag doesn't repaint the bar 60×/s; cancel commits immediately so the bar snaps back to the pre-drag color without waiting on the throttle window.

The throttle is a single re-armed **AceTimer** one-shot — `timer = NS.addon:ScheduleTimer(fn, 0.05)` (Ka0s standard library-stack-§1, **not** a raw `C_Timer.NewTimer`). A reused `pendingArgs` table holds the latest RGBA, so a 60 Hz drag produces O(1) garbage instead of 60 closures + 60 arg tables per second; the one-shot self-clears (`timer = nil` inside the callback) so there's no `CancelTimer`. The throttled commit path intentionally does **not** call `RefreshAllPanels` — traversing every panel widget every 50 ms during a drag would be wasteful.

## Always-visible scrollbar

`Helpers.PatchAlwaysShowScrollbar(scroll)` (in `libs/LibKa0s/OptionsScroll.lua`, called from `Helpers.EnsureScroll` right after the AceGUI `ScrollFrame` is created) rebinds the AceGUI `ScrollFrame`'s `FixScroll` / `MoveScroll` / `OnRelease` so the scrollbar never auto-hides. Short pages (General) keep the same right-edge gutter as long pages (Bar) — the thumb just grays out (vertex color `0.5,0.5,0.5,0.6`) and locks at value 0 when content fits the viewport. The patch restores stock behavior on widget release so the AceGUI pool returns to a clean state for the next acquirer.

## Profile change refresh

When AceDB fires `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` (registered in `NS:InitDB`, `core/Database.lua`), the active profile flips and `NS.OnProfileChanged` runs the bar repaint chain, then calls `NS.RefreshOptionsPanel()`. That routes to `Helpers.RefreshAllPanels()`, which walks every panel ctx in the library's registry and runs every registered refresher closure. Each refresher re-reads its row's value via `NS.GetSetting` and pushes it into the widget — values that didn't survive the profile flip update; values that did are no-ops.

The same `RefreshAllPanels` runs after every `/at set`, `/at reset`, and `/at resetall` write (via `settings/Slash.lua` → `NS.SetByPath` / `RefreshOptionsPanel`) and after every panel widget's `set()` (via the file-local `set()` in `libs/LibKa0s/OptionsWidgets.lua` — see [Widget makers](#widget-makers-and-refresher-closures) above), so panel-driven and slash-driven mutations both keep open panels in sync.

## `OpenOptionsPanel` and the combat-lockdown gate

`NS.OpenOptionsPanel` (`settings/OptionsSetup.lua`) is a one-line delegate to `O.OpenOptionsPanel` in `libs/LibKa0s/Options.lua`. The gate is the library's, and the behavior is unchanged from when this addon owned it:

1. Under `InCombatLockdown()` — emit a `Cfg` debug line, print `lib.STRINGS.COMBAT_REFUSED`, return. Nothing else runs.
2. Otherwise — guard `Settings and Settings.OpenToCategory` and the captured `mainCategoryID`, then `Settings.OpenToCategory(mainCategoryID)` followed by `expandMainCategory()`.

`Settings.OpenToCategory` is part of Blizzard's protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI. Per Ka0s standard options-ui-§2 the gate **refuses** rather than defers: it prints a single gray, `[AT]`-tagged notice (canonical text *"cannot open settings during combat — Blizzard's category-switch is protected"*, gray hex `aaaaaa`) and returns, never touching the protected category-switch under lockdown. It does **not** defer-and-replay — `addon:OnLeaveCombat` (`core/AbsorbTracker.lua`) only re-applies visibility and repaints now, with no queued open to replay — because a panel that auto-opens the instant combat ends steals focus during post-pull recovery; the user re-runs `/at config` when ready. The gate lives inside `OpenOptionsPanel` (not just the slash dispatcher), so `/run` scripts and any internal caller are refused too. The notice reaches chat through the descriptor's `print` hook, which routes to `NS.Print`, so it still carries the cyan `[AT]` prefix.

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

The LSM30_* widgets are the canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65 lib, vendored folder-per-lib at `libs/AceGUI-3.0-SharedMediaWidgets/` and loaded via `widget.xml`. `LSM30_Statusbar` / `LSM30_Font` use upstream's `GetBaseFrame` (no preview tile); `LSM30_Border` uses `GetBaseFrameWithWindow`, which adds a 42×42 `displayButton` border-preview tile pinned to the widget's TOPLEFT. That tile clashes with our canvas-layout panel — `NS.ApplyLSMBorderPatch` (in `core/LSMPatch.lua`) is called from `addon:OnEnable`, by which point every addon's libs have loaded and the `LSM30_Border` registry slot is stable. It wraps whatever constructor AceGUI currently holds, re-registers the wrapper at `currentVersion + 1` (via `RegisterWidgetType`, to win the version race), and per-instance hides `displayButton` and re-anchors `frame.label` / `frame.DLeft` to the frame's left edge so the empty 42px slot collapses. The fixup lives in addon code (`RegisterWidgetType`, Ka0s standard library-stack-§5) rather than as an edit to the vendored lib, so a future r66+ refresh is a clean drop-in.

The dropdown's `values` table is supplied by `Helpers.LSMValues(mediaType)`, which returns a deferred closure that pulls the live `NS.GetLSM():HashTable(mediaType)` at dropdown-render time. Schema rows in `settings/Bar.lua` / `Border.lua` / `Font.lua` set `values = NS.Helpers.LSMValues("statusbar")` (etc.) at file-load — the closure is then invoked by `makeDropdown`'s `valuesHash()` every time the dropdown re-renders, so newly-registered LSM media show up without an addon reload.

## About page (top-level "Ka0s Absorb Tracker")

`Helpers.BuildMainContent(ctx)` (defined in `settings/About.lua`, fired by the library from the main panel's first `OnShow` through the descriptor's `buildMain` hook — which resolves the member at call time precisely because `About.lua` loads *after* `settings/OptionsSetup.lua`) renders three blocks into the AceGUI scroll:

1. **Logo.** `NS.Constants.LOGO_PATH` (`media/logos/absorbracker.logo.v2.tga`) at native 300×300, anchored TOPLEFT inside a full-width SimpleGroup.
2. **TOC `Notes` blurb** — full-width `Label` with `GameFontHighlight`, left-justified. The Notes string is read through `NS.Compat.GetAddOnMetadata` (Ka0s standard `compat` — the single deprecated-API shim).
3. **Slash Commands section** — a full-width `Heading` widget (`GameFontNormalLarge`) followed by one `Label` row per string returned by `NS.Slash:LandingRows()`, formatted `|cFFFFFF00/at <cmd>|r — |cFFFFFFFF<desc>|r`: gold command, an em dash with a **single** space either side, and a **white** description. That is `LibKa0s-Slash-1.0`'s one row formatter — literally the same function `/at help` prints through, minus the two-space chat indent, which belongs to the chat renderer because a settings-panel label sitting under a heading does not need one. So the about list and the help block cannot drift. The list itself is `NS.COMMANDS` (`settings/Slash.lua`), handed to the library rather than owned by it.

## See also

- [schema.md](./schema.md) — what a row in `NS.Schema` looks like and how it drives both the panel and the slash CLI.
- [profiles.md](./profiles.md) — how profile changes drive `RefreshOptionsPanel`.
- [midnight-quirks.md](./midnight-quirks.md) — patch-day breakage catalog.
