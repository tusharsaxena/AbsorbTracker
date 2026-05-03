# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `AbsorbTracker.toc` is the source of truth for load order.

## Top-level Lua

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 1 | `Core.lua` | 35 | `AddonTable.defaults` (AceDB-shaped) + `flatDefaults` alias to `defaults.profile`. Caches `math.floor` / `math.max` / `format` on `AddonTable` to avoid repeated global lookups in hot paths. |
| 2 | `Utils.lua` | 21 | `AddonTable.Print(...)` — the cyan-`[AT]` chat-prefix pipeline. `AddonTable.DebugPrint(...)` — gated on `AddonTable.DEBUG`, routes through the same prefix. Shadows the global `print` for its own file so naked `print(...)` calls inside Utils get the prefix too. |
| 3 | `LSMPatch.lua` | 61 | Third-party-lib polyfill. Registers a one-shot `PLAYER_LOGIN` `CreateFrame` hook that wraps the currently-registered `LSM30_Border` constructor at `currentVer + 1`, hides upstream's 42×42 `displayButton` preview tile, and re-anchors `frame.label` and `frame.DLeft` to the frame's left edge so the closed dropdown's chrome sits flush with neighbouring sliders/checkboxes. No-ops cleanly when the upstream lib isn't loaded. |
| 4 | `Settings.lua` | 171 | `db` ref, `GetSetting(key)` / `SetSetting(key, value)` over `db.profile`, LSM wrappers (`GetBarTexture` / `GetBgTexture` / `GetBorder` / `GetFont`) with `FALLBACK_*` constants, color getters that resolve `useClassColor*` at call time (`GetBarColor` / `GetBgColor` / `GetBorderColor`), `ClearLSMCache` (called once at PLAYER_LOGIN). The internal class-color resolvers (`GetPlayerClassColor` / `GetBgClassColor`) are upvalues used by the color getters. |
| 5 | `Schema.lua` | 260 | The schema registry. `RegisterSchemaRows(rows)` (append), `FindSchemaRow(path)` / `SchemaForPage(pageKey)` (lookup; sorts by `row.order`), `SetByPath(path, value)` / `ApplyDefault(row)` (write/reset, fires `onChange`), `FireSchemaOnChange(row, value)` (the `onChange` dispatcher exported for the panel widget makers), `FormatSchemaValue(row, value)` / `ParseSchemaValue(row, text)` (slash IO), `ValidateSchema()` (registration-time row-shape sanity check; chat-prints malformed rows). See [schema.md](./schema.md). |
| 6 | `UI.lua` | 60 | Bar-frame creation at file-load time. Creates `AbsorbTrackerFrame` (outer movable `BackdropTemplate` frame, exported as `AddonTable.bar`), `statusBar` (child `StatusBar`), `valueText` (`FontString` child of `statusBar`). Also creates the reusable `AddonTable.backdropInfo` table. |
| 7 | `Display.lua` | 112 | `UpdateBarAppearance` (re-applies *every* visual setting; calls `SetBackdrop(nil)` first to force refresh), `UpdateAbsorbBar` (reads `UnitGetTotalAbsorbs` / `UnitHealthMax`, formats with `AbbreviateNumbers`; early-outs while `AddonTable.testHoldUntil` is in the future so a `/at test` paint survives the next tick; gates the per-tick DebugPrint behind `AddonTable.DEBUG` so AbbreviateNumbers + format don't run when debug is off), `RestoreBarPosition` (re-applies the saved `position` table or centers if absent). |
| 8 | `Timer.lua` | 39 | Single `C_Timer.NewTicker` runs `UpdateAbsorbBar` at `updateInterval` seconds. `RestartUpdateTicker(forceRestart?)` short-circuits when interval is unchanged; `ResetTickerInterval()` clears tracked interval to force a rebuild on profile change. |
| 9 | `Events.lua` | 84 | Hidden frame registered for `PLAYER_LOGIN` (bootstrap), `PLAYER_ENTERING_WORLD` (zone reset), `UNIT_ABSORB_AMOUNT_CHANGED` (debug log only). `OnProfileChanged` registered for AceDB's three profile callbacks. The AceDB-missing fallback shim deep-copies table-typed defaults so an in-place mutation of a saved variable can't corrupt `flatDefaults`. See [data-flow.md](./data-flow.md). |
| 10 | `SlashCommands.lua` | 355 | `/at` and `/absorbtracker` dispatcher (both bind to `SlashCmdList["ABSORBTRACKER"]`). The exported `AddonTable.SlashCommands = { {name, desc, handler}, ... }` array — the about page renders the same list via `Helpers.BuildMainContent` in `Panel/About.lua`. The schema-aware `/at list / get / set / reset / resetall` walk `AddonTable.Schema`. Non-schema verbs: `config`, `lock` / `unlock` / `toggle`, `debug`, `update`, `test [value] [hold-secs]`, `resetposition`, `profile <sub>`. |
| 11 | `OptionsPanel.lua` | 167 | Settings UI registration shell. Publishes empty `AddonTable.Helpers` for the `Panel/*.lua` slices to decorate, sets `AddonTable.PARENT_TITLE`, owns the `pendingPages` queue. `RegisterOptionsPage(key, name, builder)` appends to that queue; `CreateOptionsPanel()` (PLAYER_LOGIN drain) runs `ValidateSchema`, registers the top-level canvas via `Helpers.CreatePanel`, defers `Helpers.BuildMainContent` to first OnShow, then registers each queued sub-page; `OpenOptionsPanel()` is combat-lockdown gated and expands the parent category in the Settings left tree; `RefreshOptionsPanel()` routes to `Helpers.RefreshAllPanels`. See [settings-panel.md](./settings-panel.md). |

## Panel/ — settings-panel toolkit

The `Panel/` slices decorate the same `AddonTable.Helpers` table that `OptionsPanel.lua` publishes empty. Loaded immediately after `OptionsPanel.lua` (before any `Options/<page>.lua` that consumes the toolkit).

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 12 | `Panel/Helpers.lua` | 354 | Layout constants (`PADDING_X` / `HEADER_HEIGHT` / `ROW_VSPACER` / `SECTION_HEADING_H`) plus the canvas + AceGUI scroll machinery: `Helpers.CreatePanel` (frame factory + unified header + Defaults button), `Helpers.EnsureScroll` (lazy AceGUI ScrollFrame parented to `ctx.body`; calls `Helpers.PatchAlwaysShowScrollbar` once), `Helpers.Section` (AceGUI Heading), `Helpers.InlineButtonPair` (50/50 button row), `Helpers.AttachTooltip`, `Helpers.AddSpacer`, `Helpers.RestoreDefaults` / `Helpers.RestoreAllDefaults` / `Helpers.RefreshAllPanels` (panel registry + reset/refresh wiring), `Helpers.LSMValues(mediaType)` (deferred LSM hash factory used by every LSM-backed schema row). |
| 13 | `Panel/ScrollPatch.lua` | 127 | `Helpers.PatchAlwaysShowScrollbar(scroll)` — rebinds `FixScroll` / `MoveScroll` / `OnRelease` on a single AceGUI ScrollFrame so the scrollbar (and its 20 px gutter) stays visible across every panel; parks the thumb at the top when there's nothing to scroll, restores originals on `OnRelease`. Called by `Helpers.EnsureScroll`. |
| 14 | `Panel/Widgets.lua` | 292 | Schema-row → AceGUI widget translation. `Helpers.RenderField(ctx, row, parent, relativeWidth)` dispatches by `row.type`; the four widget makers (`makeCheckbox` / `makeSlider` / `makeDropdown` / `makeColorPicker`) bind to `db.profile` via `AddonTable.SetByPath` (with `Helpers.RefreshAllPanels` for non-color rows) and register a refresher closure on `ctx.refreshers`. The ColorPicker's drag throttle uses a single re-armed `C_Timer.NewTimer` + reused `pendingArgs` table so a sustained drag produces O(1) garbage. `Helpers.RenderSchema(ctx, pageKey, afterGroup?)` lays a page's rows into 50/50 flow rows with `Helpers.Section` headings and `Helpers.AddSpacer` gutters; `afterGroup` callbacks (e.g. inline button pairs) fire on the next fresh row when their group ends. |
| 15 | `Panel/About.lua` | 108 | `Helpers.BuildMainContent(ctx)` — top-level "Ka0s Absorb Tracker" page builder. Renders the logo TGA, the addon `Notes` one-liner, a "Slash Commands" Heading, and one row per `AddonTable.SlashCommands` entry so the page stays in lockstep with `/at help`. |

## Options/ — sub-page schemas

Each file under `Options/` registers schema rows for the page (except `Profiles.lua`), declares a `build(mainCategory)` closure that creates a canvas via `Helpers.CreatePanel`, defers `Helpers.RenderSchema(ctx, pageKey)` to first `OnShow`, and returns the result of `Settings.RegisterCanvasLayoutSubcategory`. Then `RegisterOptionsPage(key, name, build, opts?)`.

| # | File | Lines | Schema rows |
|---|------|-------|-------------|
| 16 | `Options/General.lua` | 137 | `hidden` (rendered inverse as "Show Bar"), `locked`, `updateInterval` (solo). Build closure injects an `InlineButtonPair` ("Reset Position" + "Reset All Settings") under the **Master controls** group via the `afterGroup` callback; defines the `ABSORBTRACKER_RESET_ALL` `StaticPopupDialog` for the destructive confirm. |
| 17 | `Options/Bar.lua` | 145 | `barWidth` / `barHeight` (Size pair), then `barTexture` / `barColor` paired with `useClassColorBar` (solo) below for the Bar Fill section, and the same `bgTexture` / `bgColor` + `useClassColorBg` (solo) trio for Background. The two color rows carry `disabledIf = "useClassColorBar"` / `"useClassColorBg"` so the picker greys out when the matching toggle is on. LSM dropdowns call `AddonTable.Helpers.LSMValues("statusbar")`. |
| 18 | `Options/Border.lua` | 91 | One section "Border" laid out as 2×2: `border` (LSM border style) / `borderSize`; `useClassColorBorder` / `borderColor`. LSM dropdown calls `AddonTable.Helpers.LSMValues("border")`. |
| 19 | `Options/Font.lua` | 96 | One section "Typography": `font` / `fontSize`; `fontFlags` (solo). LSM dropdown calls `AddonTable.Helpers.LSMValues("font")`. |
| 20 | `Options/Profiles.lua` | 70 | Custom canvas with the unified header (no Defaults button), an AceGUI `SimpleGroup` parented to `ctx.body`, and `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` on first `OnShow`. Not schema-driven; AceDBOptions supplies its own options table. The build function returns `nil` if AceDBOptions / AceConfigDialog / AceGUI is missing, which silently skips the page. |

## Bundled libraries (libs/)

Loaded before any addon source via the `#@no-lib-strip@` block at the top of the TOC.

| Path | Purpose |
|------|---------|
| `libs/LibStub-1.0/` | Library loader. |
| `libs/CallbackHandler-1.0/` | Event callback transport for the Ace3 stack. |
| `libs/LibSharedMedia-3.0/` | Texture / font / border registry. Optional dep — addon falls back to `FALLBACK_*` Blizzard constants in `Settings.lua` when missing. |
| `libs/Ace3/AceAddon-3.0/` | AceDB carrier (no `:NewModule` runtime; modules are plain `AddonTable` files). |
| `libs/Ace3/AceDB-3.0/` | Profile management. Optional dep — addon falls back to a flat `AbsorbTrackerDB` shim when missing. |
| `libs/Ace3/AceGUI-3.0/` | Widget framework used by AceConfigDialog. |
| `libs/Ace3/AceConfig-3.0/` | Pulls in AceConfigRegistry / AceConfigCmd / AceConfigDialog. Required for the multi-page settings UI. |
| `libs/Ace3/AceDBOptions-3.0/` | Builds the Profiles sub-page options table. |
| `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/` | Canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65 (widgetVersion 13, DataVersion 9004). Multi-file lib loaded via `widget.xml` — `prototypes.lua` (the `AceGUISharedMediaWidgets-1.0` LibStub library + base-frame helpers) plus per-mediatype widget files for `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Background` / `LSM30_Font` / `LSM30_Sound`. The addon only references the first three (statusbar / border / font); background and sound are bundled because the lib is monolithic. The 42×42 displayButton tile that upstream's `LSM30_Border` pins to TOPLEFT is suppressed by addon-side `LSMPatch.lua`. |

## Shared infrastructure

- `AbsorbTracker.toc` — Interface line (`120000, 120001, 120005`), `## Version:`, SavedVariables (`AbsorbTrackerDB`), file load order. Order is dependency order, not alphabetical.
- `media/` — bundled images / textures referenced by README screenshots and any addon-shipped media.
- `.gitattributes` — enforces CRLF on `*.lua` / `*.toc` / `*.xml` / `*.md` (`* text=auto eol=crlf` plus explicit per-extension lines).
- `LICENSE` — MIT.

## Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — engineer working notes (hard rules + response style + doc index).
- `ARCHITECTURE.md` — subsystems-at-a-glance + invariants + doc index.
- `docs/*.md` — topic chunks (this file is one of them).
