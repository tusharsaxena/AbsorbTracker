# Architecture

Orient-yourself map for **Ka0s Absorb Tracker** (modular layout). User-facing behavior is in
[../README.md](../README.md); the full agent brief is in [agent-context.md](./agent-context.md);
topic detail lives alongside this file in `docs/`.

## Overview

A single movable absorb status bar for the player, displaying the total of all active absorb
shields as one combined value. Reads `UnitGetTotalAbsorbs("player")` against
`UnitHealthMax("player")` on every event-driven, throttled repaint, paints a `BackdropTemplate` + `StatusBar`
+ `FontString` stack, and exposes every visual knob through both a five-page Blizzard Settings
panel and the `/at` slash CLI. Bar fill, background, and border each support an opt-in class-color
override; position is saved per-profile via AceDB. Retail Midnight only (Interface 120007),
English only.

The addon is an **AceAddon** (`core/AbsorbTracker.lua`) mixing in AceEvent / AceTimer / AceConsole.
`local addonName, NS = ...` is the shared private namespace bus in every file; there is no
`_G[addonName]` table.

## Module Map

Load order is dependency order (see `AbsorbTracker.toc`): Libraries → Core → Defaults → Locales →
Modules → Settings.

| File | Responsibility |
|------|----------------|
| `core/Compat.lua` | The only file that calls deprecated APIs. `Compat.GetAddOnMetadata` (C_AddOns → `_G` fallback). |
| `core/Constants.lua` | `NS.Constants`: fallback texture/border/font paths, `FONT_MONO` (debug console), `LOGO_PATH`. |
| `core/Namespace.lua` | `NS.name` / `NS.version` / `NS.PREFIX` (cyan `[AT]`) and the hot-path `floor`/`max` caches (`format` is cached here too but has no caller — a dead-export candidate). |
| `core/State.lua` | `NS.State` — session-only runtime state (the debug flag; never persisted). |
| `core/Util.lua` | `NS.Print` (prefixed chat) only. The secret-safe debug sink is `NS.Debug` (`core/DebugLog.lua`); every debug arg routes through `NS.SafeToString`. |
| `core/Data.lua` | The AceDB read/write seam (`GetSetting`/`SetSetting`), LSM fetchers with fallbacks, and the class-color-aware color resolvers. |
| `core/Database.lua` | `NS:InitDB` (AceDB + profile callbacks) and `NS:RunMigrations` (schema-version seam). |
| `core/LSMPatch.lua` | `NS.ApplyLSMBorderPatch` — collapses the upstream LSM30_Border preview tile; run once on enable. |
| `core/DebugLog.lua` | On-screen debug console (§12): `ScrollingMessageFrame`, monospace font, `FormatPlain`/`FormatColored`, `NS.Debug` sink, session-only enable. |
| `core/AbsorbTracker.lua` | AceAddon promotion; `OnInitialize` (font register, InitDB, slash register), `OnEnable` (the login sequence), event handlers, `OnProfileChanged`. |
| `defaults/Profile.lua` | `NS.defaults.profile` (bar settings) + `NS.defaults.global.schemaVersion`; `NS.flatDefaults` alias. |
| `locales/enUS.lua` | `NS.L` metatable-fallback locale (English source keys; nothing wrapped yet). |
| `modules/Bar.lua` | Builds the bar frame (`NS.bar`/`statusBar`/`valueText`/`backdropInfo`) at file load. |
| `modules/Display.lua` | `RestoreBarPosition`, `UpdateBarAppearance`, `UpdateAbsorbBar` (the paint path). |
| `modules/Timer.lua` | Coalescing repaint scheduler (`NS.RequestRepaint`) — a trailing-edge one-shot AceTimer throttle. |
| `settings/Schema.lua` | The schema registry + read/write seam (`SetByPath`), parse/format, and `ValidateSchema`. |
| `settings/Slash.lua` | AceConsole registration + the schema-driven `/at` dispatcher (`NS.COMMANDS`). |
| `settings/Panel.lua` | Settings-category registration shell; publishes `NS.Helpers`; combat-gated `OpenOptionsPanel`. |
| `settings/Helpers.lua` | Panel toolkit: layout constants, `CreatePanel`, section/scroll/tooltip, defaults/refresh registry, `LSMValues`. |
| `settings/ScrollPatch.lua` | Always-visible scrollbar override for the AceGUI ScrollFrame. |
| `settings/Widgets.lua` | Schema-row → AceGUI widget translation (`RenderField`/`RenderSchema`, four widget makers). |
| `settings/About.lua` | The parent page (logo + Notes + slash-command list). |
| `settings/{General,Bar,Border,Font,Profiles}.lua` | The five sub-pages; each registers schema rows + a deferred page builder — except Profiles, which registers no rows and renders AceDBOptions directly. |

## Settings Schema

`NS.Schema` is a flat array; each `settings/<page>.lua` calls `NS.RegisterSchemaRows({...})` at
file-load time. The same array drives both the AceGUI panel widgets (via
`Helpers.RenderSchema` / `Widgets.RenderField`) and the `/at list|get|set|reset|resetall` CLI —
adding an option is one schema row. All writes funnel through the single seam **`NS.SetByPath`**
(`SetSetting` + `fireOnChange`), whose `onChange` defaults to `UpdateBarAppearance`. Boot-time
`NS.ValidateSchema` checks each row's shape (`page`/`type` enums, non-empty `path`) **and** that
every `path` resolves against `NS.defaults.profile`; it returns `(errors, resolved, missing)` for
the test harness to assert. Row grammar detail: [schema.md](./schema.md).

## Message Bus

There is no closed AceEvent `SendMessage` bus. Modules are plain Lua files that hang functions on
the shared `NS` table and call each other through `NS.X` (resolved at call time, so forward
references across load order "just work"). Cross-cutting refresh runs through explicit calls:
`Helpers.RefreshAllPanels` (after `/at set` or a profile change) walks per-widget refresher
closures. The one real callback bus is **AceDB**: `NS.OnProfileChanged` is registered for
`OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` in `NS:InitDB` and repaints the bar +
refreshes an open panel.

## Slash Commands

Registered via AceConsole in `settings/Slash.lua`: `/at` and the alias `/absorbtracker` both
dispatch to `Sl:OnSlash`, which lower-cases only the verb (preserving case in the remainder so
schema paths survive) and looks it up in the ordered `NS.COMMANDS` table. Unknown verb →
`unknown command '<verb>'` then the help index (generated from `NS.COMMANDS`).

| Command | What it does |
|---------|--------------|
| `/at help` (or bare `/at`) | Print the help index |
| `/at config` (alias `/at options`) | Open the settings panel (combat-gated) |
| `/at list` | List every setting and its current value |
| `/at get <path>` | Print one setting's current value |
| `/at set <path> <value>` | Set one setting (typed: bool/number/string/color) |
| `/at reset <general\|bar\|border\|font>` | Reset one panel to defaults |
| `/at resetall` | Reset every setting and clear the saved position |
| `/at resetposition` | Return the bar to screen center |
| `/at lock` / `/at unlock` | Flip the drag lock |
| `/at toggle` | Flip bar visibility |
| `/at debug` (`on`/`off`) | Toggle the debug console window; `on`/`off` enable/disable logging |
| `/at update` | Force a bar refresh |
| `/at test [value] [hold-secs]` | Paint a fake value for visual tweaking |
| `/at profile <subcmd>` | Profile management (list/current/use/new/copy/delete/reset) |

## Event Subscriptions

AceAddon lifecycle in `core/AbsorbTracker.lua`:

- **`OnInitialize`** (ADDON_LOADED): register the monospace font with LSM, `NS:InitDB()`
  (AceDB + `RunMigrations` + profile callbacks), `NS.Slash:Register()`.
- **`OnEnable`** (PLAYER_LOGIN timing): reproduces the old login sequence in order —
  `ClearLSMCache` → `GetLSM` → `ApplyLSMBorderPatch` → `RestoreBarPosition` →
  `UpdateBarAppearance` → `UpdateAbsorbBar` (direct paint) → register events →
  `CreateOptionsPanel`.
- **Private unit-event frame** (the two `UNIT_*` events): `UNIT_ABSORB_AMOUNT_CHANGED` (bumps a
  debug-gated event counter, logs a non-secret `[Absorb]` shield up/gone transition when the value
  is concat-safe, then `NS.RequestRepaint()`) and `UNIT_MAXHEALTH` (`OnMaxHealthChanged` →
  `NS.RequestRepaint()` — the bar shows absorb as a fraction of max health) are registered on a
  private `CreateFrame("Frame")` via `RegisterUnitEvent(event, "player")`, **not** through AceEvent.
  This is a documented §9.1 deviation (see below): these events fire for *every* unit the client
  knows about (all raid members, pets, nameplates, target/focus), and AceEvent-3.0 routes all
  events through one shared frame with plain `RegisterEvent` and cannot `RegisterUnitEvent` (a frame
  can unit-filter at most two units) — so an AceEvent registration would pay a full C→Lua dispatch
  for every unit only to discard all but `"player"`. The private frame moves that filter to the C
  layer; the handler never fires for other units. The OnEvent stub routes to the same
  `addon:OnAbsorbChanged` / `addon:OnMaxHealthChanged` methods; it is created once and guarded
  against a disable/enable cycle.
- **AceEvent** subscriptions (registered in `OnEnable`): `PLAYER_ENTERING_WORLD` (`OnEnterWorld` →
  `NS.ApplyVisibility()` + `NS.RequestRepaint()`) and the combat-state pair `PLAYER_REGEN_DISABLED`
  (`OnEnterCombat`) / `PLAYER_REGEN_ENABLED` (`OnLeaveCombat`) — each re-applies
  `NS.ApplyVisibility()` (the `showOnlyInCombat` gate) and repaints. These are global, payload-free
  events with no unit to filter, so they stay on AceEvent. `OnLeaveCombat` is the sole handler of
  `PLAYER_REGEN_ENABLED` and does visibility + repaint only — it has no combat-deferred `/at config`
  to replay (the panel refuses to open in combat, options-ui-§2; see Taint Notes). `NS.RequestRepaint`
  is a coalescing one-shot AceTimer throttle (`throttleWindow`, default 0.1s) — idle = zero repaints,
  no polling ticker.

## Taint Notes

- **Combat-lockdown gate on `/at config` (refuse, options-ui-§2).** `Settings.OpenToCategory` is
  protected; calling it in combat taints the panel for the session. When `InCombatLockdown()` is
  true, `NS.OpenOptionsPanel` (`settings/Panel.lua`) **refuses** — it prints a single grey,
  `[AT]`-tagged notice (*"cannot open settings during combat — Blizzard's category-switch is
  protected"*) and returns, never touching the protected call. It does **not** defer-and-replay on
  `PLAYER_REGEN_ENABLED`; the user re-runs `/at config` after combat. The gate lives inside the
  open function, so every caller (slash verb, `/run`, internal) is refused.
- **Bar visibility Show/Hide is taint-free.** `AbsorbTrackerFrame` is a plain (non-secure) frame,
  so `NS.ApplyVisibility` calling `bar:Show()` / `bar:Hide()` on combat transitions (the
  `showOnlyInCombat` gate) carries no protected-frame restriction.
- **`SetBackdrop(nil)` before `SetBackdrop(info)`.** WoW's backdrop API is a no-op when the table
  identity is unchanged even if its fields changed; `UpdateBarAppearance` clears first.
- **Secret values.** `UnitGetTotalAbsorbs` may return a "secret" value — it is passed straight to
  `AbbreviateNumbers` / `StatusBar:SetValue`, never through `tonumber`.

## Known Limitations

- **Retail Midnight only** (Interface 120007); no game-flavor branching.
- **English only** — `NS.L` seam exists but no strings are wrapped yet.
- **Single bar** — one player absorb bar; multi-bar / other units are out of scope
  ([scope.md](./scope.md)).
- **No closed message bus** — cross-module calls are direct `NS.X` references, not
  `SendMessage`/`RegisterMessage`.

## Standards Deviations

Accepted, intentional departures from the Ka0s WoW Addon Standard. Each is recorded here with its
justification; a fresh `/standards-audit` will re-surface them into a new dated bundle under
`docs/audits/`.

- **§9.1 — private `CreateFrame` event frame for the two `UNIT_*` events.** `OnEnable`
  (`core/AbsorbTracker.lua`) registers `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` on a
  private frame via `RegisterUnitEvent(event, "player")` rather than through AceEvent-3.0.
  **Why:** both events fire for every unit the client knows about (raid, pets, nameplates,
  target/focus); AceEvent-3.0 uses a single shared frame with plain `RegisterEvent` and
  structurally cannot `RegisterUnitEvent` (a frame unit-filters at most two units), so an AceEvent
  registration pays a full C→Lua dispatch per unit only to discard all but `"player"` — a
  measurable combat CPU hotspot. A private unit-event frame is the established WoW pattern for this
  (BigWigs et al.). All other events (`PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_DISABLED/ENABLED`) stay
  on AceEvent. This is the *only* raw event frame; §9.1 otherwise holds.

## Performance & Profiler Attribution

The addon is purely reactive — **no `OnUpdate`, no repeating ticker, no combat-log parsing, no
hot-path hooks.** Its entire runtime cost is: player `UNIT_*` event (C-filtered) → `OnAbsorbChanged`
/ `OnMaxHealthChanged` → `NS.RequestRepaint` (coalescing one-shot AceTimer, `throttleWindow` default
0.1 s) → `NS.UpdateAbsorbBar`. After Finding 1 (above) the real cost is ~1.8 ms/s ≈ 0.18 % of one
core.

**Reading the in-game Addon Profiler (`C_AddOnProfiler`) — important caveat.** The profiler bills a
shared library's dispatch frame to **whichever addon created it (first to load that LibStub copy)**,
not to the addons whose callbacks it later serves. Because WoW loads addons **alphabetically** and
`AbsorbTracker` sorts near the top, it typically **owns the shared AceEvent/CallbackHandler event
frame** and is billed for *every* Ace-based addon's event dispatch. This makes it rank far higher
than its own work warrants (it out-ranked ElvUI). This is **not** waste and is **not fixable from the
addon** — a standalone Ace addon must ship AceEvent and may legitimately load first. It was proven by
a controlled disable test (the blame transferred to the next alphabetical Ace addon, AlterEgo).

Full analysis, exact numbers, and profiler screenshots:
[docs/investigations/2026-07-14-addon-profiler-attribution/](./investigations/2026-07-14-addon-profiler-attribution/analysis.md).
