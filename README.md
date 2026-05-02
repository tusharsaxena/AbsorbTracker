# Ka0s Absorb Tracker

![version](https://img.shields.io/badge/version-1.7.0-blue)
![wow](https://img.shields.io/badge/WoW-Midnight%2012.0.5-orange)
![license](https://img.shields.io/badge/license-MIT-green)

![Alt text](https://media.forgecdn.net/attachments/1659/653/absorbracker-logo-v2-jpg.jpg)

Display your total absorb shield value in a clean, customizable bar interface.

## Features

*   **Visual Absorb Bar**: Shows your total absorb amount as a status bar
*   **Abbreviated Numbers**: Large values displayed as K/M/B for readability
*   **Fully Customizable**: Textures, colors, fonts, size, and border all configurable
*   **Class Color Override**: Use your class color for bar fill, background, or border
*   **LibSharedMedia Support**: Use custom textures, fonts, and borders from SharedMedia
*   **Profile System**: Save and switch between multiple configuration profiles (requires AceDB-3.0)
*   **Movable & Lockable**: Drag the bar anywhere and lock it in place
*   **Position Saving**: Bar position persists across sessions
*   **Configurable Update Interval**: Adjust how often the bar refreshes (0.1–10 seconds)
*   **Settings Panel**: Full GUI settings in WoW's Interface Options
*   **Slash Commands**: Every setting can also be changed from the chat line via `/at` (or the long form `/absorbtracker`)

## Screenshots

_**Absorb tracker bar in action - see the bar above the unit frame**_

![Alt text](https://media.forgecdn.net/attachments/1506/197/absorbtracker-schreenshot-1-png.png)

_**Settings panel - invoked by /at config**_

![Alt text](https://media.forgecdn.net/attachments/1506/198/absorbtracker-schreenshot-2-png.png)

## Usage

### Opening Settings

*   `/at config` or `/absorbtracker config` - Opens the settings panel
*   `/at` (no args) - Prints the slash-command help in chat

### Slash Commands

Both the short form `/at` and the long form `/absorbtracker` work for every command below.
All chat output from the addon is prefixed with a cyan `[AT]`; in the help dump,
each command is shown in yellow and its description in white.

Most settings are reached through three schema-driven commands — `/at list`,
`/at get <path>`, `/at set <path> <value>` — so a single mental model covers
every setting on every sub-page.

| Command                             |Description                                          |
| ----------------------------------- |---------------------------------------------------- |
| <code>/at</code> or <code>/at help</code> |Show this help                                 |
| <code>/at config</code>             |Open the settings panel (lands on General)           |
| <code>/at list</code>               |List every setting and its current value             |
| <code>/at get &lt;path&gt;</code>         |Print one setting's current value                    |
| <code>/at set &lt;path&gt; &lt;value&gt;</code> |Set one setting (typed: bool/number/string/color) |
| <code>/at reset &lt;page&gt;</code>       |Reset one page to defaults (general, bar, border, font) |
| <code>/at resetall</code>           |Reset every setting to defaults                      |
| <code>/at resetposition</code>      |Move the bar back to the screen center               |
| <code>/at lock</code>               |Lock the bar in place                                |
| <code>/at unlock</code>             |Unlock the bar so it can be dragged                  |
| <code>/at toggle</code>             |Toggle bar visibility                                |
| <code>/at debug</code>              |Toggle debug mode                                    |
| <code>/at update</code>             |Force a bar refresh                                  |
| <code>/at test [value]</code>       |Test display with a fake absorb value                |

#### Examples

```
/at list                              # see every setting and current value
/at set barWidth 250                  # number
/at set barColor 0.4 0.7 1.0 0.8      # color (RGBA, 0-1 or 0-255)
/at set barTexture "Blizzard Raid Bar"# string (LSM media name)
/at set useClassColorBar true         # bool
/at set updateInterval 0.5            # number
/at reset bar                         # restore the Bar page defaults
```

### Profile Commands

Profiles require AceDB-3.0 (part of Ace3) to be installed.

| Command                   |Description                                    |
| ------------------------- |---------------------------------------------- |
| <code>/at profile list</code> |List all available profiles                    |
| <code>/at profile current</code> |Show current profile name                      |
| <code>/at profile use [name]</code> |Switch to a profile (creates if doesn't exist) |
| <code>/at profile new [name]</code> |Create new profile with default settings       |
| <code>/at profile copy [name]</code> |Copy settings from another profile             |
| <code>/at profile delete [name]</code> |Delete a profile (cannot delete current)       |
| <code>/at profile reset</code> |Reset current profile to defaults              |

### Moving the Bar

1.  Use `/at unlock` to unlock the bar
2.  Click and drag the bar to reposition
3.  Use `/at lock` to lock in place

## Customization

### Via Settings Panel

Open with `/at config` and configure:

*   **Profiles**: Switch, create, copy, delete, and reset profiles
*   **General**: Show/hide bar, lock position
*   **Performance**: Update interval (0.1-10 seconds)
*   **Bar Size**: Width (50-500) and height (10-100)
*   **Bar Color**: Bar color and background color, each with optional class color override
*   **Bar Textures**: Bar texture and background texture (LibSharedMedia)
*   **Border**: Border style (LibSharedMedia), size (1-32), and color with optional class color override
*   **Font**: Font face (LibSharedMedia), size (6-32), and outline style (none, outline, thick outline, monochrome, etc.)

### Via Slash Commands

Every setting in the panel is also reachable via `/at set <path> <value>`.
Run `/at list` to discover the available paths and their current values.

## Troubleshooting

**Bar doesn't show up:**

*   Check if hidden with `/at toggle`
*   Ensure the addon is enabled in the character select screen
*   You need an active absorb effect (e.g., Power Word: Shield) for the bar to fill

**Class color not applying:**

*   The bar must be visible with an active absorb effect to see the color change
*   Verify the setting is enabled: `/at color classcolor on`, `/at bgcolor classcolor on`, or `/at bordercolor classcolor on`

**Textures/fonts not working:**

*   Install LibSharedMedia-3.0 for custom media support
*   Without LSM, only default Blizzard textures and fonts are available

**Position resets:**

*   Make sure to log out or exit the game normally (don't force-quit)
*   WoW saves addon data (SavedVariables) only during a proper logout

**Profile commands not working:**

*   Install AceDB-3.0 (part of Ace3) for profile support
*   Without AceDB, settings still save but profile management is disabled

**Debug mode:**

*   Use `/at debug` to see detailed information about absorb values and updates

## Bug Reports

Please report any issues in the [Issues](https://github.com/tusharsaxena/absorbtracker/issues) tab, not as a comment!

## Version History

**1.7.0**

*   TOC version bump

**1.6.0**

*   Updated slash commands for class color options added in v1.5.0

**1.5.0**

*   Added a "class color" option for bar color, bckground color and border color
*   Updated libs

**1.4.0**

*   Replaced all dropdown selectors in the Settings panel with custom scrollable dropdowns
*   Dropdowns with 10 or more items now display a scrollbar
*   Opening a dropdown auto-scrolls to the currently selected value

**1.3.0**

*   Updated README.md for initial release

**1.2.0**

*   Removed pkgmeta and embedded libs directly

**1.1.0**

*   Added pkgmeta.yaml to install dependencies automatically

**1.0.0**

*   Initial Release … yay!