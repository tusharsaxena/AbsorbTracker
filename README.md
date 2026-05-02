# Ka0s Absorb Tracker

![wow](https://img.shields.io/badge/WoW-Midnight_12.0.5-orange)
![CurseForge Version](https://img.shields.io/curseforge/v/1450165)
![license](https://img.shields.io/badge/license-MIT-green)

![alt text](https://media.forgecdn.net/attachments/1659/653/absorbracker-logo-v2-jpg.jpg)

AbsorbTracker is a lightweight, single-folder WoW addon that displays your total absorb shield value as a movable status bar. Bar size, fill texture and color, background texture and color, border style / size / color, and font face / size / outline are all independently configurable through LibSharedMedia-backed pickers. Bar fill, background, and border each have an opt-in class-color override, and the bar position is saved per-profile.

Everything is configurable through the standard Blizzard Settings panel and through the `/at` slash command (every panel control has a CLI peer via `/at get` / `/at set`).

## Screenshots

_**Absorb tracker bar in action — see the bar above the unit frame**_

![alt text](https://media.forgecdn.net/attachments/1506/197/absorbtracker-schreenshot-1-png.png)

_**Settings panel — invoked by /at config**_

![alt text](https://media.forgecdn.net/attachments/1506/198/absorbtracker-schreenshot-2-png.png)

## Usage

### Slash commands

Both `/at` and the long form `/absorbtracker` work for every command below. All chat output from the addon is prefixed with a cyan `[AT]`; in the help dump, each command renders in yellow and its description in white.

| Command | Description |
|---------|-------------|
| `/at` or `/at help` | Print the help index |
| `/at config` | Open the settings panel (lands on **General**). Also routed by `/at options` |
| `/at list` | List every schema-driven setting grouped by panel, with current values |
| `/at get <path>` | Print one setting's current value |
| `/at set <path> <value>` | Set one setting (typed: bool / number / string / color). Examples: `/at set barWidth 250`, `/at set barColor 0.4 0.7 1.0 0.8`, `/at set useClassColorBar true` |
| `/at reset <general\|bar\|border\|font>` | Reset one panel to defaults |
| `/at resetall` | Reset every setting to defaults and clear the saved bar position |
| `/at resetposition` | Return the bar to the screen center |
| `/at lock` / `/at unlock` | Flip the drag lock |
| `/at toggle` | Flip bar visibility |
| `/at update` | Force a bar refresh |
| `/at test [value]` | Paint the bar with a fake value (default 50000) for visual tweaking |
| `/at debug` | Toggle verbose `[AT]` chat output |
| `/at profile <subcmd>` | Profile management. Subcommands: `list`, `current`, `use <name>`, `new <name>`, `copy <name>`, `delete <name>`, `reset`. Requires AceDB-3.0 |

### Settings panel

Five subcategories under **Ka0s Absorb Tracker**:

*   **General** — Show Bar, drag lock, update interval (0.1–10s), Reset Position + Reset All Settings buttons.
*   **Bar** — width (50–500), height (10–100), fill texture and color, background texture and color (each color has a class-color override).
*   **Border** — border style, thickness (1–32), color (with class-color override).
*   **Font** — face, size (6–32), outline style.
*   **Profiles** — AceDBOptions UI. Requires AceDB-3.0.

Use `/at unlock` to drag the bar into position, then `/at lock` to fix it.

## Critical settings

### Class color overrides

Three independent toggles drive whether the bar fill, background, and border use your class color instead of a configured RGB:

*   `useClassColorBar` — bar fill uses your class color.
*   `useClassColorBg` — background uses a darkened class-color variant.
*   `useClassColorBorder` — border uses your class color.

When a toggle is on, the matching color picker greys out — flip the toggle off to re-enable manual color editing.

### Optional dependencies

*   **LibSharedMedia-3.0** — when present, the texture / border / font dropdowns offer the full SharedMedia catalog rendered as inline-preview swatches. Without it, the dropdowns fall back to a small set of Blizzard built-in constants.
*   **AceDB-3.0** — when present, full profile management via the `/at profile` subcommands and the **Profiles** sub-page. Without it, settings still persist but profile management is disabled.

Both libs ship in-tree under `libs/`, so the addon is fully self-contained.

## FAQ

| Question | Answer |
|----------|--------|
| Does this replace Blizzard's absorb shield display on unit frames? | No. AbsorbTracker is a brand-new movable bar; Blizzard's overlay on the player and target unit frames is untouched. Disable it in *Edit Mode* if you don't want both visible. |
| How do I move the bar? | `/at unlock`, drag, `/at lock`. The position saves per-profile. `/at resetposition` snaps the bar back to the screen center. |
| Are there profiles? Per-character configs? | Yes — full AceDB profiles under Settings → Profiles. Every character on the account starts on the shared **Default** profile, so changes carry over to every other character out of the box. Opt into per-character / per-class / per-realm scope from the Profiles panel if you want a character to diverge. |
| Why is my bar empty? | You need an active absorb effect (Power Word: Shield, Ice Barrier, trinket procs, …) for the value to be non-zero. With no absorb up, the bar reads 0 and is effectively invisible against the background. |
| Why does the settings panel refuse to open during a pull? | Blizzard's category-switching is protected, so opening *any* settings subcategory during combat would taint the panel. `/at config` errors out cleanly until combat ends. |

## Troubleshooting

| Problem | Resolution |
|---------|------------|
| The bar never appears | Check that `/at get hidden` is `false`, the addon is enabled at character-select, and you have an active absorb effect (without one the bar reads 0 and is effectively invisible). |
| Class color isn't applying | The bar must be visible *and* have an active absorb effect for the color to be observed. Confirm the toggle is on: `/at set useClassColorBar true` (or `useClassColorBg true` / `useClassColorBorder true`). The matching RGB picker greys out when the toggle is on — that's intentional, not a bug. |
| Custom textures or fonts don't show in the dropdowns | Install LibSharedMedia-3.0 (or any addon that bundles it). Without LSM, the dropdowns fall back to a short list of Blizzard constants. |
| Bar position resets after logout | WoW only writes `SavedVariables` on a clean logout — force-quitting the client (Alt-F4 mid-fight, crash, etc.) drops anything that hadn't been flushed. Log out via the menu and the position will persist. |
| `/at profile` errors or the Profiles sub-page is missing | AceDB-3.0 isn't loaded. The addon ships its own copy under `libs/Ace3/AceDB-3.0/`, so this should only happen if `libs/` was tampered with. Reinstall or restore. |
| Want verbose logging? | `/at debug` toggles a `[AT]` chat dump on every absorb-amount update. |

## Issues and feature requests

All bugs, feature requests, and outstanding work are tracked at [https://github.com/tusharsaxena/absorbtracker/issues](https://github.com/tusharsaxena/absorbtracker/issues). Please file new reports there rather than as comments — the issue tracker is the single source of truth for the project's backlog.

## Version History

| Version | Changes |
|---------|---------|
| 1.7.0 | TOC version bump |
| 1.6.0 | Updated slash commands for class color options added in v1.5.0 |
| 1.5.0 | Added a "class color" option for bar color, bckground color and border color<br>Updated libs |
| 1.4.0 | Replaced all dropdown selectors in the Settings panel with custom scrollable dropdowns<br>Dropdowns with 10 or more items now display a scrollbar<br>Opening a dropdown auto-scrolls to the currently selected value |
| 1.3.0 | Updated README.md for initial release |
| 1.2.0 | Removed pkgmeta and embedded libs directly |
| 1.1.0 | Added pkgmeta.yaml to install dependencies automatically |
| 1.0.0 | Initial Release … yay! |
