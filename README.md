# Absorb Tracker - WoW Addon

A World of Warcraft addon for patch 12.0.1 that displays all absorb effects on your character with their values in a clean, movable bar interface.

## Features

- **Visual Absorb Bars**: Shows each absorb effect as a separate bar
- **Absorb Values**: Displays the exact amount of absorb for each effect
- **Spell Names**: Shows which spell/ability is providing the absorb
- **Auto-Hiding**: The frame becomes semi-transparent when you have no absorbs
- **Movable**: Drag the frame anywhere on your screen
- **Real-time Updates**: Updates automatically when absorbs change

## Installation

1. Download the addon files (AbsorbTracker.toc and AbsorbTracker.lua)
2. Navigate to your WoW installation directory
3. Go to `_retail_\Interface\AddOns\`
4. Create a new folder called `AbsorbTracker`
5. Place both files inside the `AbsorbTracker` folder
6. Restart WoW or reload UI with `/reload`

Full path example: `C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\AbsorbTracker\`

## Usage

### Slash Commands

- `/absorbtracker` or `/at` - Toggle the addon frame on/off
- `/at debug` - Toggle debug output on/off
- `/at update` - Force an immediate update of absorb bars
- `/at test` - Run API test to check if absorbs are being detected

### Moving the Frame

- Click and drag the frame to reposition it anywhere on your screen
- The position will persist across sessions

### Visual Elements

Each absorb effect is shown as a bar with:
- **Left side**: Name of the spell/effect providing the absorb
- **Right side**: Numeric value of the absorb (formatted as K for thousands, M for millions)
- **Bar fill**: Visual representation of absorb amount relative to your max health

## Customization

You can modify the addon by editing `AbsorbTracker.lua`:

- **Frame Position**: Change the initial position by modifying the `SetPoint` call (line 11)
- **Bar Colors**: Change the blue color by modifying `SetStatusBarColor` (line 69)
- **Frame Size**: Adjust the width by changing `SetSize` (line 9)
- **Update Frequency**: Change the ticker interval (line 213) - currently 0.5 seconds

## Compatibility

- **WoW Version**: 12.0.1 (The War Within)
- **Interface Version**: 120001
- **Game Type**: Retail only

## Troubleshooting

**Addon doesn't show up:**
- Make sure both files are in the correct folder
- Check that the folder name is exactly `AbsorbTracker` (case-sensitive on some systems)
- Type `/reload` in-game to reload the UI

**Bars not showing:**
- The frame automatically hides when you have no absorb effects
- Use `/at` to check if the frame is enabled
- Try getting an absorb effect (like Power Word: Shield) to test
- **Use `/at debug` to enable debug mode** - this will show detailed information in chat
- Use `/at test` to verify the API is detecting absorbs
- Use `/at update` to force a manual update

**Debug Mode:**
When debug mode is enabled (`/at debug`), you'll see detailed output including:
- Total absorb amount from the WoW API
- Each aura being scanned on your character
- Tooltip text from each aura
- Which absorbs are detected and their values
- Frame update information

If debug shows "Total Absorb from API: nil" or "0", the game isn't detecting any absorbs. If it shows a value but no bars appear, there may be a parsing issue.

**Not all absorbs showing:**
- Some absorb effects may not be properly detected due to WoW API limitations
- The addon will show "Total Absorb" if it can detect the total but not individual effects

## Known Limitations

- Some absorb effects may be grouped as "Total Absorb" if individual effects cannot be parsed
- The tooltip-based detection may not capture all absorb types
- Very rapid absorb changes might have a slight delay (0.5 second update interval)

## Credits

Created for WoW patch 12.0.1 (The War Within)

## Support

For issues or feature requests, you can modify the code directly or seek help in WoW addon communities.

## Version History

**v1.0.0** - Initial Release
- Basic absorb tracking
- Movable frame
- Multiple absorb effect support
- Real-time updates
