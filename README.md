# Ka0s Absorb Tracker

![wow](https://img.shields.io/badge/WoW-Midnight_12.0.7-orange)
![CurseForge Version](https://img.shields.io/curseforge/v/1450165)
![tests](https://img.shields.io/badge/tests-70%2F70_passing-brightgreen)
![license](https://img.shields.io/badge/license-MIT-green)
[![Ka0s Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-blue)](https://github.com/tusharsaxena/WowAddonStandards)

![alt text](https://media.forgecdn.net/attachments/1659/653/absorbracker-logo-v2-jpg.jpg)

AbsorbTracker is a lightweight WoW addon that displays your total absorb shield value as a movable
status bar. Bar size, fill texture and color, background texture and color, border style / size /
color, and font face / size / outline are all independently configurable through
LibSharedMedia-backed pickers. Bar fill, background, and border each have an opt-in class-color
override, and the bar position is saved per-profile.

Everything is configurable through the standard Blizzard Settings panel and through the `/at` slash
command (every panel control has a CLI peer via `/at get` / `/at set`).

## Screenshots

_**Absorb tracker bar in action — see the bar above the unit frame**_

![alt text](https://media.forgecdn.net/attachments/1506/197/absorbtracker-schreenshot-1-png.png)

_**Settings panel — invoked by /at config**_

![alt text](https://media.forgecdn.net/attachments/1506/198/absorbtracker-schreenshot-2-png.png)

## Usage

### Slash commands

Both `/at` and the long form `/absorbtracker` work for every command below. All chat output from
the addon is prefixed with a cyan `[AT]`; in the help dump, each command renders in yellow and its
description in white.

| Command | Description |
|---------|-------------|
| `/at` or `/at help` | Print the help index |
| `/at config` | Open the settings panel (lands on the parent **Ka0s Absorb Tracker** about page with the sub-page tree expanded). Also routed by `/at options` |
| `/at list` | List every schema-driven setting grouped by panel, with current values |
| `/at get <path>` | Print one setting's current value |
| `/at set <path> <value>` | Set one setting (typed: bool / number / string / color). Examples: `/at set barWidth 250`, `/at set barColor 0.4 0.7 1.0 0.8`, `/at set useClassColorBar true` |
| `/at reset <general\|bar\|border\|font>` | Reset one panel to defaults |
| `/at resetall` | Reset every setting to defaults and clear the saved bar position |
| `/at resetposition` | Return the bar to the screen center |
| `/at lock` / `/at unlock` | Flip the drag lock |
| `/at toggle` | Flip bar visibility |
| `/at update` | Force a bar refresh |
| `/at test [value] [hold-secs]` | Paint the bar with a fake value (default 50000) for the given duration (default 5 s) for visual tweaking |
| `/at debug` | Open the on-screen debug console. `/at debug on` / `/at debug off` enable/disable session logging |
| `/at profile <subcmd>` | Profile management. Subcommands: `list`, `current`, `use <name>`, `new <name>`, `copy <name>`, `delete <name>`, `reset`. Requires AceDB-3.0 |

### Settings panel

Five subcategories under **Ka0s Absorb Tracker**:

*   **General** — Show Bar, **show only in combat**, drag lock, update throttle (0.05–1s), Reset Position + Reset All Settings buttons.
*   **Bar** — width (50–500), height (10–100), fill texture and color, background texture and color (each color has a class-color override).
*   **Border** — border style, thickness (1–32), color (with class-color override).
*   **Font** — face, size (6–32), outline style.
*   **Profiles** — AceDBOptions UI. Requires AceDB-3.0.

Use `/at unlock` to drag the bar into position, then `/at lock` to fix it.

**Class-color overrides.** Three independent toggles drive whether the bar fill, background, and
border use your class color instead of a configured RGB: `useClassColorBar` (bar fill),
`useClassColorBg` (a darkened class-color variant for the background), and `useClassColorBorder`
(border). When a toggle is on, the matching color picker greys out — flip the toggle off to
re-enable manual color editing.

## FAQ

| Question | Answer |
|----------|--------|
| Do I need any libraries? | No — everything ships vendored under `libs/`, so the addon is fully self-contained. **LibSharedMedia-3.0** (when present) fills the texture / border / font dropdowns with the full SharedMedia catalog as inline-preview swatches; without it they fall back to Blizzard built-ins. **AceDB-3.0** (when present) enables profile management via `/at profile` and the Profiles sub-page; without it settings still persist but profiles are disabled. |
| Does this replace Blizzard's absorb shield display on unit frames? | No. AbsorbTracker is a brand-new movable bar; Blizzard's overlay on the player and target unit frames is untouched. Disable it in *Edit Mode* if you don't want both visible. |
| How do I move the bar? | `/at unlock`, drag, `/at lock`. The position saves per-profile. `/at resetposition` snaps the bar back to the screen center. |
| Are there profiles? Per-character configs? | Yes — full AceDB profiles under Settings → Profiles. Every character on the account starts on the shared **Default** profile, so changes carry over. Opt into per-character / per-class / per-realm scope from the Profiles panel to diverge. |
| Why is my bar empty? | You need an active absorb effect (Power Word: Shield, Ice Barrier, trinket procs, …) for the value to be non-zero. With no absorb up, the bar reads 0 and is effectively invisible against the background. |
| Why doesn't the settings panel open during a pull? | Blizzard's category-switching is protected, so opening *any* settings subcategory during combat would taint the panel. `/at config` in combat is **refused** with a short notice — just run `/at config` again once you're out of combat and it opens normally. |

## Troubleshooting

| Problem | Resolution |
|---------|------------|
| The bar never appears | Check that `/at get hidden` is `false`, the addon is enabled at character-select, and you have an active absorb effect (without one the bar reads 0 and is effectively invisible). |
| Why does my bar disappear out of combat? | You have **Show only in combat** enabled (General panel, or `/at set showOnlyInCombat false`). The master **Show Bar** toggle still hides it entirely. |
| Class color isn't applying | The bar must be visible *and* have an active absorb effect for the color to be observed. Confirm the toggle is on: `/at set useClassColorBar true` (or `useClassColorBg true` / `useClassColorBorder true`). The matching RGB picker greys out when the toggle is on — that's intentional, not a bug. |
| Custom textures or fonts don't show in the dropdowns | Install LibSharedMedia-3.0 (or any addon that bundles it). Without LSM, the dropdowns fall back to a short list of Blizzard constants. |
| Bar position resets after logout | WoW only writes `SavedVariables` on a clean logout — force-quitting the client (Alt-F4 mid-fight, crash, etc.) drops anything that hadn't been flushed. Log out via the menu and the position will persist. |
| `/at profile` errors or the Profiles sub-page is missing | AceDB-3.0 isn't loaded. The addon ships its own copy under `libs/AceDB-3.0/`, so this should only happen if `libs/` was tampered with. Reinstall or restore. |
| Want verbose logging? | `/at debug` opens an on-screen console; `/at debug on` starts logging absorb-update activity there (not in your chat frame). Logging resets to off on every `/reload`. |

## Issues and feature requests

All bugs, feature requests, and outstanding work are tracked at
[https://github.com/tusharsaxena/absorbtracker/issues](https://github.com/tusharsaxena/absorbtracker/issues).
Please file new reports there rather than as comments — the issue tracker is the single source of
truth for the project's backlog.

If you're filing a regression, the manual QA recipe at [docs/smoke-tests.md](./docs/smoke-tests.md)
is the same checklist used before each release.

## Testing

Ka0s Absorb Tracker ships a headless test harness and a lint gate; both must be green before every
commit and before tagging a release.

| Check | Command | Expected |
|-------|---------|----------|
| Unit tests | `lua tests/run.lua` | all suites green (schema parse/format/validate, DB migrations, Compat, secret-safe Util, DebugLog, slash dispatch, repaint timer/throttle, combat-visibility) |
| Lint | `luacheck .` | `0 warnings / 0 errors` |
| Syntax-check one file | `luac -p <path/to/file.lua>` | no output (clean parse) |
| Case inventory | `lua tests/run.lua --list` | regenerates [docs/test-cases.md](./docs/test-cases.md) — the authoritative case list & pass count |
| In-game smoke tests | manual | see [docs/smoke-tests.md](./docs/smoke-tests.md) |

The generated [docs/test-cases.md](./docs/test-cases.md) is the authoritative test-case count; the
`tests` badge above is hand-maintained alongside it (see [docs/testing.md](./docs/testing.md)).
Toolchain: Lua 5.1 + luacheck (`sudo apt-get install -y lua5.1 luarocks && sudo luarocks install
luacheck`). Run the full gate after bumping `## Interface:` or refreshing vendored libs, and run
the in-game smoke tests before every release.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.9.0 | 2026-07-12 | Added an on-screen debug console — `/at debug` opens it, `/at debug on`/`off` toggles logging (no more chat spam)<br>Rebuilt on the Ka0s Tier-2 standard and the Ace3 substrate (AceAddon / AceEvent / AceTimer / AceConsole) — behavior-preserving<br>Added a schema-version migration seam, a headless test harness (36 tests), and a `luacheck` lint gate<br>Re-vendored libraries folder-per-lib; moved media into `media/logos` + `media/fonts` (vendored JetBrains Mono)<br>Normalized docs to the standard (README `## Testing`, `docs/ARCHITECTURE.md`, CLAUDE stub, in-game smoke-test suite) |
| 1.8.0 | 2026-05-03 | Overhauled the Settings panel onto a canvas + AceGUI stack with breadcrumb headers and an About page<br>Refactored the options panel into a toolkit and routed all writes through a single `SetByPath` seam<br>Vendored upstream `AceGUI-3.0-SharedMediaWidgets`; `/at config` now opens the parent unfolded<br>Added a `[hold-secs]` argument to `/at test`; reshaped the Bar and Border panels; breadcrumb separator switched to an atlas chevron<br>Correctness fixes (API order, fallback deep-copy, color-picker throttle) and dead-code cleanup |
| 1.7.0 | 2026-04-24 | Rebranded to **Ka0s Absorb Tracker** with new LICENSE and media assets<br>Made the settings schema-driven and split into multi-page Blizzard subcategories; rewrote the slash dispatcher around the schema<br>Centralized chat output through a cyan `[AT]` prefix helper<br>Normalized on-disk line endings to CRLF; added `ARCHITECTURE.md` |
| 1.6.0 | 2026-02-14 | Added `/at` slash-command coverage for the class-color options |
| 1.5.0 | 2026-02-14 | Added class-color overrides for bar fill, background, and border<br>Updated bundled libs |
| 1.4.0 | 2026-02-05 | Replaced Settings-panel dropdowns with scrollable variants<br>Dropdowns with 10+ items get a scrollbar and auto-scroll to the current selection |
| 1.3.0 | 2026-01-31 | Embedded libs directly in-tree (dropped `pkgmeta`)<br>Rewrote `README.md` with screenshots for the public release |
| 1.1.0 | 2026-01-31 | Added `pkgmeta.yaml` to install dependencies automatically |
| 1.0.0 | 2026-01-31 | Initial release: movable absorb bar, configurable size / textures / colors / border / font, AceDB profile support, in-combat settings-panel guard |
