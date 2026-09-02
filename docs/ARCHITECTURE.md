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
only (Interface 120007), English only.

The addon is an **AceAddon** (`core/AbsorbTracker.lua`) mixing in AceEvent / AceTimer / AceConsole.
`local addonName, NS = ...` is the shared private namespace bus in every file; there is no
`_G[addonName]` table.

## Module Map

Load order is dependency order (see `AbsorbTracker.toc`): Libraries → Locales → Core → Defaults →
Modules → Settings.

Four of the rows below are *setup* files rather than implementation: `core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `core/PerfSetup.lua` and `settings/OptionsSetup.lua` each hand a
**descriptor** to one of the five descriptor-taking LibKa0s majors — `LibKa0s-Core-1.0`,
`-DebugLog-1.0`, `-Slash-1.0`, `-Options-1.0`, `-Perf-1.0` — and publish what
comes back under the `NS.*` name the addon already used, plus a degradation stub for when the library
is absent. `settings/Slash.lua` does the same thing without a separate setup file. `core/MediaSetup.lua`
and `core/EnvSetup.lua` are the sixth and seventh seams, and the two odd ones: `LibKa0s-Media-1.0` and
`LibKa0s-Env-1.0` take no descriptor, only this addon's FOLDER name — a texture path is absolute from
`Interface\AddOns\` and a TOC manifest is keyed by folder, and a vendored copy cannot know which folder
it was copied into. **Seven majors across eleven files** of the ten majors `libs/LibKa0s/` vendors. See
[Five extracted libraries, one descriptor each](./performance.md#five-extracted-libraries-one-descriptor-each).

There is no `:NewModule()` hierarchy. Modules are plain files hanging functions on `NS`, and a
caller reaches a function defined in a later-loaded file through `NS.X` directly — looked up at call
time, guarded with `if NS.X then … end` where the load-order coupling is soft. Cross-module
*notifications* do not use that route at all; they run over the bus (see [Message Bus](#message-bus)).

| File | Responsibility |
|------|----------------|
| `core/EnvSetup.lua` | The `LibKa0s-Env-1.0` seam: `NS.Meta(field)` / `NS.Version()` over the vendored library, told this addon's own folder name. It replaced the whole of `core/Compat.lua`, whose one export was the same TOC-metadata reader nine addons had each written for themselves. |
| `core/MediaSetup.lua` | The `LibKa0s-Media-1.0` seam: `NS.Icon` / `NS.MediaFont` over the vendored payload, and the one `Media.RegisterLSM` call. Loads before `Constants.lua`, which reads it. |
| `core/Constants.lua` | `NS.Constants`: fallback texture/border/font paths, `FONT_MONO` / `FONT_MONO_NAME` (debug console, resolved from the Media seam), `LOGO_PATH`. |
| `core/Namespace.lua` | `NS.name` / `NS.version` / `NS.PREFIX` (cyan `[AT]`) and the hot-path `floor`/`max` caches. |
| `core/State.lua` | `NS.State` — session-only runtime state (the debug flag; never persisted). |
| `core/Bus.lua` | The closed cross-module message bus: `NS.bus` (shared publish target), `NS.NewBusTarget()` (one per receiver), and the `NS.MSG` catalog (`REPAINT`/`APPEARANCE`/`VISIBILITY`/`POSITION`/`UNITS`). |
| `core/CoreSetup.lua` | Wires the addon into `LibKa0s-Core-1.0` — the guard, the stringifier and the printer are vendored library code, not addon code. Publishes `NS.Print` (prefixed chat, built via `lib:New{...}` with the `[AT]` prefix passed as a function), `NS.Util.print` (the same function object), `NS.IsConcatSafe` and `NS.SafeToString`, with working fallbacks when the library is absent. The secret-safe debug sink is `NS.Debug` (published by `core/DebugLogSetup.lua`); every debug arg routes through `NS.SafeToString`. |
| `core/PerfSetup.lua` | Wires the addon into `LibKa0s-Perf-1.0` (issue #17) — the probe itself is a vendored library, not addon code. Builds `NS.Perf` via `lib:New{...}`: the addon's name/version/SavedVariables global, the bucket declarations (order + nesting), and the `suspend`/`resume` pair that makes the addon inert without a `/reload`. Loads immediately after `core/CoreSetup.lua`, before any module takes `local Perf = NS.Perf` as an upvalue. See [Performance & Profiler Attribution](#performance--profiler-attribution) below. |
| `core/Data.lua` | The AceDB read/write seam (`GetSetting`/`SetSetting` — dotted-path aware, so `units.target.barWidth` and flat `locked` both work), LSM fetchers with fallbacks (each takes a `unit`, resolved through `NS.Units.Get`), and the class-color-aware color resolvers (each takes a `unit`; the class color is that unit's own, per options-ui-§17, and the background keeps its own darkened per-class palette — the one surface §17 exempts from the shared `NS.ResolveColor`). |
| `core/Database.lua` | `NS:InitDB` (AceDB + profile callbacks) and `NS:RunMigrations` (schema-version seam). |
| `core/Units.lua` | `NS.Units` — unit identity (`LIST`/`LABEL`), mirror resolution (`IsMirrored`/`SourceUnit`/`Get`), per-unit position read/write, and `CopyFromPlayer`. The only file that reads `db.profile.units` for appearance. |
| `core/LSMPatch.lua` | `NS.ApplyLSMBorderPatch` — collapses the upstream LSM30_Border preview tile; run once on enable. |
| `core/DebugLogSetup.lua` | Wires the addon into `LibKa0s-DebugLog-1.0` — the on-screen console (`debug-logging`) is a vendored library, not addon code. Builds `NS.DebugLog` via `lib:New{...}` and binds `NS.Debug` bare off it. What this file supplies: the frame-name prefix, the title, the monospace font, the `/at` slash name, the call-time `print`/`safeToString` hooks, the `onVisibilityChanged` panel refresh, the `[Init]` session summary, and — the part that must not move — `isEnabled`/`setEnabled` over `NS.State.debug`, so the logging flag stays this addon's single truth. Degrades to a stub that still flips the flag when the library is absent. The library's surface is unchanged: `FormatPlain`/`FormatColored`, `SetEnabled`, `Show`/`Hide`/`Toggle`/`IsShown`, the `debug-logging-§11` always-shown scrollbar (`UpdateScrollBar`) + bottom line counter (`UpdateStatus`, `lib.MAX_BUFFER = 1500`), `ConsoleCheckbox()` — the General page's checkbox spec that shows/hides the window (not the logging flag) — and the harness-facing `CopyText`/`FindLine`/`BufferSize`/`LastLine` plus the raw `buffer` array. The copy window itself is no longer DebugLog's own: as of minor 12 it is `LibKa0s-Widgets-1.0`'s `CopyWindow`, which the module hard-floors on (`NEEDS_WIDGETS = 7`) — the one place this addon reaches an eighth major, and it reaches it indirectly. |
| `core/AbsorbTracker.lua` | AceAddon promotion; `OnInitialize` (font register, InitDB, slash register), `OnEnable` (the login sequence), event handlers, `OnProfileChanged`. |
| `defaults/Profile.lua` | Six flat globals (`enabled`/`visibility`/`scale`/`alpha`/`locked`/`throttleWindow` — the first four are options-ui-§15's Master controls set; there is no `hidden` master toggle) + `NS.defaults.profile.units.{player,target,focus}` (each unit's own appearance table, built by a factory so no table is shared across units) + `NS.defaults.global.schemaVersion = 1` (the current schema is **5** — v3 introduced `profile.units`, v4 dropped the dead `hidden` toggle, v5 mapped `showOnlyInCombat` onto `visibility` — but the DEFAULT is the pre-ladder `1`, exactly like the per-profile stamp, because AceDB's `copyDefaults` fills it before `RunMigrations` reads it and a default of `4` would stamp every freshly-materialized global as already-migrated); `NS.flatDefaults` alias, `NS.unitDefaults` (= `defaults.profile.units.player`, the canonical per-row default source for `settings/Appearance.lua`). |
| `locales/enUS.lua` | `NS.L` metatable-fallback locale (English source keys; nothing wrapped yet). |
| `modules/Bar.lua` | `NS.CreateBar(unit, globalName)` builds one bar frame; `NS.bars` (keyed `player`/`target`/`focus`, frames `AbsorbTrackerFrame`/`AbsorbTrackerTargetFrame`/`AbsorbTrackerFocusFrame`) at file load, plus `NS.bar`/`statusBar`/`valueText`/`backdropInfo` as player aliases for pre-multi-unit call sites. Each bar owns its own `backdropInfo` table (border size differs per unit; `SetBackdrop` keys off table identity) and a `unitLabel` FontString above the frame naming its unit, shown only while unlocked. |
| `modules/Display.lua` | Every function takes a `unit` (defaulting to `"player"`): `RestoreBarPosition`, `UpdateBarAppearance`, `ShouldShowBar`/`ApplyVisibility` (the four-step visibility ladder), `UpdateAbsorbBar` (the paint path). `NS.ForEachUnit(fn)` and `NS.DefaultPosition(unit)` (stacks target/focus above the player bar) also live here. Subscribes to `APPEARANCE`/`VISIBILITY`/`POSITION` on its own `NS.Display.__ev` bus target, fanning each handler out over `NS.ForEachUnit` so the bus messages stay payload-free. |
| `modules/Timer.lua` | Coalescing repaint scheduler (`NS.RequestRepaint`) — a trailing-edge one-shot AceTimer throttle. |
| `settings/Schema.lua` | The schema registry + read/write seam (`SetByPath`), value formatting, and `ValidateSchema`. `NS.FormatSchemaValue` is a thin delegate to `LibKa0s-Slash-1.0`'s `lib.FormatValue`, so the `/at get` echo and the `[Set]` debug line cannot disagree about how a color or an empty string reads; the type-aware parser is the library's `lib.ParseValue` (`NS.ParseSchemaValue` and the private `parseBool`/`parseNumber`/`parseString`/`parseColor` helpers are gone). Rows carry `unit`, `alwaysPerUnit`, and `skipRender` fields; `SchemaForPage(page, unit)` filters to one unit's rows (or all, when `unit` is omitted); `PartitionUnitRows` splits a unit page into always-editable rows vs. mirror-hidden appearance rows (kept and unit-tested, but with no production caller since the mirrored state became a hint under the tab strip); `ResolvePath`/`SetPath` walk dotted paths (`units.<unit>.<key>`) so flat globals and per-unit keys share one seam. |
| `settings/Slash.lua` | AceConsole registration, the ordered `NS.COMMANDS` verb table (17 verbs), and the host verbs that reach into this addon's own state (`lock`/`unlock`/`toggle`/`update`/`test`/`profile`/`debug`/`perf`/`resetall`/`resetposition`) plus the mirror note. The dispatcher itself, the help renderer, the row and key/value formatters, the value renderer, the `/at list` builder and the type-aware value parser are `LibKa0s-Slash-1.0` (vendored, `libs/LibKa0s/Slash.lua`); this file builds the CLI with `SlashLib:New{...}` and passes `NS.COMMANDS` in. Degrades to a stub that keeps the host verbs working — and names the missing library on each schema verb — when the library is absent. |
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

## Settings Schema

`NS.Schema` is a flat array of **69 rows**; each `settings/<page>.lua` calls
`NS.RegisterSchemaRows({...})` at file-load time. The same array drives both the AceGUI panel widgets
(via `NS.Helpers.RenderTabbedSchema` / `RenderRows` / `RenderField`, all supplied by
`LibKa0s-Options-1.0` and fed the rows through the descriptor's `rowsForPage`) and the
`/at list|get|set|reset|resetall` CLI — adding an option is one schema row.

Exactly **seven** of the 69 carry an absolute, unit-agnostic path — the six flat globals (`enabled`,
`visibility`, `scale`, `alpha`, `locked`, `throttleWindow`) plus the session-only
`state.debugConsole`, all on the General page. The other **62 are unit-relative**
(`units.<unit>.<key>`): the three `units.<unit>.enabled` toggles, also on General, plus the
Appearance page's 59, generated as **nineteen appearance keys × three units** with a `mirror` row
for target and focus. So General holds ten rows (seven absolute, three unit-relative) and Appearance
the remaining 59.

Sixteen of the nineteen per-unit keys and five of the seven globals are **composed**, not typed out:
`H.MasterControls`, `H.BarGroup`, `H.BorderGroup`, `H.FontGroup` and `H.ColorPair`
(`LibKa0s-Options-1.0`'s `OptionsCompose`) emit the canonical blocks options-ui-§15/§16/§17 mandate
from one declaration each. The host passes `keys` and `defaults` so **nothing stored moved** — the
composer changes what is *declared*, never what is *persisted*.

**A row's `group` is a TAB.** Both schema-bearing pages draw their sections as a tab strip
(options-ui-§13), partitioned by `group` **in declaration order**, so the array *is* the strip and a
group's rows must stay contiguous. General is `[ Master controls | Bars ]` (6 / 4 rows); Appearance
is `[ Size | Bar | Background | Border | Text ]` (2 / 4 / 3 / 4 / 6 rows, per unit) under a chrome block
(options-ui-§14) carrying the panel's only unit picker and the page-wide mirror controls. `tests/test_schema.lua` asserts that
page → tab → count partition. All writes funnel through the single seam **`NS.SetByPath`**
(`SetSetting` + `fireOnChange`), whose `onChange` defaults to `UpdateBarAppearance`. Boot-time
`NS.ValidateSchema` checks each row's shape (`page`/`type` enums, non-empty `path`) **and** that
every `path` resolves against `NS.defaults.profile`; it returns `(errors, resolved, missing)` for
the test harness to assert (`sessionOnly` rows are exempt from the path check — their value is
deliberately not in the profile). Row grammar detail: [schema.md](./schema.md).

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
a profile change) walks per-widget refresher closures — the implementation is the library's, walking
`ctx.refreshers` on library-owned ctx tables. The other callback bus is **AceDB**:
`NS.OnProfileChanged` is registered for `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` in
`NS:InitDB`; it republishes `POSITION` / `APPEARANCE` / `REPAINT` on the bus and refreshes an open
panel.

## Slash Commands

Registered via AceConsole in `settings/Slash.lua`: `/at` and the alias `/absorbtracker` both
dispatch to `Sl:OnSlash`, which hands the line straight to `LibKa0s-Slash-1.0`. The library
lower-cases only the verb (preserving case in the remainder so schema paths survive) and looks it
up in the ordered `NS.COMMANDS` table this addon passed in. Unknown verb →
`unknown command '<verb>'` then the help index (generated from `NS.COMMANDS`).

**Schema paths are fully qualified.** `/at set units.target.barWidth 250` works; the pre-1.9
unqualified `/at set barWidth 250` is rejected, because `FindSchemaRow` has no bare-key row for a
per-unit setting. Only the seven unit-agnostic rows — `enabled`, `visibility`, `scale`, `alpha`, `locked`,
`throttleWindow` and the session-only `state.debugConsole` — take a bare path.

**What is library code and what is ours.** The dispatcher, the help renderer, the row formatter
(gold command — em dash — white description), the key/value formatter, the value renderer, the
`/at list` builder and the type-aware value parser (clamping, the case-sensitive enum check, the
0-1 / 0-255 color rescale) all live in `libs/LibKa0s/Slash.lua`, shared across every Ka0s addon.
`settings/Slash.lua` keeps `NS.COMMANDS`, the host verbs, and the mirror note attached through
`cli:SetRowAnnotator` — a `(mirrored — the bar shows Player's appearance)` tail on the
appearance rows of a unit that is currently mirroring, which reads `NS.Units.IsMirrored` and the
row's `alwaysPerUnit` flag, neither of which a generic dispatcher knows about.

`NS.COMMANDS` is passed **into** the library rather than owned by it, deliberately:
`settings/About.lua` renders the same table via `NS.Slash:LandingRows()`, so a library that owned
the verbs would force an options layer to consume this one — and two libraries reaching for each
other is a real dependency cycle. The table crossing as plain data is what keeps them independent.

| Command | What it does |
|---------|--------------|
| `/at help` (or bare `/at`) | Print the help index |
| `/at config` (alias `/at options`) | Open the settings panel (combat-gated) |
| `/at list` | List every setting and its current value |
| `/at get <path>` | Print one setting's current value |
| `/at set <path> <value>` | Set one setting (typed: bool/number/string/color) |
| `/at reset <path>` | Reset one setting to its default (a whole page is the panel's Defaults button) |
| `/at resetall` | Reset the **active profile** to the shipped defaults — a profile reset, and the same act as Profiles → Reset Profile (`options-ui-§12`). Shared `Helpers.RestoreAllDefaults`, which the panel's Reset All button and the popup also call. `resetProfile` is `db:ResetProfile()`; `skipRestoreAll` vetoes the Profiles page **and** every profile-backed row, leaving the library's walk only the `sessionOnly` rows a profile reset cannot reach. Saved positions live in the profile and come back with it — `ResetAllPositions` still backs `/at resetposition` and the General page's button, and is no longer on this path |
| `/at resetposition` | Clear **every** unit's saved position and re-anchor all three bars to their stacked defaults (shared `Helpers.ResetAllPositions`, `settings/UnitPanel.lua` — the General page's Reset Position button calls the same path) |
| `/at lock` / `/at unlock` | Flip the drag lock |
| `/at toggle [player\|target\|focus]` | Bare: flip **every** bar — all off if any is on, otherwise all on. With a unit token: flip that one bar only. Writes `units.<unit>.enabled` through `SetByPath`, so it travels the same path as the General page checkbox |
| `/at debug` (`on`/`off`) | Toggle the debug console window; `on`/`off` enable/disable logging |
| `/at perf <sub>` | The performance probe — `LibKa0s-Perf-1.0` (vendored, `libs/LibKa0s/`), wired up by `core/PerfSetup.lua`. Bare `/at perf` opens the step panel, whose first row starts a run — the entry point. `start [label]`/`finish` bracket a run, `measure a\|b` arm a combat-gated experiment, `report` print it, `dump` emit JSON, `cancel` abandon it unsaved, `show`/`hide`/`toggle` drive the step panel. `measure b` owns the suspend; there is no manual verb for it. Its own `NS.COMMANDS` verb — a thin dispatch to `NS.Perf.OnCommand`. See [performance.md](./performance.md) |
| `/at update` | Force a bar refresh |
| `/at version` | Print the addon version |
| `/at test [value] [hold-secs]` | Paint a fake value for visual tweaking |
| `/at profile <subcmd>` | Profile management (list/current/use/new/copy/delete/reset) |

## Event Subscriptions

AceAddon lifecycle in `core/AbsorbTracker.lua`:

- **`OnInitialize`** (ADDON_LOADED): register the monospace font with LSM, `NS:InitDB()`
  (AceDB + `RunMigrations` + profile callbacks), `NS.Slash:Register()`.
- **`OnEnable`** (PLAYER_LOGIN timing): reproduces the old login sequence in order —
  `ClearLSMCache` → `GetLSM` → `ApplyLSMBorderPatch` → **publish** `POSITION` → `APPEARANCE` →
  `REPAINT` on the bus → register events → `CreateOptionsPanel`. The three publishes reach
  `RestoreBarPosition` / `UpdateBarAppearance` (Display) and `RequestRepaint` (Timer); the login
  paint therefore lands one `throttleWindow` later, not synchronously.
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
  publishes `VisibilityChanged` (the `visibility` gate) and `RepaintRequested`. These three
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

- **Retail Midnight only** (Interface 120007); no game-flavor branching.
- **English only** — a ratified decision, not an unfinished job: the row lives in
  [Documented deviations](#documented-deviations) below (`localization-§1`), which is its single home.
  The `NS.L` seam is exported and `locales/enUS.lua` ships; no string is routed through it yet.
- **Three bars — player, target, focus.** Group / raid / arena / boss units are out of scope
  ([scope.md](./scope.md)).

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`) — except this
file, the hub the map itself lives in. Frozen and generated directories are named once each and never enumerated per run: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/`, `docs/superpowers/`, `docs/perf-analysis/`, `docs/investigations/`, `docs/revendor/`.

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
| `slash-dispatch.md` | Not applicable | 17 verbs, but the generated table in `ARCHITECTURE.md` → `## Slash Commands` covers the flat verb set; no subcommand tree |
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
| `events-frames-taint-§1` | `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` are registered on a private `CreateFrame` **per tracked unit** via `RegisterUnitEvent`, not through AceEvent-3.0 | Both events fire for every unit the client knows about; AceEvent shares one frame and structurally cannot `RegisterUnitEvent`, so it would pay a full C→Lua dispatch per unit only to discard all but ours. One frame each rather than packing tokens, because `RegisterUnitEvent` filters **at most two** tokens per registration. Argument in full below; filed as `AT-A-10` in `docs/audits/2026-08-05/` | 2026-07-14 | A client build where `RegisterUnitEvent` accepts more than two unit tokens |
| `savedvariables-§1` | A **per-profile** `schemaVersion` stamp at `db.profile.schemaVersion`, alongside the account-wide stamp in `db.global` | The v3 lift — flat appearance keys onto `profile.units.<unit>` — is a per-profile mutation, and an account-wide flag structurally cannot gate one: a second pre-v3 profile would have its stored appearance stranded forever. Argument in full below | 2026-07-28 | AceDB gaining a per-profile version stamp of its own, or the last per-profile migration being retired |
| `events-frames-taint-§8` (SHOULD half) | 18 chat lines in `settings/Slash.lua` and `settings/Schema.lua` pre-format their arguments — `print(("%s bar %s"):format(...))`, `print("Switched to profile '" .. name .. "'")` — instead of handing the parts to the shared printer as `print("fmt", a, b)` | **Re-graded, not deferred.** §8's pre-formatting MUST is now **scoped** to call sites whose arguments can reach a value read from one of the named combat-protected APIs (`UnitGetTotalAbsorbs`, `UnitHealth`/`UnitHealthMax`, threat, aura amounts); outside that trigger set it is a **SHOULD NOT**, because the risk is drift, not secrets. Every one of the 18 sites formats only values this addon owns — a version string, a unit label, a profile name, a user-typed test number, a schema path — so none is in the trigger set and none can be handed a secret. The two sites that DO read `UnitGetTotalAbsorbs` (`core/AbsorbTracker.lua:168`, `:231`) already pass their arguments to the sink unformatted and guard with `NS.IsConcatSafe`; the seam's own guarantee (library stringifier, `table.concat`-based probe) is untouched and unconditional. Filed as `AT-A-03` in `docs/audits/2026-08-05/` against the pre-scoping text | 2026-08-05 | Any of these lines gaining an argument that is, or derives from, a return value of one of §8's named APIs — that site converts as a MUST — or §8's trigger set growing to cover one of them |
| `localization-§1` | This addon ships **English only**: the `NS.L` seam is exported and `locales/enUS.lua` ships, but user-facing strings are hardcoded English rather than routed through `NS.L` | A deliberate decision, not a backlog item. `localization-§3` names this one of the routing SHOULD's **two terminal compliant states** — English-only, recorded — so this row IS the compliant end state and an audit records it as accepted rather than re-filing the SHOULD. Both localization MUSTs are met unconditionally: the seam is exported and `enUS.lua` ships, carrying no dead keys. Filed as `AT-A-09` in `docs/audits/2026-08-05/`; deferred twice before as [PLAN-02](https://github.com/tusharsaxena/AbsorbTracker/issues/24), closed here | 2026-08-05 | The first non-English locale file added to `locales/` |

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
