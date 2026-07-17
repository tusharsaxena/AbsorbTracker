# Schema

The schema-driven settings system. One flat array, walked by both the canvas-layout sub-pages (rendered as AceGUI widgets) and the `/at` slash dispatcher. Adding a new user-facing setting is one row in some `settings/<page>.lua` — the panel widget and the `/at set <path>` CLI are wired automatically.

## Why one schema

Two parallel surfaces — the Blizzard Settings panel and the `/at` slash CLI — historically had per-setting code in both places. That meant every new option touched at least three files (the panel page, the slash dispatcher, the docs). The schema collapses both surfaces onto a single declarative array. Each row is the *complete* description of a setting; the renderer for each surface walks the array and produces the right widget / output.

The array itself and its helpers live in `settings/Schema.lua` (`NS.Schema`). The per-page rows are registered from `settings/General.lua`, `settings/Bar.lua`, `settings/Border.lua`, and `settings/Font.lua`.

## Row shape

```lua
{
    path    = "barWidth",        -- key in db.profile (also `/at set <path>`)
    page    = "bar",             -- which settings/<page>.lua renders it
    group   = "Size",            -- optional inline group label within the page
    order   = 10,                -- render order within the group

    type    = "bool" | "number" | "string" | "color",
    label   = "Bar Width",       -- widget label + `/at list`/`get` display
    desc    = "...",             -- tooltip text (rendered via Helpers.AttachTooltip)
    default = 200,               -- used by `/at reset` and `/at resetall`

    -- type-specific:
    min, max, step,                                  -- number
    values        = NS.Helpers.LSMValues("statusbar"),  -- string (select); k=v map or fn
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

Each `settings/<page>.lua` (except `Profiles`) calls `NS.RegisterSchemaRows({ ... })` at file-load time:

```lua
local addonName, NS = ...
local flatDefaults = NS.flatDefaults

NS.RegisterSchemaRows({
    { path = "barWidth", page = "bar", group = "Size", order = 10,
      type = "number", label = "Bar Width (in px)", default = flatDefaults.barWidth,
      min = 50, max = 500, step = 1, fmt = "%d px" },
    -- ...
})
```

**Defaults reference `flatDefaults`.** `defaults/Profile.lua` is the single place to change a default — the schema rows just point at it via `flatDefaults.barWidth` / etc. `NS.flatDefaults` is an alias of `NS.defaults.profile` (the AceDB per-profile default table). Don't hard-code default values in schema rows.

## How the row drives both surfaces

```
                  NS.Schema (flat array, settings/Schema.lua)
                          │
            ┌─────────────┴──────────────┐
            ▼                            ▼
   Helpers.RenderSchema(page)      settings/Slash.lua
   (settings/Widgets.lua)                 │
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
                                  (re-syncs paired controls
                                   like disabledIf greying)
```

`NS.SetByPath` (in `settings/Schema.lua`) is the single write seam: it calls `NS.SetSetting` then fires the row's `onChange`. It does **not** itself refresh the panel — the slash handlers call `NS.RefreshOptionsPanel` afterward, and the panel widgets' own `set()` closures end with `Helpers.RefreshAllPanels`.

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

The ColorPicker maker (`settings/Widgets.lua`) reads `disabledIf` inside its refresher closure and calls `cp:SetDisabled(GetSetting(sibling))`. The refresh runs at file-load (initial state), after any panel widget write (every checkbox/slider/dropdown `set()` ends with `Helpers.RefreshAllPanels`), and on profile change — so flipping `useClassColorBar` greys / un-greys the matching color picker on the same frame.

### `onChange` (any type)

Defaults to `NS.UpdateBarAppearance`. Override when the row's side effect differs:

- `throttleWindow` — no override; uses the default `UpdateBarAppearance` (the throttle window itself is read live by `NS.RequestRepaint`, not applied via `onChange`).
- `hidden` → `UpdateBarAppearance` plus a follow-up `UpdateAbsorbBar` (only when re-showing) so the bar's first frame after un-hide reflects current state.

### `fmt = "%.1f sec"` (number only)

Formatting hint for `/at list` / `/at get` output, applied by `NS.FormatSchemaValue`. Without `fmt`, a number renders via `tostring(v)`.

### `sorting = { ... }` (string select)

Explicit option order for a select widget when the natural key sort isn't desired. `settings/Font.lua`'s `fontFlags` uses it to keep the outline flags in a hand-chosen order.

### `solo = true` (panel layout, any type)

Tells `Helpers.RenderSchema` to render this row alone on its own line instead of pairing it with the next row in the 50/50 grid. Used as a header above a paired row — e.g. on the Bar page `barTexture` (solo) sits on its own row, then `barColor` and `useClassColorBar` pair on the row beneath it, giving the texture dropdown its own line above the color/class-color pair. Has no effect on the slash CLI.

## Public API

All defined in `settings/Schema.lua`.

```lua
-- Registration (settings/*.lua)
NS.RegisterSchemaRows(rows)             -- append rows to NS.Schema

-- Lookup
NS.FindSchemaRow(path)                  -> row | nil
NS.SchemaForPage(pageKey)               -> { rows }   -- groups kept in first-seen
                                                              -- registration order, then row.order
                                                              -- within each group

-- Write / reset (fires row.onChange; reads go through NS.GetSetting)
NS.SetByPath(path, value)               -- SetSetting + onChange (the documented single seam
                                                -- both /at set and the panel widget set() use)
NS.ApplyDefault(row)                    -- reset to row.default + onChange (deep-copies table
                                                -- defaults; used by /at reset, /at resetall,
                                                -- and per-page Defaults buttons)

-- Slash IO
NS.FormatSchemaValue(row, value)        -> string    -- display formatting
NS.ParseSchemaValue(row, text)          -> value | nil, errMsg

-- Validation
NS.ValidateSchema()                     -> errors, resolved, missing
```

### `NS.ValidateSchema()`

Called once from `NS.CreateOptionsPanel` (`settings/Panel.lua:79`), which runs at `OnEnable` (PLAYER_LOGIN timing) after every `settings/<page>.lua` has registered its rows. It walks `NS.Schema` and, for each row, checks:

- the row is a table with a non-empty string `path`,
- `page` is one of `general`, `bar`, `border`, `font`, `profiles`,
- `type` is one of `bool`, `number`, `string`, `color`,
- **(Ka0s standard §4.5)** the `path` resolves against `NS.defaults.profile` — a typo'd path would otherwise silently read/write nothing. Rows on the `profiles` page are exempt (their options are AceDBOptions-supplied).

It returns **three** counts — `errors` (shape violations), `resolved` (paths found in `defaults.profile`), and `missing` (present rows whose `path` has no matching default). The validator only *prints* malformed rows through `NS.Print`; it never refuses to register.

This is exercised headlessly by `tests/test_schema.lua`, which asserts the live schema validates with `errors == 0` and `missing == 0`, plants a bogus-path row to confirm `missing == 1`, and plants an invalid page/type row to confirm the shape-error count.

## Slash CLI mapping

The slash surface is `settings/Slash.lua`, registered via AceConsole (`NS.addon:RegisterChatCommand("at", ...)` and `("absorbtracker", ...)`). The value-shaped verbs walk `NS.Schema`:

| Command | What it does |
|---------|--------------|
| `/at list` | Walks `NS.Schema`, groups rows by `page` (general, bar, border, font), prints each row's path with the current value rendered through `FormatSchemaValue`. |
| `/at get <path>` | Looks up one row via `FindSchemaRow` and prints the same formatted value. |
| `/at set <path> <value>` | Calls `ParseSchemaValue(row, text)` to coerce the tail into the typed value, then `SetByPath` to write + fire `onChange`, then `RefreshOptionsPanel`. Invalid input prints a type-specific error (`expected true/false/on/off/1/0/yes/no`, `expected a number`, `allowed values: A, B, C`, `expected: r g b [a] (each 0-1 or 0-255)`). |
| `/at reset <page>` | Walks the schema rows for `<page>` (general / bar / border / font) via `SchemaForPage` and calls `ApplyDefault(row)` on each, then `RefreshOptionsPanel`. |
| `/at resetall` | Runs `ApplyDefault` on every row. Also clears the saved bar position (`db.profile.position = nil` + `RestoreBarPosition`). |

Per-setting subcommands like `/at width 250` or `/at color classcolor on` are gone — `/at set barWidth 250` and `/at set useClassColorBar true` replace them.

## What's *not* schema-driven

- **Action buttons** like Reset Position. They're rendered via `Helpers.InlineButtonPair`, attached to a sub-page through `Helpers.RenderSchema`'s `afterGroup` callback. `settings/General.lua` wires the **Reset Position** + **Reset All Settings** pair under the **Master controls** group via `RenderSchema(ctx, "general", { ["Master controls"] = function(ctxRef) H.InlineButtonPair(ctxRef, ...) end })`. Each page's **Defaults** button (`Helpers.RestoreDefaults(pageKey, ctx)`) is likewise not a row.
- **The Debug console checkbox** (General page, beside Lock Position). Shows/hides the debug console *window* (same as the bare `/at debug`) — deliberately *not* a schema row (window visibility is transient UI, never persisted), and it does **not** change the debug logging flag (`NS.State.debug`). It's rendered via `Helpers.SessionCheckbox` wired to `NS.DebugLog:ConsoleCheckbox()` (`get` = `D:IsShown()`, `set` = `D:Show()`/`D:Hide()`) and injected through `RenderSchema`'s `pairWith` seam.
- **The non-key/value verbs.** `config`, `lock`, `unlock`, `toggle`, `debug`, `update`, `test`, `resetposition`, and `profile` live as dedicated entries in the ordered `NS.COMMANDS` table in `settings/Slash.lua` (15 verbs total; `NS.SlashCommands` is an alias the About page renders). An unknown verb prints `unknown command '<verb>'` then the help list.
- **The Profiles sub-page.** `AceDBOptions:GetOptionsTable(db)` builds its own options table; no schema rows.

## Settings reference (every schema row)

The exhaustive table of every setting the schema exposes. Defaults live in `defaults/Profile.lua`'s `NS.defaults.profile`; every row below has its `default` field point at the matching `flatDefaults.<key>`.

| Path | Type | Default | Range / Values | Description |
|------|------|---------|----------------|-------------|
| `hidden` | bool | `false` | — | If true, the bar is hidden. Rendered in the panel as an `inverse` "Show Bar" toggle. General page. |
| `locked` | bool | `false` | — | If true, the bar is unmovable. `/at lock` / `/at unlock` flip this. General page. |
| `showOnlyInCombat` | bool | `false` | — | When true, the bar is hidden except while in combat (composed with `hidden` via `NS.ShouldShowBar`; the master `hidden` toggle always wins). Label "Show only in combat". `onChange` applies visibility (`NS.ApplyVisibility`). General page, Master controls group, order 15. |
| `throttleWindow` | number | `0.1` | 0.05 – 1 s (step 0.05) | Fastest the bar repaints during a burst of changes, via `NS.RequestRepaint`'s trailing-edge one-shot AceTimer. Label "Update throttle (in sec)". Display hint `"%.2f sec"`. General page, Performance group, `solo`. |
| `barWidth` | number | `200` | 50 – 500 px | Bar width. Hint `"%d px"`. Bar page, Size. |
| `barHeight` | number | `20` | 10 – 100 px | Bar height. Hint `"%d px"`. Bar page, Size. |
| `barTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Status-bar fill texture. `dialogControl = "LSM30_Statusbar"`, `solo`. Bar page, Bar. |
| `barColor` | color | `{r=0.4, g=0.7, b=1.0, a=0.8}` | 0 – 1 each | Bar-fill color. `hasAlpha = true`. `disabledIf = "useClassColorBar"`. Bar page, Bar. |
| `useClassColorBar` | bool | `false` | — | When true, bar fill uses the player's class color and `barColor` is greyed out. Bar page, Bar. |
| `bgTexture` | string | `"Blizzard Raid Bar"` | LSM `statusbar` catalog | Bar-background texture. `dialogControl = "LSM30_Statusbar"`, `solo`. Bar page, Background. |
| `bgColor` | color | `{r=0.2, g=0.2, b=0.2, a=0.8}` | 0 – 1 each | Background color. `hasAlpha = true`. `disabledIf = "useClassColorBg"`. Bar page, Background. |
| `useClassColorBg` | bool | `false` | — | When true, background uses a darkened class-color variant and `bgColor` is greyed out. Bar page, Background. |
| `border` | string | `"Blizzard Tooltip"` | LSM `border` catalog | Border style. `dialogControl = "LSM30_Border"`. Border page. |
| `borderSize` | number | `12` | 1 – 32 px | Border thickness. Hint `"%d px"`. Border page. |
| `borderColor` | color | `{r=0.5, g=0.5, b=0.5, a=1.0}` | 0 – 1 each | Border color. `hasAlpha = true`. `disabledIf = "useClassColorBorder"`. Border page. |
| `useClassColorBorder` | bool | `false` | — | When true, border uses the class color and `borderColor` is greyed out. Border page. |
| `font` | string | `"Friz Quadrata TT"` | LSM `font` catalog | Font face. `dialogControl = "LSM30_Font"`. Font page. |
| `fontSize` | number | `12` | 6 – 32 pt | Font size. Font page. |
| `fontFlags` | string | `"OUTLINE"` | `""` / `OUTLINE` / `THICKOUTLINE` / `MONOCHROME` / `MONOCHROME, OUTLINE` / `MONOCHROME, THICKOUTLINE` | Font outline flags. `select` widget with explicit `sorting`, `solo`. Font page. |
| `position` | table | `nil` | — | Saved bar position `{ point, relPoint, x, y }`. **Not** a schema row — lives in `db.profile`, managed directly via `RestoreBarPosition` and the Reset Position button. Listed here for completeness. |

## See also

- [settings-panel.md](./settings-panel.md) — how the schema-built pages get registered with Blizzard's Settings UI.
- [data-flow.md](./data-flow.md) — the `SetByPath → onChange → UpdateBarAppearance` path.
- [common-tasks.md](./common-tasks.md#add-a-new-setting) — recipe for adding a new schema row.
