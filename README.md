# Ka0s Absorb Tracker

A World of Warcraft addon for Midnight that displays your total absorb shield value in a clean, customizable bar interface.

## Features

- **Visual Absorb Bar**: Shows your total absorb amount as a status bar
- **Abbreviated Numbers**: Large values displayed as K/M/B for readability
- **Fully Customizable**: Textures, colors, fonts, size, and border all configurable
- **LibSharedMedia Support**: Use custom textures, fonts, and borders from SharedMedia
- **Profile System**: Save and switch between multiple configuration profiles (requires AceDB-3.0)
- **Movable & Lockable**: Drag the bar anywhere and lock it in place
- **Position Saving**: Bar position persists across sessions
- **Configurable Update Interval**: Configurable update interval (0.1-10 seconds)
- **Settings Panel**: Full GUI settings in WoW's Interface Options

## Usage

### Opening Settings

- `/at` or `/absorbtracker` - Opens the settings panel

### Slash Commands

| Command | Description |
|---------|-------------|
| `/at` | Open settings panel |
| `/at toggle` | Toggle bar visibility |
| `/at lock` | Lock bar position |
| `/at unlock` | Unlock bar position |
| `/at texture [name]` | List or set bar texture |
| `/at bgtexture [name]` | List or set background texture |
| `/at border [name]` | List or set border style |
| `/at bordersize <1-32>` | Set border size |
| `/at bordercolor <r> <g> <b> [a]` | Set border color |
| `/at font [name]` | List or set font |
| `/at fontsize <6-32>` | Set font size |
| `/at fontflags <option>` | Set font outline (none, outline, thickoutline, etc.) |
| `/at width <50-500>` | Set bar width in pixels |
| `/at height <10-100>` | Set bar height in pixels |
| `/at color <r> <g> <b> [a]` | Set bar color (0-255 or 0-1) |
| `/at bgcolor <r> <g> <b> [a]` | Set background color |
| `/at interval <0.1-10>` | Set update interval in seconds |
| `/at debug` | Toggle debug mode |
| `/at test [value]` | Test display with fake value |
| `/at update` | Force immediate update |

### Profile Commands

Profiles require AceDB-3.0 (part of Ace3) to be installed.

| Command | Description |
|---------|-------------|
| `/at profile list` | List all available profiles |
| `/at profile current` | Show current profile name |
| `/at profile use <name>` | Switch to a profile (creates if doesn't exist) |
| `/at profile new <name>` | Create new profile with default settings |
| `/at profile copy <name>` | Copy settings from another profile |
| `/at profile delete <name>` | Delete a profile (cannot delete current) |
| `/at profile reset` | Reset current profile to defaults |

### Moving the Bar

1. Use `/at unlock` to unlock the bar
2. Click and drag the bar to reposition
3. Use `/at lock` to lock in place

## Customization

### Via Settings Panel

Open with `/at` and configure:
- **Profiles**: Create, switch, copy, and delete profiles
- **General**: Show/hide bar, lock position
- **Performance**: Update interval
- **Bar Size**: Width and height
- **Bar Color**: Bar and background colors
- **Bar Textures**: Bar and background textures
- **Border**: Border style, size, and color
- **Font**: Font face, size, and outline style

### Via Slash Commands

All settings can also be changed via slash commands (see tables above).

## Compatibility

- **WoW Version**: 12.0.0+ (Midnight)
- **Game Type**: Retail
- **Dependencies**: LibSharedMedia-3.0, AceDB-3.0 (Ace3)

## Troubleshooting

**Bar doesn't show up:**
- Check if hidden with `/at toggle`
- Ensure addon is enabled in character select

**Textures/fonts not working:**
- Install LibSharedMedia-3.0 for custom media support
- Without LSM, only default Blizzard textures are available

**Position resets:**
- Make sure to properly close the game (don't force-quit)
- SavedVariables need the game to save on logout

**Profile commands not working:**
- Install AceDB-3.0 (part of Ace3) for profile support
- Without AceDB, settings still save but profile management is disabled

**Debug mode:**
- Use `/at debug` to see detailed information about absorb values

## Version History

**v1.3.0**
- Updated README.md for initial release

**v1.2.0**
- Removed pkgmeta and embedded libs directly

**v1.1.0**
- Added pkgmeta.yaml to install dependencies automatically

**v1.0.0**
- Initial Release ... yay!
