# Ka0s Absorb Tracker

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1450165)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-470%2F470_passing-green)

![Logo](https://media.forgecdn.net/attachments/1659/653/absorbracker-logo-v2-jpg.jpg)

Ka0s Absorb Tracker shows your current absorb shield as a movable bar, so you can see at a glance how much damage you can soak up. It tracks up to **three bars at once — Player, Target, and Focus** (Target and Focus start off, turn them on when you want them). Move each bar anywhere on screen and restyle almost everything about it — its size, the bar and background textures and colors, the border, and the font — per bar, or link Target/Focus to live-copy the Player bar's look. The bar fill, background, and border can each follow your class color if you prefer.

Set it all up in the WoW Settings panel, or with the `/at` slash command.

## What's new in 1.9.0

- **Target and Focus absorb bars.** Two new bars — off by default — track the same combined-absorb display for your current target and focus. Turn them on with **Enable Target Bar** / **Enable Focus Bar** on the General page.
- **Each bar is switched on independently.** The old single **Show Bar** master toggle is gone; the three per-bar enable checkboxes replace it, and a bar you turn off stops receiving events entirely rather than just hiding.
- **Mirror or copy the Player bar's look.** A Target/Focus bar can live-link to the Player bar's appearance ("Use same styling as Player"), or take a one-time snapshot with **Copy styling from Player** and then customize it independently.
- **Slash paths are now fully qualified.** `/at set units.player.barWidth 250` replaces the old unqualified `/at set barWidth 250` — see [Breaking change](#breaking-change-slash-paths) below if you have macros.
- **Show the bar only in combat.** A new General option hides the bar(s) out of combat and brings them back the moment you're fighting.
- **The bar now updates the instant a shield changes** instead of ticking on a timer, so it tracks your absorbs more smoothly.
- **A proper on-screen debug window.** `/at debug` opens a styled window instead of spamming chat; `/at debug on` / `off` starts and stops logging, and each line is tagged with what triggered it.
- **A Debug console toggle on the General page** to show or hide that window without a slash command.

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
| `/at list` | Show every setting and its current value (Bar/Border/Font settings list once per bar — Player/Target/Focus) |
| `/at get name` | Show one setting's value. Bar/Border/Font settings need the full path, e.g. `/at get units.player.barWidth` |
| `/at set name value` | Change one setting. Examples: `/at set units.player.barWidth 250`, `/at set units.target.useClassColorBar true`, `/at set showOnlyInCombat true` |
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

Global settings (`showOnlyInCombat`, `locked`, `throttleWindow`) use their plain name — `/at set locked true`. Only the per-bar appearance settings on the Bar/Border/Font pages need the `units.player|target|focus.` prefix.

### Settings panel

Five pages under **Ka0s Absorb Tracker**:

| Tab | Covers |
|-----|--------|
| General | Turn each bar on or off (Player / Target / Focus), show them only in combat, lock the bars, show or hide the debug console, and the repaint throttle (how fast the bars may redraw during a burst of changes). Buttons to reset the position or all settings. |
| Bar | A **Unit** dropdown to pick Player/Target/Focus, then that bar's width and height, plus its bar and background textures and colors. |
| Border | Same Unit dropdown, then border style, thickness, and color for the selected bar. |
| Font | Same Unit dropdown, then font face, size, and outline for the selected bar. |
| Profiles | Save different setups and switch between them. |

**Target and Focus start off.** Tick **Enable Target Bar** or **Enable Focus Bar** in **General → Master controls** to start tracking that unit — all three enable toggles sit together there, so you never have to hunt through the Unit dropdown to turn a bar on. An enabled target/focus bar only shows while you actually have that unit (no target/focus = no bar).

**Mirror or copy the Player bar.** While a Target/Focus bar has **Use same styling as Player** checked, it shares the Player bar's texture, colors, border, and font live — change the Player bar and the linked one updates too. Uncheck it to style that bar independently, or click **Copy styling from Player** to grab the Player bar's current look as a one-time starting point and then tweak it on its own. Position and whether the bar is enabled are never linked — each bar keeps its own.

To move a bar, type `/at unlock`, drag it into place, then `/at lock` to fix it there. Each bar remembers its own position.

**Class colors.** The bar fill, background, and border can each follow your class color instead of a
fixed color — just turn on the matching **Use Class Color** toggle on the Bar or Border page (this
follows *your* class regardless of which unit's bar you're styling — Target/Focus don't get their
own class colors). While a toggle is on, its color picker grays out; turn the toggle off to pick a
color by hand again.

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
| Do I need to install anything else? | No. Everything the addon needs is bundled, so it works on its own. Install a media pack (such as one that includes SharedMedia) if you want extra textures and fonts in the dropdowns. |
| Does this replace the shield display on my unit frames? | No. These are separate movable bars. Blizzard's shield overlay on the player, target, and focus frames is left alone — hide it in *Edit Mode* if you don't want to see both. |
| How do I turn on the Target or Focus bar? | General page → Master controls → tick **Enable Target Bar** or **Enable Focus Bar**. It only appears while you actually have that target or focus set. |
| Can the Target/Focus bar match my Player bar automatically? | Yes — that's what **Use same styling as Player** does: it's a live link, so changes to the Player bar's look carry over immediately. Uncheck it any time to style that bar on its own, or use **Copy styling from Player** for a one-time copy you then customize independently. |
| How do I move a bar? | Type `/at unlock`, drag the bar you want where you want it, then `/at lock`. Each bar remembers its own position. Use `/at resetposition` to snap all of them back to their default spots. |
| Can I show the bars only while I'm fighting? | Yes. Turn on **Show only in combat** on the General page. Every enabled bar hides out of combat and reappears the instant you enter combat. |
| Can I have different setups? | Yes. Use the Profiles page in the settings panel to save and switch between setups. New characters start on the shared **Default** profile, so your changes carry over until you choose a separate setup. |
| Why is my bar empty? | The fill only shows a value when that unit has an active absorb shield — Power Word: Shield, Ice Barrier, a trinket proc, and so on. With no shield the fill sits empty, but you'll still see the bar's background and border where you placed it. |
| Why won't the settings panel open in combat? | WoW doesn't let addons change settings screens while you're fighting, so `/at config` answers with a gray "cannot open settings during combat" line instead. Run it again once you're out of combat and it opens normally. |
| What is the "Update throttle" setting for? | The bar redraws the moment a shield changes rather than on a timer. The throttle only caps how fast it can repaint during a burst of rapid changes — the default suits almost everyone, so you rarely need to touch it. |
| How do I see debug logs? | `/at debug` toggles the on-screen debug window; `/at debug on` / `off` starts and stops logging there instead of in chat. You can also toggle the window with the **Debug console** checkbox on the General page. Logging resets to off every reload. |
| An addon CPU profiler shows Absorb Tracker using a lot of CPU — is that real? | Almost certainly not. Its actual cost is tiny (~0.18% of one core). Wow addon profilers blame all of a shared library's work on whichever addon loaded it first, and because `AbsorbTracker` sorts near the top alphabetically it "owns" the shared Ace event frame and gets billed for *every* Ace addon's event traffic. Disabling Absorb Tracker just moves that CPU to the next addon in line. [Read the full investigation](https://github.com/tusharsaxena/absorbtracker/blob/master/docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md). |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| The Player bar never shows up | Check three things: **Enable Player Bar** is ticked on the General page (or run `/at toggle player`), the addon is enabled on the character-select screen, and — if **Show only in combat** is on — that you're actually in combat. The background and border show even with no shield, so if you see *nothing* at all the bar is hidden, not just empty. |
| The Target/Focus bar never shows up | Confirm **Enable Target Bar** / **Enable Focus Bar** is ticked on the General page. Even enabled, it only appears while you actually have that target or focus set — no target/focus means no bar, by design. |
| The bar(s) disappear when I leave combat | You have **Show only in combat** turned on. Turn it off on the General settings page. |
| `/at test` does nothing | A bar has to be enabled to preview a test value on it. If every bar is off, run `/at toggle` (or tick an **Enable ... Bar** box) first, then try `/at test` again. |
| A bar won't stay where I put it | Lock it after positioning: `/at lock`, or turn on **Lock Position** on the General page. Unlock again whenever you want to drag it. |
| My class color isn't showing | The bar has to be visible and have an active shield for the color to appear. Check that the matching **Use Class Color** toggle is on. When it's on the color picker grays out — that's normal. |
| Custom textures or fonts aren't in the dropdowns | Install a media pack addon (one that includes SharedMedia). Without one, only WoW's built-in options show. |
| A bar's position resets after I log out | WoW only saves your settings on a clean logout. A crash or a force-quit can drop the last position. Log out through the menu and it will stick. |
| I want detailed logs | `/at debug` toggles a log window; `/at debug on` starts logging there instead of in chat. You can also open it from the **Debug console** checkbox on the General page. It resets to off every time you reload. |

## Credits and libraries

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.8.0 (MIT) — the shared Ka0s
library behind the chat printer, the debug console, the slash dispatcher and schema CLI, the
settings panel toolkit and the perf harness. It ships in `libs/LibKa0s/`, license included.
Ace3, LibStub, CallbackHandler-1.0 and LibSharedMedia-3.0 are bundled in `libs/` as well, each
under its own license.

## Issues and feature requests

Bugs, feature requests, and planned work are all tracked on GitHub:
[https://github.com/tusharsaxena/absorbtracker/issues](https://github.com/tusharsaxena/absorbtracker/issues).
Please file new reports there rather than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.9.0 | 2026-07-20 | Added a **Show only in combat** option that hides the bar out of combat<br>The bar now redraws the instant a shield changes instead of on a fixed timer, for smoother tracking<br>Added an on-screen debug window — `/at debug` opens it, `/at debug on`/`off` turns logging on or off (no more chat spam), with each line tagged by what triggered it<br>Added a **Debug console** toggle on the General page to show or hide that window |
| 1.8.0 | 2026-05-03 | Redesigned the settings panel with breadcrumb navigation and an About page<br>Added a hold-time to `/at test` (`/at test value seconds`) and reshaped the Bar and Border pages |
| 1.7.0 | 2026-04-24 | Rebranded to **Ka0s Absorb Tracker** with new artwork<br>Split the settings into separate pages<br>Chat messages now use a cyan `[AT]` tag |
| 1.6.0 | 2026-02-14 | Added `/at` commands for the class-color options |
| 1.5.0 | 2026-02-14 | Added class colors for the bar fill, background, and border |
| 1.4.0 | 2026-02-05 | Long dropdowns now scroll and jump to the current selection |
| 1.3.0 | 2026-01-31 | Bundled everything the addon needs, so nothing has to be installed separately<br>Added screenshots for the public release |
| 1.1.0 | 2026-01-31 | Dependencies install automatically |
| 1.0.0 | 2026-01-31 | Initial release: movable absorb bar with configurable size, textures, colors, border, and font, plus saved setups |
