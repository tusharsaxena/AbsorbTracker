# Performance instrumentation — design

Issue: [#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17)
Branch: `feature/perf-instrumentation`
Date: 2026-07-29

## Problem

The addon feels sluggish in combat. A controlled observation at the Silvermoon training dummies
(Falconwing Square, Blood DK):

| Condition | FPS |
|-----------|-----|
| Out of combat | 115–120 |
| In combat, AbsorbTracker disabled | 95–100 |
| In combat, AbsorbTracker enabled | 75–80 |

The in-combat delta is ~20 FPS — roughly **2.7 ms of extra CPU per frame** at that frame rate.

That number is hard to reconcile with the addon itself. It is ~1,900 lines outside `libs/`, its
repaint is coalesced to one pass per `throttleWindow`, and the July 14 investigation
([docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md](../../investigations/2026-07-14-addon-profiler-attribution/analysis.md))
measured its actual cost at ~1.8 ms **per second**. Both cannot be true. The candidate explanations
are:

1. The cost is not in our Lua at all — secret-value handling in 12.0, backdrop churn, or render-side
   cost from a StatusBar fed a secret every pass.
2. Something re-enters far more often than the throttle implies.
3. The delta is not ours. Disabling AbsorbTracker changes which addon owns the shared
   LibStub/CallbackHandler dispatch frame, which can shift other addons' measured behavior too.

Nothing currently in the repo can distinguish these. WoW's built-in Addon Profiler cannot either —
that is precisely what the July 14 investigation established.

## Goal

Build measurement we control, use it to attribute the 20 FPS, and write up the finding — including
a negative result if the cost turns out not to be ours.

**Explicitly not in scope:** fixing anything. Fixes are a follow-up issue informed by these numbers.
Also out of scope: landing the reusable pieces in
[WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards) or the `wow-addon` plugin.
That is a deferred follow-up, taken up once the instrumentation has proven itself here.

## Architecture

One versioned record shape, two emitters, one destination.

```
record = {
  schema    = 1,
  source    = "offline" | "ingame",
  version   = "1.9.0",
  interface = 120007,          -- ingame only
  timestamp = <epoch seconds>,
  label     = "<free text>",
  buckets   = { <name> = { calls = n, totalMs = f, maxMs = f }, ... },
  fps       = {                -- ingame only
    active    = { seconds = f, frames = n, avgFps = f, msPerFrame = f },
    suspended = { seconds = f, frames = n, avgFps = f, msPerFrame = f },
    deltaMsPerFrame = f,
  },
}
```

Both emitters produce this shape, so one analysis path reads either and offline predictions can be
checked against in-game reality. Encoding is JSON, emitted by a single shared encoder in
`core/Perf.lua` (`NS.Perf.EncodeJSON`) that the offline runner loads through the existing test
loader — one implementation, not two. Object keys are emitted in sorted order so two records diff
cleanly.

### `core/Perf.lua` — the in-game probe

Loads after `core/Util.lua`, before `core/Data.lua`, so every consumer can take `NS.Perf` as a
load-time upvalue.

**Self-timing buckets.** `debugprofilestop()` brackets around our own entry points. Call sites use:

```lua
local t0 = Perf.on and debugprofilestop()
-- ... work ...
if t0 then Perf.Note("paintBar", debugprofilestop() - t0) end
```

When capture is off this is an upvalue read, a field read, and a boolean test — no call, no
allocation. This matches the existing §12.4 convention for gated debug reads.

Buckets, in report order:

| Bucket | Wraps |
|--------|-------|
| `absorbEvent` | `addon:OnAbsorbChanged` |
| `repaintPass` | `doRepaint` (the coalesced pass) |
| `paintBar` | `NS.UpdateAbsorbBar` (per bar) |
| `appearance` | `NS.UpdateBarAppearance` (per bar) |
| `visibility` | `NS.ApplyVisibility` (per bar) |

Buckets **nest** — `repaintPass` contains `paintBar`, `absorbEvent` contains neither (it only
publishes). The report states this so totals are never summed naively.

**FPS sampler.** A lazily-created `OnUpdate` frame that exists only while capture is running. It
accumulates elapsed seconds and frame counts into two arms keyed by suspend state, so a single
session yields both halves of the A/B on the same fight:

```
active:     62.3s   4821 frames   77.4 fps   12.92 ms/frame
suspended:  60.1s   5903 frames   98.2 fps   10.18 ms/frame
delta:                                       +2.74 ms/frame
```

Bucket ms/s divides by `active.seconds` only, since no bucket accrues while suspended.

### Suspend — the A/B mechanism

`NS.Perf.Suspend()` makes the addon inert without a reload: unregister every unit-event frame,
unregister the lifecycle AceEvent registrations, cancel any pending repaint timer, and hide the
bars. `Resume()` re-runs `SyncUnitEventFrames`, re-registers the lifecycle events, and republishes
`VISIBILITY` / `APPEARANCE` / `REPAINT`.

Visibility is enforced at the source rather than by hiding frames imperatively: `NS.ShouldShowBar`
gains a suspended check as step 0 of its ladder, so suspend simply publishes `VISIBILITY` and
nothing can re-show a bar behind its back. `NS.RequestRepaint` no-ops while suspended.

Suspend is session-only and resets on `/reload`. Entering and leaving it prints a loud chat line so
it cannot be left on by accident.

Why no-reload matters: reloading or disabling changes shared-frame ownership, which is the confound
that broke the July 14 investigation. Suspend holds load order fixed and changes only whether our
code runs.

**The documented protocol still leads with the cleaner arm** — AbsorbTracker plus stock Blizzard UI,
every other addon disabled. In that configuration there is no other Ace addon to inherit the
dispatch frame and attribution is not arguable. Suspend is the second, finer arm, and the one that
works without a client restart.

### Slash surface

`/at debug perf` — a sub-verb of the existing debug suite, not a new top-level verb. `/at debug`
already takes `on|off`, so sub-verbs are established.

| Command | Effect |
|---------|--------|
| `/at debug perf` | Status line + usage |
| `/at debug perf on` | Reset counters, start capture and sampler |
| `/at debug perf off` | Stop capture, append the record to the ring, print the summary |
| `/at debug perf report` | Print the summary without stopping |
| `/at debug perf dump` | Render the record as JSON into the copy window |
| `/at debug perf suspend` | Make the addon inert |
| `/at debug perf resume` | Restore it |

Capture works whether or not debug *logging* is enabled. Output goes to the debug console via
`D:Add` (which is ungated) plus a one-line chat acknowledgement, so running it never appears to do
nothing.

### Persistence

Captures append to `AbsorbTrackerPerfDB`, a **second top-level SavedVariables global** declared in
the TOC, holding a ring of the last 10 runs.

It is deliberately outside the AceDB tree: it never rides profile copy, reset, or switch, and it
appears as one self-contained block that can be read or deleted without disturbing settings.

A separate SavedVariables *file* was considered and rejected. WoW names the SV file after the
addon and serializes every global that addon declares into it, so a separate file would require
shipping a companion addon in its own sibling folder — restructuring this into a two-addon repo,
with knock-on effects for packaging and the CurseForge project. Not worth it for isolation that a
distinct top-level global already provides.

The file lands at
`_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` after `/reload` or logout, and is
readable directly from the dev environment — so the normal path involves no copy-paste. The copy
window `dump` remains for when the game is somewhere unreadable.

### `tests/perf.lua` — the offline runner

Standalone and **outside the green gate**, invoked as `lua tests/perf.lua [--out <path>]
[--label <text>]`. It reuses `tests/loader.lua` and `tests/wow_mock.lua`, wrapping the mock in a
counting layer inside `perf.lua` itself so the unit harness stays untouched.

Scenarios:

| Scenario | Measures |
|----------|----------|
| `coalescing` | Repaints produced by a 1,000-event absorb burst |
| `paintPass` | API calls and bytes allocated per coalesced repaint |
| `appearancePass` | Cost of `UpdateBarAppearance` (`SetBackdrop` + four LSM fetches) |
| `settingsRead` | `GetSetting` / `Units.Get` hot-path cost |
| `probeOverhead` | Bracket cost with capture off — proves the hooks are free |

It hard-asserts only deterministic quantities — repaint counts, API call counts, and bytes
allocated per pass via `collectgarbage("count")`. Wall-clock timings are reported and never
asserted, because they are not stable enough to fail a build on. Exit code is non-zero if a
deterministic invariant breaks, so it is CI-usable later even though nothing gates on it now.

`probeOverhead` is what discharges the risk that the instrumentation itself is a regression.

### Complexity

`lizard`, excluding `libs/`, generating a committed `docs/complexity.md`. Report-only, with the
refresh command documented as an optional dev tool. Not part of the green gate.

### Storage

Captured records live in `docs/perf-runs/`, a standing directory with a `README.md` describing the
record schema and naming convention (`<date>-<source>-<label>.json`). This is independent of any
one investigation so numbers can be compared across versions.

## Testing

`tests/test_perf.lua` joins the gated suite and covers the pure logic: bucket accounting, ring
buffer capping at 10, JSON encoding (including key ordering and string escaping), record assembly,
suspend/resume state transitions, the `ShouldShowBar` suspended gate, and the `RequestRepaint`
no-op while suspended.

The green gate is unchanged in shape: `lua tests/run.lua` and `luacheck .` (0/0).
`docs/test-cases.md` is regenerated and the README `tests` badge updated in the same change.

## Deliverables

**New:** `core/Perf.lua`, `tests/perf.lua`, `tests/test_perf.lua`, `docs/performance.md`,
`docs/complexity.md`, `docs/perf-runs/README.md`,
`docs/investigations/2026-07-29-combat-fps-drop/analysis.md`.

**Modified:** `AbsorbTracker.toc` (new file, second SavedVariables global), `settings/Slash.lua`
(the `perf` sub-verb + help text), `core/AbsorbTracker.lua` (brackets, extracted
`RegisterLifecycleEvents`), `modules/Display.lua` (brackets, suspended gate), `modules/Timer.lua`
(brackets, `CancelPendingRepaint`, suspend no-op), `tests/wow_mock.lua` (`debugprofilestop`),
`tests/run.lua` (new suite), `docs/smoke-tests.md` (perf section + SV filename fix),
`docs/ARCHITECTURE.md`, `docs/file-index.md`, `docs/module-map.md`, `docs/testing.md`,
`docs/test-cases.md`, `README.md`.

## Standards deviations

Recorded here for the audit bundle; none is being decided silently.

1. **`lizard` as an optional Python dev dependency** in a Lua repo. Documented as optional and kept
   outside the green gate, pending an upstream rule in WowAddonStandards. Issue #17 explicitly
   assigns the standard's definition of complexity measurement to the upstream repo.
2. **Instrumentation hooks in hot paths.** Justified only if they are provably free when capture is
   off; `tests/perf.lua`'s `probeOverhead` scenario is the evidence.
3. **A second top-level SavedVariables global.** No restructure needed, but it is a departure from
   the one-global convention and belongs in the audit record.

## Drive-by fix

`docs/smoke-tests.md` step 1 instructs deleting
`WTF/.../SavedVariables/AbsorbTrackerDB.lua`. The TOC declares the *global* `AbsorbTrackerDB`, but
WoW names the *file* after the addon, so the real path is `AbsorbTracker.lua` — confirmed present
on disk for both accounts. Corrected.

## Open question deferred

Regression thresholds and gates (issue #17's last acceptance criterion) stay unset. They cannot be
chosen before baseline numbers exist, and choosing them is a separate decision once the offline
runner has produced a few.
