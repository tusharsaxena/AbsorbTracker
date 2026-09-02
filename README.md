# Ka0s Absorb Tracker

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1450165)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-544%2F544_passing-green)

![Logo](https://media.forgecdn.net/attachments/1659/653/absorbracker-logo-v2-jpg.jpg)

Ka0s Absorb Tracker shows your current absorb shield as a movable bar, so you can see at a glance how much damage you can soak up. It tracks up to **three bars at once — Player, Target, and Focus** (Target and Focus start off, turn them on when you want them). Move each bar anywhere on screen and restyle almost everything about it — its size, the bar and background textures and colors, the border, and the font — per bar, or link Target/Focus to live-copy the Player bar's look. The bar fill, background, border and the absorb number itself can each follow a class color if you prefer — the class of the bar's own unit.

Set it all up in the WoW Settings panel, or with the `/at` slash command.

## What's new in 1.9.0

- **Target and Focus absorb bars, each switched on independently.** Two new bars — off by default — track the same combined-absorb display for your current target and focus. Turn them on with **Enable Target Bar** / **Enable Focus Bar** on the General page; the old single **Show Bar** master toggle is gone, and a bar you turn off stops receiving events entirely rather than just hiding.
- **Mirror or copy the Player bar's look.** A Target/Focus bar can live-link to the Player bar's appearance ("Use same styling as Player"), or take a one-time snapshot with **Copy styling from Player** and then customize it independently.
- **Slash paths are now fully qualified.** `/at set units.player.barWidth 250` replaces the old unqualified `/at set barWidth 250` — see [Breaking change](#breaking-change-slash-paths) below if you have macros.
- **Show the bar only in combat.** A new General option hides the bar(s) out of combat and brings them back the moment you're fighting.
- **The bar now updates the instant a shield changes** instead of ticking on a timer, so it tracks your absorbs more smoothly.
- **A proper on-screen debug window, with a General-page toggle.** `/at debug` opens a styled window instead of spamming chat; `/at debug on` / `off` starts and stops logging, each line tagged with what triggered it, and the **Debug console** checkbox shows or hides the window without a slash command.

### Breaking change: slash paths

Every `/at set` and `/at get` path is now **fully qualified** with a unit — `/at set units.player.barWidth 250`, not the old `/at set barWidth 250`. If you have a macro or keybind using the old unqualified form, update it to the `units.player.setting` form (or `units.target.setting` / `units.focus.setting` for those bars). `/at list` and the settings panel are unaffected. `/at reset` takes a path of the same shape — `/at reset units.player.barWidth`.

## Screenshots

_**Absorb Tracker in Action**_

![Absorb Tracker in Action](https://media.forgecdn.net/attachments/1506/197/absorbtracker-schreenshot-1-png.png)

_**Settings Panel**_

![Settings Panel](https://media.forgecdn.net/attachments/1804/983/absorbtracker-screenshot-02-png.png)

![Settings Panel](https://media.forgecdn.net/attachments/1804/985/absorbtracker-screenshot-03-png.png)

![Settings Panel](https://media.forgecdn.net/attachments/1804/986/absorbtracker-screenshot-04-png.png)

## Usage

### Slash commands

Use either `/at` or the longer `/absorbtracker` for any of these. Messages from the addon show up in
chat with a cyan `[AT]` tag.

| Command | What it does |
|---------|--------------|
| `/at` or `/at help` | Show the list of commands |
| `/at config` | Open the settings panel |
| `/at list` | Show every setting and its current value (Appearance settings list once per bar — Player/Target/Focus) |
| `/at get name` | Show one setting's value. Appearance settings need the full path, e.g. `/at get units.player.barWidth` |
| `/at set name value` | Change one setting. Examples: `/at set units.player.barWidth 250`, `/at set units.target.useClassColorBar true`, `/at set visibility inCombat` |
| `/at reset path` | Reset one setting to its default — e.g. `/at reset units.player.barWidth`. To reset a whole page across all three bars, use that page's **Defaults** button in the settings panel |
| `/at resetall` | Reset every setting and move every bar back to center |
| `/at resetposition` | Move every bar back to its default screen position |
| `/at lock` / `/at unlock` | Lock or unlock the bars so you can drag them |
| `/at toggle` | Turn all the bars off, or all back on. `/at toggle target` flips just one bar (`player` / `target` / `focus`) |
| `/at update` | Refresh the bars now |
| `/at version` | Show the addon version |
| `/at test [value] [seconds]` | Fill the visible bars with a test value so you can preview your styling (default 50000 for 5 seconds) |
| `/at debug` | Toggle the debug window; `/at debug on` / `off` turns logging on or off |
| `/at perf` | Measure what the addon costs your CPU — run it on its own and it prints the workflow |
| `/at profile subcommand` | Manage profiles: `list`, `current`, `use name`, `new name`, `copy name`, `delete name`, `reset` |

Global settings (`enabled`, `visibility`, `scale`, `alpha`, `locked`, `throttleWindow`) use their plain name — `/at set locked true`. Only the per-bar appearance settings on the Appearance page need the `units.player|target|focus.` prefix.

### Settings panel

Three pages under **Ka0s Absorb Tracker**, each with a row of tabs across the top:

| Page | Tabs | Covers |
|------|------|--------|
| General | **Master controls**, **Bars** | *Master controls*: turn the whole addon off, choose when it shows at all (always / only in combat / only out of combat / never), scale and fade every bar together, lock them, show the debug console, and the two reset buttons. *Bars*: turn each bar on or off (Player / Target / Focus), and the repaint throttle — how fast the bars may redraw during a burst of changes. |
| Appearance | **Size**, **Bar**, **Background**, **Border**, **Text** | A **Unit** picker at the top of the page chooses which bar you are styling — Player, Target or Focus — and every tab below applies to that one. *Size*: width and height. *Bar*: fill texture, opacity, color. *Background*: texture and color behind the fill. *Border*: style, thickness, color. *Text*: font, size, color, flags and shadow for the absorb amount. |
| Profiles | — | Save different setups and switch between them. |

**Master scale and Master alpha are addon-wide.** They scale and fade all three bars together, and
they are a different setting from the per-bar **Bar opacity** on the Appearance page — that one dims
a single bar. The two multiply, so a bar at 50% opacity under a master alpha of 50% draws at 25%.

The Unit picker sits **once**, above the tabs, so switching from styling the Player bar to styling the Target bar is one click and every tab follows it.

**Target and Focus start off.** Tick **Enable Target Bar** or **Enable Focus Bar** on **General → Bars** to start tracking that unit — all three enable toggles sit together there, so you never have to touch the Unit picker to turn a bar on. An enabled target/focus bar only shows while you actually have that unit (no target/focus = no bar).

**Mirror or copy the Player bar.** While a Target/Focus bar has **Use same styling as Player** checked, it shares the Player bar's texture, colors, border, and font live — change the Player bar and the linked one updates too. Uncheck it to style that bar independently, or click **Copy styling from Player** to grab the Player bar's current look as a one-time starting point and then tweak it on its own. Position and whether the bar is enabled are never linked — each bar keeps its own.

To move a bar, type `/at unlock`, drag it into place, then `/at lock` to fix it there. Each bar remembers its own position.

**Class colors.** The bar fill, background, and border can each follow a class color instead of a
fixed color — as can the absorb number itself. Turn on the matching **Use class color** toggle on the
**Bar**, **Background**, **Border** or **Text** tab.

**Which class it follows changed in this version.** It is now the class of the bar's own unit: the
Player bar follows yours, the Target bar follows your target's, the Focus bar follows your focus's.
It used to be your own class on all three. A unit whose class the game cannot name — an NPC, a
critter, an empty target — falls back to the color you picked, never to a substitute shade.

The color picker beside the toggle stays usable either way, so you can set the color you want to fall
back to before or after you flip the toggle, in one visit. The opacity you set on that picker applies
under both — a class color carries a hue, not a transparency.

## How the bar works

Each enabled bar watches every absorb shield on its unit at once — Power Word: Shield, Ice Barrier,
trinket procs, and the rest — and adds them into a single total. That total is what the bar shows:

1. Whenever a tracked unit gains or loses a shield, the addon works out how much absorb is left.
2. The bar fills to match that amount, and the text shows the number in short form (like `1.2M`).
3. As the shields soak up damage or wear off, the bar drains toward 0.
4. With no shield up, the bar reads 0 and sits nearly empty.

So each bar is always a live picture of how much damage that unit can take before its health starts
dropping. The Target and Focus bars only show while you actually have that unit — clear your target
or focus and its bar disappears until you have one again.

## FAQ

| Question | Answer |
|----------|--------|
| Do I need to install anything else? | No. Everything the addon needs is bundled, so it works on its own. The bundled Ka0s library also registers a shared set of bar textures and fonts, so those show up in the dropdowns without any extra addon. Install a media pack (such as one that includes SharedMedia) if you want more choices than that. |
| Does this replace the shield display on my unit frames? | No. These are separate movable bars. Blizzard's shield overlay on the player, target, and focus frames is left alone — hide it in *Edit Mode* if you don't want to see both. |
| How do I turn on the Target or Focus bar? | General page → **Bars** tab → tick **Enable Target Bar** or **Enable Focus Bar**. It only appears while you actually have that target or focus set. |
| Can the Target/Focus bar match my Player bar automatically? | Yes — that's what **Use same styling as Player** does: it's a live link, so changes to the Player bar's look carry over immediately. Uncheck it any time to style that bar on its own, or use **Copy styling from Player** for a one-time copy you then customize independently. |
| How do I move a bar? | Type `/at unlock`, drag the bar you want where you want it, then `/at lock`. Each bar remembers its own position. Use `/at resetposition` to snap all of them back to their default spots. |
| Can I show the bars only while I'm fighting? | Yes. Set **General visibility** to *Only in combat* on **General ▸ Master controls**. Every enabled bar hides out of combat and reappears the instant you enter combat. |
| Can I have different setups? | Yes. Use the Profiles page in the settings panel to save and switch between setups. New characters start on the shared **Default** profile, so your changes carry over until you choose a separate setup. |
| Why is my bar empty? | The fill only shows a value when that unit has an active absorb shield — Power Word: Shield, Ice Barrier, a trinket proc, and so on. With no shield the fill sits empty, but you'll still see the bar's background and border where you placed it. |
| Why won't the settings panel open in combat? | WoW doesn't let addons change settings screens while you're fighting, so `/at config` answers with a gray "cannot open settings during combat" line instead. Run it again once you're out of combat and it opens normally. |
| What is the "Update throttle" setting for? | The bar redraws the moment a shield changes rather than on a timer. The throttle only caps how fast it can repaint during a burst of rapid changes — the default suits almost everyone, so you rarely need to touch it. |
| How do I see debug logs? | `/at debug` toggles the on-screen debug window; `/at debug on` / `off` starts and stops logging there instead of in chat. You can also toggle the window with the **Debug console** checkbox on the General page. Logging resets to off every reload. |
| An addon CPU profiler shows Absorb Tracker using a lot of CPU — is that real? | Almost certainly not. Its actual cost is tiny (~0.18% of one core). Wow addon profilers blame all of a shared library's work on whichever addon loaded it first, and because `AbsorbTracker` sorts near the top alphabetically it "owns" the shared Ace event frame and gets billed for *every* Ace addon's event traffic. Disabling Absorb Tracker just moves that CPU to the next addon in line. [Read the full investigation](https://github.com/tusharsaxena/absorbtracker/blob/master/docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md). |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| The Player bar never shows up | Check three things: **Enable Player Bar** is ticked on the General page (or run `/at toggle player`), the addon is enabled on the character-select screen, and — if **General visibility** is set to *Only in combat* — that you're actually in combat. The background and border show even with no shield, so if you see *nothing* at all the bar is hidden, not just empty. |
| The Target/Focus bar never shows up | Confirm **Enable Target Bar** / **Enable Focus Bar** is ticked on the General page. Even enabled, it only appears while you actually have that target or focus set — no target/focus means no bar, by design. |
| The bar(s) disappear when I leave combat | **General visibility** is set to *Only in combat*. Set it back to *Always* on **General ▸ Master controls**. |
| `/at test` does nothing | A bar has to be enabled to preview a test value on it. If every bar is off, run `/at toggle` (or tick an **Enable ... Bar** box) first, then try `/at test` again. |
| A bar won't stay where I put it | Lock it after positioning: `/at lock`, or tick **Lock frame** on **General ▸ Master controls**. Unlock again whenever you want to drag it. |
| My class color isn't showing | The bar has to be visible and have an active shield for the color to appear. Check that the matching **Use class color** toggle is on. Remember it follows the *bar's own unit* — a Target bar takes your target's class, and falls back to your picked color when there is no target to read one from. |
| Custom textures or fonts aren't in the dropdowns | Install a media pack addon (one that includes SharedMedia). Without one you still get WoW's built-in options plus the shared Ka0s textures and fonts the bundled library registers (JetBrains Mono, the face the debug console prints in, is one of them) — but nothing beyond those. |
| A bar's position resets after I log out | WoW only saves your settings on a clean logout. A crash or a force-quit can drop the last position. Log out through the menu and it will stick. |
| I want detailed logs | `/at debug` toggles a log window; `/at debug on` starts logging there instead of in chat. You can also open it from the **Debug console** checkbox on the General page. It resets to off every time you reload. |

## Issues and feature requests

Bugs, feature requests, and planned work are all tracked on GitHub:
[https://github.com/tusharsaxena/absorbtracker/issues](https://github.com/tusharsaxena/absorbtracker/issues).
Please file new reports there rather than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.9.0 | 2026-07-20 | Added **Target and Focus absorb bars**, each switched on independently from the General page — the old single **Show Bar** master toggle is gone, and a bar you turn off stops receiving events entirely<br>A Target/Focus bar can **mirror** the Player bar's look live, or take a one-time **Copy styling from Player** snapshot and then be customized on its own<br>`/at set` and `/at get` paths are now **fully qualified** — `/at set units.player.barWidth 250` replaces `/at set barWidth 250`; update any macros<br>Added a **Show only in combat** option that hides the bar out of combat<br>The bar now redraws the instant a shield changes instead of on a fixed timer, for smoother tracking<br>Added an on-screen debug window with a General-page **Debug console** toggle — `/at debug` opens it, `/at debug on`/`off` turns logging on or off (no more chat spam), each line tagged by what triggered it |
| 1.8.0 | 2026-05-03 | Redesigned the settings panel with breadcrumb navigation and an About page<br>Added a hold-time to `/at test` (`/at test value seconds`) and reshaped the Bar and Border pages |
| 1.7.0 | 2026-04-24 | Rebranded to **Ka0s Absorb Tracker** with new artwork<br>Split the settings into separate pages<br>Chat messages now use a cyan `[AT]` tag |
| 1.6.0 | 2026-02-14 | Added `/at` commands for the class-color options |
| 1.5.0 | 2026-02-14 | Added class colors for the bar fill, background, and border |
| 1.4.0 | 2026-02-05 | Long dropdowns now scroll and jump to the current selection |
| 1.3.0 | 2026-01-31 | Bundled everything the addon needs, so nothing has to be installed separately<br>Added screenshots for the public release |
| 1.1.0 | 2026-01-31 | Dependencies install automatically |
| 1.0.0 | 2026-01-31 | Initial release: movable absorb bar with configurable size, textures, colors, border, and font, plus saved setups |
