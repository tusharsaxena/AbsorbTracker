# Architecture

This document describes how AbsorbTracker is structured internally. For user-facing
documentation see `README.md`; for AI-assistant quick-reference see `CLAUDE.md`.

## High-level design

AbsorbTracker is a small, modular WoW addon. The runtime is split between a
core set of plain-Lua modules (bar frame, timer, events, slash commands) and
a declarative settings layer driven by AceConfig.

- **No OO framework for the runtime.** Modules are plain Lua files; functions
  are attached to a shared `AddonTable`. There is no Ace3 `:NewModule()` or
  class hierarchy on the runtime side.
- **Settings are declarative.** Each sub-page in `Options/` is an AceConfig
  options table. AceConfigDialog renders the widgets, AceConfigRegistry
  dispatches change notifications, AceDBOptions builds the Profiles page.
- **Optional dependencies.** AceDB-3.0 (profiles) and LibSharedMedia-3.0
  (custom textures/fonts) are detected at runtime via `LibStub`. AceConfig +
  AceGUI + AceDBOptions are bundled and required for the multi-page settings
  UI; if they go missing the addon emits a chat warning and continues to
  function via slash commands.
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
| 4 | `Schema.lua` | ~330 | Schema registry, `BuildPageOptions`, `FormatSchemaValue`/`ParseSchemaValue` |
| 5 | `UI.lua` | 60 | Bar frame creation (`bar`, `statusBar`, `valueText`) |
| 6 | `Display.lua` | 107 | `UpdateBarAppearance`, `UpdateAbsorbBar`, `RestoreBarPosition` |
| 7 | `Timer.lua` | 40 | `RestartUpdateTicker`, `ResetTickerInterval` |
| 8 | `Events.lua` | 80 | Event frame, `OnProfileChanged`, login bootstrap |
| 9 | `SlashCommands.lua` | ~345 | KickCD-style COMMANDS table; schema-driven list/get/set/reset |
| 10 | `OptionsPanel.lua` | ~145 | `RegisterOptionsPage`, `CreateOptionsPanel`, `RefreshOptionsPanel`, `OpenOptionsPanel` |
| 11 | `Options/General.lua` | ~85 | General schema rows + Reset Position execute |
| 12 | `Options/Bar.lua` | ~115 | Bar schema rows |
| 13 | `Options/Border.lua` | ~70 | Border schema rows |
| 14 | `Options/Font.lua` | ~70 | Font schema rows |
| 15 | `Options/Profiles.lua` | ~20 | Profiles sub-page (AceDBOptions wrapper) |

Libraries load before the addon's own files via the `#@no-lib-strip@` block at
the top of the TOC. Bundled libraries:

- `LibStub-1.0`, `CallbackHandler-1.0` (transport)
- `Ace3/AceAddon-3.0`, `Ace3/AceDB-3.0` (state + profiles)
- `Ace3/AceGUI-3.0`, `Ace3/AceConfig-3.0`, `Ace3/AceDBOptions-3.0` (settings UI)
- `LibSharedMedia-3.0` (texture/font/border registry)
- `Ace3/AceGUI-3.0-SharedMediaWidgets` (in-tree minimal LSM30_* widgets — name
  matches upstream so dropping in the real lib later is a clean swap)

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

### Schema.lua — single source of truth for settings
A flat array `AddonTable.Schema` holds one row per user-facing setting.
Each `Options/<page>.lua` (except `Profiles`) populates the array via
`AddonTable.RegisterSchemaRows({...})` at file-load time. The schema feeds
two consumers:

1. **Sub-page rendering.** Each `Options/<page>.lua` calls
   `AddonTable.BuildPageOptions(pageKey, pageName)`, which walks the rows
   for that page and returns a ready-to-register AceConfig options table.
   Rows with the same `group` cluster into an inline AceConfig group;
   `order` controls in-group sequence. The widget's `get`/`set` callbacks
   route through `AddonTable.GetSetting` / `SetSetting` with the row's
   `onChange` fired afterwards.
2. **Slash commands.** `SlashCommands.lua` walks the same array for
   `/at list`, `/at get`, `/at set`, `/at reset` and `/at resetall`.
   `AddonTable.ParseSchemaValue(row, text)` converts the slash-command tail
   into a typed value matching `row.type` (bool / number / string / color);
   `AddonTable.FormatSchemaValue(row, value)` formats it for chat output
   (with `row.fmt` honoured for numbers).

Behaviour knobs on a row:

- `inverse = true` (bool only) — flips the widget value vs. the db value.
  Used so `path = "hidden"` shows up as a positive "Show Bar" toggle.
- `disabledIf = "<sibling-path>"` (color only) — greys out the picker
  when the named sibling toggle is on. Used by the class-color overrides
  on `barColor` / `bgColor` / `borderColor`.
- `onChange` — defaults to `UpdateBarAppearance`. Rows whose side effect
  differs (e.g. `updateInterval` calls `RestartUpdateTicker`; `hidden`
  also resets `lastAbsorb` and re-runs `UpdateAbsorbBar`) override
  explicitly.

Adding a new option = one schema row in some `Options/<page>.lua`. The
sub-page widget and the `/at <path>` surface for the new path are wired
automatically; no additional code in SlashCommands.lua or any per-page
builder.

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

The dispatcher follows the Ka0s KickCD pattern: a `COMMANDS` array maps
`{ name, description, handler(rest) }`. The handler lowercases the first
token, looks it up in `COMMANDS`, and calls the matching entry's handler
with the unmodified tail. Unknown commands fall through to `printHelp`,
which iterates `COMMANDS` to render the help block (yellow command
em-dash white description, KickCD-style).

The schema-driven core handles the bulk of user-visible options:

- `/at list` walks `AddonTable.Schema`, groups rows by `page`
  (general / bar / border / font), and prints each row's path with the
  current value rendered through `AddonTable.FormatSchemaValue`.
- `/at get <path>` looks up one row via `AddonTable.FindSchemaRow` and
  prints the same formatted value.
- `/at set <path> <value>` looks up the row, calls
  `AddonTable.ParseSchemaValue(row, value)` to coerce the tail into the
  typed value, then `AddonTable.SetByPath` to write + fire `onChange`.
  Invalid input prints a type-specific error
  (`expected true/false/on/off`, `allowed values: A, B, C`,
  `expected: r g b [a] (each 0-1 or 0-255)`).
- `/at reset <page>` walks the schema rows for that page and calls
  `AddonTable.ApplyDefault(row)` on each.
- `/at resetall` does the same for every row plus clears the saved
  bar position.

Per-setting subcommands like `/at width 250` or `/at color classcolor on`
are gone — `/at set barWidth 250` and `/at set useClassColorBar true`
replace them. The schema's `inverse` flag means `/at set hidden true` and
the panel's "Show Bar" checkbox both write the same db slot from opposite
ends, so the slash and panel paths remain truly equivalent.

Non-schema commands are kept for actions that don't fit a key/value
shape: `/at config`, `/at lock`/`unlock`/`toggle`, `/at debug`, `/at
update`, `/at test [value]`, `/at resetposition`, `/at profile <sub>`.

### OptionsPanel.lua — settings registration shell
A thin coordination layer (~145 lines). It does not build widgets or hold
schema; each sub-page's options table is declared in its own file under
`Options/`. The shell exposes three things to `AddonTable`:

- `RegisterOptionsPage(key, name, builder, opts)` — called once per page at
  file-load time. The page is queued, not registered yet (db isn't ready).
  `opts.isDefault = true` flags the page that `/at config` should open
  (typically General).
- `CreateOptionsPanel()` — invoked from `Events.lua` on `PLAYER_LOGIN` once
  AceDB has set up `AddonTable.db`. It first registers an empty
  title-only top-level "Ka0s Absorb Tracker" category (so the parent
  exists for sub-pages to attach to), then walks the queue and for each
  page calls `AceConfig:RegisterOptionsTable("AbsorbTracker-<key>",
  builder())` and
  `AceConfigDialog:AddToBlizOptions("AbsorbTracker-<key>", name,
  "Ka0s Absorb Tracker")`.
- `RefreshOptionsPanel()` — invoked from `OnProfileChanged`. Calls
  `AceConfigRegistry:NotifyChange(appName)` for every registered page so
  AceConfigDialog re-renders the active page's widgets against the new
  profile's values. Closure-based `get`/`set` callbacks already read live
  from `db.profile`, so the underlying values are correct as soon as
  `db.profile` flips — `NotifyChange` just makes the on-screen widgets
  re-pull.

`OpenOptionsPanel` refuses to run during combat (`InCombatLockdown()` — the
Settings API is protected) and prefers
`Settings.OpenToCategory(defaultCategoryID)` (the page flagged
`isDefault`), falling back to the empty parent category if no default was
registered.

The empty parent uses appName `AbsorbTracker` and is registered against an
options table with `args = {}` — AceConfigDialog still needs *some* table
to attach the canvas frame to, but a zero-args group renders as just the
title bar with an empty body, which is the desired look. Every Options/
file becomes a sub-page; the parent never holds settings of its own.

### Options/*.lua — sub-page schemas
Each file under `Options/` is now a thin schema declaration. The shape:

```lua
local AddonName, AddonTable = ...
local flatDefaults = AddonTable.flatDefaults

AddonTable.RegisterSchemaRows({
    { path = "barWidth", page = "bar", group = "Size", order = 10,
      type = "number", label = "Bar Width", default = flatDefaults.barWidth,
      min = 50, max = 500, step = 1 },
    -- ...
})

local function build()
    return AddonTable.BuildPageOptions("bar", "Bar")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("bar", "Bar", build)
end
```

Conventions:

1. **Defaults reference `flatDefaults`.** The default value for each row
   reads from `AddonTable.flatDefaults` (which is the alias to
   `AddonTable.defaults.profile`), so Core.lua remains the single place
   to change a default. Schema rows just point at it.
2. **Build closures.** `build()` is the lazy options-table builder
   `OptionsPanel.lua` invokes at PLAYER_LOGIN. Most pages just return
   `AddonTable.BuildPageOptions(pageKey, pageName)`. General also
   appends an inline `position` group with the Reset Position execute
   button — that's an action, not a schema row.
3. **No widget code in the page file.** All widget rendering happens
   inside `BuildPageOptions` (and the LSM swatch widgets in
   `libs/Ace3/AceGUI-3.0-SharedMediaWidgets`). A typical Options/<page>.lua
   is now ~70–115 lines vs. the ~70–140 of the inline-AceConfig version.

The five pages:

1. **General** (`isDefault = true`) — schema rows for `hidden` (rendered
   inverse as "Show Bar"), `locked`, `updateInterval`. Build appends an
   inline Position group with a Reset Position execute button. `/at
   config` opens this.
2. **Bar** — schema rows for `barWidth`, `barHeight`, `barTexture` /
   `useClassColorBar` / `barColor` (with `disabledIf =
   "useClassColorBar"`), and the same trio for the background.
3. **Border** — schema rows for `border`, `borderSize`,
   `useClassColorBorder`, `borderColor`.
4. **Font** — schema rows for `font`, `fontSize`, `fontFlags`.
5. **Profiles** — `AceDBOptions:GetOptionsTable(AddonTable.db)`. Not
   schema-driven; AceDBOptions builds its own options table. The build
   function returns nil if AceDBOptions is missing, which causes
   OptionsPanel.lua's `registerPage` to skip the page silently.

LSM dropdown swatches come from a custom in-tree widget at
`libs/Ace3/AceGUI-3.0-SharedMediaWidgets/widget.lua`, registered as widget
types `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Font`. AceConfigDialog
routes to them via `dialogControl = "LSM30_Statusbar"` (etc.) on the
relevant `select` rows. The widget builds a Blizzard-frame button + popup
list and renders a preview swatch beside each entry; the names match the
upstream `AceGUI-3.0-SharedMediaWidgets` lib so dropping in the real lib
later is a clean replacement.

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
