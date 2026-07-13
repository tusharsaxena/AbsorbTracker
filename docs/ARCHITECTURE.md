# Architecture

Orient-yourself map for **Ka0s Absorb Tracker** (Tier 2, modular). User-facing behavior is in
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
| `core/Namespace.lua` | `NS.name` / `NS.version` / `NS.PREFIX` (cyan `[AT]`) and cached `floor`/`max`/`format`. |
| `core/State.lua` | `NS.State` — session-only runtime state (the debug flag; never persisted). |
| `core/Util.lua` | `NS.Print` (prefixed chat) + `NS.DebugPrint` (routes to the debug console when enabled). |
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
| `settings/{General,Bar,Border,Font,Profiles}.lua` | The five sub-pages; register schema rows + a deferred page builder. |

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
- **AceEvent** subscriptions (registered in `OnEnable`): `UNIT_ABSORB_AMOUNT_CHANGED` (records a
  debug line, then `NS.RequestRepaint()`), `UNIT_MAXHEALTH` (`OnMaxHealthChanged` →
  `NS.RequestRepaint()` — the bar shows absorb as a fraction of max health),
  `PLAYER_ENTERING_WORLD` (`OnEnterWorld` → `NS.ApplyVisibility()` + `NS.RequestRepaint()`), and the
  combat-state pair `PLAYER_REGEN_DISABLED` (`OnEnterCombat`) / `PLAYER_REGEN_ENABLED`
  (`OnLeaveCombat`) — each re-applies `NS.ApplyVisibility()` (the `showOnlyInCombat` gate) and
  repaints. `OnLeaveCombat` is the single owner of `PLAYER_REGEN_ENABLED` and also replays a
  combat-deferred `/at config` from `NS.State.panelOpenPending`. `NS.RequestRepaint` is a
  coalescing one-shot AceTimer throttle (`throttleWindow`, default 0.1s) — idle = zero repaints,
  no polling ticker.

## Taint Notes

- **Combat-lockdown gate on `/at config`.** `Settings.OpenToCategory` is protected; calling it in
  combat taints the panel for the session. `NS.OpenOptionsPanel` (`settings/Panel.lua`) queues the
  open by setting `NS.State.panelOpenPending` (idempotent) and posting a chat notice while
  `InCombatLockdown()` is true; `OnLeaveCombat` (`core/AbsorbTracker.lua`, the single owner of
  `PLAYER_REGEN_ENABLED`) replays it once combat ends.
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
