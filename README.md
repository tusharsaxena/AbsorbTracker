# AbsorbTracker - WoW Addon

A World of Warcraft addon for patch 12.0.1+ that displays your total absorb shield value in a clean, customizable bar interface.

## Features

- **Visual Absorb Bar**: Shows your total absorb amount as a status bar
- **Abbreviated Numbers**: Large values displayed as K/M/B for readability
- **Fully Customizable**: Textures, colors, fonts, size, and border all configurable
- **LibSharedMedia Support**: Use custom textures, fonts, and borders from SharedMedia
- **Movable & Lockable**: Drag the bar anywhere and lock it in place
- **Position Saving**: Bar position persists across sessions
- **Settings Panel**: Full GUI settings in WoW's Interface Options
- **Real-time Updates**: Configurable update interval (0.1-10 seconds)

## Installation

1. Download the addon files
2. Navigate to your WoW installation directory
3. Go to `_retail_\Interface\AddOns\`
4. Create a new folder called `AbsorbTracker`
5. Place all files inside the `AbsorbTracker` folder
6. Restart WoW or reload UI with `/reload`

Full path example: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\AbsorbTracker\`

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
| `/at font [name]` | List or set font |
| `/at fontsize <6-32>` | Set font size |
| `/at width <50-500>` | Set bar width in pixels |
| `/at height <10-100>` | Set bar height in pixels |
| `/at color <r> <g> <b> [a]` | Set bar color (0-255 or 0-1) |
| `/at bgcolor <r> <g> <b> [a]` | Set background color |
| `/at interval <0.1-10>` | Set update interval in seconds |
| `/at debug` | Toggle debug mode |
| `/at test [value]` | Test display with fake value |
| `/at update` | Force immediate update |

### Moving the Bar

1. Use `/at unlock` to unlock the bar
2. Click and drag the bar to reposition
3. Use `/at lock` to lock in place

## Customization

### Via Settings Panel

Open with `/at` and configure:
- **General**: Show/hide bar, lock position
- **Bar Size**: Width and height
- **Font**: Font face and size
- **Performance**: Update interval
- **Bar Color**: Bar and background colors
- **Bar Textures**: Bar and background textures
- **Border**: Border style and size

### Via Slash Commands

All settings can also be changed via slash commands (see table above).

### LibSharedMedia

If you have LibSharedMedia-3.0 installed, you can use custom textures, fonts, and borders from other addons.

## Compatibility

- **WoW Version**: 12.0.1+ (The War Within)
- **Game Type**: Retail
- **Optional Dependencies**: LibSharedMedia-3.0, LibStub

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

**Debug mode:**
- Use `/at debug` to see detailed information about absorb values

## Version History

**v1.1.0**
- Added background texture support
- Added position saving
- Added settings panel
- Added LibSharedMedia integration
- Abbreviated number display

**v1.0.0** - Initial Release
- Basic absorb tracking
- Movable frame
- Real-time updates
