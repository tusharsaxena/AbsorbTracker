# Architecture

This document describes how AbsorbTracker is structured internally. For user-facing
documentation see `README.md`; for AI-assistant quick-reference see `CLAUDE.md`.

## High-level design

AbsorbTracker is a small, modular WoW addon (~1,900 lines of Lua across 9 files).
It follows the standard WoW pattern of TOC-driven file loading and a shared module
table, with a few deliberate choices:

- **No OO framework.** Modules are plain Lua files; functions are attached to a
  shared `AddonTable`. There is no Ace3 `:NewModule()` or class hierarchy.
- **Optional dependencies.** AceDB-3.0 (profiles) and LibSharedMedia-3.0 (custom
  textures/fonts) are detected at runtime via `LibStub`. The addon degrades
  gracefully when either is missing.
- **State lives in `AddonTable`.** Cross-module state (the bar frame, the database
  reference, helper functions) is exported as fields on `AddonTable`, not as
  globals. A few WoW-required globals (`AbsorbTrackerDB`, `SLASH_ABSORBTRACKER*`,
  `AbsorbTrackerFrame`) are the only exceptions.
- **Forward references guarded by nil checks.** Modules sometimes call functions
  defined in later-loaded files; those call sites use `if AddonTable.X then ... end`.

## File layout and load order

The TOC (`AbsorbTracker.toc`) declares load order. Order matters: each file may
read from `AddonTable` only what earlier files have already written.

| # | File | Lines | Provides |
|---|------|-------|----------|
| 1 | `Core.lua` | 36 | `AddonTable.defaults`, `flatDefaults`, cached math/format |
| 2 | `Utils.lua` | 52 | `Print`, `DebugPrint`, `PrintLSMList`, `ParseColor` |
| 3 | `Settings.lua` | 173 | `db` ref, `GetSetting`/`SetSetting`, LSM wrappers, color getters |
| 4 | `UI.lua` | 60 | Bar frame creation (`bar`, `statusBar`, `valueText`) |
| 5 | `Display.lua` | 107 | `UpdateBarAppearance`, `UpdateAbsorbBar`, `RestoreBarPosition` |
| 6 | `Timer.lua` | 40 | `RestartUpdateTicker`, `ResetTickerInterval` |
| 7 | `Events.lua` | 80 | Event frame, `OnProfileChanged`, login bootstrap |
| 8 | `SlashCommands.lua` | 413 | `/at` dispatcher and all subcommand handlers |
| 9 | `OptionsPanel.lua` | 950 | `CreateOptionsPanel`, `RefreshOptionsPanel`, `OpenOptionsPanel` |

Optional libs (`LibStub`, `CallbackHandler`, `Ace3`, `LibSharedMedia`) load before
the addon's own files via `#@no-lib-strip@` blocks at the top of the TOC.

## The `AddonTable` bus

Every Lua file begins with:

```lua
local AddonName, AddonTable = ...
```

`...` is the WoW-supplied vararg pair. `AddonTable` is the same table for every
file in this addon, so writing `AddonTable.foo = ...` in one file makes it
readable from any other file loaded afterward.

Each file pulls its imports as locals at the top of the chunk:

```lua
local GetSetting = AddonTable.GetSetting
local SetSetting = AddonTable.SetSetting
```

Two consequences:

1. **Locals capture the value at load time.** A function only seen via local
   import will be the version that existed when the importing file was loaded.
   For functions defined in later-loaded modules, callers must reference them
   through `AddonTable.X` directly so the lookup happens at call time.
2. **No circular re-entry.** Files lower in the TOC can call functions defined
   higher up; the reverse requires the runtime nil-check pattern.

## Module responsibilities

### Core.lua — defaults and constants
Sets `AddonTable.defaults` (AceDB-shaped, with a `profile` sub-table) and
`flatDefaults` (alias to `defaults.profile` for direct lookup). Caches
`math.floor`/`math.max`/`math.min`/`format` on `AddonTable` to avoid repeated
global lookups in hot paths.

### Utils.lua — print pipeline and helpers
Defines `AddonTable.Print(...)`, which is the single entry point for all chat
output from the addon. It prepends a cyan `|cFF00FFFF[AT]|r` prefix and
delegates to the global `print`.

```lua
local PREFIX = "|cFF00FFFF[AT]|r"
function AddonTable.Print(...)
    print(PREFIX, ...)
end
local print = AddonTable.Print  -- shadow inside this file
```

Other modules that emit chat output (`SlashCommands.lua`, `OptionsPanel.lua`)
shadow `print` the same way:

```lua
local print = AddonTable.Print
```

This means every existing `print(...)` call site automatically gets the cyan
`[AT]` prefix without per-call changes. `DebugPrint` and `PrintLSMList` route
through the same shadow, so debug output and LSM listings share the prefix.

`ParseColor` is the slash-command color parser; it accepts `r g b [a]` in
either 0–1 or 0–255 ranges and normalizes to 0–1.

### Settings.lua — database, LSM, and color resolution
Three concerns:

1. **Database access.** `GetSetting(key)` and `SetSetting(key, value)` read/write
   `AddonTable.db.profile`. If `db` is nil (libs missing or pre-login), reads
   fall back to `flatDefaults`.
2. **LibSharedMedia wrappers.** `GetBarTexture`/`GetBgTexture`/`GetBorder`/
   `GetFont` look up the configured media name in LSM and return a path. If LSM
   is missing or doesn't have the named asset, they return one of the
   `FALLBACK_*` constants (raw Blizzard interface paths). `GetLSM` caches the
   library reference; `ClearLSMCache` is called once at PLAYER_LOGIN to handle
   late-loading libraries.
3. **Color resolution.** `GetBarColor`, `GetBgColor`, `GetBorderColor` each
   return four numbers (r, g, b, a) and consult the corresponding
   `useClassColor*` toggle at call time. This is why the bar frame and the
   options panel never need explicit refresh logic for class-color toggles —
   the next `UpdateBarAppearance()` simply re-reads.

Class colors come from two sources:

- **Bar/border** use Blizzard's `C_ClassColor.GetClassColor()`.
- **Background** uses a per-class hard-coded table multiplied by `0.2` to
  produce a darkened variant. The per-class table mirrors WoW's official class
  colors (DEATHKNIGHT through WARRIOR); the result is cached in
  `playerBgClassColor` since the player class doesn't change at runtime.

### UI.lua — frame creation
Runs at file-load time (not inside a function), so the frames exist by the time
later modules need to wire callbacks. Creates:

- `AbsorbTrackerFrame` — the outer movable `BackdropTemplate` frame, exported
  as `AddonTable.bar`.
- `statusBar` — a child `StatusBar` for the absorb fill, exported as
  `AddonTable.statusBar`.
- `valueText` — a `FontString` child of `statusBar` (so it draws above the
  fill), exported as `AddonTable.valueText`.

The reusable backdrop info table (`AddonTable.backdropInfo`) is created here
and mutated in place by `Display.UpdateBarAppearance` to avoid garbage.

### Display.lua — the rendering side
- `RestoreBarPosition()` reads the saved `position` setting and reapplies it,
  defaulting to screen center if absent.
- `UpdateBarAppearance()` re-applies *every* visual setting: size, textures,
  colors, border, font, lock state, visibility. WoW's `SetBackdrop` ignores
  changes when the table identity stays the same, so this function calls
  `SetBackdrop(nil)` first to force a refresh.
- `UpdateAbsorbBar()` reads `UnitGetTotalAbsorbs("player")` and
  `UnitHealthMax("player")` and pushes them into `statusBar`. The total absorb
  may be a "secret" value (WoW's blob format for very large numbers), so the
  text label uses `AbbreviateNumbers()` directly without `tonumber()` (which
  would lose precision).

### Timer.lua — periodic update ticker
A single `C_Timer.NewTicker` runs `UpdateAbsorbBar` at `updateInterval` seconds.
`RestartUpdateTicker(forceRestart)` short-circuits when the interval is unchanged
and a ticker exists, so it's safe to call from settings-change paths.
`ResetTickerInterval()` clears the tracked interval; `OnProfileChanged` calls it
to force a restart with the new profile's interval.

### Events.lua — bootstrap and event routing
Registers a single hidden frame for three events:

- **`PLAYER_LOGIN`** is the bootstrap. It tries `AceDB:New()`; if AceDB isn't
  available, it builds a minimal `{ profile = AbsorbTrackerDB }` shim and seeds
  missing keys from `flatDefaults`. Then: clear LSM cache, restore position,
  apply appearance, do an initial absorb read, start the ticker, create the
  options panel.
- **`PLAYER_ENTERING_WORLD`** resets the absorb cache and forces an update
  (handles zone transitions where the engine may have stale state).
- **`UNIT_ABSORB_AMOUNT_CHANGED`** for the player only logs at debug level. The
  ticker is the source of truth for visual updates — this prevents per-tick
  spam during heavy combat from over-driving frame updates.

`OnProfileChanged` is registered for AceDB's `OnProfileChanged`,
`OnProfileCopied`, and `OnProfileReset` callbacks so the bar and options panel
all refresh consistently.

### SlashCommands.lua — `/at` dispatcher
WoW slash commands are registered by setting `SLASH_<UPPERTAG>1`,
`SLASH_<UPPERTAG>2`, etc., and one `SlashCmdList[<UPPERTAG>]` handler. The
addon registers `/absorbtracker` and `/at` to a single
`SlashCmdList["ABSORBTRACKER"]` handler.

Dispatch is a single `if/elseif` chain on the lowercased first word:

- `/at` (no args) and unknown commands fall into the `else` branch and print
  the help block.
- `/at config` opens the options panel.
- `/at profile` re-splits the remaining arg on whitespace and runs a nested
  `if/elseif` for `list`, `current`, `use`/`set`, `new`/`create`, `copy`,
  `delete`/`remove`, `reset`.
- All other branches mutate one setting and call `UpdateBarAppearance` (or
  `RestartUpdateTicker` for the interval).

The help output is rendered by a small `PrintCmd(cmd, desc)` helper:

```lua
local function PrintCmd(cmd, desc)
    print(format("  |cFFFFFF00%s|r - |cFFFFFFFF%s|r", cmd, desc))
end
```

This produces a yellow command and a white explanation, with the cyan `[AT]`
prefix supplied by the shadowed `print`.

### OptionsPanel.lua — settings UI
Built on raw frame APIs (`BackdropTemplate`, `OptionsSliderTemplate`,
`InputBoxTemplate`, etc.) rather than `UIDropDownMenuTemplate`. Sections (in
panel order):

1. **Profiles** — current-profile dropdown + new/copy/reset/delete buttons.
2. **General** — show/hide, lock.
3. **Performance** — update interval slider.
4. **Bar Size** — width and height sliders.
5. **Bar Color** — bar color, background color, each with a class-color toggle.
6. **Bar Textures** — bar texture and background texture (LSM dropdowns).
7. **Border** — border style, size, color, class-color toggle.
8. **Font** — font face, size, outline style.

All dropdowns go through one shared `CreateCustomDropdown(parent, items,
onSelect, ...)` builder that creates a button with a custom popout list. A
single shared `dropdownClickCatcher` frame closes any open dropdown on outside
clicks. Lists with 10+ items grow a scrollbar and auto-scroll to the currently
selected entry on open.

Registration uses `Settings.RegisterCanvasLayoutCategory` (WoW 10.0+) and falls
back to `InterfaceOptions_AddCategory` on older clients.
`OpenOptionsPanel` refuses to run during combat (`InCombatLockdown()` — the
Settings API is protected).

`RefreshOptionsPanel` is called by `OnShow` and by `OnProfileChanged` so every
slider, color swatch, and dropdown reflects current settings without per-control
hooking.

## Data flow: an absorb update

```
[player gets a shield]
        │
        ▼
UNIT_ABSORB_AMOUNT_CHANGED ─────► DebugPrint only (no visual update)
                                                   │
                                                   ▼
                              C_Timer.NewTicker fires (every updateInterval seconds)
                                                   │
                                                   ▼
                                  AddonTable.UpdateAbsorbBar()
                                                   │
                                ┌──────────────────┼──────────────────┐
                                ▼                  ▼                  ▼
                  UnitGetTotalAbsorbs    UnitHealthMax       statusBar:SetValue
                                                              valueText:SetText
                                                              (AbbreviateNumbers)
```

The decoupling between the event and the visual update is intentional: events
can fire many times per second, but the user-configurable `updateInterval`
controls actual draw rate.

## Settings flow

```
Slash command  ─►  SetSetting(key, val)  ─►  db.profile[key] = val
                                                      │
                                                      ▼
                                       UpdateBarAppearance() (or
                                       RestartUpdateTicker() for interval)
                                                      │
                                                      ▼
                              GetSetting / GetBarColor / GetBgColor / ...
                              re-read live values, push to frames

Options panel control ─►  same SetSetting + UpdateBarAppearance pattern
```

Because the color getters resolve the `useClassColor*` toggle at call time, no
explicit "switch class color on" wiring is needed — the next paint reads the
current toggle state and produces the right color.

## Forward references

`Events.lua` runs on `PLAYER_LOGIN`, before `OptionsPanel.lua` has had a chance
to attach `CreateOptionsPanel` to `AddonTable`? In practice no, because all
files are loaded synchronously before any event fires — but the pattern is
preserved with a runtime nil check anyway:

```lua
if AddonTable.CreateOptionsPanel then
    AddonTable.CreateOptionsPanel()
end
```

The same guard wraps the `RefreshOptionsPanel` call inside `OnProfileChanged`.
This keeps the load-order coupling soft, and means the addon won't error out
if a future refactor splits the options panel into a separately-loaded file.

## Saved variables

Only `AbsorbTrackerDB` is declared in the TOC. With AceDB it holds the full
profile structure (profiles, defaults, character map). Without AceDB it's
treated as a flat table that is the single profile.

## Chat output conventions

- All addon chat lines flow through `AddonTable.Print` → cyan `[AT]` prefix.
- Help rows use `PrintCmd(cmd, desc)` → yellow command, white explanation.
- Debug lines use `AddonTable.DebugPrint(...)`, gated on `AddonTable.DEBUG`,
  routed through the same prefixed pipeline.

When adding a new chat message, just call `print(...)` from within a module
that already shadows `print` (`Utils.lua`, `SlashCommands.lua`,
`OptionsPanel.lua`); from any other module, call `AddonTable.Print(...)`
directly.
