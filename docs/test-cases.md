# Test Cases

_Generated — do not hand-edit. Regenerate with `lua tests/run.lua --list > docs/test-cases.md`._

### test_schema.lua (25)

- ParseSchemaValue bool accepts truthy/falsey words, rejects junk
- ParseSchemaValue number clamps to the row's min/max
- ParseSchemaValue color accepts 0-1 and 0-255 and clamps to 0..1
- ParseSchemaValue string validates against allowed values
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
- `inverse` is only used on bool rows
- `disabledIf` names a real sibling setting
- every schema row lands on a page the panel actually builds
- FindSchemaRow returns the row for a known path and nil for an unknown one
- SetByPath writes the value and fires the row's own onChange with it
- SetByPath falls back to broadcasting APPEARANCE for a row with no onChange
- SetByPath still writes a value that has no schema row at all
- ApplyDefault deep-copies a colour table so profiles never share one
- ApplyDefault is a no-op for a row with no default

### test_database.lua (11)

- RunMigrations migrates a fresh DB to the current version (2)
- RunMigrations leaves an already-current (v2) DB unchanged
- RunMigrations is idempotent across repeated runs
- RunMigrations v2 retires the legacy updateInterval profile key
- RunMigrations backfills throttleWindow from flatDefaults
- RunMigrations backfills a missing scalar profile key from flatDefaults
- RunMigrations deep-copies table defaults (no shared reference to flatDefaults)
- RunMigrations does not overwrite an existing user value
- RunMigrations is a safe no-op when the DB is absent
- RunMigrations logs [Migrate] only when a version bump happens
- InitDB produced a profile carrying every default key

### test_compat.lua (4)

- Compat.GetAddOnMetadata prefers C_AddOns.GetAddOnMetadata
- Compat.GetAddOnMetadata falls back to the global GetAddOnMetadata
- Compat.GetAddOnMetadata returns nil when neither API is present
- No inline GetAddOnMetadata leaks: Compat is the only metadata accessor

### test_util.lua (6)

- IsConcatSafe: true for plain number/string, false for an un-concatenable value
- SafeToString: passes normal values through tostring
- SafeToString: renders a secret value as <secret> instead of raising
- NS.Debug routes the first arg as the [tag] and tolerates a secret arg
- NS.Debug is a no-op when debug is off
- Print tolerates a secret arg (no concat crash)

### test_debuglog.lua (14)

- FONT_MONO constant is a JetBrains Mono TTF path
- FormatPlain wraps the tag in brackets with single-space separators
- FormatPlain tolerates a nil tag
- FormatColored colours the timestamp and tag; pipe and content default
- /at debug on enables session state
- /at debug off disables session state
- /at debug (no arg) toggles the window, not the state
- header toggle click flips debug state
- /at debug on: green-ON ack, then '[Debug] logging enabled' bracket + [Init] summary (§5)
- /at debug off: red-OFF ack, and '[Debug] logging disabled' is the last console line (§5)
- NS.Debug is a no-op (no console write) when debug is off
- ConsoleCheckbox spec: get() reflects the console window visibility, not the debug flag
- ConsoleCheckbox spec: set(true) shows the console window without changing the debug flag
- ConsoleCheckbox spec: set(false) hides the console window without changing the debug flag

### test_slash.lua (12)

- NS.Print survives AceConsole's embed and stays the [AT]-prefixed printer
- bare /at prints the help index: header + one row per command
- unknown verb prints 'unknown command' then the help index
- /at version prints the addon version (slash-commands-§3)
- /at get <path> dispatches to the schema read
- /at list uses the mandated colour scheme (slash-commands-§5)
- /at set <path> <value> writes through the schema and preserves path case
- /at set clamps out-of-range numbers to the row max
- /at options is aliased to /at config (no unknown-command error)
- /at config in combat refuses with a grey notice (options-ui-§2)
- OpenOptionsPanel logs [Cfg] refused in combat
- SetByPath logs one [Set] path = value line (§10)

### test_timer.lua (7)

- RequestRepaint coalesces multiple requests into one scheduled repaint
- RequestRepaint schedules the timer at the throttleWindow delay
- OnAbsorbChanged requests a repaint for the player
- OnAbsorbChanged ignores non-player units
- OnMaxHealthChanged requests a repaint for the player
- OnMaxHealthChanged ignores non-player units
- OnEnterWorld requests a repaint

### test_visibility.lua (11)

- ShouldShowBar: hidden master toggle wins even in combat
- ShouldShowBar: default (not hidden, not combat-only) is shown
- ShouldShowBar: combat-only + in combat is shown
- ShouldShowBar: combat-only + out of combat is hidden
- ShouldShowBar: combat-only shows when lockdown lags actual combat
- OnEnterCombat applies visibility and requests a repaint
- OnLeaveCombat applies visibility and requests a repaint
- OnLeaveCombat never opens config, even with a stale panelOpenPending (options-ui-§2)
- combat rollup: OnLeaveCombat logs one [Combat] left summary with counts
- OnAbsorbChanged is silent on an unchanged value (no per-event spam)
- [Absorb] transition logs on a non-secret 0->nonzero change

### test_bus.lua (7)

- bus, NewBusTarget, and the message catalogue are published
- a receiver on its own target hears a message, then is silent after unregister
- two receivers of one message both fire (no (message,target) clobber)
- a message payload reaches the receiver after the message name
- REPAINT routes through Timer to one coalesced repaint
- APPEARANCE / VISIBILITY / POSITION route to their Display consumers
- sending a message with no subscribers is a harmless no-op

### test_data.lua (19)

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
- GetBarColor returns the stored colour when useClassColorBar is off
- GetBarColor substitutes the class colour but KEEPS the stored alpha
- GetBorderColor honours useClassColorBorder and keeps its own alpha
- GetBorderColor returns the stored colour when the toggle is off
- GetBgColor uses the DIMMED class colour, not the raw one
- GetBgColor returns the stored colour when the toggle is off
- the three class-colour toggles are independent of each other

### test_display.lua (23)

- RestoreBarPosition centres the bar when no position is saved
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
- UpdateAbsorbBar notes the repaint for the combat rollup
- a hidden bar's skipped paint is NOT counted as a repaint

### test_helpers.lua (22)

- CreatePanel returns a ctx wired to a panel, a body and an empty refresher list
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

### test_slashcmds.lua (43)

- every COMMANDS entry is a {name, description, handler} triple
- COMMANDS verbs are unique and already lower-case
- NS.SlashCommands is the same table the About page renders
- /at lock and /at unlock write the `locked` setting and acknowledge
- /at toggle flips `hidden` in both directions
- /at toggle requests a repaint when SHOWING, not when hiding
- /at update publishes REPAINT and acknowledges
- /at reset with no page prints usage rather than resetting anything
- /at reset rejects an unknown page and names the valid ones
- /at reset <page> restores just that page
- /at reset lower-cases the page name
- /at resetall goes through the one shared RestoreAllDefaults helper
- /at resetall really does restore the defaults end to end
- /at resetposition clears the saved anchor and republishes POSITION
- /at get with no path prints usage
- /at get on an unknown path says so instead of printing nil
- /at set with no path prints usage and points at /at list
- /at set on an unknown path says so
- /at set rejects a junk boolean and lists the words it accepts
- /at set rejects a non-numeric value for a number setting
- /at set writes a colour from `r g b a` and echoes the STORED value
- /at set accepts a bool written as a human word
- /at test refuses while the bar is hidden and tells the user how to fix it
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

### test_widgets.lua (48)

- NS.AceGUI is stashed once by CreateOptionsPanel, not re-fetched per builder
- a bool row renders a CheckBox labelled from the schema
- a checkbox reads its initial state from the current setting
- clicking a checkbox writes through SetByPath
- an `inverse` row displays the NEGATED value
- an `inverse` row writes the negated value back too
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
- a color picker substitutes 1s for a missing/corrupt stored colour
- disabledIf greys the swatch out while its sibling toggle is on
- the refresher re-evaluates disabledIf, so the pair tracks on the same frame
- OnValueConfirmed commits the colour immediately (cancel must not wait on the throttle)
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
- a pairWith partner is attached to the named row and is one-shot
- RenderSchema runs a layout pass at the end
- EnsureScroll is lazy, created once, and patched for an always-visible scrollbar
- every schema page registered a real Blizzard subcategory at build time
- the Profiles page self-skips when AceDBOptions is unavailable
- a page renders nothing until its first OnShow
- first OnShow builds the Defaults button and renders the page
- the Defaults button restores just its own page
- a second OnShow is idempotent — no duplicate button, no re-render
- showing every page builds it without error
- the main page's About content renders on its first OnShow

## Totals

| Suite | Count |
|-------|-------|
| test_schema.lua | 25 |
| test_database.lua | 11 |
| test_compat.lua | 4 |
| test_util.lua | 6 |
| test_debuglog.lua | 14 |
| test_slash.lua | 12 |
| test_timer.lua | 7 |
| test_visibility.lua | 11 |
| test_bus.lua | 7 |
| test_data.lua | 19 |
| test_display.lua | 23 |
| test_helpers.lua | 22 |
| test_slashcmds.lua | 43 |
| test_widgets.lua | 48 |
| **Total** | **252** |
