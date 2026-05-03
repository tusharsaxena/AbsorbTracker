# Schema

The schema-driven settings system. One flat array, walked by both the canvas-layout sub-pages (rendered as AceGUI widgets) and the `/at` slash dispatcher. Adding a new user-facing setting is one row in some `Options/<page>.lua` — the panel widget and the `/at set <path>` CLI are wired automatically.

## Why one schema

Two parallel surfaces — the Blizzard Settings panel and the `/at` slash CLI — historically had per-setting code in both places. That meant every new option touched at least three files (the panel page, the slash dispatcher, the docs). The schema collapses both surfaces onto a single declarative array. Each row is the *complete* description of a setting; the renderer for each surface walks the array and produces the right widget / output.

## Row shape

```lua
{
    path    = "barWidth",        -- key in db.profile (also `/at set <path>`)
    page    = "bar",             -- which Options/<page>.lua renders it
    group   = "Size",            -- optional inline group label within the page
    order   = 10,                -- render order within the group

    type    = "bool" | "number" | "string" | "color",
    label   = "Bar Width",       -- widget label + `/at list`/`get` display
    desc    = "...",             -- tooltip text (rendered via Helpers.AttachTooltip)
    default = 200,               -- used by `/at reset` and `/at resetall`

    -- type-specific:
    min, max, step,                                  -- number
    values        = function() return {...} end,    -- string (select); k=v map
    dialogControl = "LSM30_Statusbar",              -- string (LSM swatch dropdown)
    sorting       = { "", "OUTLINE", ... },         -- string: explicit option order
    hasAlpha      = true,                           -- color

    -- behavior:
    onChange   = function(v) ... end,    -- defaults to UpdateBarAppearance
    inverse    = true,                   -- bool only: widget shows !value
    disabledIf = "useClassColorBar",     -- color only: greys out when sibling toggle is on
    fmt        = "%.1f sec",             -- /at list/get formatting hint
    solo       = true,                   -- panel only: render alone in its own row
}
```

## Registration

Each `Options/<page>.lua` (except `Profiles`) calls `AddonTable.RegisterSchemaRows({ ... })` at file-load time:

```lua
local AddonName, AddonTable = ...
local flatDefaults = AddonTable.flatDefaults

AddonTable.RegisterSchemaRows({
    { path = "barWidth", page = "bar", group = "Size", order = 10,
      type = "number", label = "Bar Width", default = flatDefaults.barWidth,
      min = 50, max = 500, step = 1 },
    -- ...
})
```

**Defaults reference `flatDefaults`.** `Core.lua` is the single place to change a default — the schema rows just point at it via `flatDefaults.barWidth` / etc. Don't hard-code default values in schema rows.

## How the row drives both surfaces

```
                  AddonTable.Schema (flat array)
                          │
            ┌─────────────┴──────────────┐
            ▼                            ▼
   Helpers.RenderSchema(page)    SlashCommands.lua
            │                            │
            │ section break on           │ walks the array
            │   row.group change         │ for /at list / get / set / reset
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
   widget callback → SetSetting → fires row.onChange
                                  → Helpers.RefreshAllPanels
                                    (re-syncs paired controls
                                     like disabledIf greying)
```

## Behavior knobs

### `inverse = true` (bool only)

Flips the widget value vs. the db value. Used so `path = "hidden"` shows up as a positive "Show Bar" toggle: db stores `true` for hidden, the widget displays the opposite.

`/at set hidden true` and the panel's "Show Bar" off both write the same db slot from opposite ends — slash and panel paths remain truly equivalent.

### `disabledIf = "<sibling-path>"` (color only)

Greys out the picker when the named sibling toggle is on. Used by the class-color overrides on `barColor` / `bgColor` / `borderColor`:

```lua
{ path = "barColor", page = "bar", type = "color",
  default = flatDefaults.barColor, hasAlpha = true,
  disabledIf = "useClassColorBar" },
```

The ColorPicker maker (`Panel/Widgets.lua`) reads `disabledIf` inside its refresher closure and calls `cp:SetDisabled(GetSetting(sibling))`. The refresh runs at file-load (initial state), after any panel widget write (every `set()` ends with `Helpers.RefreshAllPanels`), and on profile change — so flipping `useClassColorBar` greys / un-greys the matching color picker on the same frame.

### `onChange` (any type)

Defaults to `AddonTable.UpdateBarAppearance`. Override when the row's side effect differs:

- `updateInterval` → `AddonTable.RestartUpdateTicker`.
- `hidden` → `UpdateBarAppearance` plus a follow-up `UpdateAbsorbBar` so the bar's first frame after un-hide reflects current state.

### `fmt = "%.1f sec"` (number only)

Formatting hint for `/at list` / `/at get` output. Without `fmt`, integers render as `%d` and floats as `%g`.

### `solo = true` (panel layout, any type)

Tells `Helpers.RenderSchema` to render this row alone on its own line instead of pairing it with the next row in the 50/50 grid. Used as a header above a paired row — e.g. on the Bar page `barTexture` (solo) sits on its own row, then `barColor` and `useClassColorBar` pair on the row beneath it, giving the texture dropdown its own line above the color/class-color pair. Has no effect on the slash CLI.

## Public API

```lua
-- Registration (Options/*.lua)
AddonTable.RegisterSchemaRows(rows)             -- append rows to AddonTable.Schema

-- Lookup
AddonTable.FindSchemaRow(path)                  -> row | nil
AddonTable.SchemaForPage(pageKey)               -> { rows }   -- sorted by group's first-seen
                                                              -- registration order, then row.order
                                                              -- within each group

-- Write / reset (fires row.onChange; reads go through GetSetting)
AddonTable.SetByPath(path, value)               -- write + onChange (the documented single seam
                                                -- both /at set and the panel widget set() use)
AddonTable.ApplyDefault(row)                    -- reset to row.default + onChange (used by
                                                -- /at reset, /at resetall, and per-page Defaults)

-- Slash IO
AddonTable.FormatSchemaValue(row, value)        -> string    -- display formatting
AddonTable.ParseSchemaValue(row, text)          -> value | nil, errMsg

-- Validation (called once at PLAYER_LOGIN by CreateOptionsPanel)
AddonTable.ValidateSchema()                     -> errorCount   -- chat-prints malformed rows
```

## Slash CLI mapping

| Command | What it does |
|---------|--------------|
| `/at list` | Walks `AddonTable.Schema`, groups rows by `page`, prints each row's path with the current value rendered through `FormatSchemaValue`. |
| `/at get <path>` | Looks up one row via `FindSchemaRow` and prints the same formatted value. |
| `/at set <path> <value>` | Calls `ParseSchemaValue(row, text)` to coerce the tail into the typed value, then `SetByPath` to write + fire `onChange`. Invalid input prints a type-specific error (`expected true/false/on/off`, `allowed values: A, B, C`, `expected: r g b [a] (each 0-1 or 0-255)`). |
| `/at reset <page>` | Walks the schema rows for `<page>` (general / bar / border / font) and calls `ApplyDefault(row)` on each. |
| `/at resetall` | Runs the reset on every row. Also clears the saved bar position. |

Per-setting subcommands like `/at width 250` or `/at color classcolor on` are gone — `/at set barWidth 250` and `/at set useClassColorBar true` replace them.

## What's *not* schema-driven

- **Action buttons** like Reset Position. They're rendered via `Helpers.InlineButtonPair`, attached to a sub-page through `Helpers.RenderSchema`'s `afterGroup` callback. `Options/General.lua` wires the **Reset Position** + **Reset All Settings** pair under the **Master controls** group via `RenderSchema(ctx, "general", { ["Master controls"] = function(ctxRef) H.InlineButtonPair(ctxRef, ...) end })`.
- **`/at config` / `/at lock` / `/at toggle` / `/at debug` / `/at update` / `/at test` / `/at resetposition` / `/at profile`.** Verbs that don't fit a key/value shape live as dedicated entries in the `AddonTable.SlashCommands` array in `SlashCommands.lua`.
- **The Profiles sub-page.** `AceDBOptions:GetOptionsTable(db)` builds its own options table; no schema rows.

## Settings reference (every schema row)

The exhaustive table of every setting the schema exposes. Defaults live in `Core.lua`'s `defaults.profile`; every row below has its `default` field point at the matching `flatDefaults.<key>`.

| Path | Type | Default | Range / Values | Description |
|------|------|---------|----------------|-------------|
| `hidden` | bool | `false` | — | If true, the bar is hidden. Rendered in the panel as an `inverse` "Show Bar" toggle. |
| `locked` | bool | `false` | — | If true, the bar is unmovable. `/at lock` / `/at unlock` flip this. |
| `updateInterval` | number | `1.0` | 0.1 – 10 s | Ticker interval. `onChange` calls `RestartUpdateTicker`. Display hint `"%.1f sec"`. |
| `barWidth` | number | `200` | 50 – 500 px | Bar width. |
| `barHeight` | number | `20` | 10 – 100 px | Bar height. |
| `barTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Status-bar fill texture. `dialogControl = "LSM30_Statusbar"`. |
| `useClassColorBar` | bool | `false` | — | When true, bar fill uses the player's class color and `barColor` is greyed out. |
| `barColor` | color | `{r=0.4, g=0.7, b=1.0, a=0.8}` | 0 – 1 each | Bar-fill color. `hasAlpha = true`. `disabledIf = "useClassColorBar"`. |
| `bgTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Bar-background texture. |
| `useClassColorBg` | bool | `false` | — | When true, background uses a darkened class-color variant and `bgColor` is greyed out. |
| `bgColor` | color | `{r=0.2, g=0.2, b=0.2, a=0.8}` | 0 – 1 each | Background color. `hasAlpha = true`. `disabledIf = "useClassColorBg"`. |
| `border` | string | `"Blizzard Tooltip"` | LSM `border` catalog | Border style. `dialogControl = "LSM30_Border"`. |
| `borderSize` | number | `12` | 1 – 32 px | Border thickness. |
| `useClassColorBorder` | bool | `false` | — | When true, border uses the class color and `borderColor` is greyed out. |
| `borderColor` | color | `{r=0.5, g=0.5, b=0.5, a=1.0}` | 0 – 1 each | Border color. `hasAlpha = true`. `disabledIf = "useClassColorBorder"`. |
| `font` | string | `"Friz Quadrata TT"` | LSM `font` catalog | Font face. `dialogControl = "LSM30_Font"`. |
| `fontSize` | number | `12` | 6 – 32 pt | Font size. |
| `fontFlags` | string | `"OUTLINE"` | `OUTLINE` / `THICKOUTLINE` / `MONOCHROME` / `OUTLINE,MONOCHROME` / `THICKOUTLINE,MONOCHROME` / `""` | Font outline flags. `select` widget. |
| `position` | table | `nil` | — | Saved bar position `{ point, relPoint, x, y }`. **Not** a schema row — managed directly via `RestoreBarPosition` and the Reset Position execute button. Listed here for completeness. |

## See also

- [settings-panel.md](./settings-panel.md) — how the schema-built options tables get registered with Blizzard's Settings UI.
- [data-flow.md](./data-flow.md) — the `Set… → onChange → UpdateBarAppearance` path.
- [common-tasks.md](./common-tasks.md#add-a-new-setting) — recipe for adding a new schema row.
