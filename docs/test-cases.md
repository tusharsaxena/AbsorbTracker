# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below is the **authoritative pass count** — the README test
badge and any count quoted in the docs must agree with it.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_loadorder.lua (14)

- loadorder: tocFiles returns every addon lua file, in TOC order
- loadorder: core/MediaSetup.lua loads before core/Constants.lua
- loadorder: tocFiles skips libs, directives and comments
- loadorder: tocFiles converts backslashes to forward slashes
- loadorder: every derived path exists on disk
- loadorder: the runner loaded exactly the TOC's files, in the TOC's order
- loadorder: tests/perf.lua derives its list from the TOC too
- loadorder: xmlFiles returns every LibKa0s script the vendored XML lists, in its order
- loadorder: the runner loaded exactly the vendored XML's library files, in its order
- loadorder: the loaded library registered — NS.Perf is the lib, not the degradation stub
- loadorder: tests/perf.lua derives its library half from the vendored XML too
- loadorder: LibStub raises for a missing major without the silent flag
- loadorder: LibStub returns nil for a missing major with the silent flag
- loadorder: LibStub keeps the higher minor when a major registers twice

### test_schema.lua (60)

- FormatSchemaValue formats by type
- SchemaForPage keeps groups in registration order, which IS the Appearance tab strip
- the page -> tab -> row-count partition is the designed one
- no tab holds fewer than two visible controls
- ValidateSchema resolves every real path against defaults (0 errors, 0 missing)
- ValidateSchema reports a planted path that does not resolve against defaults
- ValidateSchema flags an invalid page/type as a shape error
- ValidateSchema prints through NS.Print, resolved at call time, with no hand-typed tag
- every schema row carries a label and a tooltip description
- every schema path is unique
- every schema row declares a default
- every row's default matches the value in defaults.profile
- every persisted profile default is reachable from a schema row
- every number row declares a usable min/max range
- every string row supplies a values source
- every row on every page carries a `group`
- every color row is immediately followed by its class-color companion
- no color row carries `disabledIf`, and every pair declares whose class it means
- every media-backed row answers a populated option list
- `disabledIf` names a real sibling setting
- every schema row lands on a page the panel actually builds
- FindSchemaRow returns the row for a known path and nil for an unknown one
- SetByPath writes the value and fires the row's own onChange with it
- a write stores, then logs its [Set] line, then runs the row's onChange, once each
- SetByPath falls back to broadcasting APPEARANCE for a row with no onChange
- the schema runtime is LibKa0s-Schema-1.0's, over the live schema array
- the minimap row survives a sweep, and a named reset still resets it
- SetByPath refuses a path with no schema row, and stores nothing
- SetByPath stores a table value as a copy, so the caller's table never aliases the store
- ApplyDefault deep-copies a color table so profiles never share one
- ApplyDefault is a no-op for a row with no default
- ResolvePath walks a dotted path
- ResolvePath returns nil for a missing branch instead of raising
- ResolvePath still handles a flat key
- SetPath writes through a dotted path and creates intermediate tables
- GetSetting and SetByPath round-trip a dotted path
- ValidateSchema resolves nested paths against defaults.profile
- SchemaForPage with no unit returns every unit's rows
- SchemaForPage filtered to a unit excludes the other units' rows
- the appearance page carries a full row set for all three units
- each unit's row set for a page is the same size
- the enable row is per-unit, lives on General, and survives mirroring
- the Master controls tab is the canonical set, in order, and leads the General page
- there is no Test mode row beside Lock frame
- Reset all settings returns the lock to its shipped default
- the Bars tab is the three enable toggles then the throttle, under their own headings
- the mirror row exists for target and focus but not the player
- the mirror row is kept out of the auto-rendered body
- General's rows are the flat globals plus one enable toggle per unit
- FormatSchemaValue resolves the Slash major at load, never per call
- a build without LibKa0s-Slash-1.0 falls back to a minimal FormatSchemaValue
- degraded Schema stub: SetMany refuses the whole batch on one invalid entry
- degraded Schema stub: SetMany refuses an unknown path with its index
- degraded Schema stub: a valid SetMany stores both, reacts once each, announces per write
- degraded Schema stub: SetMany announces once through announceBatch when given
- degraded Schema stub: a writeThrough path with no row stores raw and announces a synthetic row
- degraded Schema stub: a row-less path outside writeThrough is still refused
- degraded Schema stub: row.normalize's answer is stored, and a nil answer refuses
- degraded Schema stub: Get forwards the instance id to a row's own get
- degraded Schema stub: ApplyDefault forwards the instance id to Set

### test_database.lua (38)

- RunMigrations migrates a fresh DB to the current version (5)
- a freshly-materialized global runs the ladder, because its default is pre-ladder
- RunMigrations leaves an already-current (v5) DB unchanged
- RunMigrations is idempotent across repeated runs
- RunMigrations v2 retires the legacy updateInterval profile key
- the account-wide schemaVersion default is 0 (savedvariables-§1)
- NS.SCHEMA_VERSION is the highest ladder step's `to`
- v2 clears updateInterval from every stored profile, not only the active one
- a step that raises leaves the stamp unmoved and says so once in chat
- RunMigrations backfills throttleWindow from flatDefaults
- RunMigrations backfills a missing scalar per-unit key from the defaults
- RunMigrations deep-copies per-unit table defaults (no shared reference to defaults)
- RunMigrations does not overwrite an existing user value
- RunMigrations is a safe no-op when the DB is absent
- RunMigrations logs [Migrate] only when a version bump happens
- RunMigrations emits the [Migrate] lines for a v1->v5 upgrade in order
- InitDB produced a profile carrying every default key
- v3 migration lifts flat appearance keys onto the player unit
- v3 migration seeds target and focus disabled and mirrored
- v3 migration leaves the remaining global keys flat
- v4 drops the dead `hidden` key from every profile, not just the active one
- v5 maps showOnlyInCombat onto visibility on every profile, not just the active one
- v5 leaves a profile that never had the boolean on the shipped default
- v4 does not resurrect `hidden` via the defaults backfill
- v3 migration is idempotent
- v3 migration does not share nested tables between units
- the schema version lands on 5
- real AceDB init: a legacy flat profile is lifted onto the player unit, not overwritten by fresh defaults
- real AceDB init: a fresh install (no saved data) converges on factory defaults at v5
- InitDB lifts EVERY saved profile, not only the active one
- a profile that appears AFTER the upgrade is lifted when it becomes active
- the InitDB sweep and the profile-change lift compose without double-applying
- the per-profile stamp defaults to 1 so copyDefaults cannot mark a pre-v3 profile migrated
- a fresh install logs no [Migrate] lift line -- nothing was actually lifted
- a real upgrade still logs the lift, with an accurate count
- profile adopt: a same-state switch publishes APPEARANCE once
- profile adopt: an off-to-on switch publishes APPEARANCE once, not twice
- profile adopt: an on-to-off switch stands down and delivers nothing

### test_units.lua (17)

- LIST is player, target, focus in render order
- Get reads the unit's own value when it is not mirrored
- Get resolves to the player's value when the unit is mirrored
- player is never mirrored even if a mirror key is force-written
- Position is never mirror-resolved
- SetPosition writes the unit's own position while mirrored
- CopyFromPlayer snapshots every appearance key and clears the mirror
- a copied unit does not track later player changes
- CopyFromPlayer deep-copies color tables rather than sharing them
- CopyFromPlayer leaves position and enabled alone
- CopyFromPlayer is a no-op for the player itself
- CopyFromPlayer writes every key through the settings seam
- CopyFromPlayer logs one [Set] copy line with its row count, and no per-row line
- IsEnabled reads the per-unit flag and ignores the global hidden toggle
- target and focus ship disabled so an upgrade changes nothing on screen
- target and focus ship mirrored so a first enable looks like the player bar
- every per-unit appearance row is in APPEARANCE_KEYS, and vice versa

### test_envsetup.lua (7)

- EnvSetup: NS.Meta asks about THIS addon's folder, not its title or its frame prefix
- EnvSetup: NS.Meta degrades to nil when the client exposes no manifest reader
- EnvSetup: NS.Version prefers the TOC over this addon's own constant
- EnvSetup: NS.Version falls back to this addon's own constant
- EnvSetup degraded: an install with no LibKa0s still reads its own TOC
- EnvSetup degraded: a legacy-only surface yields nil, and the dead global is never called
- EnvSetup: the deleted shim is gone, and so is the file that was only ever the shim

### test_coresetup.lua (6)

- core: the secret seam is the library's, not a private copy
- core: the perf descriptor names the folder and leaves the close control to the library
- core: NS.Print carries the [AT] tag and survives a secret arg
- core: NS.Print and NS.Util.print are the same object after the AceConsole reclaim
- core: the addon still prints, tagged, with LibKa0s absent
- core: the degraded SafeRegisterEvent isolates a raise and lists the name once

### test_mediasetup.lua (10)

- MediaSetup: NS.Icon answers the vendored path, extensionless
- MediaSetup: an icon the library does not ship answers nil
- MediaSetup: NS.MediaFont answers the vendored face, and an unknown face answers nil
- MediaSetup: the font this addon names is the face the library registers
- MediaSetup: FONT_MONO resolves into the payload, not into this addon's own media/
- MediaSetup: every mark this addon's windows draw is one the library ships
- MediaSetup: every name the library ships has a file in the vendored copy
- MediaSetup: the seam is handed the FOLDER name, never a frame prefix or a literal
- MediaSetup: the LSM registration happens at file load, not at OnInitialize
- MediaSetup: with no library there is no art, and that is not an error

### test_debuglog.lua (12)

- the console's font resolves through the Media seam to the LibKa0s payload
- the descriptor tells the library the FOLDER name, not just the frame name
- and it takes that folder name from the vararg, not from a hand-typed literal
- the debug flag the library reads and writes is NS.State.debug
- NS.Debug is published and reaches the console buffer
- our title and our font reach the descriptor
- the console checkbox the General page renders is wired to this addon
- /at debug on enables session state
- /at debug off disables session state
- /at debug (no arg) toggles the window, not the state
- /at debug on writes an [Init] summary naming our version, schema and profile
- the console checkbox label the library renders is prose, not its own STRINGS key

### test_slash.lua (14)

- NS.Print survives AceConsole's embed and stays the [AT]-prefixed printer
- bare /at opens the settings panel through the config verb, not the help index
- /at help prints the help index: header + one row per command
- unknown verb prints 'unknown command' then the help index
- /at version prints the addon version (slash-commands-§3)
- /at get <path> dispatches to the schema read
- /at list uses the mandated color scheme (slash-commands-§5)
- /at set <path> <value> writes through the schema and preserves path case
- /at set clamps out-of-range numbers to the row max
- /at options is aliased to /at config (no unknown-command error)
- /at config in combat refuses with a gray notice (options-ui-§2)
- OpenOptionsPanel logs [Cfg] refused in combat
- SetByPath logs one [Set] path = value line (debug-logging-§10)
- the schema CLI's list header the library renders is prose, not its own STRINGS key

### test_timer.lua (12)

- RequestRepaint coalesces multiple requests into one scheduled repaint
- the coalesced repaint paints every tracked unit, not just the player
- one coalesced pass counts one repaint, however many bars it painted
- a pass in which no bar painted counts no repaint
- a pass counts one repaint when only some of the bars painted
- RequestRepaint schedules the timer at the throttleWindow delay
- RequestRepaint hands AceTimer a clamped number, never the raw stored value
- OnAbsorbChanged requests a repaint for the player
- OnAbsorbChanged requests a repaint for any tracked unit, not just the player
- OnMaxHealthChanged requests a repaint for the player
- OnMaxHealthChanged requests a repaint for any tracked unit, not just the player
- OnEnterWorld requests a repaint

### test_perf.lua (33)

- perf: the addon holds a real LibKa0s-Perf instance
- perf: the descriptor declares this addon's buckets, with their nesting
- perf: the capture OBSERVES visibility inside appearance, it does not just declare it
- perf: a standalone ApplyVisibility claims no parent rather than inventing one
- perf: the capture OBSERVES paintBar inside repaintPass, it does not just declare it
- perf: a standalone UpdateAbsorbBar claims no parent rather than inventing one
- perf: the throttle and console rows publish no restyle, because they have no stake in one
- perf: records identify this addon and land in its own global
- perf: the ring is reachable through its own global and nowhere in AceDB
- perf: brackets record nothing while capture is off
- perf: paintBar records when capture is on
- perf: paintBar does not count a bar that early-outed
- perf: repaintPass records one note per coalesced pass
- perf: every declared bucket is reached by a real bracket
- perf: suspend hides bars through the visibility ladder
- perf: suspend unregisters every unit event frame
- perf: suspend unregisters the lifecycle events
- perf: resume restores the lifecycle set from one definition
- perf: RequestRepaint no-ops while suspended
- perf: CancelPendingRepaint drops a queued pass
- perf: suspend leaves no repaint queued behind it
- perf: the suspended state is session-only, never persisted
- perf: lifecycle lines appear even with debug logging OFF
- perf: the slash verb dispatches into the lib
- debug: the flag still flips and acks with LibKa0s absent
- debug: /at debug names the missing library instead of erroring
- debug: every member the addon reaches for answers with LibKa0s absent
- perf: the schema with LibKa0s absent is the full one minus the composed rows, by tab
- perf: the addon loads with LibKa0s absent
- perf: /at perf explains itself instead of erroring with LibKa0s absent
- perf: the brackets and the show ladder survive LibKa0s being absent
- every perf step label the library renders is prose, not its own STRINGS key
- Perf: the descriptor hands the library the FOLDER name, not just the frame name

### test_visibility.lua (22)

- ShouldShowBar: a disabled unit wins even in combat
- ShouldShowBar: default (enabled, visibility=always) is shown
- ShouldShowBar: combat-only + in combat is shown
- ShouldShowBar: combat-only + out of combat is hidden
- ShouldShowBar: out-of-combat-only is the mirror of combat-only
- ShouldShowBar: never hides the bar in either combat state
- ShouldShowBar: an unrecognized visibility mode reads as always
- ShouldShowBar: the addon-wide enable gates every unit, whatever the per-unit flag says
- ShouldShowBar: combat-only shows when lockdown lags actual combat
- SyncUnitEventFrames registers each enabled unit on its own frame, one token each
- a disabled unit is registered for nothing at all
- enabling a unit registers it and disabling it again unregisters
- the target/focus swap events are registered only while that bar is enabled
- SyncUnitEventFrames reuses its frames — a re-sync must not leak a new set
- the UNITS message re-syncs the registrations
- OnEnterCombat applies visibility and requests a repaint
- OnLeaveCombat applies visibility and requests a repaint
- OnLeaveCombat never opens config, even with a stale panelOpenPending (options-ui-§2)
- combat rollup: OnLeaveCombat logs one [Combat] left summary with counts
- OnAbsorbChanged is silent on an unchanged value (no per-event spam)
- [Absorb] transition logs on a non-secret 0->nonzero change
- ShouldShowBar: unlocking bypasses visibility entirely

### test_bus.lua (12)

- bus, NewBusTarget, and the message catalog are published
- the catalog is exactly the five declared messages, walkable with pairs
- a receiver on its own target hears a message, then is silent after unregister
- two receivers of one message both fire (no (message,target) clobber)
- a message payload reaches the receiver after the message name
- REPAINT routes through Timer to one coalesced repaint
- APPEARANCE / VISIBILITY / POSITION route to their Display consumers
- sending a message with no subscribers is a harmless no-op
- the bus record is LibKa0s-Bus-1.0's, built under the folder name
- the catalog is strict: an undeclared key raises at the call site
- with LibKa0s absent, receivers still get a private working target and nothing is recorded
- with LibKa0s absent, a UNITS publish while disabled registers nothing

### test_data.lua (32)

- GetSetting reads the value out of the active profile
- GetSetting falls back to flatDefaults when the key is missing from the profile
- GetSetting falls back to flatDefaults when the DB is absent entirely
- GetSetting returns nil for a key that is neither in the profile nor the defaults
- GetSetting returns a stored `false` rather than falling through to the default
- SetByPath writes through to the active profile
- SetByPath refuses without raising when the DB is absent, and writes nowhere
- media fetchers return the hardcoded fallbacks when LSM is absent
- media fetchers return the LSM path when LSM resolves the configured key
- media fetchers fall back when LSM is present but the key does not resolve
- ClearLSMCache lets a late-loading LSM be picked up
- LSMValues yields a self-keyed map of the live LSM hash table
- GetBarColor returns the stored color when useClassColorBar is off
- GetBarColor substitutes the class color but KEEPS the stored alpha
- GetBorderColor honors useClassColorBorder and keeps its own alpha
- GetBorderColor returns the stored color when the toggle is off
- GetBgColor uses the DIMMED class color, not the raw one
- GetBgColor returns the stored color when the toggle is off
- GetFontColor honors useClassColorText and keeps its own alpha
- an unknown class keeps the CONFIGURED color, never a hue invented for the occasion
- GetBarAlpha clamps a hand-edited SavedVariable to the slider's own range
- GetThrottleWindow clamps a hand-edited SavedVariable to the row's own range
- the four class-color toggles are independent of each other
- media getters read through the unit's mirror resolution
- a media getter with no unit still resolves the player
- with LSM present, the media getter resolves the REQUESTED unit's own key, not the player's
- GetBarColor reads the requested unit's color
- class color on a target bar is the TARGET's class, not the player's
- a MIRRORED focus bar reads the player's swatch but takes the focus's class
- the background palette is per-unit too, and stays the DARKENED set
- three bar frames exist and the retired player aliases stay off the namespace
- each bar carries its own unit tag and its own backdrop table

### test_display.lua (60)

- RestoreBarPosition centers the bar when no position is saved
- RestoreBarPosition restores the saved anchor verbatim
- RestoreBarPosition clears the old anchors before re-anchoring
- UpdateBarAppearance sizes the bar from the profile
- UpdateBarAppearance derives the backdrop inset from borderSize (floor of a quarter)
- UpdateBarAppearance floors the inset to 1 for a hairline border
- UpdateBarAppearance scales the inset up with a thick border
- UpdateBarAppearance clears the backdrop before re-applying it
- UpdateBarAppearance pushes the resolved media into the backdrop
- UpdateBarAppearance makes the bar immovable and mouse-inert when locked
- UpdateBarAppearance restores drag + mouse when unlocked
- an untouched profile paints the same white text and full alpha it always did
- the Text tab's color reaches the absorb amount, alpha included
- barAlpha reaches all three paint sites, not just the appearance pass
- fontShadow reaches the absorb amount, and turning it off CLEARS the shadow
- Master scale is applied to the frame on every appearance pass
- Master alpha MULTIPLIES the per-unit barAlpha rather than replacing it
- an unlocked bar paints a placeholder fill against a 0..1 scale
- a locked bar paints no placeholder
- a live repaint leaves the unlocked placeholder alone
- UpdateAbsorbBar reports false while the bars are unlocked
- HoldPreview arms an expiry timer for exactly the announced duration
- the expiry timer clears the hold and republishes REPAINT
- a hold that expires while unlocked falls back to the placeholder
- ClearPreview reports whether a hold was actually live
- there is no test-mode flag left behind the lock
- a LOCKED bar does not preview
- a live repaint stands down while unlocked
- re-locking ends any /at debug hold and restores live data
- unlocking shows a bar the visibility dropdown or a missing unit would hide
- unlocking does not override the addon-wide or per-unit switch
- a hold that expires while unlocked falls back to the placeholder
- combat re-locks the bars, says so, and refreshes the panel
- combat with the bars already locked says nothing and leaves the panel alone
- unlocking will not happen in combat, and says why
- re-locking in combat is always allowed
- UpdateBarAppearance re-applies the font from the profile
- UpdateBarAppearance tolerates a nil fontFlags by passing an empty flag string
- UpdateBarAppearance ends by applying visibility
- ApplyVisibility shows the bar when the gate passes and hides it when it does not
- UpdateAbsorbBar is a no-op while the bar is hidden
- UpdateAbsorbBar is a no-op inside a /at debug hold window
- UpdateAbsorbBar paints again once the hold window has expired
- UpdateAbsorbBar scales the bar to max health and sets the absorb value
- UpdateAbsorbBar substitutes 0 / 1 when the absorb and health reads come back nil
- UpdateAbsorbBar writes the abbreviated value into the bar text
- UpdateAbsorbBar reports true when it paints
- UpdateAbsorbBar reports false for a bar it skipped
- UpdateAbsorbBar reports false while a /at debug hold is active
- each unit's enable flag governs only its own bar
- a disabled unit stays hidden even when the others are on
- an enabled target bar hides when there is no target
- the player bar never consults UnitExists
- visibility=inCombat gates every bar on PLAYER combat
- UpdateAbsorbBar reads the absorb of the unit it is painting
- UpdateBarAppearance sizes the bar it is given, not always the player's
- a mirrored unit paints with the player's size
- the player bar defaults to dead center
- target and focus default stacked above the player bar
- ForEachUnit walks all three units in order

### test_draghandle.lua (22)

- every bar body is registered for a left-button drag
- dropping a bar body saves the position to that bar's own unit
- dropping one bar leaves the other bars' positions alone
- the widget major is present, so the handle is not the degraded path
- every bar owns a drag handle: a named Button parented to the bar
- the handle is labeled with its own unit's name
- the handle moves its own bar, with the help icon from the Media seam
- unlocking shows every bar's handle; locking hides it
- an unlocked handle is exactly as wide as its bar
- a handle over a narrow bar takes its own natural width instead
- a locked pass does not resize the hidden handle
- the combat re-lock hides every handle
- a locked handle refuses the drag and does not move the bar
- an unlocked handle drags its bar
- dropping a handle saves the position to its own bar's unit
- the handle and the bar body save through the same writer
- the strip's tooltip names the addon and says how to move this bar
- the strip's tooltip reads the lock on every hover
- the help mark has its own tooltip, with a footer saying how to put the strip away
- degraded: with LibKa0s absent the bars load with no handle and keep their own drag
- degraded: with no widget the default stack reserves no strip room
- an appearance pass over a bar with no handle raises nothing

### test_helpers.lua (70)

- CreatePanel returns a ctx wired to a panel, a body and an empty refresher list
- the canvas frame carries OnCommit, OnDefault and OnRefresh from the library
- OnDefault reaches a defaultsOnClick parked AFTER the panel is built
- a page that parks no defaults action still has a callable, inert OnDefault
- CreatePanel names the panel with the plain title for the Blizzard left tree
- CreatePanel starts the panel hidden
- CreatePanel only DECLARES the Defaults button, never builds it
- CreatePanel records no Defaults intent when the page did not ask for one
- CreatePanel carries the defaults tooltip through to the lazy builder
- EnsureDefaultsButton builds the button once, then is idempotent
- EnsureDefaultsButton is a safe no-op without AceGUI, and on a nil panel
- EnsureDefaultsButton leaves a panel that never wanted one alone
- RestoreDefaults resets every row on the named page
- RestoreDefaults leaves other pages untouched
- RestoreDefaults runs the ctx refreshers so open widgets re-read
- RestoreDefaults survives a refresher that throws
- RestoreDefaults on a page with no rows is a harmless no-op
- the Defaults button fires each reset row's onChange exactly once
- the appearance page's Defaults logs one [Set] line counting the rows it changed
- the appearance page's Defaults at defaults already logs 0 rows
- the general page's Defaults logs one [Set] line counting the rows it changed
- the general page's Defaults at defaults already logs 0 rows
- a nested bulk act logs exactly one line, the outer act's, summing every level
- a nested bulk act that includes a profile reset logs only the handler's line
- a page reset that raises still unmutes the seam
- a bulk act that raises logs its one line marked as stopped by an error
- a library page reset that raises logs its one line marked as stopped by an error
- Reset All on a clean profile logs (0 rows)
- a reset the addon did not drive logs the reset line with no count
- a counted reset that never reached the handler leaks no count into a later reset
- Reset All logs exactly one line in total, the profile handler's
- RestoreAllDefaults resets every schema row that is not on the profiles page
- RestoreAllDefaults clears the saved bar position so the bar recenters
- RestoreAllDefaults publishes POSITION so the bar moves immediately
- RestoreAllDefaults skips the profiles page (resetting it would delete user data)
- RefreshAllPanels runs the refreshers of every registered panel
- RefreshAllPanels isolates a throwing refresher from the rest
- NS.RefreshOptionsPanel delegates to RefreshAllPanels
- the cross-slice layout constants are published for the widget/about slices
- a page renders nothing until its first OnShow
- the Appearance page opens on the player unit with no mirror controls
- the Unit picker is in the page's chrome block, and is the page's only picker
- switching the picker to focus re-renders the page for that unit
- the Appearance page draws one tab per schema group, in declaration order
- clicking a tab switches the page to that tab's rows and nothing else's
- a tab click keeps the chrome block, and never grows a second copy of it
- a mirrored unit STILL gets its tab strip, with the mirrored state as content
- a mirrored unit shows only its chrome block, no appearance rows
- unchecking the mirror reveals the appearance rows
- the copy button snapshots the player's styling and clears the mirror
- a page Defaults button resets that page across every unit
- RestoreAllDefaults clears all three saved positions
- the mirror checkbox renders exactly once — the block owns it, RenderRows must skip it
- the page-wide mirror controls sit in the chrome block, never in the scroll
- the chrome block reserves the band its second row needs
- a raise inside the chrome block costs the block, not the page
- the chrome block's widgets go back to AceGUI's pool, after the render and not before
- the mirrored hint is a laid-out row followed by a ROW_VSPACER
- ClearScroll resets ctx.refreshers, so repeated renders do not leak stale closures
- the General page's Reset position button clears EVERY unit's saved position
- the Reset position button and /at resetposition run the SAME shared helper
- a page refresh re-syncs the mirror checkbox and re-runs the row partition
- `/at set units.<unit>.mirror` re-syncs an open panel's mirror checkbox
- the block's refresher cannot recurse: a refresh fired mid-render is a no-op
- a raise mid-render must not latch the re-entrancy flag for the session
- a failed unit-panel render is reported in chat, never swallowed
- an ordinary schema write does NOT re-render the whole unit page
- a mirror-state change DOES re-render -- the two-tier refresher keeps both halves
- /at resetposition does not claim success when the settings helpers are absent
- the Defaults button the library renders is prose, not its own STRINGS key

### test_launcher.lua (22)

- launcher: Register builds ONE broker object and hands that same object to LibDBIcon
- launcher: LibDBIcon is handed db.global.minimap ITSELF, not a copy
- launcher: Register is idempotent
- launcher: the broker label is the BRAND NAME in plain text
- launcher: the label is not WIRED to the TOC Title, even though both read the same today
- launcher: LEFT-click toggles the lock, through the seam the checkbox writes through
- launcher: the disabled gate is the descriptor's, asked on every click and never cached
- launcher: RIGHT-click always opens the settings panel, and touches nothing else
- launcher: the icon file is the one the TOC names, and is a format the client can load
- launcher: the Minimap button row is stored, global, and says SHOWN
- launcher: the row's get/set invert onto `hide`, and the button follows immediately
- launcher: Reset all settings cannot un-hide the button
- launcher: the General page's Defaults button cannot un-hide the button either
- launcher: the page Defaults button still resets every OTHER General row
- launcher: /at get global.minimap.shown reads the row's sense off the stored hide
- launcher: /at set global.minimap.shown false stores hide = true and hides the button
- launcher: the old CLI spelling global.minimap.hide answers unknown setting
- launcher: the renamed path is not reported missing from the defaults
- launcher: a legacy store keeps its hidden button, and its angle, across the rename
- launcher: with BOTH broker libraries absent, Register reports absent and does not raise
- launcher: with LibDataBroker but no LibDBIcon, the plugin exists and the button does not
- launcher: with LibKa0s absent the seam still answers, and still remembers the choice

### test_optionssetup.lua (15)

- the live and degraded builds veto exactly the same rows from Reset All
- Reset All resets a sessionOnly row and fires its onChange once, on both builds
- the degraded Reset All logs one line in total, the profile handler's, with no count
- the degraded Reset All with no AceDB writes the session row and logs nothing
- with LibKa0s absent, the lock and unlock verbs still write the store
- with LibKa0s absent, /at disable stands the addon down and /at enable brings it back
- with LibKa0s absent, /at unlock in combat is refused and the lock stays on
- with LibKa0s absent, entering combat still re-locks unlocked bars in the store
- the degraded stub publishes LSMValues, the one member reached at file load
- the degraded stub publishes the five composers, hollow
- the degraded stub keeps no private copy of the library's layout constants
- PARENT_TITLE reaches the library through the descriptor, not the namespace
- the live arm patches LSM30_Border through the library, not through a private copy
- the Profiles page SHOWS the container AceConfigDialog fills, even a pooled (hidden) one
- General's Reset all settings tooltip says it is the same act as Profiles -> Reset Profile

### test_slashcmds.lua (91)

- every COMMANDS entry is a {name, description, handler} triple
- COMMANDS verbs are unique and already lower-case
- the About page renders one row per verb, through the same formatter as /at help
- the About rows carry the help colors, without the chat indent
- /at lock and /at unlock write the `locked` setting and echo it in the set shape
- /at unlock in combat echoes the refused write: the stored value, not the argument
- /at lock and /at unlock each refresh an open options panel once
- /at toggle turns every bar off, then every bar back on
- /at toggle <unit> flips only that unit
- /at toggle rejects an unknown unit and changes nothing
- /at toggle requests a repaint when SHOWING, not when hiding
- /at update publishes REPAINT and acknowledges
- /at reset with no path prints usage rather than resetting anything
- /at reset rejects a path that is not a setting
- /at reset restores one setting and leaves its neighbors alone
- /at reset <path> writes the default and fires the row's onChange exactly once
- /at reset <path> logs exactly one [Set] line and fires onChange exactly once
- /at reset does NOT lower-case its argument
- /at resetall goes through the one shared RestoreAllDefaults helper
- /at resetall really does restore the defaults end to end
- /at resetall says the helpers are missing instead of claiming success
- /at resetposition clears the saved anchor and republishes POSITION
- /at get with no path prints usage
- /at get on an unknown path says so instead of printing nil
- /at set with no path prints usage and points at /at list
- /at set on an unknown path says so
- /at set rejects a junk boolean and lists the words it accepts
- /at set rejects a non-numeric value for a number setting
- /at set writes a color from `r g b a` and echoes the STORED value
- /at set accepts a bool written as a human word
- /at profile with no subcommand prints the sub-help
- /at profile current names the active profile
- /at profile list marks the current profile
- /at profile use switches the active profile
- /at profile use with no name prints usage and switches nothing
- /at profile new creates a profile carrying the defaults, not the old values
- /at profile new refuses a name that already exists and leaves it untouched
- /at profile new with no name prints usage
- /at profile copy pulls another profile's values into the current one
- /at profile copy with no name prints usage
- /at profile copy of a missing profile refuses before AceDB sees the name
- /at profile copy of the current profile refuses
- /at profile delete refuses to delete the profile in use
- /at profile delete removes a profile that is not in use
- /at profile delete of a missing profile says so and deletes nothing
- /at profile delete with no name prints usage
- /at profile reset restores the current profile's defaults in place
- /at profile reset logs one [Set] line from the reset handler, counting the rows it changed
- /at resetall logs one line in total, the same reset handler's
- /at profile new logs the switch line, then a (0 rows) reset line
- a profile copy logs one [Set] line naming both profiles
- /at profile copy reaches the copy handler, one line
- a profile switch keeps its [Profile] line and logs no [Set] line
- /at profile rejects an unknown subcommand and reprints the sub-help
- /at profile sub-verbs are case-insensitive
- /at profile degrades gracefully when AceDB is unavailable
- a profile switch repaints the bar through OnProfileChanged
- set writes a dotted per-unit path
- set on one unit leaves the others alone
- an unqualified appearance key is rejected
- a global key still uses its flat path
- get echoes a dotted path
- list groups the appearance page by unit
- reset takes one fully-qualified path, not a page
- resetposition clears all three positions
- toggle round-trips the enabled set
- /at get annotates a row whose unit is currently mirroring the player
- /at get does NOT annotate an unmirrored unit, or the player
- /at get does NOT annotate the per-unit rows a mirror never covers
- /at set echoes the mirrored note alongside the value it just stored
- /at list annotates only the mirrored units' appearance rows
- the mirrored note keeps the Ka0s color scheme intact and stays subordinate
- parity: both dispatchers fold the verb and preserve the rest's case
- parity: both dispatchers resolve the `options` alias to `config`
- parity: an unknown verb reaches no handler and prints the same shape in both
- parity: a bare /at reaches the config handler with an empty rest in both
- degraded: the stub's disabled-line format is the library's, byte for byte
- degraded: a schema verb prints the library-absent line
- degraded: the library-absent line is keyed by its English text (localization-§2)
- degraded: /at help rows are plain, with no color escape
- degraded: DisabledLine is the live build's line, color escapes intact
- /at set stores a multi-word string value whole
- /at enable and /at disable write the Enable row's OWN path, through the one seam
- /at disable echoes the stored value in the set shape, and /at enable undoes it
- the pair is never one-way: the dispatcher still answers while the addon is disabled
- enable and disable hold no state of their own
- every verb is either on the live list or refuses while disabled, and none is unclassified
- the refusal is the collection's one line, tagged, and not re-spelled here
- a refused `toggle` does not touch a single bar's enabled flag
- a refused `unlock` leaves the lock exactly where it was
- a refused `update` publishes nothing on the bus

### test_perfcmds.lua (42)

- /at perf (bare) reports status and prints usage
- /at perf start starts a capture
- /at perf start resets the counters from the previous capture
- /at perf finish refuses when no run is active
- /at perf finish does not print the summary
- /at perf report still prints the summary on demand
- /at perf finish saves the record to the perf ring
- /at perf finish lifts a suspend left over from the capture
- /at perf report prints without stopping the capture
- /at perf routes output to the debug console, not chat
- /at perf report writes the JSON to the console, not to a copy window
- /at perf report emits parseable JSON carrying the schema stamp, as its LAST line
- /at perf with an unknown sub falls back to the usage block
- /at debug on|off still toggles logging with perf present
- perf is a top-level verb in the help index
- perf is registered in NS.COMMANDS, so the About page lists it too
- /at debug no longer swallows a perf argument
- /at perf start accepts an optional label, appended to the timestamp
- /at perf start without a label still stamps the capture
- /at perf start label reaches the saved record
- /at perf start records who and where the capture happened
- /at perf report prints the capture's context, not just the numbers
- /at perf measure a arms Experiment A
- /at perf measure b arms Experiment B and suspends
- /at perf measure refuses outside an experiment
- /at perf measure rejects an unknown window
- /at perf bare reports the armed window
- the perf usage block documents the measure workflow
- /at perf start opens the panel instead of listing the steps in chat
- /at perf cancel abandons the run and closes the panel
- /at perf show, hide and toggle drive the panel without touching the run
- /at perf (bare) opens the panel — it is the entry point to a run
- /at perf then clicking Start runs a whole run without another typed command
- a panel click reaches chat through this addon's print sink, like typing does
- the perf usage block documents show/hide/toggle
- /at perf cancel says so when there is nothing to cancel
- the perf usage block documents cancel
- /at perf start announces to the console with debug logging OFF
- /at perf no longer offers suspend or resume
- /at perf finish resumes before it saves, so a later error cannot strand the addon
- /at perf report opens the debug console when it is hidden
- /at perf report marks itself reviewed exactly once

### test_debughold.lua (15)

- the `test` verb is gone: it prints unknown command
- COMMANDS carries no `test` row, and the debug row names `hold <value> [secs]`
- /at debug hold with a word it does not know prints the usage and changes nothing
- bare /at debug hold prints the usage and holds nothing
- /at debug hold with a negative duration prints the usage and holds nothing
- /at debug hold refuses a duration above 60 s and below 0.5 s
- /at debug hold accepts both ends of the range
- /at debug hold announces a fractional duration as given, and holds for it
- /at debug hold refuses while every bar is disabled and says how to fix it
- /at debug hold paints the given value and arms the hold window
- /at debug hold with a value and no duration holds it for 5 seconds
- /at debug hold keeps the bar scale usable for a value below the 100k floor
- /at debug hold schedules the expiry it just announced
- re-locking the bars clears a live /at debug hold preview
- /at debug hold refuses while the addon is disabled: one line, no paint, no hold

### test_widgets.lua (57)

- NS.AceGUI is stashed once by CreateOptionsPanel, not re-fetched per builder
- a bool row renders a CheckBox labeled from the schema
- a checkbox reads its initial state from the current setting
- clicking a checkbox writes through SetByPath
- a checkbox registers a refresher that re-reads after an external change
- every widget gets tooltip callbacks wired from the schema desc
- relativeWidth is applied when given, full width otherwise
- SessionCheckbox reads and writes the caller's get/set, never the DB
- SessionCheckbox registers a refresher so external state changes show up
- a number row renders a Slider carrying the schema's range and step
- a slider shows the current value
- a slider falls back to the row default when the stored value is not a number
- releasing a slider snaps the value to the row's step
- slider snapping is relative to the row's min, not to zero
- a string row falls back to a plain Dropdown when the LSM widget is absent
- a string row uses its dialogControl widget when that IS registered
- a dropdown's list is alphabetically ordered by default
- a row with explicit `sorting` keeps that order instead of sorting
- a dropdown shows the current value and writes the chosen one
- a dropdown's refresher re-applies the list, so a grown LSM list appears
- a color row renders a ColorPicker seeded from the stored rgba
- a color picker substitutes 1s for a missing/corrupt stored color
- disabledIf grays a swatch out while its sibling toggle is on
- the refresher re-evaluates disabledIf, so the pair tracks on the same frame
- no shipped color row disables itself, under either class-color mode
- OnValueConfirmed commits the color immediately (cancel must not wait on the throttle)
- OnValueChanged throttles a drag to ONE timer and commits the latest value
- a drag that resumes after the timer fired arms a fresh one
- RenderField dispatches each schema type to its widget
- RenderField returns nil for an unrecognized type instead of erroring
- RenderField adds the widget to the parent it was given
- RenderSchema pairs widgets two-to-a-row inside full-width Flow groups
- RenderSchema gives each paired widget half the row
- a `solo` row is rendered alone on its own line
- `startsLine` flushes the pending line, so a declared pair can never be split
- RenderSchema emits a Heading for each schema group
- an afterGroup callback fires exactly once, after its group's last row
- the Bars tab pairs the enable toggles with each other, not with a global
- every tracked unit gets an enable toggle on the General page
- visibility repaints for a target-only setup, not just for the player
- the Reset All popup does not claim success when the settings helpers are absent
- a pairWith partner is attached to the named row and is one-shot
- RenderSchema runs a layout pass at the end
- EnsureScroll is lazy, created once, and patched for an always-visible scrollbar
- every schema page registered a real Blizzard subcategory at build time
- the Profiles page self-skips when AceDBOptions is unavailable
- the sidebar path is covered in combat, draws nothing and leaves the window open (options-ui-§2)
- first OnShow builds the Defaults button and renders the page
- the Defaults button restores just its own page
- a second OnShow rebuilds the panel body without stacking duplicate widgets
- the General page draws its two groups as a tab strip, Master controls first
- clicking Bars swaps the rows and leaves the button pair on Master controls
- every unit's Appearance strip is its schema's groups, and each tab draws that group's rows
- a mirrored unit's every tab draws the hint and none of the appearance rows
- showing every page builds it without error
- the main page's About content renders on its first OnShow
- re-rendering the About page replaces its body rather than stacking a second copy

### test_docs.lua (4)

- README.md carries no angle-bracket argument placeholders
- every Tier 2 documentation-map row agrees with docs/
- every deviation id the register cites is assigned by a bundle in docs/audits/
- docs/smoke-tests.md carries a non-English-client section

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_ltrap.lua (8)

- the source matcher tells the three `L =` spellings apart
- no LibKa0s descriptor in this addon is handed the key-returning locale table
- locales/enUS.lua really does answer every key, so the check above guards something
- LibKa0s-Core tripwire: Core ships no STRINGS and reads no descriptor L
- LibKa0s-Options tripwire: Options reads no descriptor L
- vendored DebugLog resolves a fallback-only override to its own strings
- vendored Slash resolves a fallback-only override to its own strings
- vendored Perf resolves a fallback-only override to its own strings

### test_surface_parity.lua (10)

- parity: the Core stub publishes everything core/CoreSetup.lua publishes live
- parity: the DebugLog stub carries the whole live surface
- parity: the Options stub carries every helper the degraded build can reach
- parity: the Slash stub carries every dispatcher member the addon calls
- parity: the Launcher stub carries the whole live surface
- parity: the Bus stub carries the library's whole surface
- parity: the Schema stub carries the library's lib-level surface
- parity: the Schema stub's instance carries every member of a live instance
- parity: the Perf stub carries every Perf member the addon reaches
- parity: the Lifecycle stub carries the whole live surface

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_lintconfig.lua (4)

- lintconfig: .luacheckrc sets no top-level ignore
- lintconfig: .luacheckrc switches no warning class off wholesale
- lintconfig: every files[...] ignore is narrowed to a file or a name
- lintconfig: no source file carries a bare inline luacheck ignore

### test_events.lua (5)

- events: the session rejected list exists and starts empty
- events: one unknown lifecycle name costs only itself, and is listed once
- events: one unknown unit event on the per-unit frame costs only itself
- events: a name IsEventValid refuses never reaches the target
- events: /at debug events lists the rejected names, and 'none' once they are gone

### test_disabled.lua (16)

- disabled 1: the enabled addon registers something to stand down from
- disabled 3: writing the enable path leaves NOTHING registered
- disabled 4: no timer, ticker or OnUpdate is left armed
- disabled 5: every frame that was on screen is hidden, and stays hidden
- disabled 6: firing every baseline event writes nothing, says nothing, shows nothing
- disabled 7: every reserved verb answers, and only a feature verb refuses
- disabled 7: a refused feature verb reaches no write seam
- disabled 7: `debug` stays live, and its `hold` sub-verb refuses on its own gate
- disabled 8: the left click is refused and writes nothing; the right click still opens the panel
- disabled 9: re-enabling restores the registration set, from the settings as they are NOW
- disabled 9: the bus subscriptions come back as the same five pairs, and each still reaches its consumer once
- disabled 10: releasing one hold does not stand up an addon the other still holds down
- disabled 10: the perf hold is session-only and the disabled hold is the stored path
- bus: a registration made while stood down is recorded, and not live until the stand-up
- bus: a subscription its owner dropped is not brought back by a stand-up
- bus: the stand-down and stand-up counts are the record's, and the latch drives both

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

## Totals

| Suite | Cases |
|-------|------:|
| test_loadorder.lua | 14 |
| test_schema.lua | 60 |
| test_database.lua | 38 |
| test_units.lua | 17 |
| test_envsetup.lua | 7 |
| test_coresetup.lua | 6 |
| test_mediasetup.lua | 10 |
| test_debuglog.lua | 12 |
| test_slash.lua | 14 |
| test_timer.lua | 12 |
| test_perf.lua | 33 |
| test_visibility.lua | 22 |
| test_bus.lua | 12 |
| test_data.lua | 32 |
| test_display.lua | 60 |
| test_draghandle.lua | 22 |
| test_helpers.lua | 70 |
| test_launcher.lua | 22 |
| test_optionssetup.lua | 15 |
| test_slashcmds.lua | 91 |
| test_perfcmds.lua | 42 |
| test_debughold.lua | 15 |
| test_widgets.lua | 57 |
| test_docs.lua | 4 |
| test_prose.lua | 15 |
| test_ltrap.lua | 8 |
| test_surface_parity.lua | 10 |
| test_vendor_sync.lua | 3 |
| test_lintconfig.lua | 4 |
| test_events.lua | 5 |
| test_disabled.lua | 16 |
| test_eol.lua | 2 |
| test_layout_cap.lua | 13 |
| **Total** | **763** |
