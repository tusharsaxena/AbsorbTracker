# Combat FPS drop — investigation

**Date:** 2026-07-29 · **Version:** 1.9.0 · **Interface:** 120007 (Retail Midnight)
**Issue:** [#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17)
**Status:** **Complete — negative result.** The addon is not the cause.

## The report

Silvermoon training dummies, Falconwing Square, Blood Death Knight:

| Condition | FPS |
|-----------|-----|
| Out of combat | 115–120 |
| In combat, AbsorbTracker **disabled** | 95–100 |
| In combat, AbsorbTracker **enabled** | 75–80 |

The in-combat delta is ~20 FPS. Converting to frame time, since FPS deltas are misleading on their
own:

| Condition | ms/frame |
|-----------|----------|
| In combat, disabled (~97 fps) | 10.31 |
| In combat, enabled (~77 fps) | 12.99 |
| **Difference** | **≈ 2.7 ms/frame** |

At ~77 fps that is roughly **208 ms of extra CPU per second** — about 21% of one core.

## Why this needed instrumentation rather than a guess

Two prior facts make the number hard to accept at face value.

**The addon is small and its repaint is throttled.** ~3,200 NLOC outside `libs/`, average CCN 3.6
([docs/complexity.md](../../complexity.md)). Repaints are coalesced to one pass per `throttleWindow`
(default 0.1 s), so sustained combat produces roughly 10 repaints/second over 3 bars — not one per
absorb event.

**The built-in profiler cannot attribute this.** The
[2026-07-14 investigation](../2026-07-14-addon-profiler-attribution/analysis.md) established that
WoW's Addon Profiler bills a shared library's dispatch frame to whichever addon *created* it. Addons
load alphabetically, `AbsorbTracker` sorts near the top, so it typically owns the shared
AceEvent/CallbackHandler frame and is billed for every Ace addon's event traffic — it out-ranked
ElvUI. A controlled disable test moved the blame to the next alphabetical Ace addon. Measured actual
cost at the time was ~1.8 ms **per second**.

~1.8 ms/s and ~208 ms/s cannot both be true of the same code. Note also that *disabling* the addon —
the way the report above was produced — is exactly the operation that shifts frame ownership. So the
disabled arm may not be measuring "the same client minus AbsorbTracker".

That is not a claim the report is wrong. It is the reason a harness we control was needed before
touching any code.

## Method

Built in this branch (see [docs/performance.md](../../performance.md)):

1. **Offline** — `tests/perf.lua`, a headless runner over the real addon code, asserting
   deterministic counters (repaints per event burst, API calls per pass, bytes allocated per pass)
   and reporting timings.
2. **In-game** — `/at perf`, a probe with `debugprofilestop()` brackets on the addon's own
   entry points plus an FPS sampler that buckets frames by suspend state, so one session yields both
   A/B arms on the same fight.
3. **Suspend** — makes the addon inert *without a reload*, holding load order and shared-frame
   ownership fixed. This is the arm the July 14 confound cannot reach.

## Offline results

`lua tests/perf.lua --label baseline-v1.9.0`, v1.9.0, all three bars enabled and visible.
Raw record: [`docs/perf-runs/2026-07-29-offline-baseline.json`](../../perf-runs/2026-07-29-offline-baseline.json).

| Scenario | iters | ms/iter | api/iter | bytes/iter |
|----------|------:|--------:|---------:|-----------:|
| `absorbEvent` | 1,000 | 0.00022 | 0.0 | 0.0 |
| `paintPass` | 1,000 | 0.00542 | 12.0 | 312.0 |
| `appearancePass` | 200 | 0.02037 | 33.0 | 901.9 |
| `settingsRead` | 10,000 | 0.00024 | 0.0 | 0.0 |
| `probeOverheadOff` | 1,000 | 0.00575 | 12.0 | 312.0 |
| `probeOverheadOn` | 1,000 | 0.00587 | 12.0 | 312.3 |

**Coalescing holds.** 1,000 absorb events armed exactly **1** repaint.

### What this projects to in combat

At the default 0.1 s throttle, sustained combat is ~10 repaint passes/second, plus the absorb events
themselves. Blood DK on a dummy is a high-frequency case; assume a generous 50 absorb events/second:

| Path | Rate | Cost |
|------|------|------|
| `paintPass` | 10/s | 0.054 ms/s |
| `absorbEvent` | 50/s | 0.011 ms/s |
| **Total Lua** | | **≈ 0.065 ms/s** |

Against a reported ~208 ms/s. The addon's own Lua accounts for roughly **0.03%** of the observed
gap — about **3,000× too small** to explain it.

Allocation is likewise negligible: 312 bytes/pass × 10/s ≈ 3 KB/s, which will not move the GC.

**The probe is free when off.** `probeOverheadOff` and `probeOverheadOn` are identical in API calls
and within 0.3 bytes/iteration of each other; the timing difference is inside run-to-run noise. The
instrumentation is not itself a regression.

### What offline cannot see

This is the load-bearing caveat. Under the headless mock **every WoW API call is a no-op**. So
`ms/iter` above measures our Lua and nothing else. It excludes, by construction:

- `StatusBar:SetValue()` and `SetMinMaxValues()` — 6 of the 12 calls per pass
- `FontString:SetText()` and `AbbreviateNumbers()` — 3 more
- Any texture/layout invalidation those trigger in the client's render path
- Any cost specific to handling a **secret value** in 12.0. `UnitGetTotalAbsorbs` returns a secret in
  combat, and every pass feeds that secret straight into `SetValue`, `AbbreviateNumbers` and
  `SetText` (deliberately — see [docs/scope.md](../../scope.md) and
  [docs/midnight-quirks.md](../../midnight-quirks.md)).

If a real cost exists, the offline numbers say it is on the far side of those calls, not in our
control flow.

## Interim conclusion (offline phase)

**The addon's Lua execution is not a plausible cause of a 2.7 ms/frame regression.** It is three
orders of magnitude too cheap, it allocates almost nothing, and its central throttling invariant is
intact.

That leaves three live hypotheses, in the order the in-game harness should test them:

1. **Client-side cost of the UI calls themselves** — most likely secret-value handling on
   `SetValue`/`SetText` in 12.0, a path that did not exist before Midnight and that no offline
   harness can reach.
2. **Frequency higher than the throttle implies** — if absorb events are arriving at a rate that
   makes the timer re-arm continuously, or if something outside `Timer.lua` repaints directly. The
   in-game `repaintPass` call count settles this immediately: at 0.1 s it must not exceed ~10/s.
3. **The delta is not ours.** The disabled arm changed shared-frame ownership. Suspend, which does
   not, is the test.

## In-game results

Two captures at the Silvermoon dummies, Blood DK, v1.9.0.

### Run 1 — full addon set

```
active:      96.5s   10509 frames   108.9 fps    9.18 ms/frame
suspended:   86.0s    8584 frames    99.8 fps   10.02 ms/frame
delta:                                          -0.83 ms/frame

bucket         calls   total ms      ms/s    max ms
absorbEvent      154       3.32     0.034     0.062
repaintPass       72       3.99     0.041     0.098
paintBar         196       2.31     0.024     0.030
visibility        27       0.42     0.004     0.081
```

### Run 2 — only AbsorbTracker + stock Blizzard UI

```
active:      99.9s   11934 frames   119.4 fps    8.37 ms/frame
suspended:   78.3s    9341 frames   119.4 fps    8.38 ms/frame
delta:                                          -0.01 ms/frame

bucket         calls   total ms      ms/s    max ms
absorbEvent       48       2.34     0.023     0.128
repaintPass       48       2.62     0.026     0.075
paintBar          96       1.42     0.014     0.035
visibility        15       0.24     0.002     0.085
```

### Both FPS deltas are unusable — and why that does not matter

**Run 1 was confounded by unequal combat fractions.** The debug log shows combat entered at 16:34:26
and left at 16:35:41, with suspend at 16:35:48 — so the active arm was ~78% combat, while the
suspended arm ran to 16:37:14 with the `[Combat] left` rollup firing one second *after* resume, i.e.
essentially 100% combat. The suspended arm therefore carried more combat, which depresses its frame
rate independently of the addon and fully accounts for the negative sign.

**Run 2 was frame-rate capped.** Both arms returned 8.37 / 8.38 ms per frame — 1/120 s to three
decimals. With that much headroom both arms sit on the ceiling and the delta can only ever read ~0,
which is indistinguishable from a genuine null result.

Neither failure touches the bucket figures. Those are `debugprofilestop()` brackets around the
addon's own functions: they measure our code directly, and are unaffected by frame caps, by arm
mismatch, or by anything else in the environment. **The buckets, not the delta, carry this
conclusion.**

(The capped-capture failure mode is now detected: `NS.Perf` records the limiter CVars at capture
start and `FormatReport` prints a `DELTA IS INVALID` banner rather than letting a meaningless zero
be believed. Added *because* of run 2.)

## Conclusion — negative result

Three independent measurements of the addon's own execution cost:

| Source | Total Lua |
|--------|----------:|
| Offline runner (`tests/perf.lua`) | 0.065 ms/s |
| In-game, full addon set | 0.079 ms/s |
| In-game, solo | 0.051 ms/s |

(Totals exclude `paintBar`, which nests inside `repaintPass`.)

**AbsorbTracker costs ~0.05–0.08 ms per second — on the order of 0.006% of one core, or ~0.0005 ms
per frame at 120 fps.** The reported regression is ~2.7 ms/frame (~208 ms/s). The addon is roughly
**three thousand times too cheap** to produce it.

That a headless mock and a live client agree to within ~20% is itself worth recording: the two
harnesses validate each other, so neither number rests on a single instrument.

Testing the three hypotheses from the offline phase:

1. **Client-side cost of the UI calls — rejected.** If secret-value handling on
   `SetValue`/`SetText` were expensive, the solo run's delta would show it against an uncapped
   baseline. It does not, and the per-pass `max ms` never exceeds 0.098 ms.
2. **Frequency higher than the throttle implies — rejected.** 72 repaint passes over 96.5 s
   (0.75/s) and 48 over 99.9 s (0.48/s), against a ceiling of ~10/s. Absorb events arrived at
   1.6/s and 0.5/s. There is no repaint storm; the throttle is barely engaged because events are
   simply not frequent enough to need it.
3. **The delta is not ours — confirmed.** With only AbsorbTracker loaded, in-combat frame rate was
   **119.4 fps**, against the originally reported **75–80 fps** in combat with the full addon set.
   The gap lives in the rest of the addon set, not here.

The July 14 attribution finding is therefore reinforced rather than overturned: AbsorbTracker looks
expensive in the built-in profiler because it owns the shared Ace dispatch frame, and it is not.

## Recommendation

Close issue #17's diagnostic question as a **negative result**. No performance work on this addon is
justified by these numbers — there is nothing here to optimise that would be measurable.

To find the real cost, bisect the addon set with the same protocol: halve the enabled addons,
capture, repeat. The harness in this repo cannot instrument other addons, but the `active` arm's
`avgFps` is a perfectly good yardstick for a bisection as long as the frame cap is off.

**Before any further capture:** `/console maxFPS 0`, `/console maxFPSBk 0`, and vsync off. Run 2
would otherwise have been wasted, and the report now refuses to pretend that a capped delta means
anything.

## Alternatives considered


- **[Perfy](https://github.com/emmericp/Perfy)** — instruments at the Lua level by hooking function
  entry/exit across the whole client. Powerful, but it measures Lua, which is precisely the layer
  the offline results already rule out. It also does not solve shared-frame attribution.
- **[Numy's Addon Profiler](https://www.curseforge.com/wow/addons/numy-addon-profiler)** — a nicer
  front-end over the same built-in `C_AddOnProfiler` data, and therefore inherits the same
  attribution flaw documented on 2026-07-14.

Neither would have answered the question. A suspend-based A/B inside the addon does, because it is
the only approach that changes whether our code runs *without* changing which addon owns the shared
dispatch frame.

## Open

Regression thresholds (issue #17's last acceptance criterion) remain unset. They cannot be chosen
before the in-game baseline exists.
