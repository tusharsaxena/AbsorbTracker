# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow

- **Never auto-stage.** Don't run `git add` (or any equivalent that moves files into the index) without an explicit instruction from the user. The user reviews the working-tree diff before staging is part of the loop they want to keep.
- **Never auto-commit.** Wait for an explicit instruction (e.g. "commit this", "commit and push") before running `git commit` or `git push`. This applies even after long multi-file changes that look obviously commit-ready — the user chooses when to commit.
- Same rule for pushing: never push without an explicit instruction.
- **Never bump the version without an explicit instruction.** The version lives in `AbsorbTracker.toc` (`## Version:`) and in `README.md` (badge + changelog header). Don't increment either, and don't add a new changelog entry, just because a refactor or feature looks "done" — the user decides when to cut a release.

## Project Overview

AbsorbTracker is a World of Warcraft addon that displays absorb shield values on the player's character. It's a modular Lua addon targeting WoW retail (12.0.0+).

## Architecture

The addon is split into a core set of modules plus a per-page options
directory. All files are loaded in order via the TOC. See `ARCHITECTURE.md`
for a deeper system-design walkthrough.

| File | Lines | Purpose |
|------|-------|---------|
| `Core.lua` | 36 | AddonTable setup, defaults table, cached math functions |
| `Utils.lua` | 21 | Print (cyan [AT] prefix), DebugPrint |
| `Settings.lua` | 173 | GetSetting/SetSetting, LSM wrappers, fallback constants, class color helpers |
| `Schema.lua` | 332 | Schema registry: RegisterSchemaRows, FindSchemaRow, SchemaForPage, GetByPath/SetByPath/ApplyDefault, FormatSchemaValue, ParseSchemaValue, BuildPageOptions(pageKey) |
| `UI.lua` | 60 | Bar frame creation (BackdropTemplate, StatusBar, FontString) |
| `Display.lua` | 107 | UpdateBarAppearance, UpdateAbsorbBar, RestoreBarPosition |
| `Timer.lua` | 40 | C_Timer.NewTicker management for periodic updates |
| `Events.lua` | 80 | Event handlers (PLAYER_LOGIN, PLAYER_ENTERING_WORLD, UNIT_ABSORB_AMOUNT_CHANGED), OnProfileChanged |
| `SlashCommands.lua` | 345 | `/at` dispatcher: COMMANDS table + schema-driven list/get/set/reset |
| `OptionsPanel.lua` | 141 | Registration shell: queues page builders, registers an empty top-level "Ka0s Absorb Tracker" category and each Options/*.lua under it |
| `Options/General.lua` | 87 | General sub-page (default) — schema rows for Show Bar, Lock, Update Interval; injects Reset Position execute. `/at config` opens this. |
| `Options/Bar.lua` | 113 | Bar sub-page — schema rows for width, height, fill texture+color, background texture+color |
| `Options/Border.lua` | 69 | Border sub-page — schema rows for style, size, color |
| `Options/Font.lua` | 70 | Font sub-page — schema rows for face, size, outline |
| `Options/Profiles.lua` | 20 | Profiles sub-page — wraps `AceDBOptions:GetOptionsTable(db)` |

### Module Communication

All modules share state through the `AddonTable` (second return value from `...`). Key exports:

- `AddonTable.defaults` / `AddonTable.flatDefaults` - Default settings
- `AddonTable.db` - AceDB database reference (set in Events.lua on PLAYER_LOGIN)
- `AddonTable.bar` / `AddonTable.statusBar` / `AddonTable.valueText` - UI elements
- `AddonTable.Print()` / `AddonTable.DebugPrint()` - Cyan-`[AT]`-prefixed chat output
- `AddonTable.GetSetting()` / `AddonTable.SetSetting()` - Settings access
- `AddonTable.GetBarColor()` / `AddonTable.GetBgColor()` / `AddonTable.GetBorderColor()` - Color getters (resolve class color at call time)
- `AddonTable.GetPlayerClassColor()` / `AddonTable.GetBgClassColor()` - Class color helpers
- `AddonTable.ClearLSMCache()` - Reset cached LSM reference (called after PLAYER_LOGIN)
- `AddonTable.UpdateBarAppearance()` / `AddonTable.UpdateAbsorbBar()` - Display updates
- `AddonTable.RestoreBarPosition()` - Re-apply the saved `position` table (or center if absent). Called on PLAYER_LOGIN and OnProfileChanged.
- `AddonTable.RestartUpdateTicker(forceRestart?)` / `AddonTable.ResetTickerInterval()` - Timer control. RestartUpdateTicker short-circuits when the interval is unchanged; ResetTickerInterval clears the tracked interval so the next call always rebuilds the ticker (used on profile change).
- `AddonTable.OnProfileChanged()` - Registered for AceDB's OnProfileChanged / OnProfileCopied / OnProfileReset callbacks. Runs RestoreBarPosition + UpdateBarAppearance + UpdateAbsorbBar + ResetTickerInterval + RestartUpdateTicker(true) + RefreshOptionsPanel.
- `AddonTable.lastAbsorb` - Cached absorb value used to short-circuit redundant updates; reset to -1 to force the next UpdateAbsorbBar to repaint.
- `AddonTable.Schema` - Flat array of schema rows. Single source of truth for every user-facing setting; both the AceConfig sub-pages and the slash dispatcher walk it.
- `AddonTable.RegisterSchemaRows(rows)` - Each `Options/*.lua` calls this at file-load time to append its rows. Row shape: `{ path, page, group?, order, type, label, desc?, default, ... }` — see Schema.lua header for the full grammar.
- `AddonTable.FindSchemaRow(path)` / `AddonTable.SchemaForPage(pageKey)` - Schema lookup helpers used by slash and panel layers.
- `AddonTable.GetByPath(path)` / `AddonTable.SetByPath(path, value)` - Schema-aware read/write (fires the row's onChange). `/at set` and the panel widgets both go through SetByPath.
- `AddonTable.ApplyDefault(row)` - Reset one schema row to `row.default`. Used by `/at reset` and `/at resetall`.
- `AddonTable.FormatSchemaValue(row, value)` / `AddonTable.ParseSchemaValue(row, text)` - Render a value for `/at list/get` output / parse a slash-command tail into a typed value for `/at set`.
- `AddonTable.BuildPageOptions(pageKey, pageName)` - Assemble an AceConfig options table from the schema rows for one page (groups by `row.group`, sorts by `row.order`).
- `AddonTable.RegisterOptionsPage(key, name, builder, opts)` - Each `Options/*.lua` calls this at file-load time to queue itself. `builder()` runs at PLAYER_LOGIN and returns an AceConfig options table (typically `BuildPageOptions(key, name)`). `opts.isDefault = true` flags the page that `/at config` opens (General).
- `AddonTable.CreateOptionsPanel()` / `AddonTable.RefreshOptionsPanel()` / `AddonTable.OpenOptionsPanel()` - Options panel registration / re-render / open

### Forward References

Some modules reference functions defined in later-loaded files:
- `Events.lua` calls `AddonTable.CreateOptionsPanel()` (defined in OptionsPanel.lua)
- `Events.lua` calls `AddonTable.RefreshOptionsPanel()` (defined in OptionsPanel.lua)

These are handled with runtime nil checks:
```lua
if AddonTable.RefreshOptionsPanel then
    AddonTable.RefreshOptionsPanel()
end
```

## Key Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| barTexture | string | "Blizzard Raid Bar" | Status bar texture (LSM) |
| bgTexture | string | "Blizzard Raid Bar" | Background texture (LSM) |
| border | string | "Blizzard Tooltip" | Border style (LSM) |
| borderSize | number | 12 | Border thickness (1-32) |
| borderColor | table | {r=0.5, g=0.5, b=0.5, a=1.0} | Border color |
| font | string | "Friz Quadrata TT" | Font face (LSM) |
| fontSize | number | 12 | Font size (6-32) |
| fontFlags | string | "OUTLINE" | Font outline style (OUTLINE, THICKOUTLINE, MONOCHROME, etc.) |
| barWidth | number | 200 | Bar width in pixels (50-500) |
| barHeight | number | 20 | Bar height in pixels (10-100) |
| barColor | table | {r=0.4, g=0.7, b=1.0, a=0.8} | Bar fill color |
| bgColor | table | {r=0.2, g=0.2, b=0.2, a=0.8} | Background color |
| useClassColorBar | boolean | false | Use class color for bar fill |
| useClassColorBg | boolean | false | Use class color for background |
| useClassColorBorder | boolean | false | Use class color for border |
| locked | boolean | false | Lock bar position |
| hidden | boolean | false | Hide bar |
| updateInterval | number | 1.0 | Update frequency in seconds |
| position | table | nil | Saved bar position {point, relPoint, x, y} |

## Profile System

The addon uses AceDB-3.0 for profile management (optional dependency). Key features:

- **Shared profiles** - Same settings can be used across multiple characters
- **Per-character profiles** - Each character can have unique settings
- **Profile operations** - Create, copy, delete, reset profiles

### Profile Slash Commands
- `/at profile list` - List all available profiles
- `/at profile current` - Show current profile name
- `/at profile use <name>` - Switch to a profile (creates if doesn't exist)
- `/at profile new <name>` - Create new profile with default settings
- `/at profile copy <name>` - Copy settings from another profile
- `/at profile delete <name>` - Delete a profile (cannot delete current)
- `/at profile reset` - Reset current profile to defaults

### Fallback Behavior
If AceDB-3.0 is not installed, the addon falls back to a simple db-like structure using `AbsorbTrackerDB` directly. All settings still work, but profile management is disabled.

## Key Patterns

- **AddonTable sharing** - All modules access shared state via `AddonTable` (the second vararg)
- **AceDB-3.0** integration is optional - addon works without it but loses profile features
- **LibSharedMedia-3.0** integration is optional - addon works without it using fallback textures/fonts
- **Settings access** uses `AddonTable.GetSetting(key)` and `AddonTable.SetSetting(key, value)` which abstract db.profile access
- **Settings changes** call `AddonTable.UpdateBarAppearance()` to apply immediately
- **Profile changes** trigger `AddonTable.OnProfileChanged()` callback to refresh all UI; `RefreshOptionsPanel` calls `AceConfigRegistry:NotifyChange` on every registered page so AceConfigDialog re-reads from `db.profile` on the active page
- **Backdrop refresh** requires `SetBackdrop(nil)` before `SetBackdrop(info)` to force visual update
- **Secret values** from `UnitGetTotalAbsorbs()` must use `AbbreviateNumbers()` directly (no tonumber conversion)
- **Class color** - Bar, background, and border each have an independent `useClassColor*` toggle. Colors are resolved at call time via `GetBarColor()`/`GetBgColor()`/`GetBorderColor()` in Settings.lua. Bar and border use `C_ClassColor.GetClassColor()`; background uses a hard-coded per-class table multiplied by `0.2` to produce a darkened variant (cached in `playerBgClassColor` since the player class doesn't change at runtime). Each color row carries `disabledIf = "useClassColor*"`; `Schema.BuildPageOptions` translates that into an AceConfig `disabled` callback so the picker greys out when the matching toggle is on.
- **Multi-page settings** - `OptionsPanel.lua` is a thin shell. At PLAYER_LOGIN it registers an empty title-only top-level "Ka0s Absorb Tracker" category, then registers each `Options/*.lua` page underneath it via `AceConfigDialog:AddToBlizOptions(appName, name, "Ka0s Absorb Tracker")`. Each `Options/*.lua` calls `AddonTable.RegisterOptionsPage(key, name, builder, opts)` at load time to queue itself; `opts.isDefault = true` flags the page that `/at config` should open (typically General). `appName` is `AbsorbTracker-<key>` so each page has its own AceConfig namespace; the parent uses `AbsorbTracker`.
- **Schema-driven settings** - `AddonTable.Schema` is a flat array; each `Options/<page>.lua` (except Profiles) calls `AddonTable.RegisterSchemaRows({ ... })` at file-load time to append its rows. The page's `build()` then returns `AddonTable.BuildPageOptions(pageKey, pageName)` — an AceConfig options table assembled from the schema (rows with the same `group` cluster into an inline AceConfig group; `order` sets the rendering sequence). The same schema feeds `/at list`, `/at get`, `/at set`, `/at reset` and `/at resetall`. Adding a new option = one schema row. The panel widgets and slash command surface for that path are wired automatically.
- **Schema row behavior knobs** - `inverse = true` on a bool flips the widget value vs. the db value (used for `hidden` rendered as "Show Bar"). `disabledIf = "<sibling-path>"` on a color greys out the picker when the named sibling toggle is on (used for class-color overrides). `onChange` defaults to `UpdateBarAppearance`; rows with different reactions (e.g. `updateInterval` calls `RestartUpdateTicker`) override explicitly.
- **LSM swatch dropdowns** - Texture/border/font select fields use `dialogControl = "LSM30_Statusbar"` (or `_Border` / `_Font`). Custom AceGUI widgets at `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/widget.lua` render each item with an inline preview swatch. Names match the upstream `AceGUI-3.0-SharedMediaWidgets` lib so dropping in the real lib later is a clean swap.
- **Chat output** - All addon chat messages go through `AddonTable.Print()` which prepends a cyan `|cFF00FFFF[AT]|r` prefix. `Utils.lua`, `SlashCommands.lua`, and `OptionsPanel.lua` shadow the global `print` with `local print = AddonTable.Print` so existing `print(...)` call sites stay unchanged.
- **Slash dispatch** - `/at` and `/absorbtracker` both bind to `SlashCmdList["ABSORBTRACKER"]`. The handler walks a `COMMANDS` table mapping `name -> { desc, handler }`. `/at` with no args prints help (header + each COMMANDS row formatted as yellow `/at <cmd>` em-dash white description, KickCD-style). `/at config` opens the options panel on the General sub-page. The schema-aware `/at list`, `/at get <path>`, `/at set <path> <value>`, `/at reset <page>`, `/at resetall` cover every schema row without per-setting code; per-setting subcommands like `/at width` / `/at color` were removed in favor of `/at set <path>`.

## Testing

No automated tests. Test by:
1. Copy addon to WoW AddOns folder
2. `/reload` in-game
3. Use `/at debug` for verbose logging
4. Get an absorb effect (e.g., Power Word: Shield) to verify display
5. Test settings via both slash commands and settings panel
6. Test profile switching - create/switch profiles, verify settings refresh

## WoW API Notes

- TOC `## Interface:` declares 120000, 120001, 120005 — patches Midnight 12.0.0, 12.0.1, and 12.0.5. Update this list when a new compatible patch ships.
- Uses `UnitGetTotalAbsorbs("player")` for absorb amount (returns "secret" value)
- Uses `UnitHealthMax("player")` for bar scaling
- Uses `AbbreviateNumbers()` for display formatting (handles secret values)
- Settings panel registration goes through `AceConfigDialog:AddToBlizOptions(appName, name, parentName?)`, which internally calls `Settings.RegisterCanvasLayoutCategory` (parent) or `Settings.RegisterCanvasLayoutSubcategory` (child) on WoW 10.0+
- `Settings.OpenToCategory(categoryID)` opens the panel; the parent's category ID is the second return value of `AceConfigDialog:AddToBlizOptions`. `OpenOptionsPanel` refuses to call this during combat (`InCombatLockdown()`) because the Settings category-switch is protected.
- Frame templates: `BackdropTemplate` (used by the bar frame and the LSM dropdown widget)
- Backdrop changes require clearing first: `SetBackdrop(nil)` then `SetBackdrop(info)`

## File Structure

```
AbsorbTracker/
├── AbsorbTracker.toc          # Table of contents - defines load order
├── Core.lua                   # AddonTable setup, defaults
├── Utils.lua                  # Print pipeline, debug
├── Settings.lua               # Database, LSM, color resolution
├── Schema.lua                 # Schema registry + AceConfig options builder + value parser
├── UI.lua                     # Bar frame creation
├── Display.lua                # Bar update functions
├── Timer.lua                  # Update ticker management
├── Events.lua                 # Event handlers and login bootstrap
├── SlashCommands.lua          # Slash command dispatcher
├── OptionsPanel.lua           # Settings registration shell
├── Options/
│   ├── General.lua            # Default sub-page: visibility, lock, interval, reset
│   ├── Bar.lua                # Sub-page: dimensions, fill, background
│   ├── Border.lua             # Sub-page: style, size, color
│   ├── Font.lua               # Sub-page: face, size, outline
│   └── Profiles.lua           # Sub-page: AceDBOptions wrapper
├── libs/
│   ├── LibStub-1.0/
│   ├── CallbackHandler-1.0/
│   ├── LibSharedMedia-3.0/
│   └── Ace3/
│       ├── AceAddon-3.0/
│       ├── AceDB-3.0/
│       ├── AceGUI-3.0/
│       ├── AceConfig-3.0/
│       ├── AceDBOptions-3.0/
│       └── AceGUI-3.0-SharedMediaWidgets/   # In-tree LSM30_* widgets
├── README.md                  # User documentation
├── ARCHITECTURE.md            # System-design walkthrough
└── CLAUDE.md                  # Developer guidance (this file)
```
