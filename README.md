# Ka0s Absorb Tracker

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1450165)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW%20Addon%20Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-81%2F81_passing-green)

![alt text](https://media.forgecdn.net/attachments/1659/653/absorbracker-logo-v2-jpg.jpg)

Ka0s Absorb Tracker shows your current absorb shield as a movable bar, so you can see at a glance how much damage you can soak up. Move the bar anywhere on screen and restyle almost everything about it — its size, the bar and background textures and colors, the border, and the font. The bar fill,
background, and border can each follow your class color if you prefer.

Set it all up in the WoW Settings panel, or with the `/at` slash command.

## What's new in 1.9.0

- **Show the bar only in combat.** A new General option hides the bar out of combat and brings it back the moment you're fighting.
- **The bar now updates the instant a shield changes** instead of ticking on a timer, so it tracks your absorbs more smoothly.
- **A proper on-screen debug window.** `/at debug` opens a styled window instead of spamming chat; `/at debug on` / `off` starts and stops logging, and each line is tagged with what triggered it.
- **A Debug console toggle on the General page** to show or hide that window without a slash command.

## Screenshots

_**Absorb tracker bar in action — see the bar above the unit frame**_

![alt text](https://media.forgecdn.net/attachments/1506/197/absorbtracker-schreenshot-1-png.png)

_**Settings panel — invoked by /at config**_

![alt text](https://media.forgecdn.net/attachments/1804/983/absorbtracker-screenshot-02-png.png)

![alt text](https://media.forgecdn.net/attachments/1804/985/absorbtracker-screenshot-03-png.png)

![alt text](https://media.forgecdn.net/attachments/1804/986/absorbtracker-screenshot-04-png.png)

## Usage

### Slash commands

Use either `/at` or the longer `/absorbtracker` for any of these. Messages from the addon show up in
chat with a cyan `[AT]` tag.

| Command | What it does |
|---------|--------------|
| `/at` or `/at help` | Show the list of commands |
| `/at config` | Open the settings panel |
| `/at list` | Show every setting and its current value |
| `/at get <name>` | Show one setting's value |
| `/at set <name> <value>` | Change one setting. Examples: `/at set barWidth 250`, `/at set useClassColorBar true` |
| `/at reset <general\|bar\|border\|font>` | Reset one settings page to its defaults |
| `/at resetall` | Reset every setting and move the bar back to center |
| `/at resetposition` | Move the bar back to the center of the screen |
| `/at lock` / `/at unlock` | Lock or unlock the bar so you can drag it |
| `/at toggle` | Show or hide the bar |
| `/at update` | Refresh the bar now |
| `/at version` | Show the addon version |
| `/at test [value] [seconds]` | Fill the bar with a test value so you can preview your styling (default 50000 for 5 seconds) |
| `/at debug` | Open the debug window; `/at debug on` / `off` turns logging on or off |
| `/at profile <subcommand>` | Manage profiles: `list`, `current`, `use <name>`, `new <name>`, `copy <name>`, `delete <name>`, `reset` |

### Settings panel

Five pages under **Ka0s Absorb Tracker**:

| Tab | Covers |
|-----|--------|
| General | Show or hide the bar, show it only in combat, lock the bar, show or hide the debug console, and how often it refreshes. Buttons to reset the position or all settings. |
| Bar | Bar width and height, plus the bar and background textures and colors. |
| Border | Border style, thickness, and color. |
| Font | Font face, size, and outline. |
| Profiles | Save different setups and switch between them. |

To move the bar, type `/at unlock`, drag it into place, then `/at lock` to fix it there.

**Class colors.** The bar fill, background, and border can each follow your class color instead of a
fixed color — just turn on the matching **Use Class Color** toggle on the Bar or Border page. While
a toggle is on, its color picker greys out; turn the toggle off to pick a color by hand again.

## How the bar works

The addon watches every absorb shield on you at once — Power Word: Shield, Ice Barrier, trinket
procs, and the rest — and adds them into a single total. That total is what the bar shows:

1. Whenever you gain or lose a shield, the addon works out how much absorb you have left.
2. The bar fills to match that amount, and the text shows the number in short form (like `1.2M`).
3. As your shields soak up damage or wear off, the bar drains toward 0.
4. With no shield up, the bar reads 0 and sits nearly empty.

So the bar is always a live picture of how much damage you can take before your health starts
dropping.

## FAQ

| Question | Answer |
|----------|--------|
| Do I need to install anything else? | No. Everything the addon needs is bundled, so it works on its own. Install a media pack (such as one that includes SharedMedia) if you want extra textures and fonts in the dropdowns. |
| Does this replace the shield display on my unit frames? | No. This is a separate movable bar. Blizzard's shield overlay on the player and target frames is left alone — hide it in *Edit Mode* if you don't want to see both. |
| How do I move the bar? | Type `/at unlock`, drag the bar where you want it, then `/at lock`. Your position is remembered. Use `/at resetposition` to snap it back to center. |
| Can I have different setups? | Yes. Use the Profiles page in the settings panel to save and switch between setups. New characters start on the shared **Default** profile, so your changes carry over until you choose a separate setup. |
| Why is my bar empty? | The bar only shows a value when you have an active absorb shield — Power Word: Shield, Ice Barrier, a trinket proc, and so on. With no shield up it reads 0 and is hard to see against the background. |
| Why won't the settings panel open in combat? | WoW doesn't let addons change settings screens while you're fighting, so `/at config` is ignored until combat ends. Run it again once you're out of combat and it opens normally. |
| An addon CPU profiler shows Absorb Tracker using a lot of CPU — is that real? | Almost certainly not. Its actual cost is tiny (~0.18% of one core). Wow addon profilers blame all of a shared library's work on whichever addon loaded it first, and because `AbsorbTracker` sorts near the top alphabetically it "owns" the shared Ace event frame and gets billed for *every* Ace addon's event traffic. Disabling Absorb Tracker just moves that CPU to the next addon in line. [Read the full investigation](https://github.com/tusharsaxena/absorbtracker/blob/master/docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md). |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| The bar never shows up | Make sure it isn't hidden (`/at toggle`), the addon is enabled on the character-select screen, and you have an active absorb shield. With no shield the bar reads 0 and is nearly invisible. |
| The bar disappears when I leave combat | You have **Show only in combat** turned on. Turn it off on the General settings page. |
| My class color isn't showing | The bar has to be visible and have an active shield for the color to appear. Check that the matching **Use Class Color** toggle is on. When it's on the color picker greys out — that's normal. |
| Custom textures or fonts aren't in the dropdowns | Install a media pack addon (one that includes SharedMedia). Without one, only WoW's built-in options show. |
| The bar position resets after I log out | WoW only saves your settings on a clean logout. A crash or a force-quit can drop the last position. Log out through the menu and it will stick. |
| I want detailed logs | `/at debug` opens a log window; `/at debug on` starts logging there instead of in chat. It resets to off every time you reload. |

## Issues and feature requests

Bugs, feature requests, and planned work are all tracked on GitHub:
[https://github.com/tusharsaxena/absorbtracker/issues](https://github.com/tusharsaxena/absorbtracker/issues).
Please file new reports there rather than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 1.9.0 | 2026-07-20 | Added a **Show only in combat** option that hides the bar out of combat<br>The bar now redraws the instant a shield changes instead of on a fixed timer, for smoother tracking<br>Added an on-screen debug window — `/at debug` opens it, `/at debug on`/`off` turns logging on or off (no more chat spam), with each line tagged by what triggered it<br>Added a **Debug console** toggle on the General page to show or hide that window |
| 1.8.0 | 2026-05-03 | Redesigned the settings panel with breadcrumb navigation and an About page<br>Added a hold-time to `/at test` (`/at test <value> <seconds>`) and reshaped the Bar and Border pages |
| 1.7.0 | 2026-04-24 | Rebranded to **Ka0s Absorb Tracker** with new artwork<br>Split the settings into separate pages<br>Chat messages now use a cyan `[AT]` tag |
| 1.6.0 | 2026-02-14 | Added `/at` commands for the class-color options |
| 1.5.0 | 2026-02-14 | Added class colors for the bar fill, background, and border |
| 1.4.0 | 2026-02-05 | Long dropdowns now scroll and jump to the current selection |
| 1.3.0 | 2026-01-31 | Bundled everything the addon needs, so nothing has to be installed separately<br>Added screenshots for the public release |
| 1.1.0 | 2026-01-31 | Dependencies install automatically |
| 1.0.0 | 2026-01-31 | Initial release: movable absorb bar with configurable size, textures, colors, border, and font, plus saved setups |
