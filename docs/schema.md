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
                                  -- unit-agnostic rows, e.g. General's seven addon-wide rows)
    group   = "Size",            -- the page's TAB this row belongs to; tabs are drawn in the
                                  -- order each group's FIRST row was registered
    order   = 10,                -- render order within the group

    type    = "bool" | "number" | "string" | "color",
    group   = "Bar",             -- the page's TAB this row belongs to (options-ui-§13). EVERY row
                                  -- carries one; a page whose rows declare none cannot draw a strip
    subgroup = "Border",         -- a heading drawn INSIDE a tab, for a tab that mixes control
                                  -- KINDS (options-ui-§7). Never repeats its tab's own name
    label   = "Bar Width",       -- widget label + `/at list`/`get` display
    tooltip = "...",             -- tooltip text. `desc` is the older spelling and is still read:
                                  -- the flow engine answers `row.tooltip or row.desc`, so the
                                  -- composed rows carry `tooltip` and the hand-written ones `desc`
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

    classColorSource = "unit",              -- color pair: WHOSE class this surface means, DECLARED
                                             -- rather than inferred (options-ui-§17)
    classColorUnit   = "target",            -- ... and which unit, when the source is "unit"

    -- behavior:
    onChange      = function(v) ... end,    -- defaults to UpdateBarAppearance
    fmt           = "%.1f sec",             -- /at list/get formatting hint
    solo          = true,                   -- panel only: render alone in the LEFT HALF of a row
    startsLine    = true,                   -- panel only: flush the pending line BEFORE this row,
                                             -- so a declared pair can never be split
    sessionOnly   = true,                   -- the value is NOT in the profile; core/Data.lua's
                                             -- session-settings registry answers it
    alwaysPerUnit = true,                   -- per-unit rows only: stays editable even while this
                                             -- unit mirrors the player (e.g. the "enabled" row)
    skipRender    = true,                   -- per-unit rows only: stays in the schema (so /at
                                             -- get|set and Defaults still see it) but is drawn
                                             -- bespoke by the panel instead of by RenderRows —
                                             -- e.g. the mirror flag, drawn as the header checkbox
}
```

## Registration

`settings/General.lua` registers `H.MasterControls`'s composed block **first**, then loops `NS.Units.LIST` for one `units.<unit>.enabled` toggle per unit (the only unit-scoped rows outside the Appearance page), then the throttle. That order is load-bearing rather than tidy: options-ui-§15 requires `Master controls` to be the **first** tab, and the strip's order is the order each group's first row was registered. `settings/Appearance.lua` instead defines an `addUnitRows(unit)` function and calls it once per tracked unit:

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

Each call generates three rows per appearance key — one per `NS.Units.LIST` entry — with the path prefixed `units.<unit>.` and tagged `unit = unit`, so `NS.SchemaForPage(page, unit)` can filter the page down to whichever unit is selected in the panel's Unit picker.

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

### `disabledIf = "<sibling-path>"` (color only) — supported, and FORBIDDEN on a color row

The ColorPicker maker (`libs/LibKa0s/OptionsWidgets.lua`) reads `disabledIf` inside its refresher closure and calls `cp:SetDisabled(GetSetting(sibling))`, re-evaluated after every panel write and on profile change. **No row in this addon sets it**, and that is a reversal worth writing down.

Each of the four color swatches — `barColor`, `bgColor`, `borderColor`, `fontColor` — used to gray itself out while its "Use class color" partner was on, and each toggle's own `desc` advertised that it would. The argument was that a control the code is not currently reading should say so. options-ui-§17 has since settled it collection-wide: `disabledIf` on a color row is **anti-pattern #74**, and `tests/test_schema.lua` fails the build if one comes back.

What it cost is the ordinary order of operations. Setting a color **before** deciding you want the class one is normal, and a grayed swatch makes that a two-visit job: turn the toggle off, set the color, turn the toggle back on.

The half of the old argument that survives is that the row *is* unread under the other mode, and that is what the tooltip says now instead of graying the widget out — in the composers' own words (`H.CLASS_COLOR_NOTE`). The alpha channel was always live under either mode — the resolver takes the class RGB and keeps the swatch's `a` — so the swatch was never fully dead even under the old design, which is the clearest evidence the graying was overstating the case.

`tests/test_widgets.lua` keeps the library feature pinned against a **synthetic** row, and pins the reversal itself against the four real ones.

### `onChange` (any type)

Defaults to `NS.UpdateBarAppearance`. Override when the row's side effect differs:

- `throttleWindow` — no override; uses the default `UpdateBarAppearance` (the throttle window itself is read live by `NS.RequestRepaint`, not applied via `onChange`).
- `units.<unit>.enabled` → publishes `UNITS` (re-syncs that unit's event registrations), then `APPEARANCE`, then `REPAINT` **only when the bar ends up enabled** — a bar being switched off needs no paint work, and one just switched on is still holding whatever value it had when it went away.

### `fmt = "%.1f sec"` (number only)

Formatting hint for `/at list` / `/at get` output, applied by `lib.FormatValue` (LibKa0s-Slash-1.0), which `NS.FormatSchemaValue` delegates to. Without `fmt`, a number renders via `tostring(v)`.

### `sorting = { ... }` (string select)

Explicit option order for a select widget when the natural key sort isn't desired. `fontFlags` and `visibility` both carry one; both come from the composers now (`H.FONT_FLAGS_SORT`, `H.VISIBILITY_SORT`) rather than from a private table in a page file — which is the point of having one list per collection rather than one per addon.

### `solo = true` (panel layout, any type)

Tells `Helpers.RenderSchema` to render this row alone in the **left half** of its own line instead of pairing it with the next row in the 50/50 grid. **No row in this addon sets it any more.** `barTexture` carried it to keep the Bar tab's pairs from splitting across lines, and `throttleWindow` carried it to be a legal `pairWith` host; the first job belongs to `startsLine` now and the second is gone with the bespoke Debug console checkbox. `tests/test_widgets.lua` keeps the library feature pinned against a synthetic row, exactly as it does `disabledIf`. Has no effect on the slash CLI.

### `startsLine = true` (panel layout, any type)

Flushes any in-progress two-column row **before** this row, so whatever follows starts on a fresh
line. It is what makes a declared pair unsplittable: a color swatch carries it, so the swatch and
its "Use class color" companion land side by side however many widgets precede them. That used to be
a parity count done by hand in a comment — and any added row broke it silently. The composers set it
for you; a hand-written pair must set it itself.

### `sessionOnly = true` (any type)

The row's value is **not** in the profile and must never reach it. `core/Data.lua` keeps a small
**session-settings registry** — `NS.RegisterSessionSetting(path, { get, set })` — and `NS.GetSetting`
/ `NS.SetSetting` check it before touching `db.profile`, so the panel widget, `/at get` and `/at set`
all reach the live value down the same path every other row takes. There is exactly one such row:
`state.debugConsole`, the Master controls tab's console toggle, bound to the `{ get, set }` pair
`NS.DebugLog:ConsoleCheckbox()` answers. `NS.ValidateSchema` exempts these rows from the
"path must resolve against `defaults.profile`" check — not being in the profile is the point of them
— and `tests/test_schema.lua` exempts them from "every row declares a default", because there is
nothing for a reset to restore such a row *to*.

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
-- unchanged so the flat globals need no special case)
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
| **The panel** (`Helpers.RenderUnitPanel`) | **Hidden** — while a unit is mirrored its appearance rows are not rendered at all; the chrome block and the tab strip are drawn exactly as they are for any other unit, and a one-line hint takes the rows' place. | The stored value is not what the user would see on screen, so offering a widget for it would be a lie. `NS.PartitionUnitRows` does the split. |

The seam is only dangerous where it is **silent**, so the slash surface says so out loud: `/at get`,
`/at set` and `/at list` append a subordinate gray `(mirrored — the bar shows Player's appearance)`
note to any row whose unit is currently mirroring (`MirrorNote` in `settings/Slash.lua`). Only
appearance rows are annotated — `enabled` and `mirror` carry `alwaysPerUnit = true` and are honored
per-unit even while mirrored, so a note on them would be wrong in the other direction.

Two consequences worth remembering:

- **A write to a mirrored unit is not lost, it is parked.** `/at set units.focus.barWidth 400` really
  does store 400. Untick the mirror (or `/at set units.focus.mirror false`) and 400 is what the focus
  bar renders.
- **`Units.CopyFromPlayer` is the bridge.** It deep-copies the player's nineteen appearance keys into
  the unit's own storage and clears `mirror`, which makes the stored and resolved answers agree — once.
  It is a snapshot, not a second live link.

## What's *not* schema-driven

- **Action buttons** like Reset position. They're rendered via `Helpers.InlineButtonPair`, attached to a sub-page through `Helpers.RenderTabbedSchema`'s `afterGroup` callback. The **Reset position** + **Reset all settings** pair is `H.MasterControls`'s **second return value** — the composer hands back the hook and `settings/General.lua` wires it under the group the composer filed its rows in: `RenderTabbedSchema(ctx, "general", { [H.MASTER_GROUP] = masterTail })`. The group name *is* the hook key, which is why the literal is read off the instance rather than spelled twice. Each page's **Defaults** button (`Helpers.RestoreDefaults(pageKey, ctx)`) is likewise not a row.
- **The non-key/value verbs.** `help`, `config`, `lock`, `unlock`, `toggle`, `debug`, `perf`, `update`, `version`, `test`, `resetposition`, and `profile` live as dedicated entries in the ordered `NS.COMMANDS` table in `settings/Slash.lua` — 17 verbs in all, counting the five schema-driven ones (`list`, `get`, `set`, `reset`, `resetall`). The table is passed **into** LibKa0s-Slash-1.0 rather than owned by it: the About page renders the same rows (via `NS.Slash:LandingRows()`, the library's formatted list), and a library that owned the table would drag the options surface into depending on it. An unknown verb prints `unknown command '<verb>'` then the help list.
- **The Profiles sub-page.** `AceDBOptions:GetOptionsTable(db)` builds its own options table; no schema rows.

## Settings reference (every schema row)

Defaults live in `defaults/Profile.lua`'s `NS.defaults.profile`. The six globals below are flat, single rows on the General page, which also carries the three per-unit `enabled` toggles (the one place a `units.<unit>.*` path is edited outside the Appearance page's Unit picker — so the General page's Defaults button resets them and the Appearance page's does not). Every other setting is **per-unit**: `settings/Appearance.lua` registers the same nineteen appearance keys three times each — once per `NS.Units.LIST` entry (`player`, `target`, `focus`) — at the dotted path `units.<unit>.<key>`, all sharing one canonical `default` from `NS.unitDefaults` (= `defaults.profile.units.player`). Every one of those keys is also in `NS.Units.APPEARANCE_KEYS`, which is what the mirror and `CopyFromPlayer` walk; `tests/test_units.lua` asserts the two agree in both directions. `/at get units.target.barWidth` reads the target bar's width; `/at get barWidth` (the pre-1.9 unqualified form) finds nothing.

**Row counts, per tab:**

| Page | Tab | Rows |
|------|-----|------|
| General | Master controls | 6 |
| General | Bars | 4 |
| Appearance | Size | 2 |
| Appearance | Bar | 4 |
| Appearance | Background | 3 |
| Appearance | Border | 4 |
| Appearance | Text | 6 |

Appearance counts are **per unit** (the page renders one unit at a time behind the banner); General's are unfiltered, because that page renders with `ctx.unit` nil and shows all three enable toggles at once. The Master controls tab's two **reset buttons** are not rows and are not counted — they are the tab's closing button pair. `mirror` is in neither column either: it carries `skipRender`, so `Helpers.__partitionTabs` leaves it out of the strip and the page's chrome block draws it. `tests/test_schema.lua` asserts this table.

### General page (flat globals + the per-unit enable toggles)

| Path | Type | Default | Range / Values | Description |
|------|------|---------|----------------|-------------|
| `enabled` | bool | `true` | — | **New.** The addon-wide switch (options-ui-§15) — "turn this off without unloading it". The *second* rung of `NS.ShouldShowBar`'s ladder, above the three per-unit flags, which it does **not** replace: those are *which bars exist*, this is *whether the addon draws at all*, and §15 forbids conflating an addon-wide row with a per-instance one. Label "Enable Absorb Tracker". **Master controls** tab, order 0. |
| `visibility` | string | `"always"` | `always` / `inCombat` / `outOfCombat` / `never` | **New, and it replaced a boolean.** When the addon's display is shown at all. `showOnlyInCombat` could only ever answer two of the four, so the row's stored *type* changed — carried across by `core/Database.lua`'s **v5** step (`true` → `"inCombat"`, `false` → `"always"`, on every profile in the store). `onChange` publishes `NS.MSG.VISIBILITY` (and `REPAINT` when the change makes a bar visible). Label "General visibility". **Master controls** tab, order 10. |
| `scale` | number | `1.0` | 0.5 – 2 (step 0.05) | **New.** Addon-wide scale, applied as `bar:SetScale` in `NS.UpdateBarAppearance` — in the appearance pass rather than once at `CreateBar`, because it is a setting and a restyle has to re-apply it. Label "Master scale". **Master controls** tab, order 20. |
| `alpha` | number | `1.0` | 0 – 1 (step 0.05) | **New.** Addon-wide opacity. **Not** the per-unit `barAlpha`: this one dims all three bars, and `NS.GetBarAlpha` **multiplies** the two so all three paint sites take the product. Label "Master alpha". **Master controls** tab, order 30. |
| `locked` | bool | `false` | — | If true, no bar is movable, and the per-bar unit labels are hidden with it. `/at lock` / `/at unlock` flip this. Governs every unit. Label "Lock frame". **Master controls** tab, order 40. |
| `state.debugConsole` | bool | *(none)* | — | **New as a row**, and `sessionOnly` — the value is the console *window's* visibility, answered by `NS.DebugLog:ConsoleCheckbox()` through `core/Data.lua`'s session-settings registry, never by `db.profile`. It was a bespoke `SessionCheckbox` injected via `pairWith`; being a row is what lets `/at get state.debugConsole` and `/at set state.debugConsole true` reach it. Carries no `default`: there is nothing for a reset to restore a window's visibility *to*. Label "Debug console". **Master controls** tab, order 50. |
| `units.<unit>.enabled` | bool | `true` (player) / `false` (target, focus) | — | Track and display absorbs for that unit — *which bars exist*, as distinct from the addon-wide `enabled` above it. One row per `NS.Units.LIST` entry, labeled "Enable Player/Target/Focus Bar", orders 10 / 20 / 30, on the **Bars** tab under `subgroup = "Tracked units"`, where they pair with each other rather than with a global. The **only** unit-scoped rows on this page: `alwaysPerUnit = true`, so they stay honored — and free of the `/at get` "(mirrored)" note — even while that unit mirrors the player. Target and focus additionally need `UnitExists` before the bar appears. |
| `throttleWindow` | number | `0.1` | 0.05 – 1 s (step 0.05) | Fastest any bar repaints during a burst of changes, via `NS.RequestRepaint`'s trailing-edge one-shot AceTimer. Label "Update throttle (in sec)". Display hint `"%.2f sec"`. **Bars** tab, `subgroup = "Updates"`, order 40. It was the old Behavior tab's last survivor once lock moved to Master controls and the combat gate became `visibility`; a tab holding one control is a click that reveals one widget, so it merged into the tab whose subject contains it, under its own subsection heading. |

### Appearance page (per-unit, path = `units.<unit>.<key>`)

| Key | Type | Default | Range / Values | Description |
|-----|------|---------|----------------|-------------|
| `mirror` | bool | `true` (target, focus only — player has no row, it's the mirror source) | — | Live-mirror every appearance key from the player. `alwaysPerUnit = true`, `skipRender = true` — not drawn by `RenderRows`; `Helpers.RenderUnitPanel` draws it as the header "Use same styling as Player" checkbox instead. It carries `group = "Link"` because options-ui-§13 wants every row attributable to a section, and draws no tab because `__partitionTabs` skips `skipRender` rows. |
| `barWidth` | number | `200` | 50 – 500 px | Bar width. Hint `"%d px"`. **Size** tab. |
| `barHeight` | number | `20` | 10 – 100 px | Bar height. Hint `"%d px"`. **Size** tab. |
| `barTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Status-bar fill texture. `dialogControl = "LSM30_Statusbar"`, `startsLine`. Composed by `H.BarGroup`. **Bar** tab. |
| `barAlpha` | number | `1.0` | 0 – 1 (step 0.05) | Opacity of the whole frame — fill, background, border and text together, which is what makes it a different question from the three swatches' alpha channels. Promoted out of `modules/Display.lua`, where it was the literal `1` passed to `bar:SetAlpha` at two paint sites; the default IS that 1. The floor moved from 0.1 to 0 with the canonical bar block (options-ui-§16). `NS.GetBarAlpha` clamps it — the stored value comes from SavedVariables — and multiplies it by the addon-wide `alpha`. Composed by `H.BarGroup`. **Bar** tab. |
| `barColor` | color | `{r=0.4, g=0.7, b=1.0, a=0.8}` | 0 – 1 each | Bar-fill color. `hasAlpha = true`, `startsLine = true`, `classColorSource = "unit"`. Stays live under either class-color mode. Composed by `H.BarGroup`. **Bar** tab. |
| `useClassColorBar` | bool | `false` | — | When true, bar fill uses **the bar's own unit's** class color, keeping `barColor`'s alpha. Label "Use class color". Composed by `H.BarGroup`. **Bar** tab. |
| `bgTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Bar-background texture. `dialogControl = "LSM30_Statusbar"`. This addon's own row rather than a composed one: the Background tab is **not** a bar group (options-ui-§16), but this backdrop genuinely has a fill texture — `modules/Display.lua` sets `backdropInfo.bgFile` from it — so the control is wired to something rather than invented to fill a tab out. **Background** tab. |
| `bgColor` | color | `{r=0.2, g=0.2, b=0.2, a=0.8}` | 0 – 1 each | Background color. `hasAlpha = true`, `startsLine = true`, `classColorSource = "unit"`. Composed by `H.ColorPair`. **Background** tab. |
| `useClassColorBg` | bool | `false` | — | When true, background uses a **darkened** class-color variant of the bar's own unit's class, keeping `bgColor`'s alpha. The darkened palette is `core/Data.lua`'s own and is the one surface options-ui-§17 exempts from the shared resolver: a darkened per-class set is a different set of hues, not the class color times a constant. Label "Use class color". Composed by `H.ColorPair`. **Background** tab. |
| `border` | string | `"Blizzard Tooltip"` | LSM `border` catalog | Border style. `dialogControl = "LSM30_Border"`, `startsLine`. Composed by `H.BorderGroup` with `keys = { borderStyle = "border" }` — the composer's canonical leaf is `borderStyle`, and `keys` is what keeps the stored path where every profile on disk already has it. Label "Border style". **Border** tab. |
| `borderSize` | number | `12` | 0 – 16 px | Border thickness. The range is the canonical block's (options-ui-§16); it was 1 – 32. Label "Border thickness (px)". Composed by `H.BorderGroup`. **Border** tab. |
| `borderColor` | color | `{r=0.5, g=0.5, b=0.5, a=1.0}` | 0 – 1 each | Border color. `hasAlpha = true`, `startsLine = true`, `classColorSource = "unit"`. Composed by `H.BorderGroup`. **Border** tab. |
| `useClassColorBorder` | bool | `false` | — | When true, border uses the bar's own unit's class color, keeping `borderColor`'s alpha. Label "Use class color". Composed by `H.BorderGroup`. **Border** tab. |
| `font` | string | `"Friz Quadrata TT"` | LSM `font` catalog | Font face. `dialogControl = "LSM30_Font"`, `startsLine`. Label "Font". Composed by `H.FontGroup`. **Text** tab. |
| `fontSize` | number | `12` | 6 – 32 pt | Font size. Composed by `H.FontGroup`. **Text** tab. |
| `fontColor` | color | `{r=1.0, g=1.0, b=1.0, a=1.0}` | 0 – 1 each | Color of the absorb amount. The text had no color row at all until the Text tab gained one: the FontString was created without one and drew at a bare FontString's own default, opaque white — which is exactly what ships here, so nothing moves on an untouched install. `hasAlpha = true`, `startsLine = true`, `classColorSource = "unit"`. Composed by `H.FontGroup`. **Text** tab. |
| `useClassColorText` | bool | `false` | — | When true, the absorb amount uses the bar's own unit's class color, keeping `fontColor`'s alpha. The composer's canonical leaf is `useClassColorFont`; `keys` keeps the stored path this addon has always used. Label "Use class color". Composed by `H.FontGroup`. **Text** tab. |
| `fontFlags` | string | `"OUTLINE"` | `""` / `OUTLINE` / `THICKOUTLINE` / `MONOCHROME` / `OUTLINE, MONOCHROME` | Font outline and monochrome flags. `select` widget with explicit `sorting`, both from `H.FONT_FLAGS` / `H.FONT_FLAGS_SORT`. The value set is the collection's now rather than this file's, which drops the two combinations this addon alone offered (`MONOCHROME, OUTLINE` and `MONOCHROME, THICKOUTLINE`); a profile still holding one renders exactly as before — `SetFont` takes the string either way — but the dropdown no longer offers it. Label "Font flags", where it was "Font Outline". Composed by `H.FontGroup`. **Text** tab. |
| `fontShadow` | bool | `false` | — | **New.** A soft shadow behind the absorb amount, for legibility over bright art — the sixth row of the canonical font block (options-ui-§16), which this addon lacked. Honored in `NS.UpdateBarAppearance` beside `SetFont`: on writes `SetShadowColor(0,0,0,1)` + `SetShadowOffset(1,-1)`, off **clears** both rather than skipping the call, so turning it back off works. Composed by `H.FontGroup`. **Text** tab. |
| `position` | table | `nil` | — | Saved bar position `{ point, relPoint, x, y }`, per unit. **Not** a schema row — read/written via `NS.Units.Position` / `NS.Units.SetPosition`, never mirrored even when the rest of the unit's appearance is. Listed here for completeness. |

## See also

- [settings-panel.md](./settings-panel.md) — how the schema-built pages get registered with Blizzard's Settings UI.
- [data-flow.md](./data-flow.md) — the `SetByPath → onChange → UpdateBarAppearance` path.
- [common-tasks.md](./common-tasks.md#add-a-new-setting) — recipe for adding a new schema row.
