# Combat FPS drop — investigation

**Date:** 2026-07-29 · **Version:** 1.9.0 · **Interface:** 120007 (Retail Midnight)
**Issue:** [#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17)
**Status:** **Complete — negative result.** The addon costs 0.05–0.21 ms/s (≈0.01–0.02 % of a
frame). The reported loss is elsewhere in the addon set — see
[#18](https://github.com/tusharsaxena/AbsorbTracker/issues/18).

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

Four captures, 2026-07-29, Helyâ-Frostmourne (level 90 Blood Death Knight), v1.9.0. Full console
transcripts: [raw-captures.md](raw-captures.md).

Each capture is one A/B: **Experiment A** with the addon active, **Experiment B** with it suspended
— inert without a reload, so load order and shared-frame ownership are held fixed. Both windows are
combat-gated: they open when the player enters combat and close when they leave it, so the walk to
the pull and the dungeon reset between arms are not measured.

| # | Environment | Addon set | A (active) | B (suspended) | Delta |
|---|-------------|-----------|-----------:|--------------:|------:|
| 1 | Dummies, solo | AbsorbTracker only | 220.7 fps · 4.53 ms | 223.5 fps · 4.47 ms | +0.06 |
| 2 | Dummies, solo | All addons | 117.0 fps · 8.54 ms | 111.9 fps · 8.93 ms | −0.39 |
| 3 | Nexus-Point, party of 5 | AbsorbTracker only | 135.6 fps · 7.38 ms | 137.5 fps · 7.27 ms | +0.10 |
| 4 | Nexus-Point, party of 5 | All addons | 66.8 fps · 14.97 ms | 68.0 fps · 14.71 ms | +0.26 |

### The addon's own cost

Top-level buckets only — `absorbEvent` + `repaintPass` + `visibility`. `paintBar` nests inside
`repaintPass` and is excluded to avoid double-counting.

| # | Environment / addons | Total Lua | ms/frame | Share of a frame |
|---|----------------------|----------:|---------:|-----------------:|
| 1 | Dummies, AT only | 0.070 ms/s | 0.00032 | **0.007 %** |
| 2 | Dummies, all | 0.069 ms/s | 0.00059 | **0.007 %** |
| 3 | Nexus-Point, AT only | 0.197 ms/s | 0.00145 | **0.020 %** |
| 4 | Nexus-Point, all | 0.208 ms/s | 0.00311 | **0.021 %** |

Three properties of this table matter more than the numbers themselves.

**The cost is unchanged by the other addons** — 0.070 against 0.069 at the dummies, 0.197 against
0.208 in the dungeon. It has to be: the addon's own work does not depend on what else is loaded. The
fact that it *is* means the probe is measuring the addon rather than picking up ambient client load.

**Per-call cost is invariant across a 3× range of frame rates.**

| Bucket | #1 (220 fps) | #2 (117 fps) | #3 (136 fps) | #4 (67 fps) |
|--------|-------------:|-------------:|-------------:|------------:|
| `absorbEvent` | 0.036 ms | 0.037 ms | 0.033 ms | 0.029 ms |
| `repaintPass` | 0.057 ms | 0.053 ms | 0.058 ms | 0.055 ms |
| `paintBar` | 0.015 ms | 0.015 ms | 0.016 ms | 0.015 ms |

A repaint pass costs 0.055 ms whether the client is comfortable or drowning. The addon is not being
made expensive by contention, and the worst single pass ever recorded was 0.132 ms — under 1 % of a
15 ms frame.

**The throttle is barely engaging.** 121 passes over 67.2 s is **1.8/s** against a 10/s ceiling.
Absorb events simply do not arrive fast enough to need coalescing. There is no repaint storm.

### Where the frame time actually goes

| Environment | AbsorbTracker only | All addons | Cost of everything else |
|-------------|-------------------:|-----------:|------------------------:|
| Dummies | 4.53 ms/frame (220.7 fps) | 8.54 ms/frame (117.0 fps) | **+4.01 ms/frame** |
| Nexus-Point | 7.38 ms/frame (135.6 fps) | 14.97 ms/frame (66.8 fps) | **+7.59 ms/frame** |

The rest of the addon set roughly **halves the frame rate** in both environments. Against it,
AbsorbTracker contributes **0.04 %**.

### The FPS delta cannot resolve an addon this cheap

The four deltas — **+0.06, −0.39, +0.10, +0.26** ms/frame — scatter around zero across a 0.65 ms
spread, and one of them is negative. That spread *is* the noise floor of a 60–80 s A/B: roughly
**±0.3 ms/frame**.

The addon's measured cost is 0.0003–0.003 ms/frame — two orders of magnitude **below** what the
method can resolve. For an addon in this class the A/B delta is simply the wrong instrument; only
the bucket brackets can see anything at all. That is a finding about the harness, not just about
this addon, and it is recorded against
[#19](https://github.com/tusharsaxena/AbsorbTracker/issues/19).

It also explains the original report. Capture 2 is the closest reproduction of it — all addons, same
dummies, suspend against active — and it returned **−0.39 ms/frame**: the addon measured *faster*
active than suspended. The original 20 FPS gap was not AbsorbTracker.

### Two earlier captures, discarded

Kept because they are why the harness has the shape it does.

The first attempt sampled continuously and split the arms by suspend state. Its active arm was ~78 %
combat against a suspended arm at ~100 %, and it returned a negative delta describing the
environment rather than the addon. **Fix: combat-gated measurement windows**, so an arm contains
only combat by construction.

The second attempt returned both arms at 8.37 ms/frame — 1/120 s to three decimals — because the
client was capped at 120 fps and the addon's cost vanished into the headroom. **Fix: uncap before
capturing**, and read a suspiciously round or identical pair of arms as a pinned client. A CVar
check was tried for this and removed: `maxFPS` retains its slider value whether or not the limiter
is enabled, so it is not evidence either way.

## Conclusion — negative result

**AbsorbTracker is not the cause of the reported frame-rate loss.**

Its execution cost, measured four ways in-game and once offline, is **0.05–0.21 ms per second** —
between 0.007 % and 0.021 % of a frame. The reported regression was ~2.7 ms/frame. The addon is
roughly **three orders of magnitude too cheap** to produce it.

Every hypothesis from the offline phase is now settled:

1. **Client-side cost of the UI calls — rejected.** Uncapped, with everything else disabled, the
   delta was +0.06 ms/frame at 220 fps. If secret-value handling on `SetValue`/`SetText` were
   expensive it would show here, and per-pass cost would rise under load. It does neither.
2. **Frequency higher than the throttle implies — rejected.** 0.5–1.8 repaint passes per second
   against a 10/s ceiling.
3. **The delta is not ours — confirmed.** The other addons cost 4.01 ms/frame at the dummies and
   7.59 ms/frame in a dungeon pull. AbsorbTracker costs 0.003.

The July 14 attribution finding is reinforced rather than overturned: the addon ranks high in the
built-in profiler because it owns the shared Ace dispatch frame, and it is cheap.

### What these numbers do not support

- **n = 1 per configuration.** Four captures, no repeats.
- **Arms differ in length by 6–12 s** in every capture. Combat gating fixed *only combat*, not *the
  same amount of combat*.
- **The Nexus-Point arms were separate pulls** either side of a dungeon reset, so mob pathing and
  pull composition varied between them.
- **The cross-configuration figures (4.01 and 7.59 ms/frame) compare separate sessions**, not two
  arms of one capture. They are believable only because the effect is 15–25× the noise floor.

None of these weaken the conclusion, because the conclusion rests on the bucket measurements — which
are direct, reproducible across all four captures, and unaffected by arm mismatch.

## Recommendation

Close the diagnostic question as a **negative result**. No performance work on this addon is
justified: at 0.055 ms per repaint pass and under two passes per second, there is nothing here to
optimize that would be measurable.

The real cost is located but not attributed. [#18](https://github.com/tusharsaxena/AbsorbTracker/issues/18)
tracks bisecting the addon set for it, and these captures sharpen that work:

- **Bisect in the dungeon, not at the dummies.** 7.59 ms/frame of signal against 4.01, and the
  loaded arm sits at 66.8 fps where differences are easy to read.
- **Use `active.avgFps` as the yardstick.** Suspend is unnecessary — the comparison is between addon
  *sets*, not against our own code.
- **Uncap the frame rate first.** At 220 fps solo, a capped client would hide everything.

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
