# Architecture

Orient-yourself map for **Ka0s Absorb Tracker** (modular layout). User-facing behavior is in
[../README.md](../README.md); how to verify is in [testing.md](./testing.md); topic detail lives
alongside this file in `docs/`.

## Overview

Three movable absorb status bars — player, target, and focus — each displaying the total of all
active absorb shields on that unit as one combined value. Target and focus ship disabled; when
enabled, either can "mirror" the player's appearance live, or take a one-shot "copy from player"
snapshot and then diverge. Every bar reads `UnitGetTotalAbsorbs(unit)` against `UnitHealthMax(unit)`
on every event-driven, throttled repaint, paints a `BackdropTemplate` + `StatusBar` + `FontString`
stack (`AbsorbTrackerFrame` / `AbsorbTrackerTargetFrame` / `AbsorbTrackerFocusFrame`), and exposes
every visual knob through both a three-page Blizzard Settings panel — each page a tab strip
(options-ui-§13), with a chrome block carrying the Unit picker and the mirror controls (options-ui-§14)
above the Appearance page's — and the `/at`
slash CLI via fully-qualified `units.<unit>.<key>` paths. Bar fill, background, border and the
absorb-amount text each support an opt-in class-color override, resolved from the class of
the bar's **own** unit (options-ui-§17); position and the per-unit `enabled` flag are per-unit and are **never**
mirrored, whatever the mirror flag says. The two ways of bringing a unit in line with the player are
distinct: **mirror** is a live link (`units.<unit>.mirror = true` — the unit re-reads the player's
settings on every paint), **copy** is a one-shot snapshot (`NS.Units.CopyFromPlayer(unit)` —
deep-copies once, then the unit diverges). Position is saved per-profile via AceDB. Retail Midnight
only (Interface 120100), English only.

The addon is an **AceAddon** (`core/AbsorbTracker.lua`) mixing in AceEvent / AceTimer / AceConsole.
`NS`, the second of the two varargs the client hands every TOC-loaded file, is the shared private
namespace bus in every file; there is no `_G[addonName]` table. The FIRST vararg is the addon folder
name, and only six files read it, so only those six bind it: `core/Namespace.lua`,
`core/EnvSetup.lua`, `core/MediaSetup.lua`, `core/DebugLogSetup.lua`, `core/PerfSetup.lua` and
`core/AbsorbTracker.lua` open `local addonName, NS = ...` because each hands the folder name to a
vendored library (or to `NS.name`) that cannot infer which folder it was copied into. The other
twenty, `core/CoreSetup.lua` among them, open `local _, NS = ...`. That is not a style split: binding a name nothing reads is
what `M4c-06` found nineteen of behind the blanket `211/addonName` ignore, and `_` is the spelling
that keeps luacheck able to say so the next time.

## Module Map

Load order is dependency order (see `AbsorbTracker.toc`): Libraries → Locales → Core → Defaults →
Modules → Settings.

Six of the rows below are *setup* files rather than implementation: `core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `core/Lifecycle.lua`, `core/PerfSetup.lua`, `core/LauncherSetup.lua` and
`settings/OptionsSetup.lua` each hand a **descriptor** to one of the seven descriptor-taking LibKa0s
majors — `LibKa0s-Core-1.0`, `-DebugLog-1.0`, `-Lifecycle-1.0`, `-Perf-1.0`, `-Launcher-1.0`,
`-Options-1.0`, `-Slash-1.0` — and publish what
comes back under the `NS.*` name the addon already used, plus a degradation stub for when the library
is absent. `settings/Slash.lua` does the same thing for `-Slash-1.0` without a separate setup file. `core/MediaSetup.lua`
and `core/EnvSetup.lua` are the eighth and ninth seams, and the two odd ones: `LibKa0s-Media-1.0` and
`LibKa0s-Env-1.0` take no descriptor, only this addon's FOLDER name — a texture path is absolute from
`Interface\AddOns\` and a TOC manifest is keyed by folder, and a vendored copy cannot know which folder
it was copied into. **Nine majors bound by name** of the twelve `libs/LibKa0s/` vendors (seventeen files); Pool
and Item are registered and unread, and Widgets is reached only through DebugLog's Copy window. See
[Five extracted libraries, one descriptor each](./performance.md#five-extracted-libraries-one-descriptor-each).

There is no `:NewModule()` hierarchy. Modules are plain files hanging functions on `NS`, and a
caller reaches a function defined in a later-loaded file through `NS.X` directly — looked up at call
time, guarded with `if NS.X then … end` where the load-order coupling is soft. Cross-module
*notifications* do not use that route at all; they run over the bus (see [Message Bus](#message-bus)).

| File | Responsibility |
|------|----------------|
| `core/EnvSetup.lua` | The `LibKa0s-Env-1.0` seam: `NS.Meta(field)` / `NS.Version()` over the vendored library, told this addon's own folder name. It replaced the whole of `core/Compat.lua`, whose one export was the same TOC-metadata reader nine addons had each written for themselves. |
| `core/MediaSetup.lua` | The `LibKa0s-Media-1.0` seam: `NS.Icon` / `NS.MediaFont` over the vendored payload, and the one `Media.RegisterLSM` call. Loads before `Constants.lua`, which reads it. |
| `core/Constants.lua` | `NS.Constants`: fallback texture/border/font paths, `FONT_MONO` / `FONT_MONO_NAME` (debug console, resolved from the Media seam), `LOGO_PATH` (the About page's 300×300 logo) and `LOGO_ICON_PATH` (the 128×128 icon the TOC's `## IconTexture`, the minimap button and a broker display all read — a different file, layout-§4), plus `MINIMAP_PATH`, the one stored path that lives in the global store. |
| `core/Namespace.lua` | `NS.name` / `NS.version` / `NS.PREFIX` (cyan `[AT]`) and the hot-path `floor`/`max` caches. |
| `core/State.lua` | `NS.State` — session-only runtime state (the debug flag; never persisted). |
| `core/Bus.lua` | The closed cross-module message bus: `NS.bus` (shared publish target), `NS.NewBusTarget()` (one per receiver), and the `NS.MSG` catalog (`REPAINT`/`APPEARANCE`/`VISIBILITY`/`POSITION`/`UNITS`). |
| `core/CoreSetup.lua` | Wires the addon into `LibKa0s-Core-1.0` — the guard, the stringifier and the printer are vendored library code, not addon code. Publishes `NS.Print` (prefixed chat, built via `lib:New{...}` with the `[AT]` prefix passed as a function), `NS.Util.print` (the same function object), `NS.IsConcatSafe` and `NS.SafeToString`, with working fallbacks when the library is absent. The secret-safe debug sink is `NS.Debug` (published by `core/DebugLogSetup.lua`); every debug arg routes through `NS.SafeToString`. |
| `core/PerfSetup.lua` | Wires the addon into `LibKa0s-Perf-1.0` (issue #17) — the probe itself is a vendored library, not addon code. Builds `NS.Perf` via `lib:New{...}`: the addon's name/version/SavedVariables global, the bucket declarations (order + nesting), and the `suspend`/`resume` pair that makes the addon inert without a `/reload`. Loads immediately after `core/CoreSetup.lua`, before any module takes `local Perf = NS.Perf` as an upvalue. See [Performance & Profiler Attribution](#performance--profiler-attribution) below. |
| `core/Data.lua` | The AceDB read/write seam (`GetSetting`/`SetSetting` — dotted-path aware, so `units.target.barWidth` and flat `locked` both work), LSM fetchers with fallbacks (each takes a `unit`, resolved through `NS.Units.Get`), and the class-color-aware color resolvers (each takes a `unit`; the class color is that unit's own, per options-ui-§17, and the background keeps its own darkened per-class palette — the one surface §17 exempts from the shared `NS.ResolveColor`). |
| `core/Database.lua` | `NS:InitDB` (AceDB + profile callbacks) and `NS:RunMigrations` (schema-version seam). |
| `core/Units.lua` | `NS.Units` — unit identity (`LIST`/`LABEL`), mirror resolution (`IsMirrored`/`SourceUnit`/`Get`), per-unit position read/write, and `CopyFromPlayer`. The only file that reads `db.profile.units` for appearance. |
| `core/LauncherSetup.lua` | The `LibKa0s-Launcher-1.0` seam — see [Launcher](#launcher) below. Builds the one LDB object at file load and publishes `NS.Launcher`; `Register()` waits for `OnInitialize`, because the table it hands LibDBIcon is `db.global.minimap` and there is none until `NS:InitDB` has run. Degrades to a stub answering the same five members off the store, so the Master-controls checkbox is still honest with the library absent. |
| `core/DebugLogSetup.lua` | Wires the addon into `LibKa0s-DebugLog-1.0` — the on-screen console (`debug-logging`) is a vendored library, not addon code. Builds `NS.DebugLog` via `lib:New{...}` and binds `NS.Debug` bare off it. What this file supplies: the frame-name prefix, the title, the monospace font, the `/at` slash name, the call-time `print`/`safeToString` hooks, the `onVisibilityChanged` panel refresh, the `[Init]` session summary, and — the part that must not move — `isEnabled`/`setEnabled` over `NS.State.debug`, so the logging flag stays this addon's single truth. Degrades to a stub that still flips the flag when the library is absent. The library's surface is unchanged: `FormatPlain`/`FormatColored`, `SetEnabled`, `Show`/`Hide`/`Toggle`/`IsShown`, the `debug-logging-§11` always-shown scrollbar (`UpdateScrollBar`) + bottom line counter (`UpdateStatus`, `lib.MAX_BUFFER = 1500`), `ConsoleCheckbox()` — the General page's checkbox spec that shows/hides the window (not the logging flag) — and the harness-facing `CopyText`/`FindLine`/`BufferSize`/`LastLine` plus the raw `buffer` array. The copy window itself is no longer DebugLog's own: as of minor 12 it is `LibKa0s-Widgets-1.0`'s `CopyWindow`, which the module hard-floors on (`NEEDS_WIDGETS = 7`) — the one place this addon reaches an eighth major, and it reaches it indirectly. |
| `core/AbsorbTracker.lua` | AceAddon promotion; `OnInitialize` (InitDB, slash register, launcher register — in that order, because the launcher needs the DB), `OnEnable` (the login sequence), event handlers, `OnProfileChanged`. |
| `defaults/Profile.lua` | Six flat globals (`enabled`/`visibility`/`scale`/`alpha`/`locked`/`throttleWindow` — the first four are options-ui-§15's Master controls set; there is no `hidden` master toggle) + `NS.defaults.profile.units.{player,target,focus}` (each unit's own appearance table, built by a factory so no table is shared across units) + `NS.defaults.global.schemaVersion = 1` (the current schema is **5** — v3 introduced `profile.units`, v4 dropped the dead `hidden` toggle, v5 mapped `showOnlyInCombat` onto `visibility` — but the DEFAULT is the pre-ladder `1`, exactly like the per-profile stamp, because AceDB's `copyDefaults` fills it before `RunMigrations` reads it and a default of `5` would stamp every freshly-materialized global as already-migrated); `NS.flatDefaults` alias, `NS.unitDefaults` (= `defaults.profile.units.player`, the canonical per-row default source for `settings/Appearance.lua`). |
| `locales/enUS.lua` | `NS.L` metatable-fallback locale (English source keys; nothing wrapped yet). |
| `modules/Bar.lua` | `NS.CreateBar(unit, globalName)` builds one bar frame; `NS.bars` (keyed `player`/`target`/`focus`, frames `AbsorbTrackerFrame`/`AbsorbTrackerTargetFrame`/`AbsorbTrackerFocusFrame`) at file load, plus `NS.bar`/`statusBar`/`valueText`/`backdropInfo` as player aliases for pre-multi-unit call sites. Each bar owns its own `backdropInfo` table (border size differs per unit; `SetBackdrop` keys off table identity) and a `unitLabel` FontString above the frame naming its unit, shown only while unlocked. |
| `modules/Display.lua` | Every function takes a `unit` (defaulting to `"player"`): `RestoreBarPosition`, `UpdateBarAppearance`, `ShouldShowBar`/`ApplyVisibility` (the four-step visibility ladder), `UpdateAbsorbBar` (the paint path). `NS.ForEachUnit(fn)` and `NS.DefaultPosition(unit)` (stacks target/focus above the player bar) also live here. Subscribes to `APPEARANCE`/`VISIBILITY`/`POSITION` on its own `NS.Display.__ev` bus target, fanning each handler out over `NS.ForEachUnit` so the bus messages stay payload-free. |
| `modules/Timer.lua` | Coalescing repaint scheduler (`NS.RequestRepaint`) — a trailing-edge one-shot AceTimer throttle. |
| `settings/Schema.lua` | The schema registry + read/write seam (`SetByPath`), value formatting, and `ValidateSchema`. `NS.FormatSchemaValue` is a thin delegate to `LibKa0s-Slash-1.0`'s `lib.FormatValue`, so the `/at get` echo and the `[Set]` debug line cannot disagree about how a color or an empty string reads; the type-aware parser is the library's `lib.ParseValue` (`NS.ParseSchemaValue` and the private `parseBool`/`parseNumber`/`parseString`/`parseColor` helpers are gone). Rows carry `unit`, `alwaysPerUnit`, and `skipRender` fields; `SchemaForPage(page, unit)` filters to one unit's rows (or all, when `unit` is omitted); `ResolvePath`/`SetPath` walk dotted paths (`units.<unit>.<key>`) so flat globals and per-unit keys share one seam. |
| `settings/Slash.lua` | AceConsole registration, the ordered `NS.COMMANDS` verb table (19 verbs), and the host verbs that reach into this addon's own state (`enable`/`disable`/`lock`/`unlock`/`toggle`/`update`/`test`/`profile`/`debug`/`perf`/`resetall`/`resetposition`) plus the mirror note. The dispatcher itself, the help renderer, the row and key/value formatters, the value renderer, the `/at list` builder and the type-aware value parser are `LibKa0s-Slash-1.0` (vendored, `libs/LibKa0s/Slash.lua`); this file builds the CLI with `SlashLib:New{...}` and passes `NS.COMMANDS` in. Degrades to a stub that keeps the host verbs working — and names the missing library on each schema verb — when the library is absent. |
| `settings/OptionsSetup.lua` | Wires the addon into `LibKa0s-Options-1.0` — the canvas shell, the schema-row → AceGUI translation, the schema composers, the two-column flow engine and the always-visible scrollbar patch are vendored library code (`libs/LibKa0s/{Options,OptionsWidgets,OptionsCompose,OptionsScroll}.lua`), not addon code. It replaces four files that used to be this addon's own toolkit (`Panel.lua`, `Helpers.lua`, `ScrollPatch.lua`, `Widgets.lua`). Holds the brand string as a **file-scope local** (`PARENT_TITLE`), handed to the library as `descriptor.parentTitle` rather than published on the namespace — the two files that used to read it off `NS` are inside the library now. Then assigns `NS.Helpers = lib:New(descriptor)` — the library instance **itself**, not a decorated copy, so every existing `NS.Helpers.*` call site keeps working — plus thin `NS.RegisterOptionsPage` / `NS.CreateOptionsPanel` / `NS.OpenOptionsPanel` / `NS.RefreshOptionsPanel`. What this file supplies is the part that is ours: `get`/`set` (through `NS.GetSetting`/`NS.SetByPath`, so a panel change takes exactly the path `/at set` takes), `applyDefault`, `allRows`, `rowsForPage`, `skipRestoreAll` (excludes the Profiles page — its rows are AceDBOptions-supplied and resetting them is data loss — and every profile-backed row), `resetProfile` (→ `db:ResetProfile()`, because Reset All Settings **is** a profile reset per options-ui-§12), `scheduleTimer`, `getLSM`, `validate`, `onAceGUI`, `buildMain`, `colorDecode`/`colorEncode`, `print` and `debug`. Its stub is **load-completing, not member-answering** — the one setup file that breaks the addon's honest-line-per-member pattern, because `settings/Appearance.lua` calls `NS.Helpers.LSMValues` inside schema-row literals at *file load* and a nil there would abort the file, taking most of `NS.Schema` with it. |
| `settings/UnitPanel.lua` | The two pieces of the old toolkit that did not generalize. **Decorates** `NS.Helpers` — which *is* the library instance — rather than sitting beside it, so page files call `H.RenderUnitPanel` and `H.RenderSchema` interchangeably. `Helpers.RenderUnitPanel(ctx, pageKey)` draws the page's ONE **chrome block** (`PageHeader`, in the chrome band: the Unit picker — the panel's one and only — plus, for target and focus, the "Use same styling as Player" checkbox beside the "Copy styling from Player" button) and then the **tab strip** (`TabStrip`, one tab per `group`, drawn for every unit including a mirrored one, whose rows are replaced by a one-line hint), as a full rebuild via the library's `ClearScroll` + `RenderGrid` + `RenderRows`. The two mirror controls govern every tab, so options-ui-§14 puts them in the band above the strip and not in the scroll below it, and a page draws at most one block — so the picker goes inside `PageHeader`'s frame and `PageBanner` is never called. `PageHeader` pcalls the builder, so a raise inside the block costs the block rather than the strip and the rows under it; the block's AceGUI widgets are recorded on `ctx.__chromeWidgets` and released back to the pool after the following render. There is a re-entrancy guard and a two-tier refresher: always re-sync the mirror checkbox in place, re-render only when mirror state actually changed (an unconditional re-render would `ClearScroll` the very widget whose `OnValueChanged` is still on the stack). `Helpers.ResetAllPositions()` is the single reset-position implementation, shared by `/at resetposition` and the General page's Reset Position button (Reset All Settings is a profile reset now, and the saved positions come back with the profile, so it is no longer on that path). Loads after `settings/OptionsSetup.lua` (it takes `local Helpers = NS.Helpers` at load). |
| `settings/About.lua` | The parent page (logo + Notes + slash-command list), declared as a spec and drawn by the library's `BuildLandingPage`. |
| `settings/{General,Appearance,Profiles}.lua` | The three sub-pages; each registers schema rows + a deferred page builder — except Profiles, which registers no rows and renders AceDBOptions directly. Appearance generates its rows once per unit in `NS.Units.LIST` (path prefixed `units.<unit>.`, tagged `unit = unit`) and defers its page render to `Helpers.RenderUnitPanel` instead of `Helpers.RenderTabbedSchema` — the two reach the same `NS.Helpers` table from opposite sides, one addon code (`settings/UnitPanel.lua`), the other library code (`libs/LibKa0s/OptionsWidgets.lua`); General has no Unit picker, but does carry the three `units.<unit>.enabled` toggles — the one place a per-unit path is edited outside that picker. Both pages draw their groups as a **tab strip** (options-ui-§13), so a `group` is a tab and no section headings are drawn. |

## Invariants

Rules the code depends on that reading one file will not reveal. The visual/taint ones live under
[Taint Notes](#taint-notes); these are the structural ones.

- **Color getters resolve at call time.** `NS.GetBarColor(unit)` / `GetBgColor(unit)` /
  `GetBorderColor(unit)` (`core/Data.lua`) re-read that unit's `useClassColor*` on every paint, so a
  class change, respec or profile switch needs no refresh wiring. **Do not cache a resolved color on
  a frame** — that is what re-introduces the wiring.
- **`core/Units.lua` is the only file that reads `db.profile.units` for appearance.** Every other
  file — `modules/Bar.lua`, `modules/Display.lua`, `core/Data.lua`, the settings pages — goes through
  `NS.Units.Get(unit, key)`, so mirror resolution ("does this unit read its own config or the
  player's?") lives in exactly one place. Do not add a second read site.
- **TOC metadata goes through `core/EnvSetup.lua`.** `NS.Meta(field)` and `NS.Version()` are the
  only metadata accessors; never call `GetAddOnMetadata` / `C_AddOns.GetAddOnMetadata` inline. The
  deprecated-global rung still exists — it is the seam's own fallback, for an install with no
  LibKa0s — and that file is the only place it may be spelled.
- **Every LibKa0s seam publishes the same `NS` names whether the library loaded or not.** The nine
  seams listed under [Module Map](#module-map) each answer with the library's instance or with a
  degradation stub under one name, and the rest of the addon codes against that symmetry rather than
  checking for the library. `settings/OptionsSetup.lua`'s stub is the one deliberate exception to
  the honest-line-per-member pattern — it is **load-completing, not member-answering**, and
  [settings-panel.md](./settings-panel.md) says why; `loadDegraded()` in `tests/test_perf.lua` loads
  the whole TOC without the library and asserts `#NS.Schema` still matches. Do not weaken it.

## Settings Schema

`NS.Schema` is a flat array of **70 rows**; each `settings/<page>.lua` calls
`NS.RegisterSchemaRows({...})` at file-load time. The same array drives both the AceGUI panel widgets
(via `NS.Helpers.RenderTabbedSchema` / `RenderRows` / `RenderField`, all supplied by
`LibKa0s-Options-1.0` and fed the rows through the descriptor's `rowsForPage`) and the
`/at list|get|set|reset|resetall` CLI — adding an option is one schema row.

Exactly **eight** of the 70 carry an absolute, unit-agnostic path — the six flat globals (`enabled`,
`visibility`, `scale`, `alpha`, `locked`, `throttleWindow`) plus the session-only
`state.debugConsole` and the global-store `global.minimap.hide`, all on the General page. The other **62 are unit-relative**
(`units.<unit>.<key>`): the three `units.<unit>.enabled` toggles, also on General, plus the
Appearance page's 59, generated as **nineteen appearance keys × three units** with a `mirror` row
for target and focus. So General holds eleven rows (eight absolute, three unit-relative) and
Appearance the remaining 59.

Sixteen of the nineteen per-unit keys and seven of the eight unit-agnostic rows (all but
`throttleWindow`) are **composed**, not typed out:
`H.MasterControls`, `H.BarGroup`, `H.BorderGroup`, `H.FontGroup` and `H.ColorPair`
(`LibKa0s-Options-1.0`'s `OptionsCompose`) emit the canonical blocks options-ui-§15/§16/§17 mandate
from one declaration each. The host passes `keys` and `defaults` so **nothing stored moved** — the
composer changes what is *declared*, never what is *persisted*.

**A row's `group` is a TAB.** Both schema-bearing pages draw their sections as a tab strip
(options-ui-§13), partitioned by `group` **in declaration order**, so the array *is* the strip and a
group's rows must stay contiguous. General is `[ Master controls | Bars ]` (7 / 4 rows); Appearance
is `[ Size | Bar | Background | Border | Text ]` (2 / 4 / 3 / 4 / 6 rows, per unit) under a chrome block
(options-ui-§14) carrying the panel's only unit picker and the page-wide mirror controls. `tests/test_schema.lua` asserts that
page → tab → count partition. Every write to a schema-row path funnels through the single seam
**`NS.SetByPath`** (`SetSetting`, the `[Set]` debug line, then `fireOnChange`), whose `onChange`
defaults to `UpdateBarAppearance`. The panel widgets and `/at set` call it directly; a reset to a
row's default (`/at reset`, a page's Defaults button, and the `sessionOnly` rows `/at resetall`
touches before its profile reset) reaches it through `NS.ApplyDefault`, which only builds the
copied default. A **bulk copy or reset** is one `[Set] <act> <scope>: N rows` line
(debug-logging-§10): the seam keeps a bracket depth (`NS.Bulk`, `settings/Schema.lua`), and inside
a bracket it mutes its per-row line and tallies the writes that changed a stored value. The
library brackets a page's Defaults and Reset All through the Options descriptor's
`bulkBegin`/`bulkEnd` (LibKa0s-Options-1.0 minor 16). `NS.Bulk.Run` brackets the two host acts,
`Units.CopyFromPlayer` and the degraded Reset All. N counts rows actually written, so a Defaults
press on a page already at its defaults logs `0 rows`. A nested bracket is one act, logged once at
depth 0, and an act that reset the whole profile logs no bulk line: the profile-event handler logs
it (see Message Bus below). An act that ends with an error (`bulkEnd` handed an `err`, or
`NS.Bulk.Run` catching one) still logs its one line, with ` (stopped by an error)` appended; the
mute is released and the error re-raised. `/at resetall` does not reach `LibKa0s-Slash-1.0`'s `CliResetAll`, so
the Slash descriptor carries no bracket. **This addon holds no structural registry** in architecture-§5's sense: the tracked units
are the fixed `Units.LIST` (`player`, `target`, `focus`, `core/Units.lua:16`), which the player
cannot add to or remove from, and `units.<unit>.*` is a fixed-key map the schema rows address
directly. So there is no registry writer and no registry load pass to name here. The seeding of
`units[unit]` in `core/Database.lua` (`MigrateProfileToV3`, `backfillUnitKeys`) is savedvariables-§1
default-shape repair over that fixed list, not registry membership. Boot-time
`NS.ValidateSchema` checks each row's shape (`page`/`type` enums, non-empty `path`) **and** that
every `path` resolves against `NS.defaults.profile` (a `global.` path resolves against `NS.defaults.global` instead — the minimap button's row is the only one, launcher-§3); it returns `(errors, resolved, missing)` for
the test harness to assert (`sessionOnly` rows are exempt from the path check — their value is
deliberately not in the profile). Row grammar detail: [schema.md](./schema.md).

**Named non-setting state: `units.<unit>.position`** (architecture-§5). Each bar's saved anchor,
`db.profile.units.<unit>.position = { point, relPoint, x, y }`, is geometry only a drag
determines. No schema row addresses it and no control chooses it, so it is written outside
`NS.SetByPath` and needs no register row. Its **one owner is `core/Units.lua`**:
`Units.SetPosition(unit, pos)` is the only function that assigns the key (`Units.Position` reads
it, never mirror-resolved). Every writer, with the act that reaches it:

- **Drag-stop.** The bar's `OnDragStop` handler (`modules/Bar.lua`) saves the dragged frame's own
  anchor through `Units.SetPosition(self.unit, …)`.
- **Reset position.** `Helpers.ResetAllPositions` (`settings/UnitPanel.lua`) clears every unit's
  position through `Units.SetPosition(unit, nil)`, then publishes `POSITION`. Two acts reach it:
  `/at resetposition` (`settings/Slash.lua`) and the General page's **Reset Position** button
  (`onResetPosition`, `settings/General.lua`). The button puts back the shipped default (no saved
  anchor, so each bar re-stacks at `NS.DefaultPosition`) and chooses nothing, so it does not make
  the position a preference.

Nothing else writes it at runtime. Reset All Settings (`/at resetall`, the descriptor's
`resetProfile` and the degraded-path `Helpers.RestoreAllDefaults`) is the options-ui-§12 profile
reset: `db:ResetProfile()` replaces the profile whole, positions with it. The `afterRestoreAll`
hook that once called `ResetAllPositions` is gone. AceDB's profile swap and copy replace it the same
way. The v3 lift (`NS.MigrateProfileToV3`, `core/Database.lua`) moves a pre-v3 flat
`profile.position` onto `units.player.position`; that is the load pass. `Units.CopyFromPlayer`
deliberately does not copy it. The `[Set]` log does not trace it (debug-logging-§10).

**Named non-setting state: `AbsorbTrackerPerfDB`** (architecture-§5, recorded data written by a
vendored library). The perf capture ring is the second SavedVariables global, `{ schema, runs }`,
which savedvariables-§4 sanctions and keeps outside the AceDB tree. Each record is a capture the
library measured, so the player authors no entry's value. Its **one owner is
`core/PerfSetup.lua`**: its descriptor hands `LibKa0s-Perf-1.0` the global's name (`sv`) and sets no
`ring`, so the library default applies. Nothing in this addon's own code writes it. The one writer
is the library's `P.Save` (`libs/LibKa0s/Perf.lua`). One act reaches it: `/at perf finish`
(`SUBS.finish`). That call does three things in one pass:

- appends the run;
- trims the oldest records past the ring's size, which is the retention prune, and logs one line
  when it trims;
- discards a ring stored under an older record schema, and logs one line when it drops records.

Both drops are logged, each once per save as a single summary line, never one line per record
(debug-logging-§8/§9). The trim has been traced since `LibKa0s-Perf-1.0` minor 11.

`/at perf cancel` saves nothing. AceDB's profile reset, swap and copy never reach this global.

## Message Bus

Cross-module communication runs through a closed, named message bus (`core/Bus.lua`,
architecture-§4), not direct `NS.X` calls. Producers — the event layer (`core/AbsorbTracker.lua`),
the slash surface (`settings/Slash.lua`), the settings pages (`settings/{General,Schema}.lua`) and
the reset helper `Helpers.ResetAllPositions` (`settings/UnitPanel.lua`) — publish via
`NS.bus:SendMessage(...)`. Each consumer
subscribes on its **own** target from `NS.NewBusTarget()` (never two receivers on one shared object;
CallbackHandler keys callbacks by `(message, target)`, so a shared target would silently overwrite —
anti-pattern #32). All messages are payload-free: the consumer re-reads live state (settings,
absorbs) when it fires.

| Message (`NS.MSG`) | Sender | Consumer | Effect |
|---|---|---|---|
| `Ka0s_AbsorbTracker_RepaintRequested` (`REPAINT`) | event / slash / lifecycle layer | `modules/Timer.lua` (`NS.Timer.__ev`) | Coalesced repaint via `NS.RequestRepaint` → `NS.UpdateAbsorbBar` |
| `Ka0s_AbsorbTracker_AppearanceChanged` (`APPEARANCE`) | settings / lifecycle layer | `modules/Display.lua` (`NS.Display.__ev`) | `NS.UpdateBarAppearance` (size / texture / colors / border / font) |
| `Ka0s_AbsorbTracker_VisibilityChanged` (`VISIBILITY`) | event / settings layer | `modules/Display.lua` (`NS.Display.__ev`) | `NS.ApplyVisibility` (the show/hide gate) |
| `Ka0s_AbsorbTracker_PositionChanged` (`POSITION`) | slash / lifecycle / reset layer | `modules/Display.lua` (`NS.Display.__ev`) | `NS.RestoreBarPosition` (restore from profile) |
| `Ka0s_AbsorbTracker_UnitsChanged` (`UNITS`) | settings / slash / profile layer, whenever a per-unit `enabled` flag changes | `core/AbsorbTracker.lua` (`NS.Events.__ev`) | `addon:SyncUnitEventFrames` — registers the absorb / max-health / swap events only for enabled units. Deliberately distinct from `VISIBILITY`, which also fires on combat and target-swap transitions and must not churn registrations |

The perf run panel is **not** on this bus. `LibKa0s-Perf-1.0` repaints its own panel directly off the
instance's state (`RefreshPanel`, called at the end of every phase transition inside the lib) rather
than publishing a message this addon's bus would have to carry — the panel and the state it renders
both live inside the vendored library. See [Performance & Profiler Attribution](#performance--profiler-attribution) below.

Each Display handler fans out over `NS.ForEachUnit`, repainting/re-appearancing/re-positioning all
three bars per message — this is what keeps the bus messages payload-free (no "which unit" to
carry).

Each message has exactly one sender concept and one consuming module. The display functions
(`NS.UpdateBarAppearance` / `NS.ApplyVisibility` / `NS.RestoreBarPosition` / `NS.UpdateAbsorbBar`)
and `NS.RequestRepaint` remain defined on `NS` — they are the consumer-side implementations the bus
handlers call, and stay directly unit-testable. Within the display concern, `Timer`'s coalescer
calls `NS.UpdateAbsorbBar` directly (intra-concern), as does `NS.UpdateBarAppearance` calling
`NS.ApplyVisibility`; the debug-counter hook `NS.NoteRepaint` (`modules/Timer.lua`'s pass → `core/AbsorbTracker.lua`
combat rollup) is likewise a direct intra-implementation call, not a bus notification. The bus mock
in `tests/wow_mock.lua` models real `(message, target)` dispatch so `tests/test_bus.lua` asserts
two receivers of one message both fire (anti-pattern #33).

Other cross-cutting refresh stays as explicit calls: `Helpers.RefreshAllPanels` (after `/at set` or
a profile change) is the STRUCTURAL tier: every settings page declares its body through
`Helpers.SetRenderer`, so a page on screen re-renders and a hidden one is flagged dirty for its
next `OnShow`. A panel widget's own write takes `Helpers.RefreshScalars` instead, which walks
`ctx.refreshers` in place. Both implementations are the library's. The other callback bus is **AceDB**:
`NS:InitDB` registers one handler per event: `NS.OnProfileChanged`, `NS.OnProfileCopied` and
`NS.OnProfileReset` (`core/AbsorbTracker.lua`). All three share one body: they lift the profile,
republish `UNITS` / `POSITION` / `APPEARANCE` / `REPAINT` on the bus and refresh an open panel.
They differ only in their one debug line, worded by the event (debug-logging-§10):
`[Profile] changed → <name>` for a switch, `[Set] copied profile '<source>' → '<name>'` for a copy,
and `[Set] reset profile '<name>' to defaults (N rows)` for a reset. For a reset, N is the rows
the reset changed, never the schema size: every reset the addon drives goes through
`NS.ResetProfileCounted` (`settings/Schema.lua`), which counts the rows off their default just
before `db:ResetProfile()` and leaves the number for the handler to take once
(`NS.ConsumeResetCount`). The number is cleared when the reset returns or raises, so it cannot
leak into a later reset. A reset the addon did not drive (AceDBOptions' button, a `/run`) has no
count, and its line omits `(N rows)`. That reset line is the only line Reset All logs.

## Slash Commands

Registered via AceConsole in `settings/Slash.lua`: `/at` and the alias `/absorbtracker` both dispatch
to `Sl:OnSlash`, which hands the line straight to `LibKa0s-Slash-1.0`. The library lowercases only
the verb — preserving case in the remainder, so schema paths and profile names survive — and looks it
up in the ordered `NS.COMMANDS` table this addon passed in. Nineteen verbs, of which `profile`
carries a sub-verb table of its own (`PROFILE_VERBS`, dispatched at `settings/Slash.lua:506`) and
`perf`, `debug` and `toggle` each parse a token. A bare `/at`, empty or whitespace-only, runs the
`config` verb and opens the settings panel on its landing page; `/at help` prints the command list
(slash-commands-§4).

**Schema paths are fully qualified.** `/at set units.target.barWidth 250` works; the pre-1.9
unqualified `/at set barWidth 250` is rejected, because `FindSchemaRow` has no bare-key row for a
per-unit setting. Only the eight unit-agnostic rows — `enabled`, `visibility`, `scale`, `alpha`,
`locked`, `throttleWindow`, the session-only `state.debugConsole` and the global-store
`global.minimap.hide` — take a bare path.

**`/at enable` and `/at disable` are ALIASES, not a second switch** (slash-commands-§2). Both write
the `enabled` path the Master controls tab's Enable checkbox writes, through the same `NS.SetByPath`
seam, and hold no state of their own. The dispatcher survives the disabled state — it is **setup,
not a feature** — which is what keeps the pair from being one-way. What the write actually does is
in [The disabled state is total](#the-disabled-state-is-total) below.

**A disabled addon refuses a FEATURE verb, on one tagged line naming `/at enable`** (slash-commands-§2,
a SHOULD this addon takes). The gate is **`LibKa0s-Slash-1.0`'s** since the v1.42.0 re-vendor (Slash minor 14):
`settings/Slash.lua` passes `isEnabled`, `brandName` and a `liveVerbs` array built from
`SlashLib.LIVE_VERBS`, and the dispatcher applies it. Live are `help`, `config`, `version`,
`enable`, `disable`, `debug`, `perf` and the schema CLI (`get`, `set`, `list`, `reset`, `resetall`)
— the standard's own twelve, because a player must be able to read and repair settings and reach
the panel while the addon is off — plus `resetposition` and `profile`, which are this addon's
reading and are argued in [slash-dispatch.md](./slash-dispatch.md). The **bare `/at` opens the
settings panel**, which is the case that reversed the standard's brief v2.56.0 narrowing. Refusing
are `lock`, `unlock`, `toggle`, `update` and `test`. The refusal line is the **collection's** one
wording (`lib.DISABLED_LINE_FORMAT`), published as `NS.Slash:DisabledLine()` and reused verbatim by
the launcher's refused left click; it is deliberately **not** routed through `NS.L`.

The verb table, the sub-verb trees, the mirror note, the help convention and the degraded arm are in
[slash-dispatch.md](./slash-dispatch.md).

## Launcher

`core/LauncherSetup.lua` owns it, and there is **one object**: a single LibDataBroker-1.1 table of
`type = "launcher"`, named for the addon's **folder** (`AbsorbTracker`, from the file's first
vararg), handed to LibDBIcon-1.0 under that same name — LibDBIcon keys the button's saved position
by it, so the spelling is not cosmetic. LibDBIcon draws the minimap button from that table and any
broker display draws its own row from it, so there is one `OnClick`, one icon and one identity
(launcher-§1). Its **`label` is `Ka0s Absorb Tracker`** — the brand name in plain text, because a
broker row is printed beside the other ten Ka0s addons and that one string is what decides whether
they read as one collection. It is `NS.Constants.BRAND`, the **one** plain-text brand constant —
the same string `settings/Slash.lua` hands the dispatcher as `brandName`, because slash-commands-§7
makes the disabled refusal line carry exactly this spelling and two literals would be two brand
names. Deliberately **not** wired to the TOC's `## Title` (which may carry color escapes) and not
the folder name (which is `name`). Both libraries are
vendored under `libs/` and resolved with `LibStub(..., true)` at `Register()` time; a host missing
either gets an honest report rather than a raise.

**The rung is (b)** (launcher-§2, and the standard's `ADDONS.md` records it): left-click toggles the
addon's preview switch, which here is the **lock** — options-ui-§15 exempts an addon whose unlocked
view already is its preview, and this one took that exemption. The click writes through
`NS.SetByPath`, the same seam the Lock frame checkbox and `/at lock` / `/at unlock` write through,
so the in-combat unlock refusal, the preview clear and the repaint all come from the row's own
`onChange` rather than being reimplemented. **Right-click always opens the settings panel.**

**While the addon is disabled the left click is refused** (launcher-§2, slash-commands-§7). Rung (b)
drives a preview switch, which is a feature, so the click prints `NS.Slash:DisabledLine()` — the
dispatcher's own line, not a second spelling — and does **nothing else**; in particular it reaches
no write seam, which is the audit finding it fixes: an ungated minimap button writes the stored tree
of an addon the player switched off, and a mouse click is a game event in every sense that matters.
The gate sits **before** the write, because `NS.SetByPath` would fire the `locked` `onChange` and
land in SavedVariables whatever the click printed. **Right-click is unchanged in either state** —
the panel is setup rather than a feature, so the right button opens it for the same reason `config` and the bare `/at` still do — and the button
itself stays on the minimap, because `minimap.hide` is a per-installation display preference that
says nothing about whether the addon is running. `tests/test_disabled.lua` step 8 pins all three.

**Visibility is one row and one boolean.** `Minimap button` on Master controls stores LibDBIcon's
own `hide` key at `db.global.minimap.hide` — **global**, so a profile switch does not move the
player's buttons. The row says *shown* and the key says *hidden*, so `NS.GetSetting` /
`NS.SetSetting` invert it (`core/Data.lua`, beside the session-settings branch it most resembles);
the set also calls `NS.Launcher:SetShown`, so the button follows the checkbox immediately. The
**The row survives every reset, as a property of the setting** (launcher-§3): a minimap button's
visibility is a per-installation display preference, like the angle LibDBIcon keeps beside it in the
same table. *Reset all settings* never reached it — it is a profile reset and the value is global —
but the **General page's Defaults button did**, because `LibKa0s-Options-1.0`'s `RestoreDefaults`
walks every row on the page and consults no veto. The exemption is one predicate,
`survivesEveryReset` (`settings/OptionsSetup.lua`), applied at the descriptor's `applyDefault`,
which is the one seam both library resets write through. `/at reset global.minimap.hide` is
deliberately outside it: that verb goes through the Slash descriptor, and naming the row is asking
for it. Detail in [settings-panel.md](./settings-panel.md).

The **icon** is `media/logos/absorbtracker.logo.128.tga`, the same file `## IconTexture` names
(launcher-§4) — 128×128, uncompressed 32-bit, regenerated from the `.png` beside it by layout-§4's
recipe. `tests/test_launcher.lua` reads its header bytes, because a wrong format there draws nothing
and raises nothing.

## The disabled state is total

`slash-commands-§7`. **Disabled means the addon is not running** — not hidden, not quiet, not
skipping a repaint. A player who unticks *Enable Absorb Tracker* has asked for the same outcome they
would get by unticking the addon in Blizzard's own AddOns list, minus the `/reload`.

**This addon used to implement a draw gate**, and the entry that described it was accurate: `enabled`
was one rung of `NS.ShouldShowBar`'s ladder and nothing else, so the bars went away and every
registration stayed live. That is the shape `anti-pattern #85` names. An early-returning handler did
not stop watching — it stopped reacting, and the client went on walking the registration list on
every `UNIT_ABSORB_AMOUNT_CHANGED` in a raid, building the argument frame and entering Lua to run
the comparison that decided to leave.

### One latch, two named holds

`core/Lifecycle.lua` owns a single `LibKa0s-Lifecycle-1.0` instance, `NS.lifecycle`:

| Hold | Taken by | Lifetime |
|---|---|---|
| `disabled` | the stored `enabled` path, through `NS.SyncEnabledHold()` | **persisted** — surviving a `/reload` is the entire point of the setting |
| `perf` | `LibKa0s-Perf-1.0`'s Experiment B, which takes and releases it itself | **session-only**, never written to SavedVariables |

The addon is stood down whenever **at least one** hold is taken and stood up only when the **last**
one is released. There is no `:StandUp()` member to call, and its absence is the feature: a resume
that stood the addon up would resurrect one the player disabled mid-capture, and a disable that did
the same would end a run that was still recording. Both go through release-and-re-evaluate.

`NS.SyncEnabledHold()` is the one line every surface reaches — the Master controls checkbox and
`/at enable` / `/at disable` / `/at set enabled` through the `enabled` row's `onChange`, a Defaults
press through the same row, and AceDB's `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset`
through `adoptProfile`, which re-reads the store and calls `:Reevaluate()` because a profile switch
can flip the path with nothing else being touched.

**There is no second teardown path.** `core/PerfSetup.lua` no longer carries `suspend` / `resume`:
those bodies **are** `NS.StandDown` / `NS.StandUp`, and the perf descriptor passes the latch
instead. Two mechanisms that both mean "be inert" diverge on the first module added after the second
one was written.

### What stands down

- **Every AceEvent registration on the addon object** — `PLAYER_ENTERING_WORLD`, the combat pair,
  and the two swap events — actually `UnregisterEvent`ed.
- **All three per-unit `RegisterUnitEvent` frames**, `UnregisterAllEvents`'d.
- **Every bus subscription.** A `RegisterMessage` is a registration like any other. The subscribing
  modules hold their targets as file-locals, so `core/Bus.lua` keeps a register — `NS.BusSubscribe`
  records the triple and `NS.BusUnsubscribeAll` / `NS.BusResubscribeAll` drive it — and no module
  learns that the latch exists.
- **Every timer**: the coalescing repaint (`NS.CancelPendingRepaint`) and the `/at test` preview
  hold (`NS.ClearPreview`).
- **The bars, at the source.** `StandDown` publishes `VISIBILITY` *before* it takes the bus down, and
  `NS.ShouldShowBar`'s rung 0 asks `NS.IsStoodDown()` — the latch, never the stored `enabled` — so it
  already answers no, so nothing — a combat transition, a target swap, a settings
  change — can re-show a bar behind the switch's back.
- **No SavedVariables write from a game event.** The finding this fixes: entering combat while
  disabled used to write `locked = true` and print `Bars locked — combat started`. `OnEnterCombat`
  is **unchanged**; what changed is that `PLAYER_REGEN_DISABLED` is no longer registered, so the
  client never calls it. That is the difference between standing down and gating.

**No secure work is held pending**, and that is a statement about this addon rather than an omission.
§7 requires `UnregisterStateDriver` / `UnregisterAttributeDriver` / a secure-attribute rewrite to
wait for `PLAYER_REGEN_ENABLED`; this addon owns no secure frame, no state driver and no attribute
driver — the bars are plain `CreateFrame("Frame", …, "BackdropTemplate")` — so the whole stand-down
is combat-safe and completes in the same turn as the write. The day a secure element arrives here it
holds its half pending, and `core/Lifecycle.lua` carries that note.

### What survives, because it is setup

The chat command registration, the dispatcher and `NS.COMMANDS`; the settings-category registration
and the panel body (`CreateOptionsPanel` is deliberately outside `OnEnable`'s latch gate); the AceDB
handle, the single write seam and the three profile callbacks; and the launcher's registration. The
addon is inert; its command surface is not the addon.

### Standing up rebuilds from current state

Never from a snapshot taken on the way down. `StandUp` re-subscribes the bus, calls
`RegisterLifecycleEvents` and `SyncUnitEventFrames` — which read the enabled set **as it is now** —
and publishes `POSITION` → `VISIBILITY` → `APPEARANCE` → `REPAINT`. `POSITION` is there and is not
symmetric with `StandDown` for a reason: a login that came up disabled never applied the stored
anchors, so a later enable has to place the bars before it shows them.

`tests/test_disabled.lua` is the conformance suite §7 requires, and it asserts on the **registration
set** through the kit's recording mocks — never on a handler's return value, because a suite written
against an early return certifies the draw gate it exists to catch.

## Event Subscriptions

AceAddon lifecycle in `core/AbsorbTracker.lua`:

- **`OnInitialize`** (ADDON_LOADED): register the monospace font with LSM, `NS:InitDB()`
  (AceDB + `RunMigrations` + profile callbacks), `NS.Slash:Register()`.
- **`OnEnable`** (PLAYER_LOGIN timing): `ClearLSMCache` → `GetLSM` → **`NS.SyncEnabledHold()`** →
  and then, **only while the latch is up**, publish `POSITION` → `APPEARANCE` → `REPAINT` on the bus
  and register the events. `CreateOptionsPanel` is outside that gate, because the settings
  registration is setup rather than a feature. The three publishes reach `RestoreBarPosition` /
  `UpdateBarAppearance` (Display) and `RequestRepaint` (Timer); the login paint therefore lands one
  `throttleWindow` later, not synchronously. **An addon that comes up disabled registers nothing at
  all** — it does not register five events and three unit frames only to tear them down in the same
  turn.
- **One private unit-event frame per unit** (`addon:SyncUnitEventFrames()`) for the `UNIT_*` events:
  `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` fire for *every* unit the client knows about
  (all raid members, pets, nameplates, target/focus), and AceEvent-3.0 routes all events through
  one shared frame with plain `RegisterEvent` and cannot `RegisterUnitEvent` — so an AceEvent
  registration would pay a full C→Lua dispatch for every unit only to discard all but ours. A
  private `CreateFrame("Frame")` with `RegisterUnitEvent` moves that filter to the C layer instead
  — a documented events-frames-taint-§1 deviation (see below). One frame per unit rather than packing tokens two at a
  time (`RegisterUnitEvent`'s cap): each unit's registration can then be added or dropped on its own
  as its bar is enabled or disabled, with no repacking. **A disabled bar is registered for nothing
  at all**, and its `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` watch is dropped too — that
  pair is where the saving actually lands, since the absorb events were already C-filtered. The
  registrations re-sync off the `UNITS` bus message. Each frame registers both events for its own
  unit token, and all of them share one `OnEvent` stub that routes to `addon:OnAbsorbChanged` /
  `addon:OnMaxHealthChanged` (bumping a debug-gated event counter and logging a non-secret
  `[Absorb]` shield up/gone transition, player only, when the value is concat-safe, then
  `NS.RequestRepaint()`). The frames are built once and reused; only their registrations change as
  bars are enabled and disabled. (Before per-unit gating this was two frames — `"player", "target"`
  on one and `"focus"` on the other — packed against `RegisterUnitEvent`'s two-token cap.)
- **AceEvent** subscriptions (registered in `OnEnable`): `PLAYER_ENTERING_WORLD` (`OnEnterWorld` →
  publishes `VisibilityChanged` + `RepaintRequested`), the combat-state pair
  `PLAYER_REGEN_DISABLED` (`OnEnterCombat`) / `PLAYER_REGEN_ENABLED` (`OnLeaveCombat`) — each
  publishes `VisibilityChanged` (the `visibility` gate) and `RepaintRequested` — except that
  `OnEnterCombat` **re-locks** the bars first if they are unlocked (preview-mode), and then
  publishes neither, because the `locked` onChange already publishes `AppearanceChanged` (which
  re-runs the ladder) and `RepaintRequested`. These three
  are global, payload-free events with no unit to filter, so they stay on AceEvent unconditionally.

  `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` (both → `OnUnitSwap`, which publishes
  `VisibilityChanged` then `RepaintRequested`: a swap changes both which bars should be visible, via
  the `UnitExists` step of the ladder, and what they should read) are also AceEvent, but are
  **registered and unregistered by `SyncUnitEventFrames` alongside the per-unit frames** — they are
  only subscribed while that unit's bar is enabled. This is where the gating actually pays: both
  fire on every target/focus change in ordinary play, whereas the `UNIT_*` events were already
  C-filtered to the tokens we asked for.
  `OnLeaveCombat` is the sole handler of `PLAYER_REGEN_ENABLED` and does visibility + repaint only
  — it has no combat-deferred `/at config` to replay (the panel refuses to open in combat,
  options-ui-§2; see Taint Notes). The event handlers do not call the display module directly —
  they publish on the message bus (see Message Bus); `modules/Timer.lua`'s `NS.RequestRepaint`
  consumer coalesces `RepaintRequested` into a one-shot AceTimer throttle (`throttleWindow`,
  default 0.1s) — idle = zero repaints, no polling ticker. The `[Combat] left: N events` debug
  rollup counts **player** events only, deliberately, so the printed count matches what it reports.

## Taint Notes

- **Combat-lockdown gate on `/at config` (refuse, options-ui-§2).** `Settings.OpenToCategory` is
  protected; calling it in combat taints the panel for the session. When `InCombatLockdown()` is
  true, `NS.OpenOptionsPanel` **refuses** — the wrapper is `settings/OptionsSetup.lua`'s, the check
  and the notice are `libs/LibKa0s/Options.lua`'s (`lib.STRINGS.COMBAT_REFUSED`), printed through the
  descriptor's `print` so the line still carries `[AT]` and logged through its `debug` under tag
  `"Cfg"`. One gray, `[AT]`-tagged notice (*"cannot open settings during combat — Blizzard's
  category-switch is protected"*), then a return, never touching the protected call. It does **not** defer-and-replay on
  `PLAYER_REGEN_ENABLED`; the user re-runs `/at config` after combat. The gate lives inside the
  open function, so every caller (slash verb, `/run`, internal) is refused.
- **Bar visibility Show/Hide is taint-free.** All three bar frames (`AbsorbTrackerFrame` /
  `AbsorbTrackerTargetFrame` / `AbsorbTrackerFocusFrame`) are plain (non-secure) frames, so
  `NS.ApplyVisibility` calling `bar:Show()` / `bar:Hide()` on combat or target/focus transitions
  carries no protected-frame restriction.
- **`SetBackdrop(nil)` before `SetBackdrop(info)`.** WoW's backdrop API is a no-op when the table
  identity is unchanged even if its fields changed; `UpdateBarAppearance` clears first.
- **Secret values.** `UnitGetTotalAbsorbs` may return a "secret" value — it is passed straight to
  `AbbreviateNumbers` / `StatusBar:SetValue`, never through `tonumber`.

## Known Limitations

- **Retail Midnight only** (Interface 120100); no game-flavor branching.
- **English only** — a ratified decision, not an unfinished job: the row lives in
  [Documented deviations](#documented-deviations) below (`localization-§1`), which is its single home.
  The `NS.L` seam is exported and `locales/enUS.lua` ships, carrying **no keys at all**. The one
  string this addon used to route was the disabled-verb refusal, and it left the addon at LibKa0s
  v1.42.0: `slash-commands-§7` makes that line the **collection's** wording, built by
  `LibKa0s-Slash-1.0` from one exported format string so four Ka0s addons cannot give a player four
  answers to the same question. `enUS.lua` carries no key nothing reads (`localization-§3`), so the
  key went with the call site. Everything else is hardcoded English.
- **Three bars — player, target, focus.** Group / raid / arena / boss units are out of scope
  ([scope.md](./scope.md)).

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`) — except this
file, the hub the map itself lives in. Frozen and generated directories are named once each and never enumerated per run: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/perf-analysis/`, `docs/investigations/`, `docs/revendor/`.

The repo **root** ships exactly three docs plus `LICENSE`, and never a fourth: the player-facing
`README.md`, the `CLAUDE.md` stub and `DEPENDENCIES.md` (the toolchain contract). Everything else
lives under `docs/`.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in v2.17.0 and shipping it is anti-pattern #49. It held the scaffolding pack
(`NEW_ADDON_CONTEXT.md`), which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, and because it loads as working context a stale copy is not
ignored, it is **followed** (documentation-§3). Root `CLAUDE.md` is the repo's only agent brief, and
it points here. Older audit bundles, review bundles and plans under `docs/` predate v2.17.0 and
still name the file, and some describe a four-file or a pre-v2.3.0 `agent-context.md`-based set.
They are frozen history: never treat them as a live requirement, and never "restore" the file.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the bar tracks, and the absorbs it deliberately leaves alone |
| `module-map.md` | Every non-vendored file, its responsibility, and load order |
| `schema.md` | The persisted shape, every default, and the migration seam |
| `settings-panel.md` | The panel tree, per-option behavior, and the write seam |
| `data-flow.md` | Aura event in → shield accounting → what the bar shows |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | Nineteen verbs, over the eight-or-more threshold, and `profile` carries a subcommand tree (`PROFILE_VERBS`) |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon’s own |
| `profiles.md` | Present | AceDB profiles are user-visible — the Profiles settings page |
| `message-bus.md` | Not applicable | Five messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message Bus` |
| `compat-layer.md` | Not applicable | There is no compat layer left: `core/Compat.lua` held one straight API normalization and it moved to `LibKa0s-Env-1.0`, reached through `core/EnvSetup.lua` |
| `debug.md` | Not applicable | The console is `LibKa0s-DebugLog-1.0`’s, with no debug surface of the addon’s own |
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |


## Documented deviations

Ratified departures from the Ka0s WoW Addon Standard, in the row shape `documentation-§3` fixes.
**This is the single home**: a decision may be reasoned at length in an audit bundle or in
this repo's GitHub issues, and the row cites it — but a deviation that is not in this table is not
ratified. The long-form argument for each row follows the table; a fresh `/wow-addon:standards-audit`
reads the register first and records a match as accepted rather than re-filing it.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `events-frames-taint-§1` | `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` are registered on a private `CreateFrame` **per tracked unit** via `RegisterUnitEvent`, not through AceEvent-3.0 | Both events fire for every unit the client knows about; AceEvent shares one frame and structurally cannot `RegisterUnitEvent`, so it would pay a full C→Lua dispatch per unit only to discard all but ours. One frame each rather than packing tokens, because `RegisterUnitEvent` filters **at most two** tokens per registration. Argument in full below; filed as `AT-31` in `docs/audits/2026-08-05/` | 2026-07-14 | A client build where `RegisterUnitEvent` accepts more than two unit tokens |
| `savedvariables-§1` | A **per-profile** `schemaVersion` stamp at `db.profile.schemaVersion`, alongside the account-wide stamp in `db.global` | The v3 lift — flat appearance keys onto `profile.units.<unit>` — is a per-profile mutation, and an account-wide flag structurally cannot gate one: a second pre-v3 profile would have its stored appearance stranded forever. Argument in full below | 2026-07-28 | AceDB gaining a per-profile version stamp of its own, or the last per-profile migration being retired |
| `events-frames-taint-§8` (SHOULD half) | 18 chat lines in `settings/Slash.lua` and `settings/Schema.lua` pre-format their arguments — `print(("%s bar %s"):format(...))`, `print("Switched to profile '" .. name .. "'")` — instead of handing the parts to the shared printer as `print("fmt", a, b)` | **Re-graded, not deferred.** §8's pre-formatting MUST is now **scoped** to call sites whose arguments can reach a value read from one of the named combat-protected APIs (`UnitGetTotalAbsorbs`, `UnitHealth`/`UnitHealthMax`, threat, aura amounts); outside that trigger set it is a **SHOULD NOT**, because the risk is drift, not secrets. Every one of the 18 sites formats only values this addon owns — a version string, a unit label, a profile name, a user-typed test number, a schema path — so none is in the trigger set and none can be handed a secret. The two sites that DO read `UnitGetTotalAbsorbs` (`core/AbsorbTracker.lua:171`, `:243`) already pass their arguments to the sink unformatted and guard with `NS.IsConcatSafe`; the seam's own guarantee (library stringifier, `table.concat`-based probe) is untouched and unconditional. Filed as `AT-35` in `docs/audits/2026-08-05/` against the pre-scoping text | 2026-08-05 | Any of these lines gaining an argument that is, or derives from, a return value of one of §8's named APIs — that site converts as a MUST — or §8's trigger set growing to cover one of them |
| `localization-§1` | This addon ships **English only**: the `NS.L` seam is exported and `locales/enUS.lua` ships, but user-facing strings are hardcoded English rather than routed through `NS.L`. The one string that WAS routed — the disabled-verb refusal — left the addon at LibKa0s v1.41.0, because `slash-commands-§7` makes that line the collection's wording rather than the addon's and `lib.L` does not reach it; `enUS.lua` now carries no keys, which `localization-§3` requires rather than merely permits | A deliberate decision, not a backlog item. `localization-§3` names this one of the routing SHOULD's **two terminal compliant states** — English-only, recorded — so this row IS the compliant end state and an audit records it as accepted rather than re-filing the SHOULD. Both localization MUSTs are met unconditionally: the seam is exported and `enUS.lua` ships, carrying no dead keys. Filed as `AT-30` in `docs/audits/2026-08-05/`; deferred twice before as [PLAN-02](https://github.com/tusharsaxena/AbsorbTracker/issues/24), closed here | 2026-08-05 | The first non-English locale file added to `locales/` |

**Retired on 2026-08-05** — four entries this register carried whose cited rule the standard has since
changed, so the behavior is now permitted outright and a row for it reads as a deviation that is not
one (`documentation-§3`: the register must not become a graveyard):

- **No `## X-Wago-ID` in the TOC.** `toc-file-§1` marks the distribution IDs as mandatory only for a
  platform the addon actually ships on. Absorb Tracker is CurseForge-only, so there is nothing to
  declare and nothing to deviate from.
- **`AbsorbTrackerPerfDB`, a second top-level SavedVariables global.** `savedvariables-§4` now names
  the diagnostics global as the one sanctioned non-AceDB SV, which is exactly what this is.
- **`lizard` as an optional dev dependency.** `performance-§10` mandates the complexity measurement
  and names the tool; `automated-tests-§3` places it outside the commit gate. Both are what this repo
  already does.
- **Instrumentation brackets in hot paths.** `performance-§2` now specifies the bracket idiom itself,
  including the inline `local t0 = Perf.on and debugprofilestop()` shape these files use.

The perf capture ring, the complexity tooling and the bracket idiom are all still described in this
document — under **Performance & Profiler Attribution** below, where they belong as design, not as
departures.

### The per-unit event frames, in full

- **events-frames-taint-§1 — private `CreateFrame` event frames for the `UNIT_*` events, one per unit.**
  `addon:SyncUnitEventFrames()` (called from `OnEnable` and from the `UNITS` bus message,
  `core/AbsorbTracker.lua`) registers `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` on a private
  frame per tracked unit via `RegisterUnitEvent` rather than through AceEvent-3.0 — and only for
  units whose bar is currently enabled.
  **Why two events fire for every unit at all:** both events fire for every unit the client knows
  about (raid, pets, nameplates, target/focus); AceEvent-3.0 uses a single shared frame with plain
  `RegisterEvent` and structurally cannot `RegisterUnitEvent`, so an AceEvent registration pays a
  full C→Lua dispatch per unit only to discard all but ours — a measurable combat CPU hotspot.
  **Why one frame per unit:** `RegisterUnitEvent` unit-filters **at most two** tokens per
  registration, so three tracked units cannot share a single frame anyway. Given that, a frame each
  beats packing two-and-one: enabling or disabling a bar becomes a registration change on that
  unit's own frame, with no token repacking, and a disabled unit ends up registered for nothing at
  all. A private unit-event frame is the established WoW pattern for this (BigWigs et al.).
  **`PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` are gated on the same flag** (still on
  AceEvent, registered and unregistered by the same function): they fire on every target and focus
  swap regardless of absorbs, so gating them is where the CPU saving actually lands — the `UNIT_*`
  events were already C-filtered to the tokens we asked for. `PLAYER_ENTERING_WORLD` and
  `PLAYER_REGEN_DISABLED/ENABLED` stay unconditionally on AceEvent. The per-unit frames are the
  *only* raw event frames; events-frames-taint-§1 otherwise holds.

### The per-profile schema stamp, in full

- **savedvariables-§1 — a PER-PROFILE `schemaVersion` stamp alongside the account-wide one.** savedvariables-§1 puts the
  persisted-DB version stamp account-wide in `db.global`. This addon keeps that stamp *and* adds a
  second one at `db.profile.schemaVersion` (`defaults/Profile.lua`, default `1`). **Why:** the v3
  migration — lifting flat appearance keys onto `profile.units.<unit>` — is a **per-profile**
  mutation, and an account-wide flag structurally cannot gate one. A user with "Default" and "Raid"
  both pre-v3 who upgrades while on Default migrates Default, flips the account-wide stamp to 3, and
  Raid's flat `barWidth` / `barColor` / `position` become unreachable forever — no later login
  re-runs the lift, so their raid layout silently reverts to factory defaults. `NS:InitDB` now sweeps
  every profile in `db.sv.profiles` before the account-wide stamp flips, and `NS.OnProfileChanged`
  re-runs the lift for any profile that only *appears* later (copied in from another character,
  restored from a backup SavedVariables file, or reset). The per-profile stamp is the authority for
  "has **this** profile been lifted"; the account-wide stamp remains the DB-wide marker and still
  drives the v2 step. The per-profile default is deliberately `1`, not `3`: AceDB's `copyDefaults`
  fills every absent key before `RunMigrations` reads the profile, so a default of `3` would mark
  every upgrading profile as already-migrated and make the gate dead code. See
  [profiles.md](./profiles.md).

### Recorded, but not deviations

The two entries below cite no rule. They are kept in this document because an audit or a media sweep
would otherwise surface them cold, and the reason they exist is not obvious from the code.

- **A production test seam: `Helpers.__lastUnitCtx` (`settings/UnitPanel.lua`).**
  `Helpers.RenderUnitPanel` stashes the ctx it just rendered on `NS.Helpers.__lastUnitCtx`.
  **Why, now that the library has its own seams:** `LibKa0s-Options-1.0` does expose `O.__panels()`
  and `O.__panelFor(pageKey)`, so the panel registry is no longer unreachable. What those do not
  answer is *which unit was rendered* — `RenderUnitPanel` is the only renderer that sets `ctx.unit`,
  and a page key alone cannot distinguish the ctx of an Appearance page showing `target` from the
  same page showing `player`. `__lastUnitCtx` hands the harness the live ctx of the last unit render,
  `ctx.unit` and `ctx.activeTab` included, which is what makes the per-unit path (the chrome block's
  picker and mirror controls, the tab strip, the row partition) assertable headlessly instead of only through in-game smoke tests. It is a single dunder-prefixed
  field, written on every render and read by nothing in production — no behavior depends on it.
  Recorded here rather than removed because the coverage it buys is worth more than the purity; if
  the library ever grows a unit-aware panel accessor, this should collapse into it.

- **Non-Blizzard media that is intentionally fixed (no LSM selector).** The bar-appearance media —
  `barTexture`, `bgTexture` (both default `"Blizzard Raid Bar"`), `border` (`"Blizzard Tooltip"`) and
  `font` (`"Friz Quadrata TT"`) — is 100% Blizzard-stock by default and fully user-configurable
  through LSM (`LSM30_Statusbar`/`LSM30_Border`/`LSM30_Font` dropdowns in `settings/Appearance.lua`,
  resolved via `lsm:Fetch` in `core/Data.lua` with Blizzard-stock fallbacks in `core/Constants.lua`).
  Two assets sit outside that model — non-Blizzard *and* deliberately not exposed as a user setting.
  Both are standard-sanctioned; they are recorded here only so a font/texture audit (or a fresh
  `/standards-audit`) re-surfaces them with their justification rather than flagging them:
  - **Debug-console font — JetBrains Mono (OFL), shipped by LibKa0s, not by this addon.** The
    console is `libs/LibKa0s/DebugLog.lua` and renders in whatever face its descriptor's `font`
    names; `core/DebugLogSetup.lua` hands it `C.FONT_MONO`, so the choice of face is still this
    addon's — but the bytes are `libs/LibKa0s/media/fonts/JetBrainsMono-Regular.ttf`, resolved at
    load through `NS.MediaFont` (`core/MediaSetup.lua`) and falling back to `C.FALLBACK_FONT`
    (`Fonts\FRIZQT__.TTF`, a literal in `core/Constants.lua`) when the payload is missing — a
    literal rather than `_G.STANDARD_TEXT_FONT` so the last rung of the ladder cannot itself be nil. `Media.RegisterLSM` registers it with LSM as
    `"JetBrains Mono"` at FILE LOAD (this addon used to register its own copy at init), but the
    console does not read a user font setting. **Why:** a fixed
    monospace face is required for column-aligned debug output (debug-logging-§2). The console's backdrop is
    Blizzard-stock too, but it is no longer the tooltip frame: `WHITE8x8` for both the fill and
    the edge, the edge tinted flat black at `edgeSize = 1`, with a 1px gray highlight synthesized
    just inside it, a gold title and a gray divider. That edge is the **shared Ka0s window edge**,
    not this addon's — it is `LibKa0s-Core-1.0`'s `SKIN` + `ApplySkin` (`libs/LibKa0s/Core.lua`),
    and `core/DebugLogSetup.lua` takes it as-is (it passes neither `skin` nor `applySkin`), so the
    console and the perf panel wear whatever every other Ka0s window wears. The Ka0s WoW Addon
    Standard specifies those values normatively (standalone-windows); the 12px
    `UI-Tooltip-Border` is what the same seam drew before LibKa0s v1.3.0.
  - **About-page logo — `media/logos/absorbtracker.logo.tga`.** `settings/About.lua` draws the
    addon's branding logo via `C.LOGO_PATH`. **Why:** addon branding, not bar appearance; a
    user-swappable logo would be meaningless. Stored under a typed media subfolder per layout-§3.

## Performance & Profiler Attribution

The addon is purely reactive — **no `OnUpdate`, no repeating ticker, no combat-log parsing, no
hot-path hooks**. Its whole runtime cost is a C-filtered `UNIT_*` event, a coalescing one-shot
repaint timer, and one bar update fanned across the three units.

The measurements, the profiler-attribution caveats and what the numbers do and do not cover are in
**[performance.md](performance.md)**.
