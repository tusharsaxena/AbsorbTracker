# Test Cases

_Generated — do not hand-edit. Regenerate with `lua tests/run.lua --list > docs/test-cases.md`._

### test_schema.lua (9)

- ParseSchemaValue bool accepts truthy/falsey words, rejects junk
- ParseSchemaValue number clamps to the row's min/max
- ParseSchemaValue color accepts 0-1 and 0-255 and clamps to 0..1
- ParseSchemaValue string validates against allowed values
- FormatSchemaValue formats by type
- SchemaForPage keeps groups in registration order (Size, Bar, Background)
- ValidateSchema resolves every real path against defaults (0 errors, 0 missing)
- ValidateSchema reports a planted path that does not resolve against defaults
- ValidateSchema flags an invalid page/type as a shape error

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

## Totals

| Suite | Count |
|-------|-------|
| test_schema.lua | 9 |
| test_database.lua | 11 |
| test_compat.lua | 4 |
| test_util.lua | 6 |
| test_debuglog.lua | 14 |
| test_slash.lua | 12 |
| test_timer.lua | 7 |
| test_visibility.lua | 11 |
| test_bus.lua | 7 |
| **Total** | **81** |
