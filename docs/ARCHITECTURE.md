# Architecture

Orient-yourself map for **Ka0s Absorb Tracker** (modular layout). User-facing behavior is in
[../README.md](../README.md); the full agent brief is in [agent-context.md](./agent-context.md);
topic detail lives alongside this file in `docs/`.

## Overview

Three movable absorb status bars — player, target, and focus — each displaying the total of all
active absorb shields on that unit as one combined value. Target and focus ship disabled; when
enabled, either can "mirror" the player's appearance live, or take a one-shot "copy from player"
snapshot and then diverge. Every bar reads `UnitGetTotalAbsorbs(unit)` against `UnitHealthMax(unit)`
on every event-driven, throttled repaint, paints a `BackdropTemplate` + `StatusBar` + `FontString`
stack (`AbsorbTrackerFrame` / `AbsorbTrackerTargetFrame` / `AbsorbTrackerFocusFrame`), and exposes
every visual knob through both a five-page Blizzard Settings panel — with a Unit dropdown on the
Bar/Border/Font pages — and the `/at` slash CLI via fully-qualified `units.<unit>.<key>` paths. Bar
fill, background, and border each support an opt-in class-color override (always resolved from the
player, on all three bars); position is per-unit and saved per-profile via AceDB. Retail Midnight
only (Interface 120007), English only.

The addon is an **AceAddon** (`core/AbsorbTracker.lua`) mixing in AceEvent / AceTimer / AceConsole.
`local addonName, NS = ...` is the shared private namespace bus in every file; there is no
`_G[addonName]` table.

## Module Map

Load order is dependency order (see `AbsorbTracker.toc`): Libraries → Locales → Core → Defaults →
Modules → Settings.

| File | Responsibility |
|------|----------------|
| `core/Compat.lua` | The only file that calls deprecated APIs. `Compat.GetAddOnMetadata` (C_AddOns → `_G` fallback). |
| `core/Constants.lua` | `NS.Constants`: fallback texture/border/font paths, `FONT_MONO` (debug console), `LOGO_PATH`. |
| `core/Namespace.lua` | `NS.name` / `NS.version` / `NS.PREFIX` (cyan `[AT]`) and the hot-path `floor`/`max` caches. |
| `core/State.lua` | `NS.State` — session-only runtime state (the debug flag; never persisted). |
| `core/Bus.lua` | The closed cross-module message bus: `NS.bus` (shared publish target), `NS.NewBusTarget()` (one per receiver), and the `NS.MSG` catalogue (`REPAINT`/`APPEARANCE`/`VISIBILITY`/`POSITION`). |
| `core/Util.lua` | `NS.Print` (prefixed chat) only. The secret-safe debug sink is `NS.Debug` (`core/DebugLog.lua`); every debug arg routes through `NS.SafeToString`. |
| `core/Perf.lua` | `NS.Perf` — the performance probe (issue #17). `debugprofilestop()` brackets (`Note`/`Reset`), the suspend-state-bucketed FPS sampler (`Start`/`Stop`), `Suspend`/`Resume`, the shared `EncodeJSON`, and the `AbsorbTrackerPerfDB` capture ring (`Save`). Session-only; zero cost when capture is off. |
| `core/Data.lua` | The AceDB read/write seam (`GetSetting`/`SetSetting` — dotted-path aware, so `units.target.barWidth` and flat `locked` both work), LSM fetchers with fallbacks (each takes a `unit`, resolved through `NS.Units.Get`), and the class-color-aware color resolvers (each takes a `unit`; the class color itself is always the player's). |
| `core/Database.lua` | `NS:InitDB` (AceDB + profile callbacks) and `NS:RunMigrations` (schema-version seam). |
| `core/Units.lua` | `NS.Units` — unit identity (`LIST`/`LABEL`), mirror resolution (`IsMirrored`/`SourceUnit`/`Get`), per-unit position read/write, and `CopyFromPlayer`. The only file that reads `db.profile.units` for appearance. |
| `core/LSMPatch.lua` | `NS.ApplyLSMBorderPatch` — collapses the upstream LSM30_Border preview tile; run once on enable. |
| `core/DebugLog.lua` | On-screen debug console (§12): `ScrollingMessageFrame`, monospace font, `FormatPlain`/`FormatColored`, `NS.Debug` sink, session-only logging enable (`SetEnabled`), window visibility (`Show`/`Hide`/`Toggle`/`IsShown`), the §11 always-shown scrollbar (`UpdateScrollBar`) + bottom line counter (`UpdateStatus`), and `ConsoleCheckbox()` — the General page's checkbox spec that shows/hides the window (not the logging flag). |
| `core/AbsorbTracker.lua` | AceAddon promotion; `OnInitialize` (font register, InitDB, slash register), `OnEnable` (the login sequence), event handlers, `OnProfileChanged`. |
| `defaults/Profile.lua` | Three flat globals (`locked`/`showOnlyInCombat`/`throttleWindow` — there is no `hidden` master toggle; the per-unit `enabled` flags are the visibility switch) + `NS.defaults.profile.units.{player,target,focus}` (each unit's own appearance table, built by a factory so no table is shared across units) + `NS.defaults.global.schemaVersion = 3`; `NS.flatDefaults` alias, `NS.unitDefaults` (= `defaults.profile.units.player`, the canonical per-row default source for `settings/{Bar,Border,Font}.lua`). |
| `locales/enUS.lua` | `NS.L` metatable-fallback locale (English source keys; nothing wrapped yet). |
| `modules/Bar.lua` | `NS.CreateBar(unit, globalName)` builds one bar frame; `NS.bars` (keyed `player`/`target`/`focus`, frames `AbsorbTrackerFrame`/`AbsorbTrackerTargetFrame`/`AbsorbTrackerFocusFrame`) at file load, plus `NS.bar`/`statusBar`/`valueText`/`backdropInfo` as player aliases for pre-multi-unit call sites. Each bar owns its own `backdropInfo` table (border size differs per unit; `SetBackdrop` keys off table identity) and a `unitLabel` FontString above the frame naming its unit, shown only while unlocked. |
| `modules/Display.lua` | Every function takes a `unit` (defaulting to `"player"`): `RestoreBarPosition`, `UpdateBarAppearance`, `ShouldShowBar`/`ApplyVisibility` (the four-step visibility ladder), `UpdateAbsorbBar` (the paint path). `NS.ForEachUnit(fn)` and `NS.DefaultPosition(unit)` (stacks target/focus above the player bar) also live here. Subscribes to `APPEARANCE`/`VISIBILITY`/`POSITION` on its own `NS.Display.__ev` bus target, fanning each handler out over `NS.ForEachUnit` so the bus messages stay payload-free. |
| `modules/Timer.lua` | Coalescing repaint scheduler (`NS.RequestRepaint`) — a trailing-edge one-shot AceTimer throttle. |
| `settings/Schema.lua` | The schema registry + read/write seam (`SetByPath`), parse/format, and `ValidateSchema`. Rows carry `unit`, `alwaysPerUnit`, and `skipRender` fields; `SchemaForPage(page, unit)` filters to one unit's rows (or all, when `unit` is omitted); `PartitionUnitRows` splits a unit page into always-editable rows vs. mirror-hidden appearance rows; `ResolvePath`/`SetPath` walk dotted paths (`units.<unit>.<key>`) so flat globals and per-unit keys share one seam. |
| `settings/Slash.lua` | AceConsole registration + the schema-driven `/at` dispatcher (`NS.COMMANDS`). |
| `settings/Panel.lua` | Settings-category registration shell; publishes `NS.Helpers`; combat-gated `OpenOptionsPanel`. |
| `settings/Helpers.lua` | Panel toolkit: layout constants, `CreatePanel`, `EnsureDefaultsButton` (builds the header Defaults button lazily on first OnShow), section/scroll/tooltip, defaults/refresh registry, `LSMValues`. `RenderUnitPanel(ctx, pageKey)` draws the Unit dropdown + mirror header (checkbox + copy button, hidden-while-mirrored hint) via `Helpers.ClearScroll` (full rebuild) + `Widgets.lua`'s `RenderRows` for the filtered rows. |
| `settings/ScrollPatch.lua` | Always-visible scrollbar override for the AceGUI ScrollFrame. |
| `settings/Widgets.lua` | Schema-row → AceGUI widget translation (`RenderField`/`RenderSchema`, four schema widget makers), plus non-schema `SessionCheckbox` and the `RenderSchema` `pairWith` seam (the session Debug console checkbox, attached beside Enable Focus Bar). |
| `settings/About.lua` | The parent page (logo + Notes + slash-command list). |
| `settings/{General,Bar,Border,Font,Profiles}.lua` | The five sub-pages; each registers schema rows + a deferred page builder — except Profiles, which registers no rows and renders AceDBOptions directly. Bar/Border/Font each generate their rows once per unit in `NS.Units.LIST` (path prefixed `units.<unit>.`, tagged `unit = unit`) and defer their page render to `Helpers.RenderUnitPanel` instead of `Helpers.RenderSchema`; General has no Unit dropdown, but does carry the three `units.<unit>.enabled` toggles — the one place a per-unit path is edited outside that dropdown. |

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

Cross-module communication runs through a closed, named message bus (`core/Bus.lua`,
architecture-§4), not direct `NS.X` calls. Producers — the event layer (`core/AbsorbTracker.lua`),
the slash surface (`settings/Slash.lua`), the settings pages (`settings/{General,Schema}.lua`) and
the reset helpers (`settings/Helpers.lua`) — publish via `NS.bus:SendMessage(...)`. Each consumer
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
a profile change) walks per-widget refresher closures. The other callback bus is **AceDB**:
`NS.OnProfileChanged` is registered for `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` in
`NS:InitDB`; it republishes `POSITION` / `APPEARANCE` / `REPAINT` on the bus and refreshes an open
panel.

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
| `/at resetall` | Reset every setting, clear the saved position, and recenter the bar (shared `Helpers.RestoreAllDefaults` — the panel's Reset All button calls the same path) |
| `/at resetposition` | Clear **every** unit's saved position and re-anchor all three bars to their stacked defaults (shared `Helpers.ResetAllPositions` — the General page's Reset Position button calls the same path) |
| `/at lock` / `/at unlock` | Flip the drag lock |
| `/at toggle [player\|target\|focus]` | Bare: flip **every** bar — all off if any is on, otherwise all on. With a unit token: flip that one bar only. Writes `units.<unit>.enabled` through `SetByPath`, so it travels the same path as the General page checkbox |
| `/at debug` (`on`/`off`) | Toggle the debug console window; `on`/`off` enable/disable logging |
| `/at perf <sub>` | The performance probe (`core/Perf.lua`): `start [label]`/`finish` bracket a run, `measure a\|b` arm a combat-gated experiment, `report` print it, `dump` emit JSON, `suspend`/`resume` make the addon inert by hand. Its own `NS.COMMANDS` verb. See [performance.md](./performance.md) |
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
  — a documented §9.1 deviation (see below). One frame per unit rather than packing tokens two at a
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
  publishes `VisibilityChanged` (the `showOnlyInCombat` gate) and `RepaintRequested`. These three
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
  true, `NS.OpenOptionsPanel` (`settings/Panel.lua`) **refuses** — it prints a single grey,
  `[AT]`-tagged notice (*"cannot open settings during combat — Blizzard's category-switch is
  protected"*) and returns, never touching the protected call. It does **not** defer-and-replay on
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
- **English only** — `NS.L` seam exists but no strings are wrapped yet.
- **Three bars — player, target, focus.** Group / raid / arena / boss units are out of scope
  ([scope.md](./scope.md)).

## Standards Deviations

Accepted, intentional departures from the Ka0s WoW Addon Standard. Each is recorded here with its
justification; a fresh `/standards-audit` will re-surface them into a new dated bundle under
`docs/audits/`.

- **A second top-level SavedVariables global — `AbsorbTrackerPerfDB`.** The TOC declares it
  alongside `AbsorbTrackerDB`. It holds the perf capture ring (last 10 runs) and is deliberately
  **outside** the AceDB tree so diagnostic data never rides profile copy / reset / switch.
  A separate SavedVariables *file* was considered and rejected: WoW names the file after the addon
  and serialises every global it declares into that one file, so a separate file would require
  shipping a companion addon in its own sibling folder — a two-addon repo, with packaging and
  CurseForge knock-ons, for isolation a distinct global already provides.

- **`lizard` as an optional dev dependency (complexity reporting).** Python tooling in a Lua repo,
  used to generate `docs/complexity.md`. It is **not** part of the green gate
  (`lua tests/run.lua` + `luacheck .`) and nothing fails without it. Issue #17 assigns the
  standard's definition of a complexity rule to WowAddonStandards; this addon adopts whatever
  lands there.

- **Instrumentation hooks in hot paths.** `modules/Display.lua`, `modules/Timer.lua` and
  `core/AbsorbTracker.lua` carry `local t0 = Perf.on and debugprofilestop()` brackets. When capture
  is off this is an upvalue read, a field read and a boolean test — no call, no allocation. The
  claim is enforced, not asserted: `tests/perf.lua`'s `probeOverheadOff` / `probeOverheadOn`
  scenarios fail if a dormant bracket ever allocates more than an armed one.

- **§9.1 — private `CreateFrame` event frames for the `UNIT_*` events, one per unit.**
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
  *only* raw event frames; §9.1 otherwise holds.

- **§5.1 — a PER-PROFILE `schemaVersion` stamp alongside the account-wide one.** §5.1 puts the
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

- **A production test seam: `Helpers.__lastUnitCtx` (`settings/Helpers.lua`).**
  `Helpers.RenderUnitPanel` stashes the ctx it just rendered on `NS.Helpers.__lastUnitCtx`.
  **Why:** the per-page `ctx` tables are private to the `renderedPanels` list inside
  `settings/Helpers.lua`, so the headless harness has no other handle on a *live* rendered panel;
  without it, the entire per-unit render path (Unit dropdown, mirror header, row partition) would
  be reachable only through in-game smoke tests. It is a single dunder-prefixed field, written on
  every render and read by nothing in production — no behaviour depends on it. Recorded here rather
  than removed because the coverage it buys is worth more than the purity; if a public
  panel-registry accessor is ever added, this should collapse into it.

- **Non-Blizzard media that is intentionally fixed (no LSM selector).** The bar-appearance media —
  `barTexture`, `bgTexture` (both default `"Blizzard Raid Bar"`), `border` (`"Blizzard Tooltip"`) and
  `font` (`"Friz Quadrata TT"`) — is 100% Blizzard-stock by default and fully user-configurable
  through LSM (`LSM30_Statusbar`/`LSM30_Border`/`LSM30_Font` dropdowns in `settings/{Bar,Border,Font}.lua`,
  resolved via `lsm:Fetch` in `core/Data.lua` with Blizzard-stock fallbacks in `core/Constants.lua`).
  Two assets sit outside that model — non-Blizzard *and* deliberately not exposed as a user setting.
  Both are standard-sanctioned; they are recorded here only so a font/texture audit (or a fresh
  `/standards-audit`) re-surfaces them with their justification rather than flagging them:
  - **Debug-console font — `JetBrainsMono-Regular.ttf` (vendored, OFL).** `core/DebugLog.lua` renders
    the on-screen console in this fixed monospace face via `C.FONT_MONO`. It is registered with LSM as
    `"JetBrains Mono"` at init, but the console does not read a user font setting. **Why:** a fixed
    monospace face is required for column-aligned debug output (§12.2). The console's backdrop is
    Blizzard-stock (`WHITE8x8` fill + `UI-Tooltip-Border` edge).
  - **About-page logo — `media/logos/absorbracker.logo.v2.tga`.** `settings/About.lua` draws the
    addon's branding logo via `C.LOGO_PATH`. **Why:** addon branding, not bar appearance; a
    user-swappable logo would be meaningless. Stored under a typed media subfolder per §1.4.

## Performance & Profiler Attribution

The addon is purely reactive — **no `OnUpdate`, no repeating ticker, no combat-log parsing, no
hot-path hooks.** Its entire runtime cost is: a player/target/focus `UNIT_*` event (C-filtered) →
`OnAbsorbChanged` / `OnMaxHealthChanged` → `NS.RequestRepaint` (coalescing one-shot AceTimer,
`throttleWindow` default 0.1 s) → `NS.UpdateAbsorbBar` (fanned out over all three units). The
measurements below predate the multi-unit-bars feature (player-only at the time) and have not been
re-run; after Finding 1 (above) the real cost was ~1.8 ms/s ≈ 0.18 % of one core for the single-bar
build.

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

**Measuring it yourself (issue #17).** Because the built-in profiler cannot attribute cost past the
shared-frame problem above, the addon ships its own harnesses:

- `lua tests/perf.lua` — offline, headless, over the real addon code. Asserts deterministic counters
  (repaints per event burst, API calls per pass, bytes allocated per pass) and reports timings.
  **Outside the green gate** — wall-clock numbers are not stable enough to gate a commit on.
- `/at perf` — in-game. `debugprofilestop()` brackets on the addon's own entry points, plus an
  FPS sampler bucketed by suspend state so one session yields both arms of an A/B. `suspend` makes
  the addon inert **without a reload**, holding load order and shared-frame ownership fixed — the
  one thing the July 14 confound cannot reach.

Protocol, caveats and how to read the numbers: [docs/performance.md](./performance.md). Captured
records: [docs/perf-runs/](./perf-runs/README.md). Complexity: [docs/complexity.md](./complexity.md).
The current investigation into the reported in-combat FPS drop:
[docs/investigations/2026-07-29-combat-fps-drop/](./investigations/2026-07-29-combat-fps-drop/analysis.md).
