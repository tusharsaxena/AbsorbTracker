# Schema

The schema-driven settings system. One flat array, walked by both the canvas-layout sub-pages (rendered as AceGUI widgets) and the `/at` slash dispatcher. Adding a new user-facing setting is one row in some `settings/<page>.lua` — the panel widget and the `/at set <path>` CLI are wired automatically.

## Why one schema

Two parallel surfaces — the Blizzard Settings panel and the `/at` slash CLI — historically had per-setting code in both places. That meant every new option touched at least three files (the panel page, the slash dispatcher, the docs). The schema collapses both surfaces onto a single declarative array. Each row is the *complete* description of a setting; the renderer for each surface walks the array and produces the right widget / output.

The array itself and its helpers live in `settings/Schema.lua` (`NS.Schema`). The per-page rows are registered from `settings/General.lua` and `settings/Appearance.lua`.

**A row's `group` is its TAB.** Both pages draw their sections as a tab strip (options-ui-§13), and the partition is by `group` **in declaration order** — so the schema array *is* the strip, and a group's rows must stay **contiguous**. A row filed under a group the page has already left would print that heading a second time further down.

## Row shape

```lua
{
    path    = "barWidth",        -- key in db.profile (also `/at set <path>`) — or a dotted
                                  -- per-unit path, "units.<unit>.barWidth"
    page    = "appearance",      -- which settings/<page>.lua renders it
    unit    = "player",          -- per-unit rows only: which unit this row belongs to (nil for
                                  -- unit-agnostic rows, e.g. General's three globals)
    group   = "Size",            -- the page's TAB this row belongs to; tabs are drawn in the
                                  -- order each group's FIRST row was registered
    order   = 10,                -- render order within the group

    type    = "bool" | "number" | "string" | "color",
    label   = "Bar Width",       -- widget label + `/at list`/`get` display
    desc    = "...",             -- tooltip text (rendered via Helpers.AttachTooltip)
    default = 200,               -- restored by `/at reset <path>`, `/at resetall`, and
                                  -- a page's Defaults button

    -- type-specific:
    min, max, step,                                  -- number
    values        = NS.Helpers.LSMValues("statusbar"),  -- string (select); k=v map or fn
                                  -- NOTE: evaluated at FILE LOAD, so settings/OptionsSetup.lua
                                  -- must load first — see settings-panel.md, "The degradation stub"
    dialogControl = "LSM30_Statusbar",              -- string (LSM swatch dropdown)
    sorting       = { "", "OUTLINE", ... },         -- string: explicit option order
    hasAlpha      = true,                           -- color

    -- behavior:
    onChange      = function(v) ... end,    -- defaults to UpdateBarAppearance
    disabledIf    = "useClassColorBar",     -- color only: grays out when sibling toggle is on.
                                             -- NO ROW IN THIS ADDON USES IT -- see below
    fmt           = "%.1f sec",             -- /at list/get formatting hint
    solo          = true,                   -- panel only: render alone in its own row
    alwaysPerUnit = true,                   -- per-unit rows only: stays editable even while this
                                             -- unit mirrors the player (e.g. the "enabled" row)
    skipRender    = true,                   -- per-unit rows only: stays in the schema (so /at
                                             -- get|set and Defaults still see it) but is drawn
                                             -- bespoke by the panel instead of by RenderRows —
                                             -- e.g. the mirror flag, drawn as the header checkbox
}
```

## Registration

`settings/General.lua` loops `NS.Units.LIST` first to register one `units.<unit>.enabled` toggle per unit (the only unit-scoped rows outside the Appearance page), **then** calls `NS.RegisterSchemaRows({ ... })` for its three unit-agnostic globals. That order is load-bearing rather than tidy: the Bars tab must come before Behavior in the strip, and the strip's order is the order each group's first row was registered. `settings/Appearance.lua` instead defines an `addUnitRows(unit)` function and calls it once per tracked unit:

```lua
local addonName, NS = ...
local unitDefaults = NS.unitDefaults

local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local rows = {
        { path = p .. "barWidth", page = "appearance", unit = unit, group = "Size", order = 10,
          type = "number", label = "Bar Width (in px)", default = unitDefaults.barWidth,
          min = 50, max = 500, step = 1, fmt = "%d px" },
        -- ...
    }
    NS.RegisterSchemaRows(rows)
end

for _, unit in ipairs(NS.Units.LIST) do addUnitRows(unit) end
```

Each call generates three rows per appearance key — one per `NS.Units.LIST` entry — with the path prefixed `units.<unit>.` and tagged `unit = unit`, so `NS.SchemaForPage(page, unit)` can filter the page down to whichever unit is selected in the panel's Unit banner.

**Defaults reference `unitDefaults` (per-unit pages) or `flatDefaults` (General's globals).** `defaults/Profile.lua` is the single place to change a default — the schema rows just point at it. `NS.flatDefaults` is an alias of `NS.defaults.profile` (the three flat globals plus `units`); `NS.unitDefaults` is an alias of `NS.defaults.profile.units.player`, the canonical per-row default source shared by all three units (a color picker's default doesn't change based on which unit is selected). Don't hard-code default values in schema rows.

## How the row drives both surfaces

```
                  NS.Schema (flat array, settings/Schema.lua)
                          │
      the addon hands the rows out through two descriptors
            ┌─────────────┴──────────────┐
            ▼                            ▼
   settings/OptionsSetup.lua      settings/Slash.lua
   (rowsForPage / allRows)        (findRow / allRows)
            │                            │
            ▼                            ▼
   LibKa0s-Options-1.0            LibKa0s-Slash-1.0
   (OptionsWidgets.lua)           (Slash.lua)
            │                            │ walks the array
            │ section break on           │ for /at list / get / set / reset
            │   row.group change         │
            │ pairs adjacent rows        │
            │   into 50/50 Flow rows     │
            │ honors `solo = true`       │
            ▼                            ▼
   AceGUI widgets                Type-validated CLI write through SetByPath
   (CheckBox / Slider /                  │
    Dropdown / ColorPicker)              ▼
            │                  fires row.onChange
            │                  (default: UpdateBarAppearance)
            ▼
   widget callback → SetByPath → fires row.onChange
                                → Helpers.RefreshAllPanels
                                  (re-syncs every open panel's
                                   widgets against the new value)
```

`NS.SetByPath` (in `settings/Schema.lua`) is the single write seam: it calls `NS.SetSetting` then fires the row's `onChange`. It does **not** itself refresh the panel — the slash path calls `NS.RefreshOptionsPanel` afterward (inside the `set` / `applyDefault` closures `settings/Slash.lua` hands the library), and the panel widgets' own `set()` closures end with `Helpers.RefreshAllPanels`.

## Behavior knobs

### `disabledIf = "<sibling-path>"` (color only) — supported, and deliberately unused

The ColorPicker maker (`libs/LibKa0s/OptionsWidgets.lua`) reads `disabledIf` inside its refresher closure and calls `cp:SetDisabled(GetSetting(sibling))`, re-evaluated after every panel write and on profile change. **No row in this addon sets it**, and that is a reversal worth writing down.

Each of the four color swatches — `barColor`, `bgColor`, `borderColor`, `fontColor` — used to gray itself out while its "Use Class Color" partner was on, and each toggle's own `desc` advertised that it would. The argument was that a control the code is not currently reading should say so.

What it cost is the ordinary order of operations. Setting a color **before** deciding you want the class one is normal, and a grayed swatch makes that a two-visit job: turn the toggle off, set the color, turn the toggle back on.

The half of the old argument that survives is that the row *is* unread under the other mode, and that is what the `desc` says now instead of graying the widget out. The alpha channel was always live under either mode — `core/Data.lua`'s `resolveColor` takes the class RGB and keeps the swatch's `a` — so the swatch was never fully dead even under the old design, which is the clearest evidence the graying was overstating the case.

`tests/test_widgets.lua` keeps the library feature pinned against a **synthetic** row, and pins the reversal itself against the four real ones.

### `onChange` (any type)

Defaults to `NS.UpdateBarAppearance`. Override when the row's side effect differs:

- `throttleWindow` — no override; uses the default `UpdateBarAppearance` (the throttle window itself is read live by `NS.RequestRepaint`, not applied via `onChange`).
- `units.<unit>.enabled` → publishes `UNITS` (re-syncs that unit's event registrations), then `APPEARANCE`, then `REPAINT` **only when the bar ends up enabled** — a bar being switched off needs no paint work, and one just switched on is still holding whatever value it had when it went away.

### `fmt = "%.1f sec"` (number only)

Formatting hint for `/at list` / `/at get` output, applied by `lib.FormatValue` (LibKa0s-Slash-1.0), which `NS.FormatSchemaValue` delegates to. Without `fmt`, a number renders via `tostring(v)`.

### `sorting = { ... }` (string select)

Explicit option order for a select widget when the natural key sort isn't desired. `settings/Appearance.lua`'s `fontFlags` uses it to keep the outline flags in a hand-chosen order.

### `solo = true` (panel layout, any type)

Tells `Helpers.RenderSchema` to render this row alone on its own line instead of pairing it with the next row in the 50/50 grid. Used as a header above a paired row — e.g. on the Appearance page's **Bar** tab, `barTexture` (solo) sits on its own row, then `barColor` and `useClassColorBar` pair on the row beneath it, giving the texture dropdown its own line above the color/class-color pair. It has a second job on General: `throttleWindow` is `solo` so it is **always** the lone widget on its line, which is what makes it a legal `pairWith` host for the Debug console checkbox. Has no effect on the slash CLI.

## Public API

All defined in `settings/Schema.lua`.

```lua
-- Registration (settings/*.lua)
NS.RegisterSchemaRows(rows)             -- append rows to NS.Schema

-- Lookup
NS.FindSchemaRow(path)                  -> row | nil
NS.SchemaForPage(pageKey, unit)         -> { rows }   -- groups kept in first-seen registration
                                                              -- order, then row.order within each
                                                              -- group. `unit` filters to that
                                                              -- unit's rows plus any unit-agnostic
                                                              -- rows (General's); omit `unit` to
                                                              -- get every unit's rows (what
                                                              -- RestoreDefaults / RestoreAllDefaults
                                                              -- / `/at list` want).
NS.PartitionUnitRows(rows)              -> perUnit, styled   -- splits a unit page's rows into
                                                              -- alwaysPerUnit rows (stay editable
                                                              -- while mirrored) vs. the appearance
                                                              -- rows the mirror hides

-- Dotted-path walkers (per-unit settings live at units.<unit>.<key>; flat keys pass through
-- unchanged so the three globals need no special case)
NS.ResolvePath(tbl, path)               -> value | nil
NS.SetPath(tbl, path, value)

-- Write / reset (fires row.onChange; reads go through NS.GetSetting)
NS.SetByPath(path, value)               -- SetSetting + onChange (the documented single seam
                                                -- both /at set and the panel widget set() use)
NS.ApplyDefault(row)                    -- reset to row.default + onChange (deep-copies table
                                                -- defaults; used by /at reset, /at resetall,
                                                -- and per-page Defaults buttons)

-- Slash IO (formatting only — the type-aware parser is LibKa0s-Slash-1.0's lib.ParseValue)
NS.FormatSchemaValue(row, value)        -> string    -- thin delegate to lib.FormatValue

-- Validation
NS.ValidateSchema()                     -> errors, resolved, missing
```

### `NS.ValidateSchema()`

Called once through the descriptor's `validate` hook (`settings/OptionsSetup.lua`, `validate = function() NS.ValidateSchema() end`), which `LibKa0s-Options-1.0`'s `CreateOptionsPanel` runs before the page builders — at `OnEnable` (PLAYER_LOGIN timing), after every `settings/<page>.lua` has registered its rows. It walks `NS.Schema` and, for each row, checks:

- the row is a table with a non-empty string `path`,
- `page` is one of `general`, `appearance`, `profiles`,
- `type` is one of `bool`, `number`, `string`, `color`,
- **(Ka0s standard architecture-§5)** the `path` resolves against `NS.defaults.profile` via `NS.ResolvePath` — dotted per-unit paths (`units.target.barWidth`) walk the nested `units` table the same way flat paths (`hidden`) index directly, so a typo anywhere in a per-unit path is caught the same as a flat one. Rows on the `profiles` page are exempt (their options are AceDBOptions-supplied).

It returns **three** counts — `errors` (shape violations), `resolved` (paths found in `defaults.profile`), and `missing` (present rows whose `path` has no matching default). The validator only *prints* malformed rows through `NS.Print`; it never refuses to register.

This is exercised headlessly by `tests/test_schema.lua`, which asserts the live schema validates with `errors == 0` and `missing == 0`, plants a bogus-path row to confirm `missing == 1`, and plants an invalid page/type row to confirm the shape-error count.

## Slash CLI mapping

The slash surface is `settings/Slash.lua`, registered via AceConsole (`NS.addon:RegisterChatCommand("at", ...)` and `("absorbtracker", ...)`). The dispatcher itself — the help renderer, the `key = value` and value formatters, the list builder and the type-aware parser — is **LibKa0s-Slash-1.0** (`libs/LibKa0s/Slash.lua`), shared across every Ka0s addon. `settings/Slash.lua` hands it a descriptor: the verb table, the schema seams (`get` / `set` / `findRow` / `applyDefault`), the row order (`allRows`), and the `[appearance / player]` group key. The value-shaped verbs walk `NS.Schema` through that descriptor:

| Command | What it does |
|---------|--------------|
| `/at list` | Walks the descriptor's `allRows` — page by page (general, appearance), with Appearance listed **once per unit** (`appearance / player`, `appearance / target`, `appearance / focus` — `PER_UNIT_PAGES` in `settings/Slash.lua`) — and prints each row's full dotted path with the current value, rendered by `lib.FormatValue` and paired by `lib.FormatKV`. |
| `/at get <path>` | Looks up one row via `FindSchemaRow` (the path must be the full dotted form, e.g. `units.target.barWidth`) and prints the same formatted pair. |
| `/at set <path> <value>` | Calls `lib.ParseValue(row, text)` (LibKa0s-Slash-1.0) to coerce the tail into the typed value, then `SetByPath` to write + fire `onChange`, then `RefreshOptionsPanel`. Invalid input prints a type-specific error (`expected true/false/on/off/1/0/yes/no`, `expected a number`, `allowed values: A, B, C`, `expected: r g b [a] (each 0-1 or 0-255)`). **Fully-qualified paths only** — `/at set units.target.barWidth 250` works, `/at set barWidth 250` does not (the unqualified pre-1.9 form is gone; `FindSchemaRow` has no per-unit rows registered under the bare key). |
| `/at reset <path>` | Resolves one row via `FindSchemaRow(path)` and calls `ApplyDefault` on it, then `RefreshOptionsPanel`. One setting, not a page — a whole page across all three units is that page's **Defaults** button (`NS.Helpers.RestoreDefaults`). |
| `/at resetall` | Runs `ApplyDefault` on every row (all pages, all units). Also clears every unit's saved position (`NS.Units.SetPosition(unit, nil)` for each of `NS.Units.LIST`) and republishes `POSITION`. |

Per-setting subcommands like `/at width 250` or `/at color classcolor on` were removed in favor of `/at set <path> <value>` — today that path is fully qualified: `/at set units.player.barWidth 250` and `/at set units.player.useClassColorBar true`.

## Stored vs. resolved — the mirror seam

Ask *"what is focus's `barWidth`?"* and three layers give three different answers. None of them is
wrong; the point of this section is that the split is **deliberate**, so it is written down once
here instead of being rediscovered from three files.

| Layer | Answer | Why |
|-------|--------|-----|
| **`NS.Units.Get(unit, key)`** (`core/Units.lua`) | **Resolved** — follows the mirror. While `units.focus.mirror` is true it returns the **player's** value. | This is what the bar renders. `modules/Bar.lua`, `modules/Display.lua` and `core/Data.lua` read appearance *only* through here, so "mirror the player" lives in exactly one place. |
| **`NS.GetSetting(path)`** (`core/Data.lua`) | **Stored** — `ResolvePath(db.profile, path)`, mirror ignored. Returns focus's *own* saved `barWidth`, whatever the bar is currently showing. | It is the read half of the same seam `/at set` writes through. Resolving on read would make `get` and `set` asymmetric: `/at set units.focus.barWidth 400` followed by `/at get units.focus.barWidth` would echo the player's number. `NS.Units.Set` is deliberately unresolved for the same reason — a write while mirrored must never silently edit the *player's* bar. |
| **The panel** (`Helpers.RenderUnitPanel`) | **Hidden** — while a unit is mirrored its appearance rows are not rendered at all, and the page draws no tab strip either; only the banner, the mirror header and the hint line are shown. | The stored value is not what the user would see on screen, so offering a widget for it would be a lie. `NS.PartitionUnitRows` does the split. |

The seam is only dangerous where it is **silent**, so the slash surface says so out loud: `/at get`,
`/at set` and `/at list` append a subordinate gray `(mirrored — the bar shows Player's appearance)`
note to any row whose unit is currently mirroring (`MirrorNote` in `settings/Slash.lua`). Only
appearance rows are annotated — `enabled` and `mirror` carry `alwaysPerUnit = true` and are honored
per-unit even while mirrored, so a note on them would be wrong in the other direction.

Two consequences worth remembering:

- **A write to a mirrored unit is not lost, it is parked.** `/at set units.focus.barWidth 400` really
  does store 400. Untick the mirror (or `/at set units.focus.mirror false`) and 400 is what the focus
  bar renders.
- **`Units.CopyFromPlayer` is the bridge.** It deep-copies the player's eighteen appearance keys into
  the unit's own storage and clears `mirror`, which makes the stored and resolved answers agree — once.
  It is a snapshot, not a second live link.

## What's *not* schema-driven

- **Action buttons** like Reset Position. They're rendered via `Helpers.InlineButtonPair`, attached to a sub-page through `Helpers.RenderTabbedSchema`'s `afterGroup` callback. `settings/General.lua` wires the **Reset Position** + **Reset All Settings** pair under the **Bars** tab via `RenderTabbedSchema(ctx, "general", { ["Bars"] = function(ctxRef) H.InlineButtonPair(ctxRef, ...) end })`. Each page's **Defaults** button (`Helpers.RestoreDefaults(pageKey, ctx)`) is likewise not a row.
- **The Debug console checkbox** (General page, Behavior tab, beside Update throttle). Shows/hides the debug console *window* (same as the bare `/at debug`) — deliberately *not* a schema row (window visibility is transient UI, never persisted), and it does **not** change the debug logging flag (`NS.State.debug`). It's rendered via `Helpers.SessionCheckbox` wired to `NS.DebugLog:ConsoleCheckbox()` (`get` = `D:IsShown()`, `set` = `D:Show()`/`D:Hide()`) and injected through `RenderTabbedSchema`'s `pairWith` seam as **Update throttle's** right partner — a `solo` row, and therefore always the lone widget on its line, which is what `pairWith` requires of a host.
- **The non-key/value verbs.** `help`, `config`, `lock`, `unlock`, `toggle`, `debug`, `perf`, `update`, `version`, `test`, `resetposition`, and `profile` live as dedicated entries in the ordered `NS.COMMANDS` table in `settings/Slash.lua` — 17 verbs in all, counting the five schema-driven ones (`list`, `get`, `set`, `reset`, `resetall`). The table is passed **into** LibKa0s-Slash-1.0 rather than owned by it: the About page renders the same rows (via `NS.Slash:LandingRows()`, the library's formatted list), and a library that owned the table would drag the options surface into depending on it. An unknown verb prints `unknown command '<verb>'` then the help list.
- **The Profiles sub-page.** `AceDBOptions:GetOptionsTable(db)` builds its own options table; no schema rows.

## Settings reference (every schema row)

Defaults live in `defaults/Profile.lua`'s `NS.defaults.profile`. The three globals below are flat, single rows on the General page, which also carries the three per-unit `enabled` toggles (the one place a `units.<unit>.*` path is edited outside the Appearance page's Unit banner — so the General page's Defaults button resets them and the Appearance page's does not). Every other setting is **per-unit**: `settings/Appearance.lua` registers the same eighteen appearance keys three times each — once per `NS.Units.LIST` entry (`player`, `target`, `focus`) — at the dotted path `units.<unit>.<key>`, all sharing one canonical `default` from `NS.unitDefaults` (= `defaults.profile.units.player`). Every one of those keys is also in `NS.Units.APPEARANCE_KEYS`, which is what the mirror and `CopyFromPlayer` walk; `tests/test_units.lua` asserts the two agree in both directions. `/at get units.target.barWidth` reads the target bar's width; `/at get barWidth` (the pre-1.9 unqualified form) finds nothing.

**Row counts, per tab:**

| Page | Tab | Rows |
|------|-----|------|
| General | Bars | 3 |
| General | Behavior | 3 |
| Appearance | Size | 2 |
| Appearance | Bar | 4 |
| Appearance | Background | 3 |
| Appearance | Border | 4 |
| Appearance | Text | 5 |

Appearance counts are **per unit** (the page renders one unit at a time behind the banner); General's are unfiltered, because that page renders with `ctx.unit` nil and shows all three enable toggles at once. `mirror` is in neither column: it carries no `group`, belongs to no tab, and is drawn bespoke in the header. `tests/test_schema.lua` asserts this table.

### General page (flat globals + the per-unit enable toggles)

| Path | Type | Default | Range / Values | Description |
|------|------|---------|----------------|-------------|
| `locked` | bool | `false` | — | If true, no bar is movable, and the per-bar unit labels are hidden with it. `/at lock` / `/at unlock` flip this. Governs every unit. Behavior tab, order 10. |
| `showOnlyInCombat` | bool | `false` | — | When true, every *enabled* bar is hidden except while in combat (the second step of `NS.ShouldShowBar`'s ladder, after the per-unit `enabled` flag). Label "Show only in combat". `onChange` publishes `NS.MSG.VISIBILITY` (and `REPAINT` when the change makes a bar visible). Behavior tab, order 20. |
| `units.<unit>.enabled` | bool | `true` (player) / `false` (target, focus) | — | Track and display absorbs for that unit. **The visibility switch** — there is no master `hidden` toggle. One row per `NS.Units.LIST` entry, labeled "Enable Player/Target/Focus Bar", orders 10 / 20 / 30, on the **Bars** tab, where they pair with each other rather than with a global. The **only** unit-scoped rows on this page: `alwaysPerUnit = true`, so they stay honored — and free of the `/at get` "(mirrored)" note — even while that unit mirrors the player. Target and focus additionally need `UnitExists` before the bar appears. |
| `throttleWindow` | number | `0.1` | 0.05 – 1 s (step 0.05) | Fastest any bar repaints during a burst of changes, via `NS.RequestRepaint`'s trailing-edge one-shot AceTimer. Label "Update throttle (in sec)". Display hint `"%.2f sec"`. Behavior tab, order 30, `solo` — which is also what makes it the Debug console checkbox's `pairWith` host. |

### Appearance page (per-unit, path = `units.<unit>.<key>`)

| Key | Type | Default | Range / Values | Description |
|-----|------|---------|----------------|-------------|
| `mirror` | bool | `true` (target, focus only — player has no row, it's the mirror source) | — | Live-mirror every appearance key from the player. `alwaysPerUnit = true`, `skipRender = true` — not drawn by `RenderRows`; `Helpers.RenderUnitPanel` draws it as the header "Use same styling as Player" checkbox instead. |
| `barWidth` | number | `200` | 50 – 500 px | Bar width. Hint `"%d px"`. **Size** tab. |
| `barHeight` | number | `20` | 10 – 100 px | Bar height. Hint `"%d px"`. **Size** tab. |
| `barTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Status-bar fill texture. `dialogControl = "LSM30_Statusbar"`, `solo`. **Bar** tab. |
| `barColor` | color | `{r=0.4, g=0.7, b=1.0, a=0.8}` | 0 – 1 each | Bar-fill color. `hasAlpha = true`. Stays live under either class-color mode. **Bar** tab. |
| `useClassColorBar` | bool | `false` | — | When true, bar fill uses the **player's** class color (always, on all three bars), keeping `barColor`'s alpha. **Bar** tab. |
| `barAlpha` | number | `1.0` | 0.1 – 1 (step 0.05) | **New.** Opacity of the whole frame — fill, background, border and text together, which is what makes it a different question from the three swatches' alpha channels. Promoted out of `modules/Display.lua`, where it was the literal `1` passed to `bar:SetAlpha` at two paint sites; the default IS that 1. Clamped in `NS.GetBarAlpha`, because the stored value comes from SavedVariables and an alpha of 0 is an invisible bar with no error. `solo`. **Bar** tab. |
| `bgTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Bar-background texture. `dialogControl = "LSM30_Statusbar"`, `solo`. **Background** tab. |
| `bgColor` | color | `{r=0.2, g=0.2, b=0.2, a=0.8}` | 0 – 1 each | Background color. `hasAlpha = true`. Stays live under either class-color mode. **Background** tab. |
| `useClassColorBg` | bool | `false` | — | When true, background uses a darkened class-color variant (player's), keeping `bgColor`'s alpha. **Background** tab. |
| `border` | string | `"Blizzard Tooltip"` | LSM `border` catalog | Border style. `dialogControl = "LSM30_Border"`. **Border** tab. |
| `borderSize` | number | `12` | 1 – 32 px | Border thickness. Hint `"%d px"`. **Border** tab. |
| `borderColor` | color | `{r=0.5, g=0.5, b=0.5, a=1.0}` | 0 – 1 each | Border color. `hasAlpha = true`. Stays live under either class-color mode. **Border** tab. |
| `useClassColorBorder` | bool | `false` | — | When true, border uses the player's class color, keeping `borderColor`'s alpha. **Border** tab. |
| `font` | string | `"Friz Quadrata TT"` | LSM `font` catalog | Font face. `dialogControl = "LSM30_Font"`. **Text** tab. |
| `fontSize` | number | `12` | 6 – 32 pt | Font size. **Text** tab. |
| `fontColor` | color | `{r=1.0, g=1.0, b=1.0, a=1.0}` | 0 – 1 each | **New.** Color of the absorb amount. The text had no color row at all: the FontString was created without one and drew at a bare FontString's own default, opaque white — which is exactly what ships here, so nothing moves on an untouched install. `hasAlpha = true`. **Text** tab. |
| `useClassColorText` | bool | `false` | — | **New.** When true, the absorb amount uses the player's class color, keeping `fontColor`'s alpha. **Text** tab. |
| `fontFlags` | string | `"OUTLINE"` | `""` / `OUTLINE` / `THICKOUTLINE` / `MONOCHROME` / `MONOCHROME, OUTLINE` / `MONOCHROME, THICKOUTLINE` | Font outline flags. `select` widget with explicit `sorting`, `solo`. **Text** tab. |
| `position` | table | `nil` | — | Saved bar position `{ point, relPoint, x, y }`, per unit. **Not** a schema row — read/written via `NS.Units.Position` / `NS.Units.SetPosition`, never mirrored even when the rest of the unit's appearance is. Listed here for completeness. |

## See also

- [settings-panel.md](./settings-panel.md) — how the schema-built pages get registered with Blizzard's Settings UI.
- [data-flow.md](./data-flow.md) — the `SetByPath → onChange → UpdateBarAppearance` path.
- [common-tasks.md](./common-tasks.md#add-a-new-setting) — recipe for adding a new schema row.
