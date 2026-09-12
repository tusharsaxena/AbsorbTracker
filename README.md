# Ka0s Absorb Tracker

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1450165)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-565%2F565_passing-green)

Ka0s Absorb Tracker puts your absorb shields on screen as a movable bar. Every shield on the unit,
added into one number, so a glance tells you how much damage you can eat before your health starts
moving.

There are three bars: Player, Target and Focus - the last two ship switched off. Each one goes
anywhere on screen and can be restyled down to the texture, the border and the font, or linked to
the Player bar so it simply follows along. Fill, background, border and the absorb number itself
will each take a class color if you prefer — the class of that bar's own unit.

## Screenshots

_**Absorb Tracker in Action**_

![Absorb Tracker in Action](https://media.forgecdn.net/attachments/1936/457/absorbtracker-screenshot-01-png.png)

## Usage

On the first run after installing, the Player bar turns up centered and unlocked, so drag it where you want it and type
`/at lock` to pin it there. While the bars are unlocked each one paints a partial fill and its unit
name, so there is something to grab even with no shield up. To see a bar carrying a number instead,
`/at test` puts a fake absorb on every visible bar — 50000 held for five seconds by default, and
both of those are arguments if you want a bigger figure or a longer look at it. At least one bar
has to be enabled for the preview to land anywhere.

Tick **Enable Target Bar** or **Enable Focus Bar** on General → Bars to bring the other two up. All
three switches sit together there, next to **Update throttle**, so turning a bar on never means a
trip to the Appearance page. An enabled Target or Focus bar only draws while you actually have that
unit; clear your target and its bar goes with it. Positions are per bar, so unlock, drag and lock
again is a separate trip for each one.

Appearance is where the look lives, and a **Unit** picker above the tab strip decides which bar you
are editing. There is only one of it, above all five tabs, so switching bars is not a thing you
redo on every tab. Size, fill texture and color, background, border and the text of the absorb
number each get their own tab, and fill, background, border and text each carry a **Use class
color** toggle. The class is the bar's own unit's: your target's on the Target bar, not yours. A
unit whose class the game will not name — an NPC, a critter, an empty target — falls back to the
color you picked, and the picker beside the toggle stays usable either way. Opacity applies under
both, because a class color carries a hue and not a transparency. Rather than style the same bar
twice, tick **Use same styling as Player** and it tracks the Player bar's look live; **Copy styling
from Player** takes a snapshot instead and leaves you free to diverge afterwards.

General → Master controls governs all three bars at once: the addon's own off switch, **General
visibility** (always, only in combat, only out of combat, never), master scale, master alpha, the
lock, the debug console, and the two reset buttons. Master alpha is not the per-bar **Bar opacity**
on the Appearance page — that one dims a single bar, and the two multiply, so 50% under a master
alpha of 50% draws at 25%. General and Appearance each carry a **Defaults** button that reverts
that page across all three bars in one go. Profiles has a page to itself for saving setups and
switching between them; new characters start on the shared **Default** profile until you give one a
setup of its own.

Anything the panel does, `/at` does too. `/at list` prints every setting with its current value,
and `/at get` and `/at set` read and write one by its fully qualified path (`/at set
units.target.useClassColorBar true`); the globals — `enabled`, `visibility`, `scale`, `alpha`,
`locked`, `throttleWindow` — go by their plain names instead. Reverting comes in three widths:
`/at reset` for a single setting, `/at resetposition` to move every bar home, and `/at resetall` to
put the lot back and recenter them. `/at toggle` flips all the bars at once or one by name, `/at
update` forces a repaint, and `/at profile` and `/at perf` each print their own verbs when run
bare. Addon output arrives in chat behind a cyan `[AT]` tag.

Everything else is configuration, and it lives in two places: the addon's own page under Settings →
AddOns in game, and `/at` (or `/absorbtracker`), which prints the full command list.

## How the bar works

Each enabled bar watches every absorb on its unit at once — Power Word: Shield, Ice Barrier,
trinket procs, whatever else is up — and adds them into one total. That total is the bar.

1. A tracked unit gains or loses a shield, and the addon works out how much absorb is left.
2. The bar fills to match, with the number in short form (`1.2M`) written across it.
3. Damage and expiry drain it toward 0.
4. Nothing up, and the bar reads 0 and sits nearly empty.

So the bar is a live picture of how much a unit can take before its health starts dropping.

## FAQ

| Question | Answer |
|----------|--------|
| Do I need to install anything else? | No. Everything the addon needs is bundled, so it works on its own. The bundled Ka0s library also registers a shared set of bar textures and fonts, so those show up in the dropdowns without any extra addon. Install a media pack (such as one that includes SharedMedia) if you want more choices than that. |
| Does this replace the shield display on my unit frames? | No. These are separate movable bars. Blizzard's shield overlay on the player, target, and focus frames is left alone — hide it in *Edit Mode* if you don't want to see both. |
| How do I turn on the Target or Focus bar? | General page → **Bars** tab → tick **Enable Target Bar** or **Enable Focus Bar**. It only appears while you actually have that unit. |
| Can the Target/Focus bar match my Player bar automatically? | That is what **Use same styling as Player** is for. It is a live link, so anything you change on the Player bar carries over at once. Uncheck it whenever you want that bar styled on its own, or use **Copy styling from Player** for a one-time copy you then take in your own direction. |
| How do I move a bar? | Type `/at unlock`, drag the bar you want where you want it, then `/at lock`. Each bar remembers its own position. Use `/at resetposition` to snap all of them back to their default spots. |
| Can I show the bars only while I'm fighting? | Yes. Set **General visibility** to *Only in combat* on **General ▸ Master controls**. Every enabled bar hides out of combat and reappears the instant you enter combat. |
| Can I have different setups? | Yes. Use the Profiles page in the settings panel to save and switch between setups. New characters start on the shared **Default** profile, so your changes carry over until you choose a separate setup. |
| Why is my bar empty? | The fill only shows a value when that unit has an absorb up. With no shield it sits empty, though the background and border stay where you placed them. |
| Why won't the settings panel open in combat? | WoW doesn't let addons change settings screens while you're fighting, so `/at config` answers with a gray "cannot open settings during combat" line instead. Run it again once you're out of combat and it opens normally. |
| What is the "Update throttle" setting for? | The bar redraws the moment a shield changes rather than on a timer. The throttle only caps how fast it can repaint during a burst of rapid changes — the default suits almost everyone, so you rarely need to touch it. |
| How do I see debug logs? | `/at debug` toggles the on-screen debug window; `/at debug on` / `off` starts and stops logging there instead of in chat. You can also toggle the window with the **Debug console** checkbox on the General page. Logging resets to off every reload. |
| An addon CPU profiler shows Absorb Tracker using a lot of CPU — is that real? | Almost certainly not. Its actual cost is tiny (~0.18% of one core). Wow addon profilers blame all of a shared library's work on whichever addon loaded it first, and because `AbsorbTracker` sorts near the top alphabetically it "owns" the shared Ace event frame and gets billed for *every* Ace addon's event traffic. Disabling Absorb Tracker just moves that CPU to the next addon in line. [Read the full investigation](https://github.com/tusharsaxena/absorbtracker/blob/master/docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md). |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| The Player bar never shows up | Check that **Enable Player Bar** is ticked on the General page (or run `/at toggle player`) and that the addon is enabled on the character-select screen. If **General visibility** is *Only in combat*, you also have to be in combat. The background and border show even with no shield, so seeing *nothing* means the bar is hidden rather than empty. |
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
| 1.10.0 | 2026-09-10 | The settings panel is now three tabbed pages with a **Master controls** group, replacing the single scrolling wall<br>Target and Focus bars take composed appearance groups and unit-scoped class coloring<br>Fixed the unlocked placeholder fill vanishing when a bar repainted<br>Updated for game patch 12.1.0 |
| 1.9.0 | 2026-07-20 | Added **Target and Focus absorb bars**, each switched on independently from the General page — the old single **Show Bar** master toggle is gone, and a bar you turn off stops receiving events entirely<br>A Target/Focus bar can **mirror** the Player bar's look live, or take a one-time **Copy styling from Player** snapshot and then be customized on its own<br>`/at set` and `/at get` paths are now **fully qualified** — `/at set units.player.barWidth 250` replaces `/at set barWidth 250`; update any macros<br>Added a **Show only in combat** option that hides the bar out of combat<br>The bar now redraws the instant a shield changes instead of on a fixed timer, for smoother tracking<br>Added an on-screen debug window with a General-page **Debug console** toggle — `/at debug` opens it, `/at debug on`/`off` turns logging on or off (no more chat spam), each line tagged by what triggered it |
| 1.8.0 | 2026-05-03 | Redesigned the settings panel with breadcrumb navigation and an About page<br>Added a hold-time to `/at test` (`/at test value seconds`) and reshaped the Bar and Border pages |
| 1.7.0 | 2026-04-24 | Rebranded to **Ka0s Absorb Tracker** with new artwork<br>Split the settings into separate pages<br>Chat messages now use a cyan `[AT]` tag |
| 1.6.0 | 2026-02-14 | Added `/at` commands for the class-color options |
| 1.5.0 | 2026-02-14 | Added class colors for the bar fill, background, and border |
| 1.4.0 | 2026-02-05 | Long dropdowns now scroll and jump to the current selection |
| 1.3.0 | 2026-01-31 | Bundled everything the addon needs, so nothing has to be installed separately<br>Added screenshots for the public release |
| 1.1.0 | 2026-01-31 | Dependencies install automatically |
| 1.0.0 | 2026-01-31 | Initial release: movable absorb bar with configurable size, textures, colors, border, and font, plus saved setups |
