# Analysis — 20260807-125002

- **Addon:** AbsorbTracker 1.9.0 (record schema 2, client interface 120007)
- **Captured:** 2026-08-07 12:47 local, label `2026-08-07 12:47`
- **Who / where:** Lânfear-Frostmourne, level 90 Destruction Warlock · Murder Row (no subZone) · party (5) / party
- **Delta:** −0.18 ms/frame — **unresolved**, and backwards-signed: the suspended arm read *slower*
- **Previous capture:** none — this is the first capture in this store

## Headline

Two combat-gated arms in Murder Row, in a 5-man party, on 1.9.0. The addon's own bracketed code cost
**0.34 ms per second of combat** (9.06 ms over a 26.6 s fight, [`dump.json`](dump.json)), which is
about **0.006 ms of the 16.56 ms active frame** — roughly a thirtieth of one percent. The frame-time
delta resolved **nothing**: at −0.18 ms/frame it is both inside the ±0.3–0.5 ms/frame floor and
pointing the wrong way, so it measures the gap between the arms rather than the addon. Nothing here
needs acting on for cost; the one thing worth recording is an **instrumentation** result — the
`appearance` bucket never fired, which leaves `visibility`'s declared parent unverified in this run.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 26.6010 | 1606 | 60.3737 | 16.5635 |
| suspended (addon inert) | 21.5460 | 1287 | 59.7327 | 16.7413 |
| **delta** | +5.055 | +319 | +0.641 | **−0.1777** |

The delta is **unresolved and its sign is backwards**. Magnitude first: 0.1777 ms/frame sits below
the ±0.3 ms/frame run-to-run spread the harness has measured and well below the ~0.5 ms/frame line at
which a reading starts to mean something, so the frame-time instrument could not see this addon on
this run. That is a statement about the instrument, not about the addon — "no measurable impact"
would be the wrong sentence to write from it (`performance-§8`). Sign second: a negative
`deltaMsPerFrame` says the *suspended* arm rendered more slowly than the active one, which no amount
of addon cost can produce. It is the tell that the environment moved between the arms, and this run
has three candidates for that, all in [`report.md`](report.md)'s run log — the arms differ in
duration (26.6 s vs 21.5 s, a 23% shorter B), 62 s and two `[World] entering world` transitions
separate them, and the group had four other players in it whose own load the sampler cannot
distinguish from ours. Read the buckets below instead; they measure this addon's code directly and
are indifferent to all three.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
26.6010 s, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `absorbEvent` | 86 | 4.5313 | 0.170 | 0.0752 | none declared — a root |
| `repaintPass` | 72 | 4.2879 | 0.161 | 0.0919 | none declared — a root |
| `paintBar` | 143 | 2.4014 | 0.090 | 0.0454 | declares `within: repaintPass` — **not observed** |
| `visibility` | 21 | 0.2388 | 0.009 | 0.0915 | declares `within: appearance` — **not observed** |
| `appearance` | — | — | — | — | declared in `core/PerfSetup.lua:59`, **never fired** |

**Total accounted cost: 0.3405 ms per second of combat** — 9.0580 ms of Lua across the three
non-nested roots (`absorbEvent` + `repaintPass` + `visibility`) over 26.6010 s. Spread over the arm's
1606 frames that is 0.0056 ms/frame against a 16.5635 ms frame, or 0.034%. Treating `paintBar` as
disjoint instead of contained raises the ceiling to 11.4594 ms — 0.431 ms/s, 0.0071 ms/frame, 0.043%.
Both readings are two orders of magnitude under the delta's own resolution floor, which is exactly
why the delta could not resolve them.

The ratios that survive a change of combat duration, and are what the next capture should be compared
on:

- **0.84 repaint passes per absorb event** (72 / 86) — coalescing is doing real work; roughly one
  event in six is absorbed into a pass already queued.
- **1.99 bar paints per repaint pass** (143 / 72) — two bars painted per pass, consistent with the
  player and target bars both being live for the whole arm. The `[Bar] target: hidden (no unit)` line
  lands at 12:48:32, the same second combat ended, so the target bar was up for essentially the whole
  fight.
- **0.0527 ms per absorb event**, **0.0596 ms per repaint pass**, **0.0168 ms per bar paint**,
  **0.0114 ms per visibility apply**.
- **Worst single call anywhere: 0.0919 ms** (`repaintPass`). No bracket in this run came within a
  tenth of a frame budget.

Two containment claims in the descriptor went **unverified** here, and neither should be read as
measured. `paintBar` declares itself within `repaintPass` but no call site passed the parent, so the
capture reports the declaration, not an observation. The arithmetic is at least *consistent* with the
declaration — 2.4014 ms of `paintBar` fits inside 4.2879 ms of `repaintPass`, and 143 paints over 72
passes is the fan-out `core/PerfSetup.lua:54` describes — but consistent is not observed, and this
table does not get to claim the stronger word.

`visibility` is the more interesting one. It declares itself within `appearance`
(`core/PerfSetup.lua:63`), and **`appearance` is absent from the table entirely — it never fired**.
So every one of the 21 `visibility` calls came in through its own entry point, the `VISIBILITY` bus
message, and none of them came the way the descriptor's comment says is the real nesting. That is a
result about what the run exercised: nothing in this fight changed bar appearance — no settings row
was touched, no `APPEARANCE` message was published — so `NS.UpdateBarAppearance` was never entered.
The declared parent stays an unverified claim, and this capture is not the one that verifies it.

## What the capture did not hold constant

Quite a lot, and it is why the delta is worthless while the buckets are not. From
[`report.md`](report.md)'s context block and run log:

- **Arm duration.** A ran 26.6 s, B ran 21.5 s. Combat gating equalizes the *kind* of window, never
  its length; a 23% shorter B is a differently-averaged aggregate, not a matched one.
- **A 62-second gap with two loading screens in it.** Arm A ended 12:48:32; arm B started recording
  12:49:34. Between them sit two `[World] entering world` lines (12:48:51, 12:49:11) — the player
  crossed a world boundary twice. The run's `where:` was captured once at 12:47:54 and says
  *Murder Row*, so arm B's zone is not recorded and may not be Murder Row at all. Two arms in two
  places measure two places.
- **No `/reload` landed between the arms**, which is the one thing the gap could have meant and did
  not. The run survived across both transitions in memory, and there is no second `[Init]` banner
  after 12:47:59 — a reload would have produced one and lost the armed run. `performance-§7`'s
  no-reload condition holds.
- **Four other players.** `group: party (5) / party` for the whole run. `performance-§7` asks for
  somewhere with no other players, precisely because four other clients' load lands in the same frame
  sampler; this run did not get that.
- **Different pulls.** Nothing in the log ties the two arms to the same target or the same pack. Arm A
  logged its own combat totals (`left: 86 events, 72 repaints`); arm B, suspended, logged nothing at
  all — which is itself the confirmation that suspend worked.

The suspend itself is clean and verifiable in the log: `addon SUSPENDED — inert` at 12:49:30 followed
immediately by `[Bar] player: hidden (perf suspended)`, i.e. the show-decision ladder answered
"suspended" at the source rather than a frame being hidden imperatively, and `addon RESUMED` at
12:50:00 came before the save, both as `performance-§6` requires.

## What moved

**First capture — nothing to diff against; every figure above is a baseline reading.** The store's
index in [`../README.md`](../README.md) had an empty capture table before this bundle. Nothing in
this analysis should be read as "unchanged" — there is no previous value for any of it.

For the next capture to be comparable, the figures to carry forward are the ratios rather than the
totals: 0.34 ms/s accounted cost, 0.84 passes/event, 1.99 paints/pass, 0.053 ms/event, 0.060 ms/pass,
0.017 ms/paint, and a 0.092 ms worst call.

## Actions

1. **`appearance` never fired, so `visibility`'s declared parent is still unverified.** Not a defect —
   `core/PerfSetup.lua:59-63` already documents the containment and deliberately declares it — but the
   claim has now gone one capture without evidence. A future run that touches a settings row, or
   changes a bar's look mid-combat, would exercise `NS.UpdateBarAppearance` and settle it. Worth
   naming as a **capture-protocol** note for the next run rather than a code change: nothing about the
   addon needs to move for it.
2. **`paintBar` declares `within: repaintPass`, and its call site does not supply it — confirmed in
   the source.** `modules/Display.lua:297` reads
   `Perf.Note("paintBar", debugprofilestop() - t0)` with no third argument, so `observedWithin` can
   never be set for this bucket and the containment is structurally unverifiable, not merely
   unexercised. `performance-§3` wants nested brackets to *supply* their parent, and the comment at
   `core/PerfSetup.lua:42-44` asserts that every nested bracket already does — which is true of
   `visibility` (`modules/Display.lua:260` passes `openBucket`) and `appearance`
   (`modules/Display.lua:196`), but not of `paintBar`. The fix is one argument at
   `modules/Display.lua:297`, threading the open bucket the way `Display.lua:140` already does for
   `appearance`. **New here** — not tracked by any existing issue or deviation, and the source check
   above is the only claim in this analysis that comes from outside the bundle.
3. **Re-run the protocol solo, in one zone, without the loading screens.** The buckets are trustworthy
   as they stand, but this run cannot say anything about frame time, and the reason is entirely
   environmental. `performance-§7`'s "same target, back to back, no other players" is the missing
   half. **None of this invalidates the bundle** — it is a real capture of a real fight, and its
   bucket figures are the addon's first in-game cost measurement on 1.9.0.
