# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `AbsorbTracker.toc` is the source of truth for load order.

## Top-level Lua

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 1 | `Core.lua` | 36 | `AddonTable.defaults` (AceDB-shaped) + `flatDefaults` alias to `defaults.profile`. Caches `math.floor` / `math.max` / `math.min` / `format` on `AddonTable` to avoid repeated global lookups in hot paths. |
| 2 | `Utils.lua` | 21 | `AddonTable.Print(...)` — the cyan-`[AT]` chat-prefix pipeline. `AddonTable.DebugPrint(...)` — gated on `AddonTable.DEBUG`, routes through the same prefix. Shadows the global `print` for its own file so naked `print(...)` calls inside Utils get the prefix too. |
| 3 | `LSMPatch.lua` | 61 | Third-party-lib polyfill. Registers a one-shot `PLAYER_LOGIN` `CreateFrame` hook that wraps the currently-registered `LSM30_Border` constructor at `currentVer + 1`, hides upstream's 42×42 `displayButton` preview tile, and re-anchors `frame.label` and `frame.DLeft` to the frame's left edge so the closed dropdown's chrome sits flush with neighbouring sliders/checkboxes. No-ops cleanly when the upstream lib isn't loaded. |
| 4 | `Settings.lua` | 171 | `db` ref, `GetSetting(key)` / `SetSetting(key, value)` over `db.profile`, LSM wrappers (`GetBarTexture` / `GetBgTexture` / `GetBorder` / `GetFont`) with `FALLBACK_*` constants, color getters that resolve `useClassColor*` at call time (`GetBarColor` / `GetBgColor` / `GetBorderColor`), `ClearLSMCache` (called once at PLAYER_LOGIN). The internal class-color resolvers (`GetPlayerClassColor` / `GetBgClassColor`) are upvalues used by the color getters. |
| 5 | `Schema.lua` | 260 | The schema registry. `RegisterSchemaRows(rows)` (append), `FindSchemaRow(path)` / `SchemaForPage(pageKey)` (lookup; sorts by `row.order`), `SetByPath(path, value)` / `ApplyDefault(row)` (write/reset, fires `onChange`), `FireSchemaOnChange(row, value)` (the `onChange` dispatcher exported for the panel widget makers), `FormatSchemaValue(row, value)` / `ParseSchemaValue(row, text)` (slash IO), `ValidateSchema()` (registration-time row-shape sanity check; chat-prints malformed rows). See [schema.md](./schema.md). |
| 6 | `UI.lua` | 60 | Bar-frame creation at file-load time. Creates `AbsorbTrackerFrame` (outer movable `BackdropTemplate` frame, exported as `AddonTable.bar`), `statusBar` (child `StatusBar`), `valueText` (`FontString` child of `statusBar`). Also creates the reusable `AddonTable.backdropInfo` table. |
| 7 | `Display.lua` | 107 | `UpdateBarAppearance` (re-applies *every* visual setting; calls `SetBackdrop(nil)` first to force refresh), `UpdateAbsorbBar` (reads `UnitGetTotalAbsorbs` / `UnitHealthMax`, formats with `AbbreviateNumbers`), `RestoreBarPosition` (re-applies the saved `position` table or centers if absent). |
| 8 | `Timer.lua` | 40 | Single `C_Timer.NewTicker` runs `UpdateAbsorbBar` at `updateInterval` seconds. `RestartUpdateTicker(forceRestart?)` short-circuits when interval is unchanged; `ResetTickerInterval()` clears tracked interval to force a rebuild on profile change. |
| 9 | `Events.lua` | 80 | Hidden frame registered for `PLAYER_LOGIN` (bootstrap), `PLAYER_ENTERING_WORLD` (zone reset), `UNIT_ABSORB_AMOUNT_CHANGED` (debug log only). `OnProfileChanged` registered for AceDB's three profile callbacks. See [data-flow.md](./data-flow.md). |
| 10 | `SlashCommands.lua` | 347 | `/at` and `/absorbtracker` dispatcher (both bind to `SlashCmdList["ABSORBTRACKER"]`). The exported `AddonTable.SlashCommands = { {name, desc, handler}, ... }` array — the about page renders the same list via `buildMainContent`. The schema-aware `/at list / get / set / reset / resetall` walk `AddonTable.Schema`. Non-schema verbs: `config`, `lock` / `unlock` / `toggle`, `debug`, `update`, `test [value]`, `resetposition`, `profile <sub>`. |
| 11 | `OptionsPanel.lua` | 958 | Settings UI framework. `RegisterOptionsPage(key, name, builder)` (file-load queue), `CreateOptionsPanel()` (PLAYER_LOGIN drain — `ValidateSchema` + canvas-layout main category + each queued page registered via `Settings.RegisterCanvasLayoutSubcategory`), `RefreshOptionsPanel()` (routes to `Helpers.RefreshAllPanels`), `OpenOptionsPanel()` (combat-lockdown gated; opens the parent category and expands the sub-page tree). Exposes the `Helpers` table on `AddonTable` (`CreatePanel` / `RenderField` / `RenderSchema` / `Section` / `InlineButtonPair` / `RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels` / `AttachTooltip` / `PatchAlwaysShowScrollbar`) so each `Options/<page>.lua` builds its own canvas. The top-level "Ka0s Absorb Tracker" canvas hosts an about page (logo + Notes + slash command list) and is the page `/at config` lands on. See [settings-panel.md](./settings-panel.md). |

## Options/ — sub-page schemas

Each file under `Options/` registers schema rows for the page (except `Profiles.lua`), declares a `build(mainCategory)` closure that creates a canvas via `Helpers.CreatePanel`, defers `Helpers.RenderSchema(ctx, pageKey)` to first `OnShow`, and returns the result of `Settings.RegisterCanvasLayoutSubcategory`. Then `RegisterOptionsPage(key, name, build, opts?)`.

| # | File | Lines | Schema rows |
|---|------|-------|-------------|
| 12 | `Options/General.lua` | 138 | `hidden` (rendered inverse as "Show Bar"), `locked`, `updateInterval` (solo). Build closure injects an `InlineButtonPair` ("Reset Position" + "Reset All Settings") under the **Master controls** group via the `afterGroup` callback; defines the `ABSORBTRACKER_RESET_ALL` `StaticPopupDialog` for the destructive confirm. |
| 13 | `Options/Bar.lua` | 154 | `barWidth` / `barHeight` (Size pair), then `barTexture` / `barColor` paired with `useClassColorBar` (solo) below for the Bar Fill section, and the same `bgTexture` / `bgColor` + `useClassColorBg` (solo) trio for Background. The two color rows carry `disabledIf = "useClassColorBar"` / `"useClassColorBg"` so the picker greys out when the matching toggle is on. |
| 14 | `Options/Border.lua` | 100 | One section "Border" laid out as 2×2: `border` (LSM border style) / `borderSize`; `useClassColorBorder` / `borderColor`. |
| 15 | `Options/Font.lua` | 105 | One section "Typography": `font` / `fontSize`; `fontFlags` (solo). |
| 16 | `Options/Profiles.lua` | 70 | Custom canvas with the unified header (no Defaults button), an AceGUI `SimpleGroup` parented to `ctx.body`, and `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` on first `OnShow`. Not schema-driven; AceDBOptions supplies its own options table. The build function returns `nil` if AceDBOptions / AceConfigDialog / AceGUI is missing, which silently skips the page. |

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
