# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `AbsorbTracker.toc` is the source of truth for load order.

## Top-level Lua

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 1 | `Core.lua` | 36 | `AddonTable.defaults` (AceDB-shaped) + `flatDefaults` alias to `defaults.profile`. Caches `math.floor` / `math.max` / `math.min` / `format` on `AddonTable` to avoid repeated global lookups in hot paths. |
| 2 | `Utils.lua` | 21 | `AddonTable.Print(...)` — the cyan-`[AT]` chat-prefix pipeline. `AddonTable.DebugPrint(...)` — gated on `AddonTable.DEBUG`, routes through the same prefix. Shadows the global `print` for its own file so naked `print(...)` calls inside Utils get the prefix too. |
| 3 | `Settings.lua` | 173 | `db` ref, `GetSetting(key)` / `SetSetting(key, value)` over `db.profile`, LSM wrappers (`GetBarTexture` / `GetBgTexture` / `GetBorder` / `GetFont`) with `FALLBACK_*` constants, color getters that resolve `useClassColor*` at call time (`GetBarColor` / `GetBgColor` / `GetBorderColor`), `GetPlayerClassColor` / `GetBgClassColor`, `ClearLSMCache` (called once at PLAYER_LOGIN). |
| 4 | `Schema.lua` | 332 | The schema registry. `RegisterSchemaRows(rows)` (append), `FindSchemaRow(path)` / `SchemaForPage(pageKey)` (lookup), `GetByPath(path)` / `SetByPath(path, value)` / `ApplyDefault(row)` (read/write/reset, fires `onChange`), `FormatSchemaValue(row, value)` / `ParseSchemaValue(row, text)` (slash IO), `BuildPageOptions(pageKey, pageName)` (assembles an AceConfig options table from the schema rows for one page). See [schema.md](./schema.md). |
| 5 | `UI.lua` | 60 | Bar-frame creation at file-load time. Creates `AbsorbTrackerFrame` (outer movable `BackdropTemplate` frame, exported as `AddonTable.bar`), `statusBar` (child `StatusBar`), `valueText` (`FontString` child of `statusBar`). Also creates the reusable `AddonTable.backdropInfo` table. |
| 6 | `Display.lua` | 107 | `UpdateBarAppearance` (re-applies *every* visual setting; calls `SetBackdrop(nil)` first to force refresh), `UpdateAbsorbBar` (reads `UnitGetTotalAbsorbs` / `UnitHealthMax`, formats with `AbbreviateNumbers`), `RestoreBarPosition` (re-applies the saved `position` table or centers if absent). |
| 7 | `Timer.lua` | 40 | Single `C_Timer.NewTicker` runs `UpdateAbsorbBar` at `updateInterval` seconds. `RestartUpdateTicker(forceRestart?)` short-circuits when interval is unchanged; `ResetTickerInterval()` clears tracked interval to force a rebuild on profile change. |
| 8 | `Events.lua` | 80 | Hidden frame registered for `PLAYER_LOGIN` (bootstrap), `PLAYER_ENTERING_WORLD` (zone reset), `UNIT_ABSORB_AMOUNT_CHANGED` (debug log only). `OnProfileChanged` registered for AceDB's three profile callbacks. See [data-flow.md](./data-flow.md). |
| 9 | `SlashCommands.lua` | 345 | `/at` and `/absorbtracker` dispatcher (both bind to `SlashCmdList["ABSORBTRACKER"]`). KickCD-style `COMMANDS = { {name, desc, handler}, ... }` array. The schema-aware `/at list / get / set / reset / resetall` walk `AddonTable.Schema`. Non-schema verbs: `config`, `lock` / `unlock` / `toggle`, `debug`, `update`, `test [value]`, `resetposition`, `profile <sub>`. |
| 10 | `OptionsPanel.lua` | 141 | Settings registration shell. `RegisterOptionsPage(key, name, builder, opts)` (file-load queue), `CreateOptionsPanel()` (PLAYER_LOGIN drain — registers empty title-only "Ka0s Absorb Tracker" parent + each queued page via `AceConfigDialog:AddToBlizOptions("AbsorbTracker-<key>", name, "Ka0s Absorb Tracker")`), `RefreshOptionsPanel()` (`AceConfigRegistry:NotifyChange` per registered page), `OpenOptionsPanel()` (combat-lockdown gated). See [settings-panel.md](./settings-panel.md). |

## Options/ — sub-page schemas

Each file under `Options/` is a thin schema declaration: register schema rows for the page, declare a `build()` closure that returns `BuildPageOptions(pageKey, pageName)` (or appends inline groups for action buttons), then `RegisterOptionsPage(key, name, build, opts?)`.

| # | File | Lines | Schema rows |
|---|------|-------|-------------|
| 11 | `Options/General.lua` | 87 | `hidden` (rendered inverse as "Show Bar"), `locked`, `updateInterval`. Build closure appends an inline Position group with a Reset Position execute button. Flagged `isDefault = true` so `/at config` opens this page. |
| 12 | `Options/Bar.lua` | 113 | `barWidth`, `barHeight`, `barTexture` / `useClassColorBar` / `barColor` (with `disabledIf = "useClassColorBar"`), and the same trio for the background (`bgTexture` / `useClassColorBg` / `bgColor`). |
| 13 | `Options/Border.lua` | 69 | `border` (LSM border style), `borderSize`, `useClassColorBorder`, `borderColor`. |
| 14 | `Options/Font.lua` | 70 | `font`, `fontSize`, `fontFlags`. |
| 15 | `Options/Profiles.lua` | 20 | `AceDBOptions:GetOptionsTable(AddonTable.db)`. Not schema-driven; AceDBOptions builds its own options table. The build function returns `nil` if AceDBOptions is missing, which causes `OptionsPanel.lua`'s `registerPage` to skip the page silently. |

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
| `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/` | In-tree minimal `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Font` AceGUI widget that renders preview swatches in the LSM dropdowns. Names match the upstream `AceGUI-3.0-SharedMediaWidgets` lib so dropping in the real lib later is a clean swap. |

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
