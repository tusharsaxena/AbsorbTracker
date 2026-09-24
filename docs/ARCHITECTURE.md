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
namespace bus in every file; there is no `_G[addonName]` table. The nine files that hand the folder
name (the first vararg) to a vendored library bind it as `addonName`; the other nineteen open
`local _, NS = ...` so luacheck can report a bound name nothing reads. Which nine, and why:
[module-map.md → The `NS` bus](./module-map.md#the-ns-bus).

## Module Map

Load order is dependency order (see `AbsorbTracker.toc`): Libraries → Locales → Core → Defaults →
Modules → Settings.

Six of the rows below are *setup* files rather than implementation: `core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `core/Lifecycle.lua`, `core/PerfSetup.lua`, `core/LauncherSetup.lua` and
`settings/OptionsSetup.lua` each hand a **descriptor** to one of the seven descriptor-taking LibKa0s
majors — `LibKa0s-Core-1.0`, `-DebugLog-1.0`, `-Lifecycle-1.0`, `-Perf-1.0`, `-Launcher-1.0`,
`-Options-1.0`, `-Slash-1.0` — and publish what comes back under the `NS.*` name the addon already
used, plus a degradation stub for when the library is absent. `settings/Slash.lua` does the same thing
for `-Slash-1.0` without a separate setup file. `core/MediaSetup.lua` and `core/EnvSetup.lua` are the
eighth and ninth seams, and the two odd ones: `LibKa0s-Media-1.0` and `LibKa0s-Env-1.0` take no
descriptor, only this addon's FOLDER name — a texture path is absolute from `Interface\AddOns\` and a
TOC manifest is keyed by folder, and a vendored copy cannot know which folder it was copied into.
**Twelve majors bound by name** of the fifteen `libs/LibKa0s/` vendors (twenty-one files); Compat,
Pool and Item are registered and unread. `LibKa0s-Widgets-1.0` is bound with no setup seam:
`modules/Bar.lua` reads it to build each bar's unlocked drag handle (`DragHandle`) and
`modules/Display.lua` reads its published `DRAG_HANDLE` sizes for the default stack, and DebugLog also
reaches it for its Copy window. See [Five extracted libraries, one descriptor
each](./performance.md#five-extracted-libraries-one-descriptor-each).

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
| `core/State.lua` | `NS.State` — session-only runtime state (the debug flag and `rejectedEvents`, the event names the client refused this session; never persisted). |
| `core/Bus.lua` | The closed cross-module message bus, and the `LibKa0s-Bus-1.0` seam: `NS.bus` (shared publish target, host code), `NS.busRecord` (the library's stand-down record), `NS.NewBusTarget()` (one tracked target per receiver), `NS.BusStandDown()` / `NS.BusStandUp()` (the latch's two calls), and the `NS.MSG` catalog (`REPAINT`/`APPEARANCE`/`VISIBILITY`/`POSITION`/`UNITS`), declared through `Bus.Catalog`. With the library absent, the untracked-target stub. |
| `core/CoreSetup.lua` | Wires the addon into `LibKa0s-Core-1.0` — the guard, the stringifier and the printer are vendored library code, not addon code. Publishes `NS.Print` (prefixed chat, built via `lib:New{...}` with the `[AT]` prefix passed as a function), `NS.Util.print` (the same function object), `NS.IsConcatSafe`, `NS.SafeToString`, `NS.ResolveColor` and the pcalled event registration helper `NS.SafeRegisterEvent` / `NS.SafeRegisterUnitEvent` / `NS.SafeRegisterEvents`, with working fallbacks when the library is absent. The secret-safe debug sink is `NS.Debug` (published by `core/DebugLogSetup.lua`); every debug arg routes through `NS.SafeToString`. |
| `core/PerfSetup.lua` | Wires the addon into `LibKa0s-Perf-1.0` (issue #17) — the probe itself is a vendored library, not addon code. Builds `NS.Perf` via `lib:New{...}`: the addon's name/version/SavedVariables global, the bucket declarations (order + nesting), and the stand-down latch (`lifecycle = NS.lifecycle`) — it carries no `suspend`/`resume` pair; the addon goes inert without a `/reload` through `NS.StandDown` / `NS.StandUp` in `core/Lifecycle.lua`. The TOC order is `core/CoreSetup.lua` → `core/Lifecycle.lua` → `core/PerfSetup.lua`: it loads after `core/Lifecycle.lua`, whose latch the descriptor carries, and before any module takes `local Perf = NS.Perf` as an upvalue. See [Performance & Profiler Attribution](#performance--profiler-attribution) below. |
| `core/Data.lua` | The settings read seam (`GetSetting`: the `LibKa0s-Schema-1.0` runtime's read with the shipped defaults behind it, dotted-path aware, so `units.target.barWidth` and flat `locked` both work; every write is `NS.SetByPath`), the minimap row's own inverted `get`/`set` (`NS.MinimapShown` / `NS.SetMinimapShown`), LSM fetchers with fallbacks (each takes a `unit`, resolved through `NS.Units.Get`), and the class-color-aware color resolvers (each takes a `unit`; the class color is that unit's own, per options-ui-§17, and the background keeps its own darkened per-class palette — the one surface §17 exempts from the shared `NS.ResolveColor`). |
| `core/Database.lua` | `NS:InitDB` (AceDB + profile callbacks) and `NS:RunMigrations` (schema-version seam). |
| `core/Units.lua` | `NS.Units` — unit identity (`LIST`/`LABEL`), mirror resolution (`IsMirrored`/`SourceUnit`/`Get`), per-unit position read/write, and `CopyFromPlayer`. The only file that reads `db.profile.units` for appearance. |
| `core/LauncherSetup.lua` | The `LibKa0s-Launcher-1.0` seam — see [Launcher](#launcher) below. Builds the one LDB object at file load and publishes `NS.Launcher`; `Register()` waits for `OnInitialize`, because the table it hands LibDBIcon is `db.global.minimap` and there is none until `NS:InitDB` has run. Degrades to a stub answering the same five members off the store, so the Master-controls checkbox is still honest with the library absent. |
| `core/DebugLogSetup.lua` | Wires the addon into `LibKa0s-DebugLog-1.0` — the on-screen console (`debug-logging`) is a vendored library, not addon code. Builds `NS.DebugLog` via `lib:New{...}` and binds `NS.Debug` bare off it. What this file supplies: the frame-name prefix, the title, the monospace font, the `/at` slash name, the call-time `print`/`safeToString` hooks, the `onVisibilityChanged` panel refresh, the `[Init]` session summary, and — the part that must not move — `isEnabled`/`setEnabled` over `NS.State.debug`, so the logging flag stays this addon's single truth. Degrades to a stub that still flips the flag when the library is absent. The library's surface is unchanged: `FormatPlain`/`FormatColored`, `SetEnabled`, `Show`/`Hide`/`Toggle`/`IsShown`, the `debug-logging-§11` always-shown scrollbar (`UpdateScrollBar`) + bottom line counter (`UpdateStatus`, `lib.MAX_BUFFER = 1500`), `ConsoleCheckbox()` — the General page's checkbox spec that shows/hides the window (not the logging flag) — and the harness-facing `CopyText`/`FindLine`/`BufferSize`/`LastLine` plus the raw `buffer` array. The copy window itself is no longer DebugLog's own: as of minor 12 it is `LibKa0s-Widgets-1.0`'s `CopyWindow`, which the module hard-floors on (`NEEDS_WIDGETS = 7`) — the one place this addon reaches an eighth major, and it reaches it indirectly. |
| `core/AbsorbTracker.lua` | AceAddon promotion; `OnInitialize` (InitDB, slash register, launcher register — in that order, because the launcher needs the DB), `OnEnable` (the login sequence), event handlers, `OnProfileChanged`. |
| `defaults/Profile.lua` | Six flat globals (`enabled`/`visibility`/`scale`/`alpha`/`locked`/`throttleWindow` — the first four are options-ui-§15's Master controls set; there is no `hidden` master toggle) + `NS.defaults.profile.units.{player,target,focus}` (each unit's own appearance table, built by a factory so no table is shared across units) + `NS.defaults.global.schemaVersion = 0` (savedvariables-§1: the pre-migration floor, never the current version. The runner's target is `NS.SCHEMA_VERSION` = **5**, derived in `core/Database.lua` from the ladder's last step — v2 retired `updateInterval`, v3 introduced `profile.units`, v4 dropped the dead `hidden` toggle, v5 mapped `showOnlyInCombat` onto `visibility`. A default equal to the current version would be stripped by AceDB's `removeDefaults` at every logout and backfilled onto a legacy account that stored no stamp, making both read as already migrated); `NS.flatDefaults` alias, `NS.unitDefaults` (= `defaults.profile.units.player`, the canonical per-row default source for `settings/Appearance.lua`). |
| `locales/enUS.lua` | `NS.L` metatable-fallback locale (English source keys; nothing wrapped yet). |
| `modules/Bar.lua` | `NS.CreateBar(unit, globalName)` builds one bar frame; `NS.bars` (keyed `player`/`target`/`focus`, frames `AbsorbTrackerFrame`/`AbsorbTrackerTargetFrame`/`AbsorbTrackerFocusFrame`) at file load; there are no player aliases, every caller indexes `NS.bars[unit]`. Each bar owns its own `backdropInfo` table (border size differs per unit; `SetBackdrop` keys off table identity) and `bar.handle`, the unlocked **drag handle**: `LibKa0s-Widgets-1.0`'s `DragHandle` (a dark strip with a gold 1px edge, the unit's name centered in gold, a `?` help mark at its right end), named `<frame>Handle`, anchored `BOTTOM` to the bar's `TOP` at the widget's `DRAG_HANDLE.GAP`. The addon supplies only its strings (routed through `NS.L`), the `help` icon from `NS.Icon`, `canDrag` (asks the lock) and `onDragStop`, which saves through the same local `savePosition` the bar body's own `OnDragStop` uses. The bar body stays draggable. With the widget absent `bar.handle` is nil and no strip is drawn — the library's documented degradation. |
| `modules/Display.lua` | Every function takes a `unit` (defaulting to `"player"`): `RestoreBarPosition`, `UpdateBarAppearance`, `ShouldShowBar`/`ApplyVisibility` (the four-step visibility ladder), `UpdateAbsorbBar` (the paint path). `UpdateBarAppearance` shows each bar's drag handle while unlocked, sized with `ApplyWidth(barWidth)` (as wide as the bar, or its own natural width over a narrower bar), and hides it while locked. `NS.ForEachUnit(fn)` and `NS.DefaultPosition(unit)` (stacks target/focus above the player bar, one bar height plus the handle's `HEIGHT + GAP` plus 8px apart, so an unlocked strip never sits over the bar above it) also live here. Subscribes to `APPEARANCE`/`VISIBILITY`/`POSITION` on its own `NS.Display.__ev` bus target, fanning each handler out over `NS.ForEachUnit` so the bus messages stay payload-free. |
| `modules/Timer.lua` | Coalescing repaint scheduler (`NS.RequestRepaint`) — a trailing-edge one-shot AceTimer throttle. |
| `settings/Schema.lua` | The schema registry + read/write seam (`SetByPath`), value formatting, and `ValidateSchema`. `NS.FormatSchemaValue` is a thin delegate to `LibKa0s-Slash-1.0`'s `lib.FormatValue`, so the `/at get` echo and the `[Set]` debug line cannot disagree about how a color or an empty string reads; the type-aware parser is the library's `lib.ParseValue` (`NS.ParseSchemaValue` and the private `parseBool`/`parseNumber`/`parseString`/`parseColor` helpers are gone). Rows carry `unit`, `alwaysPerUnit`, and `skipRender` fields; `SchemaForPage(page, unit)` filters to one unit's rows (or all, when `unit` is omitted); `ResolvePath`/`SetPath` walk dotted paths (`units.<unit>.<key>`) so flat globals and per-unit keys share one seam. |
| `settings/Slash.lua` | AceConsole registration, the ordered `NS.COMMANDS` verb table (18 verbs), and the host verbs that reach into this addon's own state (`enable`/`disable`/`lock`/`unlock`/`toggle`/`update`/`profile`/`debug`/`perf`/`resetall`/`resetposition`, with the value hold under `debug hold`) plus the mirror note. The dispatcher itself, the help renderer, the row and key/value formatters, the value renderer, the `/at list` builder and the type-aware value parser are `LibKa0s-Slash-1.0` (vendored, `libs/LibKa0s/Slash.lua`); this file builds the CLI with `SlashLib:New{...}` and passes `NS.COMMANDS` in. Degrades to a stub that keeps the host verbs working — and names the missing library on each schema verb — when the library is absent. |
| `settings/OptionsSetup.lua` | Wires the addon into `LibKa0s-Options-1.0` — the canvas shell, the schema-row → AceGUI translation, the schema composers, the two-column flow engine and the always-visible scrollbar patch are vendored library code (`libs/LibKa0s/{Options,OptionsWidgets,OptionsCompose,OptionsScroll}.lua`), not addon code. It replaces four files that used to be this addon's own toolkit (`Panel.lua`, `Helpers.lua`, `ScrollPatch.lua`, `Widgets.lua`). Holds the brand string as a **file-scope local** (`PARENT_TITLE = NS.Constants.BRAND`, the one brand constant, never a second literal), handed to the library as `descriptor.parentTitle` rather than published on the namespace — the two files that used to read it off `NS` are inside the library now. Then assigns `NS.Helpers = lib:New(descriptor)` — the library instance **itself**, not a decorated copy, so every existing `NS.Helpers.*` call site keeps working — plus thin `NS.RegisterOptionsPage` / `NS.CreateOptionsPanel` / `NS.OpenOptionsPanel` / `NS.RefreshOptionsPanel`. What this file supplies is the part that is ours: `get`/`set` (through `NS.GetSetting`/`NS.SetByPath`, so a panel change takes exactly the path `/at set` takes), `applyDefault`, `allRows`, `rowsForPage`, `skipRestoreAll` (excludes the Profiles page — its rows are AceDBOptions-supplied and resetting them is data loss — and every profile-backed row), `resetProfile` (→ `db:ResetProfile()`, because Reset All Settings **is** a profile reset per options-ui-§12), `scheduleTimer`, `getLSM`, `validate`, `onAceGUI`, `buildMain`, `colorDecode`/`colorEncode`, `print` and `debug`. Its stub is **load-completing, not member-answering** — the one setup file that breaks the addon's honest-line-per-member pattern, because `settings/Appearance.lua` calls `NS.Helpers.LSMValues` inside schema-row literals at *file load* and a nil there would abort the file, taking most of `NS.Schema` with it. Its five composers are hollow (each answers `{}`, options-ui-§1); the composed `enabled` and `locked` paths reach the store through `settings/Schema.lua`'s `writeThrough` list. |
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
  only metadata accessors; never call `C_AddOns.GetAddOnMetadata` inline. The seam's own fallback,
  for an install with no LibKa0s, is `C_AddOns` then nil; the pre-11.0 bare-global rung was deleted
  as dead code (compat: no client the TOC admits provides it), so no file spells it.
- **Every LibKa0s seam publishes the same `NS` names whether the library loaded or not.** The nine
  seams listed under [Module Map](#module-map) each answer with the library's instance or with a
  degradation stub under one name, and the rest of the addon codes against that symmetry rather than
  checking for the library. `settings/OptionsSetup.lua`'s stub is the one deliberate exception to
  the honest-line-per-member pattern — it is **load-completing, not member-answering**, and
  [settings-panel.md](./settings-panel.md) says why; `loadDegraded()` in `tests/test_perf.lua` loads
  the whole TOC without the library and pins the degraded row count and its named gap to the full
  one. Do not weaken it.

## Settings Schema

`NS.Schema` is a flat array of **70 rows**; each `settings/<page>.lua` calls
`NS.RegisterSchemaRows({...})` at file load, and the same array drives the panel widgets
(`LibKa0s-Options-1.0`) and the `/at list|get|set|reset|resetall` CLI, so adding an option is one
schema row. **Eight** rows carry an absolute path: the six flat globals (`enabled`, `visibility`,
`scale`, `alpha`, `locked`, `throttleWindow`), the session-only `state.debugConsole` and the
global-store `global.minimap.shown`, all on General. The other **62** are unit-relative
(`units.<unit>.<key>`): the three `units.<unit>.enabled` toggles on General, plus the Appearance
page's 59 (nineteen keys × three units, and a `mirror` row for target and focus). A row's `group` is
its **tab** (options-ui-§13), in declaration order, and 55 of the rows are emitted by
`LibKa0s-Options-1.0`'s composers rather than typed out.

The runtime is **`LibKa0s-Schema-1.0`**, instanced in `settings/Schema.lua` as `NS.SchemaRuntime`.
Every write goes through the one seam **`NS.SetByPath`** (store, `[Set]` line, `onChange`,
announce). A path with no row is refused, except `enabled` and `locked` on a library-less load,
which the descriptor's `writeThrough` list stores. A bulk copy or reset logs one `[Set]` line
through the `NS.Bulk` bracket.

This addon holds **no structural registry** (architecture-§5): the tracked units are the fixed
`Units.LIST`. It holds two pieces of **named non-setting state**:

- **`units.<unit>.position`**: owner `core/Units.lua` (`Units.SetPosition`). Writers: the bar's
  drag-stop (`modules/Bar.lua`) and `Helpers.ResetAllPositions` (`settings/UnitPanel.lua`, behind
  `/at resetposition` and the Reset Position button).
- **`AbsorbTrackerPerfDB`**: owner `core/PerfSetup.lua`. Its one writer is `LibKa0s-Perf-1.0`'s
  `P.Save`, reached only by `/at perf finish`.

The runtime binding, the bulk bracket, the validator, the full writer list for each named state and
the row grammar are in [schema.md](./schema.md).

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

How the tracked targets stand down with the latch, the fan-out, what is deliberately not on the bus
and the AceDB callbacks: [message-bus.md](./message-bus.md).

## Slash Commands

Registered via AceConsole in `settings/Slash.lua`: `/at` and the alias `/absorbtracker` both dispatch
to `Sl:OnSlash`, which hands the line straight to `LibKa0s-Slash-1.0`. The library lowercases only
the verb — preserving case in the remainder, so schema paths and profile names survive — and looks it
up in the ordered `NS.COMMANDS` table this addon passed in. Eighteen verbs, of which `profile`
and `debug` carry sub-verb tables of their own (`PROFILE_VERBS`, `DEBUG_VERBS`) and `perf` and
`toggle` each parse a token. A bare `/at`, empty or whitespace-only, runs the
`config` verb and opens the settings panel on its landing page; `/at help` prints the command list
(slash-commands-§4).

**Schema paths are fully qualified.** `/at set units.target.barWidth 250` works; the pre-1.9
`/at set barWidth 250` is rejected, because `FindSchemaRow` has no bare-key row for a per-unit
setting. Only the eight absolute rows under [Settings Schema](#settings-schema) take a bare path.

**`/at enable` and `/at disable` are ALIASES, not a second switch** (slash-commands-§2). Both write
the `enabled` path the Master controls tab's Enable checkbox writes, through the same `NS.SetByPath`
seam, and hold no state of their own. The dispatcher survives the disabled state — it is **setup,
not a feature** — which is what keeps the pair from being one-way. What the write actually does is
in [lifecycle.md](./lifecycle.md).

**A disabled addon refuses a FEATURE verb, on one tagged line naming `/at enable`** (slash-commands-§2,
a SHOULD this addon takes). The gate is `LibKa0s-Slash-1.0`'s. Live are the standard's twelve plus
`resetposition` and `profile`; `lock`, `unlock`, `toggle`, `update` and `debug hold` refuse. The live
set is argued verb by verb in [slash-dispatch.md](./slash-dispatch.md).

**There is no `test` verb.** The unlocked view is the preview (options-ui-§15): `/at unlock` and
`/at lock` are the switch, and the one-shot value hold is `/at debug hold <value> [secs]`.

The verb table, the sub-verb trees, the mirror note, the help convention and the degraded arm are in
[slash-dispatch.md](./slash-dispatch.md).

## Launcher

`core/LauncherSetup.lua` builds **one** LibDataBroker `launcher` object, named for the addon's folder
and labeled `NS.Constants.BRAND`, which LibDBIcon draws as the minimap button (launcher-§1). The rung
is **(b)**: left-click toggles the lock, the addon's preview switch, through `NS.SetByPath`, and is
refused with `NS.Slash:DisabledLine()` while the addon is disabled. Right-click always opens the
settings panel. The button's tooltip is the library's (Launcher minor 3), fed `version`,
`isEnabled`, `isLocked` and a `Lock / unlock` left-click label, and it shows while disabled too. The
button's visibility is the global-store `global.minimap.shown` row, which survives every reset
(launcher-§3). The object, the click gate, the tooltip, the inverted visibility row and the icon's
format are in [launcher.md](./launcher.md).

## The disabled state is total

`slash-commands-§7`: disabling the addon **stands it down**, unregistering every event, bus
subscription and timer in the same turn, rather than hiding the bars. One `LibKa0s-Lifecycle-1.0`
latch (`core/Lifecycle.lua`) carries two holds, `disabled` and `perf`. What stands down, what
survives as setup, and how `StandUp` rebuilds from current state: [lifecycle.md](./lifecycle.md).

## Event Subscriptions

AceAddon lifecycle in `core/AbsorbTracker.lua`:

- **`OnInitialize`** (ADDON_LOADED): `NS:InitDB()` (AceDB + `RunMigrations` + profile callbacks),
  `NS.Slash:Register()`, then `NS.Launcher:Register()`.
- **`OnEnable`** (PLAYER_LOGIN timing): `ClearLSMCache` → `GetLSM` → **`NS.SyncEnabledHold()`**,
  then, **only while the latch is up**, publish `POSITION` → `APPEARANCE` → `REPAINT` and register
  the events. An addon that comes up disabled registers nothing at all. `CreateOptionsPanel` sits
  outside that gate, because the settings registration is setup.
- **`UNIT_ABSORB_AMOUNT_CHANGED` / `UNIT_MAXHEALTH`** ride one private `RegisterUnitEvent` frame per
  unit (`addon:SyncUnitEventFrames`, re-run on `UNITS`), registered only while that unit's bar is
  enabled. `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` (AceEvent → `OnUnitSwap`) are gated the
  same way.
- **AceEvent, unconditional:** `PLAYER_ENTERING_WORLD` (`OnEnterWorld`), `PLAYER_REGEN_DISABLED`
  (`OnEnterCombat`, which re-locks unlocked bars first) and `PLAYER_REGEN_ENABLED` (`OnLeaveCombat`).
- **Every registration is pcalled** (events-frames-taint-§1). All seven call sites go through
  `NS.SafeRegisterEvent` / `NS.SafeRegisterUnitEvent` (`LibKa0s-Core-1.0`), so a refused name costs
  only itself and lands in `NS.State.rejectedEvents`.

The handlers never call the display module; they publish on the bus. Each handler's work, the
combat rollup, rejected-event reporting and the login diagram are in [data-flow.md](./data-flow.md).

### The per-unit frames are the unit-filter carve-out

The private frames above are not a deviation. events-frames-taint-§1 **permits** a private
`CreateFrame("Frame")` whose only job is to filter `UNIT_*` events to the units `RegisterUnitEvent`
names — the events-frames-taint-§1 unit-filter carve-out — and each of these meets its conditions:

- **Only that job.** Each frame gets exactly one `SetScript("OnEvent", onEvent)` and its
  `RegisterUnitEvent` calls for `UNIT_ABSORB_AMOUNT_CHANGED` / `UNIT_MAXHEALTH`, made through
  `NS.SafeRegisterUnitEvent` (the file-local `safeRegisterUnit` in `addon:SyncUnitEventFrames`),
  one unit token per frame. No other event, script or ticker is ever put on it.
- **Held.** The frames live at `addon.__unitEventFrames`, keyed by unit.
- **Torn down.** `StandDown` in `core/Lifecycle.lua` walks `addon.__unitEventFrames` and calls
  `UnregisterAllEvents` on each, so a disabled addon has no per-unit registration left
  (slash-commands-§7).
- **Created once, reused.** `SyncUnitEventFrames` builds the table only while
  `self.__unitEventFrames` is nil; every later call (the `UNITS` message, `StandUp`) changes only
  the registrations on the frames it already has.

They are the addon's only raw event frames; everything else rides AceEvent. The register row this
used to carry, filed as `AT-31` in `docs/audits/2026-08-05/`, was retired on 2026-09-24 once the
standard wrote the carve-out.

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
- **English only** — a ratified decision, not an unfinished job. The `NS.L` seam is exported and
  routes only the drag handle's strings; the row, and why it is compliant, is `localization-§1` in
  [Documented deviations](#documented-deviations) below, its single home.
- **Three bars — player, target, focus.** Group / raid / arena / boss units are out of scope
  ([scope.md](./scope.md)).
- **With LibKa0s missing, a disable leaves the bus subscriptions live.** `core/Bus.lua`'s
  untracked-target stub (`options-ui-§1`) still gives every receiver a private target, but it
  records nothing, so the latch's stand-down has no record to take down: the five bus
  subscriptions stay registered on a disabled addon. The show ladder and `NS.RequestRepaint` still
  answer to the latch, so nothing is drawn. The one receiver whose work is a REGISTRATION, the
  `UNITS` handler in `core/AbsorbTracker.lua` (it calls `SyncUnitEventFrames`), asks the latch
  first and does nothing while down, so a publish on a disabled addon cannot put the per-unit
  frames or the swap events back; StandUp re-syncs from current state (`tests/test_bus.lua` pins
  it on the degraded load). What is lost is the registration-level stand-down of the five bus
  subscriptions themselves on that one install shape, which is also already without Options, Slash
  and the rest of LibKa0s.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`) — except this
file, the hub the map itself lives in. Frozen and generated bundles are named once each and never enumerated per run: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`, `docs/superpowers/`, `docs/perf-analysis/<run>/`, `docs/investigations/`, `docs/revendor/`. The `README.md` beside the `<run>` folders (and `automated-tests/RESULTS.md`) are registered in the tables below.

The repo **root** ships exactly three docs plus `LICENSE`, and never a fourth: the player-facing
`README.md`, the `CLAUDE.md` stub and `DEPENDENCIES.md` (the toolchain contract). Everything else
lives under `docs/`.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created** (anti-pattern #49;
the standard deleted it in v2.17.0, and documentation-§3 says why a stored copy of the scaffolding pack
is followed rather than ignored). Root `CLAUDE.md` is the repo's only agent brief, and it points here.
Older bundles and plans under `docs/` that still name the file are frozen history: never "restore" it.

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
| `slash-dispatch.md` | Present | Eighteen verbs, over the eight-or-more threshold, and `profile` carries a subcommand tree (`PROFILE_VERBS`) |
| `midnight-quirks.md` | Present | Client-version workarounds of the addon’s own |
| `profiles.md` | Present | AceDB profiles are user-visible — the Profiles settings page |
| `message-bus.md` | Present | Spill target of the hub's ~60-line rule (the more-than-ten-message trigger is not met: five messages); the catalog table stays in `## Message Bus` |
| `compat-layer.md` | Not applicable | Not applicable — this addon calls no deprecated or version-variant client API outside LibKa0s's majors (compat, v2.65.0 applicability condition); the TOC metadata read is LibKa0s-Env-1.0's, reached through `core/EnvSetup.lua`, whose library-absent fallback is `C_AddOns` then nil |
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
| `automated-tests/RESULTS.md` | One row per run; generated, except the watch list's Disposition column |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `lifecycle.md` | The disabled state: the lifecycle latch, its two holds, what stands down and what survives |
| `launcher.md` | The minimap button and broker row: the one object, the click rung and its gate, the status tooltip, the visibility row, the icon |
| `recorded-decisions.md` | Retired register rows, and recorded choices that are not deviations |

## Documented deviations

Ratified departures from the Ka0s WoW Addon Standard, in the row shape `documentation-§3` fixes.
**This is the single home**: a decision may be reasoned at length in an audit bundle, a topic doc or
this repo's GitHub issues, and the row cites it — but a deviation that is not in this table is not
ratified. A fresh `/wow-addon:standards-audit` reads the register first and records a match as
accepted rather than re-filing it.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `savedvariables-§1` | A **per-profile** `schemaVersion` stamp at `db.profile.schemaVersion` (default `1`), alongside the account-wide stamp in `db.global` (default `0`, owned by the runner as §1 requires) | The v3 lift — flat appearance keys onto `profile.units.<unit>` — is a per-profile mutation, and an account-wide flag structurally cannot gate one: a second pre-v3 profile would have its stored appearance stranded forever. §1 also allows the raw `profiles` walk for a profile-scoped step, and the other profile-scoped steps (v2, v4, v5) take that route under the account-wide stamp; the v3 lift keeps its own stamp because `NS.OnProfileChanged` re-runs it for a profile that appears after the upgrade. Argument in full in [profiles.md](./profiles.md#the-v3-lift-and-why-the-gate-is-per-profile) | 2026-07-28 | AceDB gaining a per-profile version stamp of its own, or the last per-profile migration being retired |
| `events-frames-taint-§8` (SHOULD half) | 19 chat lines in `settings/Slash.lua` pre-format their arguments (`settings/Schema.lua`, the row's other file, has none left; re-measured 2026-09-24 with the grep `docs/audits/2026-09-23/03_EVIDENCE.md` records under `AT-78`, which counted 17 at that audit) — `print(("%s bar %s"):format(...))`, `print("Switched to profile '" .. name .. "'")` — instead of handing the parts to the shared printer as `print("fmt", a, b)` | **Re-graded, not deferred.** §8's pre-formatting MUST is now **scoped** to call sites whose arguments can reach a value read from one of the named combat-protected APIs (`UnitGetTotalAbsorbs`, `UnitHealth`/`UnitHealthMax`, threat, aura amounts); outside that trigger set it is a **SHOULD NOT**, because the risk is drift, not secrets. Every one of the 19 sites formats only values this addon owns — a version string, a unit label, a profile name, a user-typed hold value, a schema path — so none is in the trigger set and none can be handed a secret. The two sites that DO read `UnitGetTotalAbsorbs` (`core/AbsorbTracker.lua:225`, `:305`) already pass their arguments to the sink unformatted and guard with `NS.IsConcatSafe`; the seam's own guarantee (library stringifier, `table.concat`-based probe) is untouched and unconditional. Filed as `AT-35` in `docs/audits/2026-08-05/` against the pre-scoping text | 2026-08-05 | Any of these lines gaining an argument that is, or derives from, a return value of one of §8's named APIs — that site converts as a MUST — or §8's trigger set growing to cover one of them |
| `localization-§1` | This addon ships **English only**: the `NS.L` seam is exported and `locales/enUS.lua` ships, but user-facing strings are hardcoded English rather than routed through `NS.L`, except the unlocked drag handle's (`modules/Bar.lua`: the three unit labels and its two tooltips) and the library-absent line (`L["%s is unavailable: the LibKa0s library did not load."]`, keyed by its English text per localization-§2, printed by `settings/Slash.lua`'s library-absent stub for each schema verb, slash-commands-§1), which are routed and whose keys are the only ones `enUS.lua` lists. The disabled-verb refusal that used to be routed left the addon at LibKa0s v1.42.0, because `slash-commands-§7` makes that line the collection's wording rather than the addon's and `lib.L` does not reach it, and its key went with it — `enUS.lua` carries no key nothing reads, which `localization-§3` requires rather than merely permits | A deliberate decision, not a backlog item. `localization-§3` names this one of the routing SHOULD's **two terminal compliant states** — English-only, recorded — so this row IS the compliant end state and an audit records it as accepted rather than re-filing the SHOULD. Both localization MUSTs are met unconditionally: the seam is exported and `enUS.lua` ships, carrying no dead keys. Filed as `AT-30` in `docs/audits/2026-08-05/`; deferred twice before as [PLAN-02](https://github.com/tusharsaxena/AbsorbTracker/issues/24), closed here | 2026-08-05 | The first non-English locale file added to `locales/` |

The four rows retired on 2026-08-05, when the standard changed under them, and four choices recorded
because an audit would otherwise surface them cold (the `Helpers.__lastUnitCtx` test seam, the fixed
debug font and logo, no host window, the bootstrap spelling) are in
[recorded-decisions.md](./recorded-decisions.md). None of them is a deviation.

### Files over the 1500-line cap

`layout-§1` caps every **authored** `.lua` file this repository tracks at 1500 lines, `tests/`
included. Vendored code (`libs/`, `tests/_kit/`) is the only carve-out that reaches anything here;
nothing in this repo is generated non-shipping data, so the generated-data carve-out has no instance
and the runner hands the gate no exempt set. A file over the cap has three terminal states: peeled,
an open issue naming the seam a peel would follow, or a ratified row in the register above carrying
a re-check trigger. The census records which one, one row per over-cap file; the 1000-1500 band is
observed and dispositioned in the automated-tests watch list alone (`automated-tests-§4`).

Nothing is over the cap today. The largest authored file is `tests/test_helpers.lua` at 1447 lines,
measured on 2026-09-24 with `git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' |
xargs wc -l | sort -rn`. `tests/test_slashcmds.lua` was peeled into `tests/test_perfcmds.lua` when it
crossed the cap, and its value-hold cases later moved to `tests/test_debughold.lua` with the verb. The vendored `tests/_kit/test_layout_cap.lua` gates this census against the tree.

## Performance & Profiler Attribution

The addon is purely reactive — **no `OnUpdate`, no repeating ticker, no combat-log parsing, no
hot-path hooks**. Its whole runtime cost is a C-filtered `UNIT_*` event, a coalescing one-shot
repaint timer, and one bar update fanned across the three units.

The measurements, the profiler-attribution caveats and what the numbers do and do not cover are in
**[performance.md](performance.md)**.
