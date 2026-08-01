# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below is the **authoritative pass count** — the README test
badge and any count quoted in the docs must agree with it.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_loadorder.lua (10)

- loadorder: tocFiles returns every addon lua file, in TOC order
- loadorder: tocFiles skips libs, directives and comments
- loadorder: tocFiles converts backslashes to forward slashes
- loadorder: every derived path exists on disk
- loadorder: the runner loaded exactly the TOC's files, in the TOC's order
- loadorder: tests/perf.lua derives its list from the TOC too
- loadorder: both runners load every LibKa0s file the vendored XML lists, in its order
- loadorder: LibStub raises for a missing major without the silent flag
- loadorder: LibStub returns nil for a missing major with the silent flag
- loadorder: LibStub keeps the higher minor when a major registers twice

### test_schema.lua (38)

- FormatSchemaValue formats by type
- SchemaForPage keeps groups in registration order (Size, Bar, Background)
- ValidateSchema resolves every real path against defaults (0 errors, 0 missing)
- ValidateSchema reports a planted path that does not resolve against defaults
- ValidateSchema flags an invalid page/type as a shape error
- every schema row carries a label and a tooltip description
- every schema path is unique
- every schema row declares a default
- every row's default matches the value in defaults.profile
- every persisted profile default is reachable from a schema row
- every number row declares a usable min/max range
- every string row supplies a values source
- `disabledIf` names a real sibling setting
- every schema row lands on a page the panel actually builds
- FindSchemaRow returns the row for a known path and nil for an unknown one
- SetByPath writes the value and fires the row's own onChange with it
- SetByPath falls back to broadcasting APPEARANCE for a row with no onChange
- SetByPath still writes a value that has no schema row at all
- ApplyDefault deep-copies a color table so profiles never share one
- ApplyDefault is a no-op for a row with no default
- ResolvePath walks a dotted path
- ResolvePath returns nil for a missing branch instead of raising
- ResolvePath still handles a flat key
- SetPath writes through a dotted path and creates intermediate tables
- GetSetting and SetSetting round-trip a dotted path
- ValidateSchema resolves nested paths against defaults.profile
- SchemaForPage with no unit returns every unit's rows
- SchemaForPage filtered to a unit excludes the other units' rows
- PartitionUnitRows splits alwaysPerUnit rows from the mirrored appearance rows
- every appearance page carries a full row set for all three units
- each unit's row set for a page is the same size
- the enable row is per-unit, lives on General, and survives mirroring
- the enable toggles lead the left column, interleaved with the globals
- the mirror row exists for target and focus but not the player
- the mirror row is kept out of the auto-rendered body
- General's rows are the flat globals plus one enable toggle per unit
- FormatSchemaValue resolves the Slash major at load, never per call
- a build without LibKa0s-Slash-1.0 falls back to a minimal FormatSchemaValue

### test_database.lua (27)

- RunMigrations migrates a fresh DB to the current version (4)
- RunMigrations leaves an already-current (v4) DB unchanged
- RunMigrations is idempotent across repeated runs
- RunMigrations v2 retires the legacy updateInterval profile key
- RunMigrations backfills throttleWindow from flatDefaults
- RunMigrations backfills a missing scalar per-unit key from the defaults
- RunMigrations deep-copies per-unit table defaults (no shared reference to defaults)
- RunMigrations does not overwrite an existing user value
- RunMigrations is a safe no-op when the DB is absent
- RunMigrations logs [Migrate] only when a version bump happens
- InitDB produced a profile carrying every default key
- v3 migration lifts flat appearance keys onto the player unit
- v3 migration seeds target and focus disabled and mirrored
- v3 migration leaves the remaining global keys flat
- v4 drops the dead `hidden` key from every profile, not just the active one
- v4 does not resurrect `hidden` via the defaults backfill
- v3 migration is idempotent
- v3 migration does not share nested tables between units
- the schema version lands on 4
- real AceDB init: a legacy flat profile is lifted onto the player unit, not overwritten by fresh defaults
- real AceDB init: a fresh install (no saved data) converges on factory defaults at v4
- InitDB lifts EVERY saved profile, not only the active one
- a profile that appears AFTER the upgrade is lifted when it becomes active
- the InitDB sweep and the profile-change lift compose without double-applying
- the per-profile stamp defaults to 1 so copyDefaults cannot mark a pre-v3 profile migrated
- a fresh install logs no [Migrate] lift line -- nothing was actually lifted
- a real upgrade still logs the lift, with an accurate count

### test_units.lua (14)

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
- IsEnabled reads the per-unit flag and ignores the global hidden toggle
- target and focus ship disabled so an upgrade changes nothing on screen
- target and focus ship mirrored so a first enable looks like the player bar

### test_compat.lua (4)

- Compat.GetAddOnMetadata prefers C_AddOns.GetAddOnMetadata
- Compat.GetAddOnMetadata falls back to the global GetAddOnMetadata
- Compat.GetAddOnMetadata returns nil when neither API is present
- No inline GetAddOnMetadata leaks: Compat is the only metadata accessor

### test_coresetup.lua (4)

- core: the secret seam is the library's, not a private copy
- core: NS.Print carries the [AT] tag and survives a secret arg
- core: NS.Print and NS.Util.print are the same object after the AceConsole reclaim
- core: the addon still prints, tagged, with LibKa0s absent

### test_debuglog.lua (10)

- FONT_MONO constant is a JetBrains Mono TTF path
- the debug flag the library reads and writes is NS.State.debug
- NS.Debug is published and reaches the console buffer
- our title and our font reach the descriptor
- the console checkbox the General page renders is wired to this addon
- /at debug on enables session state
- /at debug off disables session state
- /at debug (no arg) toggles the window, not the state
- /at debug on writes an [Init] summary naming our version, schema and profile
- the console checkbox label the library renders is prose, not its own STRINGS key

### test_slash.lua (13)

- NS.Print survives AceConsole's embed and stays the [AT]-prefixed printer
- bare /at prints the help index: header + one row per command
- unknown verb prints 'unknown command' then the help index
- /at version prints the addon version (slash-commands-§3)
- /at get <path> dispatches to the schema read
- /at list uses the mandated color scheme (slash-commands-§5)
- /at set <path> <value> writes through the schema and preserves path case
- /at set clamps out-of-range numbers to the row max
- /at options is aliased to /at config (no unknown-command error)
- /at config in combat refuses with a gray notice (options-ui-§2)
- OpenOptionsPanel logs [Cfg] refused in combat
- SetByPath logs one [Set] path = value line (§10)
- the schema CLI's list header the library renders is prose, not its own STRINGS key

### test_timer.lua (11)

- RequestRepaint coalesces multiple requests into one scheduled repaint
- the coalesced repaint paints every tracked unit, not just the player
- one coalesced pass counts one repaint, however many bars it painted
- a pass in which no bar painted counts no repaint
- a pass counts one repaint when only some of the bars painted
- RequestRepaint schedules the timer at the throttleWindow delay
- OnAbsorbChanged requests a repaint for the player
- OnAbsorbChanged requests a repaint for any tracked unit, not just the player
- OnMaxHealthChanged requests a repaint for the player
- OnMaxHealthChanged requests a repaint for any tracked unit, not just the player
- OnEnterWorld requests a repaint

### test_perf.lua (27)

- perf: the addon holds a real LibKa0s-Perf instance
- perf: the descriptor declares this addon's buckets, with their nesting
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
- perf: the schema is COMPLETE with LibKa0s absent (the pages still finish loading)
- perf: the addon loads with LibKa0s absent
- perf: /at perf explains itself instead of erroring with LibKa0s absent
- perf: the brackets and the show ladder survive LibKa0s being absent
- every perf step label the library renders is prose, not its own STRINGS key

### test_visibility.lua (17)

- ShouldShowBar: a disabled unit wins even in combat
- ShouldShowBar: default (enabled, not combat-only) is shown
- ShouldShowBar: combat-only + in combat is shown
- ShouldShowBar: combat-only + out of combat is hidden
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

### test_bus.lua (7)

- bus, NewBusTarget, and the message catalog are published
- a receiver on its own target hears a message, then is silent after unregister
- two receivers of one message both fire (no (message,target) clobber)
- a message payload reaches the receiver after the message name
- REPAINT routes through Timer to one coalesced repaint
- APPEARANCE / VISIBILITY / POSITION route to their Display consumers
- sending a message with no subscribers is a harmless no-op

### test_data.lua (26)

- GetSetting reads the value out of the active profile
- GetSetting falls back to flatDefaults when the key is missing from the profile
- GetSetting falls back to flatDefaults when the DB is absent entirely
- GetSetting returns nil for a key that is neither in the profile nor the defaults
- GetSetting returns a stored `false` rather than falling through to the default
- SetSetting writes through to the active profile
- SetSetting is a harmless no-op when the DB is absent
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
- the three class-color toggles are independent of each other
- media getters read through the unit's mirror resolution
- a media getter with no unit still resolves the player
- with LSM present, the media getter resolves the REQUESTED unit's own key, not the player's
- GetBarColor reads the requested unit's color
- class color on a target bar is still the PLAYER's class color
- three bar frames exist and the player alias points at the player frame
- each bar carries its own unit tag and its own backdrop table

### test_display.lua (39)

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
- every bar owns a unit label
- unlocking shows a label naming the unit
- locking hides the unit label
- the unit label follows the unit's own font face
- UpdateBarAppearance re-applies the font from the profile
- UpdateBarAppearance tolerates a nil fontFlags by passing an empty flag string
- UpdateBarAppearance ends by applying visibility
- ApplyVisibility shows the bar when the gate passes and hides it when it does not
- UpdateAbsorbBar is a no-op while the bar is hidden
- UpdateAbsorbBar is a no-op inside a /at test hold window
- UpdateAbsorbBar paints again once the hold window has expired
- UpdateAbsorbBar scales the bar to max health and sets the absorb value
- UpdateAbsorbBar substitutes 0 / 1 when the absorb and health reads come back nil
- UpdateAbsorbBar writes the abbreviated value into the bar text
- UpdateAbsorbBar reports true when it paints
- UpdateAbsorbBar reports false for a bar it skipped
- UpdateAbsorbBar reports false while a /at test hold is active
- each unit's enable flag governs only its own bar
- a disabled unit stays hidden even when the others are on
- an enabled target bar hides when there is no target
- the player bar never consults UnitExists
- showOnlyInCombat gates every bar on PLAYER combat
- UpdateAbsorbBar reads the absorb of the unit it is painting
- UpdateBarAppearance sizes the bar it is given, not always the player's
- a mirrored unit paints with the player's size
- the player bar defaults to dead center
- target and focus default stacked above the player bar
- ForEachUnit walks all three units in order

### test_helpers.lua (49)

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
- RestoreAllDefaults resets every schema row that is not on the profiles page
- RestoreAllDefaults clears the saved bar position so the bar recentres
- RestoreAllDefaults publishes POSITION so the bar moves immediately
- RestoreAllDefaults skips the profiles page (resetting it would delete user data)
- RefreshAllPanels runs the refreshers of every registered panel
- RefreshAllPanels isolates a throwing refresher from the rest
- NS.RefreshOptionsPanel delegates to RefreshAllPanels
- the cross-slice layout constants are published for the widget/about slices
- the Bar page opens on the player unit with no mirror header
- RenderUnitPanel draws a Unit dropdown listing all three units
- switching the dropdown to focus re-renders the page for that unit
- a mirrored unit shows only its header, no appearance rows
- unchecking the mirror reveals the appearance rows
- the copy button snapshots the player's styling and clears the mirror
- a page Defaults button resets that page across every unit
- RestoreAllDefaults clears all three saved positions
- the mirror checkbox renders exactly once — the header owns it, RenderRows must skip it
- the mirror checkbox and copy button share one full-width Flow row at half width each
- every header row is followed by a ROW_VSPACER, as the hand-rolled block did
- one raising header item no longer costs the rest of the page
- ClearScroll resets ctx.refreshers, so repeated renders do not leak stale closures
- the General page's Reset Position button clears EVERY unit's saved position
- the Reset Position button and /at resetposition run the SAME shared helper
- a page refresh re-syncs the mirror checkbox and re-runs the row partition
- `/at set units.<unit>.mirror` re-syncs an open panel's mirror header
- the header refresher cannot recurse: a refresh fired mid-render is a no-op
- a raise mid-render must not latch the re-entrancy flag for the session
- a failed unit-panel render is reported in chat, never swallowed
- an ordinary schema write does NOT re-render the whole unit page
- a mirror-state change DOES re-render -- the two-tier refresher keeps both halves
- /at resetposition does not claim success when the settings helpers are absent
- the Defaults button the library renders is prose, not its own STRINGS key

### test_optionssetup.lua (4)

- the live and degraded builds veto exactly the same rows from Reset All
- the degraded stub publishes LSMValues, the one member reached at file load
- the degraded stub keeps no private copy of the library's layout constants
- PARENT_TITLE reaches the library through the descriptor, not the namespace

### test_slashcmds.lua (109)

- every COMMANDS entry is a {name, description, handler} triple
- COMMANDS verbs are unique and already lower-case
- the About page renders one row per verb, through the same formatter as /at help
- the About rows carry the help colors, without the chat indent
- /at lock and /at unlock write the `locked` setting and acknowledge
- /at toggle turns every bar off, then every bar back on
- /at toggle <unit> flips only that unit
- /at toggle rejects an unknown unit and changes nothing
- /at toggle requests a repaint when SHOWING, not when hiding
- /at update publishes REPAINT and acknowledges
- /at reset with no path prints usage rather than resetting anything
- /at reset rejects a path that is not a setting
- /at reset restores one setting and leaves its neighbours alone
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
- /at test refuses while every bar is disabled and tells the user how to fix it
- /at test paints the given value and arms the hold window
- /at test defaults to 50000 held for 5 seconds
- /at test keeps the bar scale usable for a value below the 100k floor
- /at profile with no subcommand prints the sub-help
- /at profile current names the active profile
- /at profile list marks the current profile
- /at profile use switches the active profile
- /at profile use with no name prints usage and switches nothing
- /at profile new creates a profile carrying the defaults, not the old values
- /at profile new with no name prints usage
- /at profile copy pulls another profile's values into the current one
- /at profile copy with no name prints usage
- /at profile delete refuses to delete the profile in use
- /at profile delete removes a profile that is not in use
- /at profile delete with no name prints usage
- /at profile reset restores the current profile's defaults in place
- /at profile rejects an unknown subcommand and reprints the sub-help
- /at profile sub-verbs are case-insensitive
- /at profile degrades gracefully when AceDB is unavailable
- a profile switch repaints the bar through OnProfileChanged
- set writes a dotted per-unit path
- set on one unit leaves the others alone
- an unqualified appearance key is rejected
- a global key still uses its flat path
- get echoes a dotted path
- list groups the appearance pages by unit
- reset takes one fully-qualified path, not a page
- resetposition clears all three positions
- toggle round-trips the enabled set
- /at get annotates a row whose unit is currently mirroring the player
- /at get does NOT annotate an unmirrored unit, or the player
- /at get does NOT annotate the per-unit rows a mirror never covers
- /at set echoes the mirrored note alongside the value it just stored
- /at list annotates only the mirrored units' appearance rows
- the mirrored note keeps the Ka0s color scheme intact and stays subordinate
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
- /at perf dump writes to the console, not the copy window
- /at perf dump emits parseable JSON carrying the schema stamp
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
- /at perf dump opens the debug console when it is hidden
- /at perf dump marks itself reviewed exactly once
- parity: both dispatchers fold the verb and preserve the rest's case
- parity: both dispatchers resolve the `options` alias to `config`
- parity: an unknown verb reaches no handler and prints the same shape in both
- parity: a bare /at reaches no handler and prints help in both

### test_widgets.lua (48)

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
- disabledIf grays the swatch out while its sibling toggle is on
- the refresher re-evaluates disabledIf, so the pair tracks on the same frame
- OnValueConfirmed commits the color immediately (cancel must not wait on the throttle)
- OnValueChanged throttles a drag to ONE timer and commits the latest value
- a drag that resumes after the timer fired arms a fresh one
- RenderField dispatches each schema type to its widget
- RenderField returns nil for an unrecognised type instead of erroring
- RenderField adds the widget to the parent it was given
- RenderSchema pairs widgets two-to-a-row inside full-width Flow groups
- RenderSchema gives each paired widget half the row
- a `solo` row is rendered alone on its own line
- RenderSchema emits a Heading for each schema group
- an afterGroup callback fires exactly once, after its group's last row
- each enable toggle leads its row, paired with a global on the right
- every tracked unit gets an enable toggle on the General page
- a pairWith partner is attached to the named row and is one-shot
- RenderSchema runs a layout pass at the end
- EnsureScroll is lazy, created once, and patched for an always-visible scrollbar
- every schema page registered a real Blizzard subcategory at build time
- the Profiles page self-skips when AceDBOptions is unavailable
- a page renders nothing until its first OnShow
- first OnShow builds the Defaults button and renders the page
- the Defaults button restores just its own page
- a second OnShow rebuilds the panel body without stacking duplicate widgets
- showing every page builds it without error
- the main page's About content renders on its first OnShow

### test_docs.lua (2)

- README.md carries no angle-bracket argument placeholders
- the addon's own files use US spellings

### test_ltrap.lua (8)

- the source matcher tells the three `L =` spellings apart
- no LibKa0s descriptor in this addon is handed the key-returning locale table
- locales/enUS.lua really does answer every key, so the check above guards something
- LibKa0s-Core tripwire: Core ships no STRINGS and reads no descriptor L
- LibKa0s-Options tripwire: Options reads no descriptor L
- vendored DebugLog resolves a fallback-only override to its own strings
- vendored Slash resolves a fallback-only override to its own strings
- vendored Perf resolves a fallback-only override to its own strings

## Totals

| Suite | Cases |
|-------|------:|
| test_loadorder.lua | 10 |
| test_schema.lua | 38 |
| test_database.lua | 27 |
| test_units.lua | 14 |
| test_compat.lua | 4 |
| test_coresetup.lua | 4 |
| test_debuglog.lua | 10 |
| test_slash.lua | 13 |
| test_timer.lua | 11 |
| test_perf.lua | 27 |
| test_visibility.lua | 17 |
| test_bus.lua | 7 |
| test_data.lua | 26 |
| test_display.lua | 39 |
| test_helpers.lua | 49 |
| test_optionssetup.lua | 4 |
| test_slashcmds.lua | 109 |
| test_widgets.lua | 48 |
| test_docs.lua | 2 |
| test_ltrap.lua | 8 |
| **Total** | **467** |
