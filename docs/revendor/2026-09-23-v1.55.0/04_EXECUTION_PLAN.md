# 04 - Execution plan

Written before any code moved. One commit per adopted candidate, in the order `03_DECISIONS.md`
takes them. Every commit is gated on `ka0s-bounded lua tests/run.lua` and the linter under the same
wrapper (`~/.claude/wow-addon/bin/ka0s-bounded`), both green. A candidate that goes red and cannot
be made green without changing behavior a test pins or a player sees is rolled back to its own
commit boundary and declined; it does not block the next one.

Baseline on `d5e37d6`: `lua tests/run.lua` 674 passed, 0 failed, 0 skipped, 674 total; the linter
0 warnings / 0 errors in 60 files; `lua tests/perf.lua` `probeOverheadOff` 48.0 bytes/iter
(ceiling 72), `settingsRead` 0.0 bytes/iter.

## C1. `LibKa0s-Bus-1.0` (one commit)

**Characterization first**, green on the unmodified tree, in `tests/test_bus.lua`:

1. The catalog is exactly the five keys and wire names (`pairs` over `NS.MSG`), `UNITS` included
   (today's case checks four).
2. A full stand-down and stand-up through the latch takes exactly the five production message
   subscriptions down and puts the same five back, the same (message, target) pairs in the same
   order, read off the kit's recording mock (`M.__registrations()`, kind `message`).
3. After that cycle each production message still reaches its consumer, once: `REPAINT` arms one
   coalesced repaint, `UNITS` re-syncs the unit frames, `APPEARANCE` / `VISIBILITY` / `POSITION`
   fan out once per unit (callback order and count, not "still runs").

**Then the change:**

- `core/Bus.lua`: resolve `LibStub("LibKa0s-Bus-1.0", true)`, else the untracked-target stub of
  `docs/api/Bus/version-1-docs.md` "Worked example". Keep `NS.bus` (host publisher). Add
  `NS.busRecord = Bus:New{ name = addonName, isDown = function() return NS.IsStoodDown() end }`,
  `NS.NewBusTarget` / `NS.BusStandDown` / `NS.BusStandUp` as one-line delegates (the last logging
  `rejected` through `NS.Debug`), `NS.MSG = Bus.Catalog(addonName, {...})`. Delete
  `NS.BusSubscribe`, `NS.BusUnsubscribeAll`, `NS.BusResubscribeAll`.
- `core/Lifecycle.lua:104` -> `NS.BusStandDown()`, `:112` -> `NS.BusStandUp()` (already bus-last
  down, bus-first up).
- The five sites become `target:RegisterMessage(...)`: `core/AbsorbTracker.lua:362`,
  `modules/Timer.lua:81`, `modules/Display.lua:439`, `:442`, `:445`, with their comments.
- `tests/run.lua`: `Kit.setSurfaceSource` gains `["LibKa0s-Bus-1.0"]`, the library table (the stub
  mirrors the library table, not an instance).

**Tests added with the change:** the stub's parity with the live library by name
(`T.assertSurfaceParity(stub, "LibKa0s-Bus-1.0")`); the degraded load (LibKa0s absent): each
receiver still gets a private working target, `BusStandDown` answers 0, `BusStandUp` answers 0 and
the catalog is the host's plain table; `Catalog`'s strict read raises on an undeclared key; a
registration made while stood down is not live until stand-up; a subscription its owner dropped is
not resurrected by a stand-up (the defect the spec names in the old register).

**Docs:** `docs/ARCHITECTURE.md` Message Bus and "What stands down" name the major; Known
Limitations gains the degraded-bus line; the module map rows that name the deleted functions.

## C2. `LibKa0s-Schema-1.0` (one commit)

**Characterization first**, green on the unmodified tree:

1. The write seam's observable order on one write: stored value, then the `[Set]` line, then the
   row's `onChange`; and for a row without `onChange` exactly one `APPEARANCE`.
2. The bracket: a page Defaults press over rows already at default logs `0 rows`; over changed
   rows it logs the changed count once; nested brackets log once; a raising walk logs
   `(stopped by an error)` and re-raises the same value.
3. The profile reset count: only changed profile rows count, never the minimap row nor a
   `sessionOnly` row; the pending count is taken once and cleared on both exits.
4. The minimap row's inversion and the console row's session storage, both read and written
   through the one seam.
5. Degraded (LibKa0s absent): the host verbs, Reset All and the combat re-lock still write.

**Then the change**, bullet for bullet from spec `schema.md` section 11 "AbsorbTracker - full
adopter": the instance and the write-completing stub in `settings/Schema.lua`, the public names
bound to members, `core/Data.lua`'s session and minimap branches moved onto the two rows' own
`get`/`set`, `NS.GetSetting` a wrapper with the pre-db `flatDefaults` fallback, `NS.SetSetting`
deleted, `settings/OptionsSetup.lua` and `settings/Slash.lua` descriptors on the members,
`resetExempt` for the minimap row. `tests/perf.lua` re-run (dormant repaint ceiling 72
bytes/iter, `settingsRead` 0.0).

**Behavior deltas pinned in the same commit** (the API document's adoption notes): an unknown path
is refused and stores nothing; a table value is stored as a copy; the degraded build's reset lines
re-pin to "the write landed, the line is absent".

**Stop rule:** if a pin that encodes player-visible behavior (a stored value, a panel refresh, a
chat line outside the debug console) cannot be kept green, the candidate is rolled back and
declined as *not now*.

## As executed

- **C1** landed as `92c48d8`. Characterization went in first and was green on the unmodified tree
  (676 passed): the catalog's five names by `pairs`, and "disabled 9: the bus subscriptions come
  back as the same five pairs, and each still reaches its consumer once". The three record cases
  were placed in `tests/test_disabled.lua` rather than `tests/test_bus.lua`: they drive the latch
  for real, and that suite runs last precisely so its stand-downs do not empty another suite's
  registration set. After the change: 683 passed, 0 failed.
- **C2** landed as `0e72839`. Characterization first, green on the unmodified seam (686 passed):
  the write's order (store, `[Set]` line, `onChange`), and the lock verbs and the combat re-lock
  writing the store on a LibKa0s-less load. Plan item 2 (the bracket) and 3 (the reset count) were
  already pinned by `tests/test_helpers.lua` (the nine bulk and reset cases from "a nested bulk act
  logs exactly one line" to "Reset All logs exactly one line in total") and stayed green unchanged
  apart from their probe row's shape; item 4 was already pinned by `tests/test_launcher.lua` and
  `tests/test_schema.lua`. After the change: 691 passed, 0 failed. `tests/perf.lua`:
  `probeOverheadOff` 48.0 bytes/iter (ceiling 72), `settingsRead` 0.0, `appearancePass` 385.8
  (384.2 at baseline; that scenario carries no ceiling, and the 1.6 bytes/iter were not traced
  further).
