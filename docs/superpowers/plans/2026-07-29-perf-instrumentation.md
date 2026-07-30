# Performance instrumentation — implementation plan

Spec: [2026-07-29-perf-instrumentation-design.md](../specs/2026-07-29-perf-instrumentation-design.md)
Issue: [#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17)
Branch: `feature/perf-instrumentation`

Green gate after every stage: `lua tests/run.lua` and `luacheck .` (0/0).

---

## Stage 1 — `core/Perf.lua`, standalone

Build the module with no call sites yet, so it can be tested in isolation.

1. `NS.Perf` with `SCHEMA = 1`, `RING_MAX = 10`, `on = false`, `suspended = false`.
2. `Perf.Note(key, ms)` — accumulate `calls` / `totalMs` / `maxMs` into a module-local bucket table.
   Unknown keys are accepted (the bucket order list drives *report* order, not validity).
3. `Perf.Reset()` — wipe buckets and both FPS arms.
4. `Perf.EncodeJSON(value)` — numbers (`%d` for integrals, `%.4f` otherwise), escaped strings,
   booleans, arrays (`#t > 0`), objects with **sorted keys** for diffability.
5. `Perf.BuildRecord(label)` — assemble the spec's record shape.
6. `Perf.Save(record)` — append to `AbsorbTrackerPerfDB.runs`, trimming from the front past
   `RING_MAX`.
7. `Perf.FormatReport(record)` — the human-readable line list, returned as a table of strings so it
   is testable without frames.

**Wiring:** TOC entry after `core/Util.lua`, before `core/Data.lua`.

## Stage 2 — mock + gated tests

1. `tests/wow_mock.lua`: add `debugprofilestop` (driven off a settable `__profileMs` so timings are
   deterministic in tests).
2. `tests/test_perf.lua`: bucket accounting, ring capping, JSON encoding (key order, escaping,
   integral vs float), record assembly, report formatting.
3. Register the suite in `tests/run.lua`.

## Stage 3 — suspend/resume

1. `modules/Display.lua`: `NS.ShouldShowBar` gains the suspended check as step 0.
2. `modules/Timer.lua`: `NS.CancelPendingRepaint()`; `NS.RequestRepaint` no-ops while suspended.
3. `core/AbsorbTracker.lua`: extract `addon:RegisterLifecycleEvents()` from `OnEnable` so suspend
   and resume share one definition of the lifecycle registration set.
4. `core/Perf.lua`: `Suspend()` / `Resume()`.
5. Tests: suspended hides bars via the visibility ladder, `RequestRepaint` no-ops, resume restores
   registrations.

## Stage 4 — the probe brackets

Add the five brackets (`absorbEvent`, `repaintPass`, `paintBar`, `appearance`, `visibility`) using
the `local t0 = Perf.on and debugprofilestop()` idiom. Each call-site file takes `NS.Perf` as a
load-time upvalue.

Test that brackets record when `on` and record nothing when off.

## Stage 5 — FPS sampler

Lazily-created `OnUpdate` frame, started by `Perf.Start()` and stopped by `Perf.Stop()`,
accumulating into `active` / `suspended` arms by current suspend state. Derived `avgFps`,
`msPerFrame`, and `deltaMsPerFrame` computed at record-build time, guarding division by zero for an
arm that never ran.

## Stage 6 — slash surface

1. `settings/Slash.lua`: `perf` sub-verb in `runDebug`, dispatching
   `on|off|report|dump|suspend|resume` plus a bare status/usage line.
2. Update the `debug` entry's description in `NS.COMMANDS` to mention `perf`.
3. Tests in `tests/test_slashcmds.lua` for each sub-verb, including the unknown-sub case.

## Stage 7 — offline runner

`tests/perf.lua`, standalone. Loads the addon through `tests/loader.lua`, wraps the mock in a
counting layer, runs the five scenarios, asserts the deterministic invariants, prints a human table,
and writes JSON when `--out` is given.

## Stage 8 — complexity

Install `lizard`, run it over the repo excluding `libs/`, commit `docs/complexity.md` with the
refresh command recorded in it.

## Stage 9 — docs

1. `docs/performance.md` — both harnesses, the controlled-environment recipe, how to read output.
2. `docs/perf-runs/README.md` — schema and naming convention.
3. `docs/investigations/2026-07-29-combat-fps-drop/analysis.md` — method and the offline findings,
   with the in-game section left explicitly pending the user's capture.
4. `docs/smoke-tests.md` — perf section, plus the `AbsorbTracker.lua` SV filename fix.
5. `docs/ARCHITECTURE.md`, `docs/file-index.md`, `docs/module-map.md`, `docs/testing.md`.
6. Regenerate `docs/test-cases.md`; update the README `tests` badge.

## Stage 10 — verify

Full gate, offline runner run for real, and a written summary of what the offline numbers already
say about the 20 FPS gap.

## Not doing

No performance fixes. No version bump. No commit, stage, or push — per `CLAUDE.md`, those need an
explicit instruction. No upstream WowAddonStandards or `wow-addon` plugin changes.
