# Architecture

Orient-yourself map for **Ka0s Absorb Tracker**. This file is the high-level index; topic detail lives in `docs/`. User-facing behavior is in [README.md](./README.md); engineer rules + response style are in [CLAUDE.md](./CLAUDE.md).

## What it does

A single movable absorb status bar for the player, displaying the total of all active absorb shields as one combined value. Reads `UnitGetTotalAbsorbs("player")` against `UnitHealthMax("player")` on a periodic ticker, paints a `BackdropTemplate` + `StatusBar` + `FontString` stack, and exposes every visual knob through both a five-page Blizzard Settings panel and the `/at` slash CLI. Bar fill, background, and border each support an opt-in class-color override; position is saved per-profile via AceDB.

## Subsystems at a glance

```
WoW events ─▶ Events.lua  ─▶ C_Timer.NewTicker  ─▶ Display.UpdateAbsorbBar
                  │             (Timer.lua)              │
                  │                                      ▼
                  │                            statusBar:SetValue
                  │                            valueText:SetText (AbbreviateNumbers)
                  │
                  └─▶ AceDB callbacks ─▶ OnProfileChanged ─▶ RestoreBarPosition
                                                          + UpdateBarAppearance
                                                          + RestartUpdateTicker(true)
                                                          + RefreshOptionsPanel

  AceDB profile  ──  AddonTable.Schema  ──  Settings panel  +  /at slash CLI
       │                    │                      │                  │
       └────────────────────┴──── SetByPath / GetSetting ───────────────┘
                                       │
                                       ▼
                             onChange (default: UpdateBarAppearance)
```

| Subsystem | Lives in | Read |
|-----------|----------|------|
| Per-module APIs + `AddonTable` bus + load order | `Core.lua`, `Utils.lua`, `LSMPatch.lua`, `Settings.lua`, `Schema.lua`, `UI.lua`, `Display.lua`, `Timer.lua`, `Events.lua`, `SlashCommands.lua`, `OptionsPanel.lua` | [docs/module-map.md](./docs/module-map.md) |
| Per-file responsibility map | — | [docs/file-index.md](./docs/file-index.md) |
| Bootstrap + absorb update + settings write + profile-change refresh | `Events.lua`, `Display.lua`, `Timer.lua` | [docs/data-flow.md](./docs/data-flow.md) |
| Schema-driven settings (registry, row knobs, `/at` mapping, settings reference) | `Schema.lua`, `Options/*.lua` | [docs/schema.md](./docs/schema.md) |
| Multi-page Settings panel (canvas-layout shell, `Helpers` toolkit, two-column AceGUI render, LSM swatch widgets, about page) | `OptionsPanel.lua`, `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/` | [docs/settings-panel.md](./docs/settings-panel.md) |
| Profiles (AceDB integration + `/at profile` + fallback shim) | `Events.lua`, `Options/Profiles.lua`, `SlashCommands.lua` | [docs/profiles.md](./docs/profiles.md) |
| WoW retail API gotchas (secret values, backdrop refresh, combat lockdown, Interface line) | — | [docs/midnight-quirks.md](./docs/midnight-quirks.md) |
| In/out scope + resolved design decisions | — | [docs/scope.md](./docs/scope.md) |
| Routine recipes (add a setting, add a sub-page, troubleshoot LSM, bump Interface) | — | [docs/common-tasks.md](./docs/common-tasks.md) |
| Manual QA / smoke-test recipe (release checklist) | — | [docs/smoke-tests.md](./docs/smoke-tests.md) |

## Invariants worth not breaking

- **`AddonTable` is the bus.** Every file does `local AddonName, AddonTable = ...` and reads/writes shared state through `AddonTable`. Never shadow it locally (`local AddonTable = {}` would break everything downstream). The only WoW-required globals are `AbsorbTrackerDB`, `SLASH_ABSORBTRACKER1` / `SLASH_ABSORBTRACKER2`, and `AbsorbTrackerFrame`.
- **Schema is the single source of truth for settings.** `AddonTable.Schema` is a flat array; both the canvas-layout sub-pages (via `Helpers.RenderSchema`, which lays rows out as AceGUI widgets) and the slash dispatcher (via `/at list/get/set/reset/resetall`) walk it. Adding a new option = one schema row; the widget AND the CLI surface are wired automatically. No per-setting code in `SlashCommands.lua`. See [docs/schema.md](./docs/schema.md).
- **Color getters resolve at call time.** `GetBarColor` / `GetBgColor` / `GetBorderColor` re-read `useClassColor*` on every paint. Class change / respec / profile switch all work without explicit refresh wiring. Don't cache the resolved color.
- **`SetBackdrop(nil)` before `SetBackdrop(info)`.** WoW's backdrop API is a no-op when the table identity is unchanged, even if its fields changed. `UpdateBarAppearance` clears first, then re-applies. See [docs/midnight-quirks.md](./docs/midnight-quirks.md#setbackdrop-is-a-no-op-when-the-table-identity-is-unchanged).
- **`OpenOptionsPanel` early-returns on `InCombatLockdown()`.** `Settings.OpenToCategory` is protected; calling it during combat taints the panel. The combat-lockdown gate is mandatory.
- **Cyan `[AT]` prefix on all addon chat output.** Routes through `AddonTable.Print` → `|cFF00FFFF[AT]|r`. Files that emit chat shadow the global `print`. No raw `print(...)` calls.
- **Ticker drives visual updates, not events.** `UNIT_ABSORB_AMOUNT_CHANGED` is registered for `DebugPrint` only; the periodic `C_Timer.NewTicker` is the source of truth for `UpdateAbsorbBar` calls. `updateInterval` is user-configurable.
- **Canvas-layout parent + sub-pages, unified breadcrumb header.** `OptionsPanel.lua` registers a custom canvas frame for the "Ka0s Absorb Tracker" parent (rendering an about page: logo + TOC `Notes` + slash-command list) and one canvas frame per sub-page. Every page wears the same header (`GameFontNormalHuge` title in `"Ka0s Absorb Tracker | <Page>"` breadcrumb form + `Options_HorizontalDivider` atlas + optional Defaults button). The five sub-pages (General, Bar, Border, Font, Profiles) hold every setting; the parent never holds settings of its own. Profile / `/at set` refresh runs `Helpers.RefreshAllPanels`, which walks per-widget refresher closures rather than per-page namespaces.

## External dependencies

All vendored under `libs/`:

- LibStub
- CallbackHandler-1.0
- LibSharedMedia-3.0 (optional dep — addon falls back to `FALLBACK_*` Blizzard constants in `Settings.lua` when missing)
- AceAddon-3.0
- AceDB-3.0 (optional dep — addon falls back to a flat `AbsorbTrackerDB` shim when missing)
- AceGUI-3.0
- AceConfig-3.0 (pulls in AceConfigRegistry / AceConfigCmd / AceConfigDialog)
- AceDBOptions-3.0
- AceGUI-3.0-SharedMediaWidgets r65 (canonical upstream multi-file lib loaded via `widget.xml`; ships `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Background` / `LSM30_Font` / `LSM30_Sound` widgets — only the first three media types are referenced from the addon). The `LSM30_Border` displayButton 42×42 preview tile is suppressed at PLAYER_LOGIN by addon-side `LSMPatch.lua`, so future `r66+` lib refreshes are a clean drop-in

`AbsorbTracker.toc`'s `## Interface:` line is `120000, 120001, 120005`.

## Load order

`AbsorbTracker.toc` is the source of truth. Order is dependency, not alphabetical:

1. `libs/` (via the `#@no-lib-strip@` block) — LibStub + CallbackHandler + LSM + Ace3 stack + AceGUI-3.0-SharedMediaWidgets r65.
2. `Core.lua` — defaults + cached globals on `AddonTable`.
3. `Utils.lua` — `Print` / `DebugPrint`.
4. `LSMPatch.lua` — registers a `PLAYER_LOGIN` hook that wraps `LSM30_Border`'s registered constructor and hides upstream's displayButton preview tile.
5. `Settings.lua` — db access + LSM wrappers + color getters.
6. `Schema.lua` — schema registry + builders.
7. `UI.lua` — bar frame creation (runs at file-load time; frames exist before later modules need them).
8. `Display.lua` → `Timer.lua` → `Events.lua` → `SlashCommands.lua` → `OptionsPanel.lua`.
9. `Options/General.lua` → `Bar.lua` → `Border.lua` → `Font.lua` → `Profiles.lua` — each calls `RegisterSchemaRows` + `RegisterOptionsPage` at file-load time.

Event handlers and `OnProfileChanged` are *defined* during file load but only *called* from event dispatch and AceDB callbacks, which run after every file has loaded — so the bodies can freely reference modules that load later, guarded by the [forward-reference nil check](./docs/module-map.md#forward-references).

If you add a new runtime file, put it in the right place in `AbsorbTracker.toc`.
