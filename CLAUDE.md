# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AbsorbTracker is a World of Warcraft addon that displays absorb shield values on the player's character. It's a modular Lua addon targeting WoW retail (12.0.0+).

## Architecture

The addon is split into 9 modular files, loaded in order via the TOC file. See
`ARCHITECTURE.md` for a deeper system-design walkthrough.

| File | Lines | Purpose |
|------|-------|---------|
| `Core.lua` | ~36 | AddonTable setup, defaults table, cached math functions |
| `Utils.lua` | ~52 | Print (cyan [AT] prefix), DebugPrint, PrintLSMList, ParseColor |
| `Settings.lua` | ~173 | GetSetting/SetSetting, LSM wrappers, fallback constants, class color helpers |
| `UI.lua` | ~60 | Bar frame creation (BackdropTemplate, StatusBar, FontString) |
| `Display.lua` | ~107 | UpdateBarAppearance, UpdateAbsorbBar, RestoreBarPosition |
| `Timer.lua` | ~40 | C_Timer.NewTicker management for periodic updates |
| `Events.lua` | ~80 | Event handlers (PLAYER_LOGIN, UNIT_ABSORB_AMOUNT_CHANGED), OnProfileChanged |
| `SlashCommands.lua` | ~413 | `/at` and `/absorbtracker` slash dispatch and subcommand handlers |
| `OptionsPanel.lua` | ~950 | Settings UI panel with all controls |

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
- `AddonTable.RestartUpdateTicker()` - Timer control
- `AddonTable.CreateOptionsPanel()` / `AddonTable.RefreshOptionsPanel()` / `AddonTable.OpenOptionsPanel()` - Options panel

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
- **Profile changes** trigger `AddonTable.OnProfileChanged()` callback to refresh all UI
- **Backdrop refresh** requires `SetBackdrop(nil)` before `SetBackdrop(info)` to force visual update
- **Secret values** from `UnitGetTotalAbsorbs()` must use `AbbreviateNumbers()` directly (no tonumber conversion)
- **Class color** - Bar, background, and border each have an independent `useClassColor*` toggle. Colors are resolved at call time via `GetBarColor()`/`GetBgColor()`/`GetBorderColor()` in Settings.lua. Background class color uses a darkened variant (×0.2 multiplier) from a per-class lookup table.
- **Custom dropdowns** - All dropdowns in OptionsPanel use `CreateCustomDropdown()`, a shared scrollable dropdown builder (no `UIDropDownMenuTemplate`). Scrollbar appears at 10+ items, auto-scrolls to selected value on open. A shared `dropdownClickCatcher` frame closes any open dropdown when clicking outside.
- **Chat output** - All addon chat messages go through `AddonTable.Print()` which prepends a cyan `|cFF00FFFF[AT]|r` prefix. `Utils.lua`, `SlashCommands.lua`, and `OptionsPanel.lua` shadow the global `print` with `local print = AddonTable.Print` so existing `print(...)` call sites stay unchanged.
- **Slash dispatch** - `/at` and `/absorbtracker` both bind to `SlashCmdList["ABSORBTRACKER"]`. `/at` with no args (and any unknown command) prints help via the `else` branch; `/at config` opens the options panel. Help rows use `PrintCmd(cmd, desc)` to format yellow command + white explanation.

## Testing

No automated tests. Test by:
1. Copy addon to WoW AddOns folder
2. `/reload` in-game
3. Use `/at debug` for verbose logging
4. Get an absorb effect (e.g., Power Word: Shield) to verify display
5. Test settings via both slash commands and settings panel
6. Test profile switching - create/switch profiles, verify settings refresh

## WoW API Notes

- Uses `UnitGetTotalAbsorbs("player")` for absorb amount (returns "secret" value)
- Uses `UnitHealthMax("player")` for bar scaling
- Uses `AbbreviateNumbers()` for display formatting (handles secret values)
- Settings panel uses `Settings.RegisterCanvasLayoutCategory()` (WoW 10.0+) or `InterfaceOptions_AddCategory()` (legacy)
- Frame templates: `BackdropTemplate`, `InterfaceOptionsCheckButtonTemplate`, `OptionsSliderTemplate`, `InputBoxTemplate`, `UIPanelButtonTemplate`
- Backdrop changes require clearing first: `SetBackdrop(nil)` then `SetBackdrop(info)`

## File Structure

```
AbsorbTracker/
├── AbsorbTracker.toc    # Table of contents - defines load order
├── Core.lua             # AddonTable setup, defaults
├── Utils.lua            # Print pipeline, debug, ParseColor
├── Settings.lua         # Database, LSM, color resolution
├── UI.lua               # Bar frame creation
├── Display.lua          # Bar update functions
├── Timer.lua            # Update ticker management
├── Events.lua           # Event handlers and login bootstrap
├── SlashCommands.lua    # Slash command dispatcher
├── OptionsPanel.lua     # Settings UI panel
├── README.md            # User documentation
├── ARCHITECTURE.md      # System-design walkthrough
└── CLAUDE.md            # Developer guidance (this file)
```
