# Multi-unit absorb bars — design

Add Target and Focus absorb bars alongside the existing Player bar. Every appearance setting
becomes per-unit, selected through a Unit dropdown at the top of each appearance page (the KickCD
pattern), with a "mirror the Player bar" link and a one-shot "copy from Player" snapshot.

Branch: `feature/multi-unit-bars`. Supersedes the `docs/scope.md` entry that declared target
tracking out of scope.

## 1. Scope

**In:** Player, Target, and Focus bars. Per-unit appearance (size, textures, colors, border, font)
and position. A live mirror link and a one-shot copy, both sourced from Player.

**Out (unchanged):** group / raid / arena / boss / party unit bars, per-aura breakdown, separate
bars per shield source, aura filtering. Mirroring is Player-sourced only — Focus cannot mirror
Target.

**Scope amendment.** `docs/scope.md` currently lists *"Group / raid / target absorb tracking.
Player only. The unit is hard-coded to `"player"` in `modules/Display.lua`"* under **Out of scope**,
and `ARCHITECTURE.md` → Known Limitations says *"Single bar — one player absorb bar; multi-bar /
other units are out of scope."* Both are reversed by this design and are rewritten as part of it.
Group / raid tracking stays out.

## 2. Data model

`defaults/Profile.lua` — persisted schema version moves v2 → v3.

```lua
NS.defaults.profile = {
    -- Globals: flat keys, unchanged. These govern all three bars.
    hidden           = false,
    locked           = false,
    showOnlyInCombat = false,
    throttleWindow   = 0.1,

    units = {
        player = { enabled = true,  position = nil, <appearance> },
        target = { enabled = false, mirror = true, position = nil, <appearance> },
        focus  = { enabled = false, mirror = true, position = nil, <appearance> },
    },
}
```

`<appearance>` is the fifteen existing keys, unchanged in name, type, and default:
`barWidth`, `barHeight`, `barTexture`, `barColor`, `useClassColorBar`, `bgTexture`, `bgColor`,
`useClassColorBg`, `border`, `borderSize`, `borderColor`, `useClassColorBorder`, `font`,
`fontSize`, `fontFlags`.

Rules:

- **Player has no `mirror` key.** It is the mirror source; a Player mirror row would be circular.
- **`position` and `enabled` are per-unit and never mirrored.** Mirroring a position would stack
  every bar on one spot; mirroring `enabled` would make the per-unit toggle meaningless.
- **Target and Focus default to `mirror = true`, `enabled = false`.** They are invisible until the
  user enables them, and when first enabled they look exactly like the Player bar rather than like
  the raw factory defaults.

### Migration (v2 → v3)

In `NS:RunMigrations` (`core/Database.lua`), guarded by `profile.units == nil` so it is idempotent:

1. Create `profile.units`.
2. Deep-copy the fifteen appearance keys plus `position` from the flat profile into
   `units.player`, then `nil` the flat originals.
3. Seed `units.target` and `units.focus` from `NS.defaults.profile.units` (deep copies — two
   profiles must never share a nested table).
4. Leave the four global keys where they are.
5. Bump `g.schemaVersion = 3`.

The existing flatDefaults backfill loop becomes units-aware: it backfills the global keys flat and
each unit's keys under `units.<unit>`.

**Upgrade contract: an existing user sees no visual change.** Their bar keeps its position and
every setting; Target and Focus exist in the DB but are disabled.

## 3. `core/Units.lua` — the unit identity and mirror seam

New file, loaded after `core/Data.lua` and before `core/Database.lua`. Modelled on KickCD's
`core/Units.lua`. **Nothing outside this file reads `db.profile.units` for appearance** — the
mirror behaviour lives in exactly one place.

| Function | Contract |
|---|---|
| `Units.LIST` | `{ "player", "target", "focus" }` — render and iteration order. |
| `Units.LABEL` | `{ player = "Player", target = "Target", focus = "Focus" }`. |
| `Units.Config(unit)` | Raw `db.profile.units[unit]`, or `nil` when the DB isn't ready. |
| `Units.IsEnabled(unit)` | The per-unit `enabled` flag. Does **not** consider the global `hidden`. |
| `Units.IsMirrored(unit)` | Always `false` for `player`; otherwise `config.mirror == true`. |
| `Units.SourceUnit(unit)` | `"player"` when mirrored, else `unit`. |
| `Units.Get(unit, key)` | Mirror-resolved appearance read: `Config(SourceUnit(unit))[key]`, falling back to the unit's default. The single read path for all fifteen appearance keys. |
| `Units.Position(unit)` | The unit's own saved position. Never mirror-resolved. |
| `Units.SetPosition(unit, pos)` | Writes the unit's own position. Never mirror-resolved. |
| `Units.CopyFromPlayer(unit)` | Deep-copies Player's fifteen appearance keys onto `unit`, then sets `mirror = false`. No-op for `player`. Does not touch `position` or `enabled`. |

`core/Data.lua`'s media and color getters gain a `unit` parameter and route their setting reads
through `Units.Get`: `NS.GetBarTexture(unit)`, `NS.GetBgTexture(unit)`, `NS.GetBorder(unit)`,
`NS.GetFont(unit)`, `NS.GetBarColor(unit)`, `NS.GetBgColor(unit)`, `NS.GetBorderColor(unit)`.

**Class colors are always the player's.** `GetPlayerClassColor` / `GetBgClassColor` and their
caches are untouched — a Target bar with "Use Class Color" on shows *your* class color, not the
target's. This is a deliberate simplification: resolving the tracked unit's class would require a
`PLAYER_TARGET_CHANGED`-driven recolor and a non-player fallback path, for a cosmetic gain.

`NS.GetSetting(key)` / `NS.SetSetting(key, value)` keep their flat-key semantics and now serve the
four globals only.

## 4. Three bar frames — `modules/Bar.lua`

`Bar.lua` becomes a factory. `NS.CreateBar(unit, globalName)` builds the
`BackdropTemplate` + `StatusBar` + `FontString` stack exactly as today and returns the frame; the
file calls it three times at load and publishes `NS.bars = { player = …, target = …, focus = … }`.

- The Player frame keeps the global name **`AbsorbTrackerFrame`**; Target and Focus get
  `AbsorbTrackerTargetFrame` / `AbsorbTrackerFocusFrame`.
- `NS.bar`, `NS.statusBar`, `NS.valueText` remain as aliases to the Player frame's, so
  `core/DebugLog.lua` and the existing tests keep working without a rename sweep.
- Each frame carries `frame.unit` so its `OnDragStop` handler writes
  `Units.SetPosition(self.unit, …)`.
- `NS.backdropInfo` becomes per-frame (`frame.backdropInfo`) — a single shared table cannot serve
  three bars with different border sizes.

## 5. Per-unit display — `modules/Display.lua`

Every display function takes a `unit`:

- `NS.RestoreBarPosition(unit)`
- `NS.UpdateBarAppearance(unit)`
- `NS.ShouldShowBar(unit)`
- `NS.ApplyVisibility(unit)`
- `NS.UpdateAbsorbBar(unit)`

plus `NS.ForEachUnit(fn)`, which walks `Units.LIST`. The three bus handlers call
`ForEachUnit`, so the bus stays payload-free and the message catalogue is unchanged.

### Visibility

`NS.ShouldShowBar(unit)` composes, in order — first `false` wins:

1. Global `hidden` is true → hidden. (Master kill-switch; `/at toggle` flips it.)
2. `Units.IsEnabled(unit)` is false → hidden.
3. Global `showOnlyInCombat` is true and `UnitAffectingCombat("player")` is false → hidden.
   Note this keys off *player* combat for all three bars, matching the global semantics.
4. `unit ~= "player"` and `UnitExists(unit)` is false → hidden.
5. Otherwise shown.

`UnitExists` is the only unit-presence predicate used. "Hide when the unit has no absorb" is
**not** implementable: `UnitGetTotalAbsorbs` returns a secret in restricted content and comparing
it to zero raises — the same constraint recorded in `scope.md` for the audio-alert feature.

The transition-only debug log (`dbgLastShown`) becomes a per-unit table keyed by unit.

### Paint

`NS.UpdateAbsorbBar(unit)` reads `UnitGetTotalAbsorbs(unit)` against `UnitHealthMax(unit)`. The
value stays secret-safe: straight into `AbbreviateNumbers` and `StatusBar:SetValue`, never through
`tonumber`.

### Default positions

When `Units.Position(unit)` is nil, `RestoreBarPosition` anchors to `UIParent` `CENTER` with a
per-unit y-offset, stacking upward from the Player bar:

- `player` → `y = 0`
- `target` → `y = (playerBarHeight + 8)`
- `focus`  → `y = 2 * (playerBarHeight + 8)`

`playerBarHeight` is read live from `Units.Get("player", "barHeight")`. A newly-enabled bar
therefore lands somewhere visible and non-overlapping.

## 6. Events — `core/AbsorbTracker.lua`

A frame can `RegisterUnitEvent` for at most two units, so the existing private frame gains one
sibling:

- **Frame A** — `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` for `("player", "target")`.
- **Frame B** — the same two events for `("focus")`.

Both are created once and guarded against a disable/enable cycle, exactly as the current frame is.
Registration is unconditional (not gated on `enabled`) — the C-side filter already limits dispatch
to three units, so conditional registration would add lifecycle complexity for no measurable gain.

Repaints stay **one coalesced all-bars pass**: the handlers call `NS.RequestRepaint()` with no
unit, `modules/Timer.lua` is unchanged, and the trailing-edge timer fires `ForEachUnit` over
`UpdateAbsorbBar`. Three `SetValue` calls per throttle window is cheaper than three independent
timers.

New AceEvent subscriptions: `PLAYER_TARGET_CHANGED` and `PLAYER_FOCUS_CHANGED`, each publishing
`VISIBILITY` then `REPAINT`. These are global, payload-free events with no unit to filter, so they
belong on AceEvent per §9.1.

**Standards note.** This widens the accepted §9.1 deviation from one raw event frame to two. The
justification is unchanged and strengthened — the events fire for every unit the client knows
about, and AceEvent structurally cannot `RegisterUnitEvent`. `ARCHITECTURE.md` → Standards
Deviations is rewritten to describe two frames and why a second is required (the two-unit filter
limit).

## 7. Schema

`settings/{Bar,Border,Font}.lua` generate their rows inside
`for _, unit in ipairs(NS.Units.LIST) do` loops. Each row gains:

- `path = "units." .. unit .. "." .. key`
- `unit = unit`

`page`, `group`, `order`, `type`, `label`, `desc`, `default`, and the widget hints are unchanged,
so the panel layout per unit is identical to today's Player layout.

Two new row kinds:

| Row | Page | Behaviour |
|---|---|---|
| `units.<unit>.enabled` | `bar` | "Enable this bar". `alwaysPerUnit = true` — renders even while mirrored. Player's is present too (defaults on), so the CLI can reach it. |
| `units.<unit>.mirror` | `bar` | `skipRender = true` — kept in the schema so `/at set units.focus.mirror true` works, but drawn bespoke by the panel header. Not registered for `player`. |

Schema infrastructure changes (`settings/Schema.lua`):

- `NS.SchemaForPage(pageKey, unit)` — an optional `unit` filter. `unit == nil` returns every unit's
  rows (what `RestoreDefaults` / `RestoreAllDefaults` / `/at list` want); a unit returns that
  unit's rows plus any unit-agnostic rows (General's, which carry no `unit` field).
- `NS.ResolvePath(tbl, path)` / `NS.SetPath(tbl, path, value)` — dotted-path walkers.
  `NS.SetByPath` and `NS.GetSetting`'s callers route through them.
- `NS.ValidateSchema`'s §4.5 check resolves dotted paths against `defaults.profile` rather than
  indexing it flat. Its `(errors, resolved, missing)` return shape is unchanged, so the harness
  assertion still holds — the counts simply grow.
- `NS.PartitionUnitRows(rows)` — splits `alwaysPerUnit` rows from mirrored appearance rows.

## 8. Settings panel

`Helpers.RenderUnitPanel(ctx, pageKey)` — a port of KickCD's, added to `settings/Helpers.lua`.
It clears the scroll and rebuilds from scratch on every unit switch (AceGUI's widget pool makes
release-and-recreate cheap, and the ScrollFrame anchors flush to `ctx.body`, leaving no room for a
truly persistent header).

Layout, matching KickCD's exactly:

```
Unit
[                                              Focus  ▾ ]

[☑ Use same styling as Player]  [ Copy styling from Player ]
Linked to Player – uncheck to customize.

  … appearance rows (hidden while mirrored) …
```

- The dropdown is full-width, listing `Units.LIST` by `Units.LABEL`, defaulting to `player`.
  `OnValueChanged` sets `ctx.unit` and re-renders.
- The mirror checkbox + copy button row and the hint line render **only** for target and focus.
- The checkbox writes `units.<unit>.mirror` through `NS.SetByPath` and re-renders.
- The copy button calls `Units.CopyFromPlayer(unit)` (which clears `mirror`) and re-renders, so
  the page flips from the mirrored state to a fully-populated editable one in a single click.
- While mirrored, `PartitionUnitRows` renders only the `alwaysPerUnit` rows (the enable toggle);
  the appearance rows are omitted entirely rather than greyed out.

`settings/{Bar,Border,Font}.lua` builders call `RenderUnitPanel(ctx, pageKey)` in place of
`RenderSchema(ctx, pageKey)`. `settings/General.lua` and `settings/About.lua` are unchanged — the
General page holds only global settings and gets no dropdown.

Each page's **Defaults** button resets that page's rows across **all three units**
(`SchemaForPage(pageKey)` with no unit filter), matching KickCD. `Helpers.RestoreAllDefaults`
additionally clears all three saved positions.

## 9. Slash surface

**Full dotted paths only — a deliberate clean break** (KickCD parity):

```
/at set units.target.barWidth 250
/at get units.focus.barColor
```

`/at set barWidth 250` now errors with the standard unknown-setting message. Every `/at set`
example in `README.md` and `docs/` is rewritten accordingly, and the change is called out in the
changelog as breaking for existing macros.

- `/at list` groups its output by unit, with the unit name as a section header, globals first.
- `/at reset <general|bar|border|font>` resets that page across all three units.
- `/at resetall` unchanged in meaning; also clears all three positions.
- `/at resetposition` clears all three positions and republishes `POSITION`.
- `/at toggle` still flips the global `hidden`.
- `/at test` paints its fake value on every enabled bar.

## 10. Tests

New `tests/test_units.lua`:

- `Units.Get` resolves to Player's value when mirrored and the unit's own when not.
- `IsMirrored("player")` is always false even if a `mirror` key is force-written.
- `CopyFromPlayer` snapshots the fifteen keys, clears `mirror`, and leaves `position` / `enabled`
  untouched; subsequently changing Player does not move the copied unit.
- `IsEnabled` reads the per-unit flag and ignores the global `hidden`.

Extensions:

- `test_display` — the five-step `ShouldShowBar(unit)` ladder, including `UnitExists` gating for
  target/focus and the fact that `player` skips step 4; per-unit default position offsets.
- `test_schema` — dotted-path resolve/set; `ValidateSchema` resolving nested paths;
  `SchemaForPage` with and without a unit filter; `PartitionUnitRows`.
- `test_database` — the v2 → v3 migration: flat keys lift into `units.player`, flat originals are
  cleared, target/focus are seeded, re-running is a no-op, and nested tables are not shared.
- `test_slashcmds` — `set`/`get` on dotted paths; unqualified paths rejected; `reset <page>`
  covering all units.
- `test_helpers` — `RenderUnitPanel` builds the header, hides appearance rows while mirrored, and
  re-renders on a unit switch; `RestoreDefaults` covers all units.
- `tests/wow_mock.lua` — add `UnitExists`, per-unit `UnitGetTotalAbsorbs` / `UnitHealthMax`, and
  `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` dispatch.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). When the suite settles,
regenerate `docs/test-cases.md` via `lua tests/run.lua --list` and update the README `tests` badge
in the same change.

## 11. Documentation

| File | Change |
|---|---|
| `AbsorbTracker.toc` | Add `core\Units.lua` after `core\Data.lua`. |
| `docs/scope.md` | Move target/focus tracking from Out of scope to In scope (raid/group stays out). Add resolved decisions: mirror is Player-sourced and live; copy is a one-shot snapshot; position and enable are never mirrored; class colors are always the player's; visibility uses `UnitExists`, never an absorb comparison. |
| `docs/ARCHITECTURE.md` | Module map row for `core/Units.lua`; rewrite the "Single bar" limitation; rewrite the §9.1 deviation for two event frames; add the two new AceEvent subscriptions. |
| `docs/schema.md` | Dotted paths, the `unit` / `alwaysPerUnit` / `skipRender` row fields, per-unit row generation. |
| `docs/settings-panel.md` | The Unit dropdown, the mirror header, and the hidden-while-mirrored rule. |
| `docs/data-flow.md` | Three bars through one coalesced repaint; the mirror resolution step. |
| `docs/module-map.md`, `docs/file-index.md` | `core/Units.lua`. |
| `docs/common-tasks.md` | "Add a per-unit setting" recipe. |
| `docs/smoke-tests.md` | Manual checks: enable target, mirror on/off, copy, drag each bar, target/focus swap, combat gate. |
| `README.md` | The three bars, the dropdown, mirror vs copy, the breaking slash-path change, the tests badge. |

Version is **not** bumped as part of this work — that's a separate explicit instruction.

## 12. Build order

1. `core/Units.lua` + defaults + migration + `test_units` / `test_database`.
2. Dotted paths in `settings/Schema.lua` + validator + `test_schema`.
3. `modules/Bar.lua` factory + `modules/Display.lua` per-unit + `test_display`.
4. Events in `core/AbsorbTracker.lua` + mock additions.
5. Per-unit schema rows in `settings/{Bar,Border,Font}.lua`.
6. `Helpers.RenderUnitPanel` + the three builders + `test_helpers`.
7. Slash surface + `test_slashcmds`.
8. Docs, `test-cases.md` regeneration, README badge.

Each step ends green on `lua tests/run.lua` and `luacheck .`.
