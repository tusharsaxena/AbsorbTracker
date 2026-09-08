# Analysis — 20260909-013016

- **Addon:** AbsorbTracker 1.9.0 (record schema 2, client interface 120100)
- **Record validated:** dump `addon` = `AbsorbTracker`, the repository this bundle sits in; dump
  `version` = `1.9.0`, matching `AbsorbTracker.toc:5` and `core/Namespace.lua:7`; dump `schema` = 2,
  matching the vendored `libs/LibKa0s/Perf.lua:42` (`lib.SCHEMA = 2`). Dump `interface` 120100 does
  **not** match the TOC's `## Interface: 120007` — see Action 4.
- **Captured:** 2026-09-09 01:24 local, label `2026-09-09 01:24`
- **Who / where:** Sacrìlege-Frostmourne, level 90 Protection Paladin · Silvermoon City — The Bazaar · solo
- **Delta:** +0.26 ms/frame — **unresolved**, below the floor
- **Previous capture:** [20260807-125002](../20260807-125002/ANALYSIS.md)

## Headline

Two combat-gated arms, solo, in one city subzone, on 1.9.0 — a materially cleaner run than the first
capture. The addon's own bracketed code cost **0.1421 ms per second of combat** (12.8834 ms of Lua
over a 90.685 s fight, [`dump.json`](dump.json)), which is **0.0019 ms of the 13.0538 ms active
frame**, or 0.014%. The frame-time delta still resolved **nothing**: +0.2620 ms/frame is inside the
±0.3 ms/frame run-to-run spread and well under the ~0.5 ms/frame line, so the frame instrument could
not see this addon. The sign of an unresolved delta is not evidence either way: 20260807 read
−0.1777 ms/frame, this run reads +0.2620, and a sign that flips between runs while both magnitudes
sit under the floor is what an instrument below its resolution looks like. The one structural
result: `paintBar` now reports **observed** containment inside `repaintPass`, closing the first
capture's Action 2; `appearance` still never fired, so
`visibility`'s declared parent is now unverified for a second consecutive run.

## The arms

Both figures come from [`dump.json`](dump.json)'s `fps` block; the rounded forms are in
[`report.md`](report.md).

| Arm | Seconds | Frames | Avg fps | ms/frame |
|---|---|---|---|---|
| active (addon running) | 90.6850 | 6947 | 76.6058 | 13.0538 |
| suspended (addon inert) | 65.2000 | 5097 | 78.1748 | 12.7918 |
| **delta** (active − suspended) | +25.485 | +1850 | −1.5690 | **+0.2620** |

The delta is **unresolved**. 0.2620 ms/frame sits inside the ±0.3 ms/frame spread the harness has
measured collection-wide — four captures of a very cheap addon,
`docs/perf-analysis/README.md:145-146`, not captures of this addon, of which this store holds two —
and is roughly half the ~0.5 ms/frame line at which a reading starts to carry information, so this
run's frame sampler could not separate the addon from the noise.
That is a statement about the instrument, not about the addon (`performance-§8`); "no measurable
impact" is the sentence not to write from it. The sign carries nothing either: 20260807's
−0.1777 ms/frame told us only that the environment had moved, and this run's +0.2620 — a *larger*
magnitude, equally unresolved — tells us the same. The flip between the two runs is itself the
signature of a reading below its floor, not an improvement.

The magnitude is the whole of it, and the arms were not matched either. **Arm B ran
28.1% shorter** — 65.2 s against 90.7 s — so the two numbers are differently-averaged aggregates over
different windows. Combat gating equalizes the *kind* of window, never its length. The arms are also
separated by a **73-second gap** (`Experiment A ENDED` 01:27:42, `Experiment B RECORDING` 01:28:55,
[`report.md`](report.md)), during which the suspend landed at 01:28:46 and the player left and
re-entered combat. There is no `/reload` and no zone transition in the log between them, which is
the material improvement over the first run.

The right reading is the one below: the buckets measure this addon's Lua directly and are indifferent
to arm length, frame pacing and whatever else was drawing in The Bazaar.

## The buckets — what the addon actually cost

Every figure from [`dump.json`](dump.json)'s `buckets`; `ms/s` is `totalMs` over the **active** arm's
90.6850 s, as [`report.md`](report.md) computes it. Buckets nest — **do not sum the column**.

| Bucket | Calls | Total ms | ms/s | Max ms | Parent |
|---|---|---|---|---|---|
| `repaintPass` | 130 | 9.1603 | 0.1010 | 0.1862 | none declared — a root (`core/PerfSetup.lua:62`) |
| `paintBar` | 258 | 5.5714 | 0.0614 | 0.1248 | declares `within: repaintPass`, and `observedWithin: repaintPass` — **observed** |
| `absorbEvent` | 183 | 3.3133 | 0.0365 | 0.0654 | none declared — a root (`core/PerfSetup.lua:61`) |
| `visibility` | 69 | 0.4098 | 0.0045 | 0.0140 | declares `within: appearance` — **not observed**, and `appearance` never fired |
| `appearance` | — | — | — | — | declared at `core/PerfSetup.lua:68`, **never fired** |

**Total accounted cost: 0.1421 ms per second of combat** — 12.8834 ms of Lua across the three buckets
that ran with no observed parent (`absorbEvent` + `repaintPass` + `visibility`) over 90.6850 s.
Spread over the arm's 6947 frames that is **0.0019 ms/frame** against a 13.0538 ms frame, or
**0.014%** — a seventh of a thousandth of the frame. `paintBar` is *not* added: this run observed it
inside `repaintPass`, so its 5.5714 ms is already counted once in the parent's 9.1603 ms. Unlike the
first capture, that is now a measurement rather than a declaration, and the "treat it as disjoint"
ceiling the first analysis had to carry is gone.

The ratios that survive a change of combat duration:

- **0.710 repaint passes per absorb event** (130 / 183) — an **upper bound** on the absorb-driven
  ratio, because `NS.MSG.REPAINT` is also published by max-health changes and by every lifecycle
  transition (`core/AbsorbTracker.lua:196, 202, 210, 220, 232`), including the 23 inferred below.
  Absorb-driven passes are therefore fewer than 130 and the trailing-edge throttle
  (`modules/Timer.lua:51-61`) absorbed **at least** three events in ten into a pass already queued.
- **1.985 bar paints per repaint pass** (258 / 130) — two bars painted per pass, from three iterated.
- **1.434 passes per second.** `NS.GetThrottleWindow()` clamps to 0.05 .. 1 s
  (`core/Data.lua:305-311`), so the ceiling is between **1/s and 20/s** depending on a setting this
  record does not carry; the default 0.1 s (`defaults/Profile.lua:90`, the ~10/s of `modules/Timer.lua:14`) puts it near 10/s.
  The throttle was **not the binding constraint** for any window at or below ~0.7 s; the absorb event
  rate (2.018/s) was.
- **0.0181 ms per absorb event**, **0.0705 ms per repaint pass**, **0.0216 ms per bar paint**,
  **0.0059 ms per visibility apply**.
- **Worst single call anywhere: 0.1862 ms** (`repaintPass`) — 1.4% of one 13.0538 ms frame.

### Why each bucket costs what it costs

**`repaintPass` — 0.1010 ms/s, the largest line, and 60.8% of it is `paintBar`.** The bucket is
`doRepaint` (`modules/Timer.lua:17-49`), which fans out over `NS.Units.LIST` via
`NS.ForEachUnit` (`modules/Display.lua:107-109`) and calls `NS.UpdateAbsorbBar` for **every** unit in
the list, not only the enabled ones. 130 passes × 3 units = 390 invocations, of which 258 painted.
The residual — 9.1603 − 5.5714 = **3.5889 ms, 0.0276 ms per pass** — is the fan-out itself plus the
132 invocations that early-outed before the bracket opened. That early-out is not free, and it has
**three** exits, which cost different amounts. An invocation that fails the `NS.ShouldShowBar` ladder
(`modules/Display.lua:280-288` — five predicates: two `NS.GetSetting` reads, a `NS.Units.IsEnabled`,
`visibilityAllows()` which is itself another `GetSetting` plus `UnitAffectingCombat`, and a
`UnitExists`) returns at `modules/Display.lua:345` and **never reaches** the `testHold` check at
`:349` or the `GetSetting("locked")` read at `:367`; only an invocation that passes the ladder gets
that far. The record does not say how the 132 split between the three exits, so the per-invocation
cost is a range rather than a fixed ladder-plus-one-read — though `locked` and `testHoldUntil` are
global rather than per-unit and 258 bars did paint during the arm, so both of those gates were open
whenever a paint happened; the ladder exit at `:344-346` is very likely where nearly all 132 went. The bracket is **deliberately outside** these early-outs
(`modules/Display.lua:381-382`: "counts only passes that actually painted"), which is the right call
for `ms/call` and does mean this cost is visible only as the parent's residual. Scaling: proportional
to passes × `#NS.Units.LIST`, and the list is fixed at three, so it does not grow with group size or
with combat intensity beyond the throttle ceiling.

**`paintBar` — 0.0614 ms/s over 258 calls.** `NS.UpdateAbsorbBar`'s painting half
(`modules/Display.lua:371-389`) is four C-side writes per bar — `SetAlpha`, `SetMinMaxValues`,
`SetValue`, `SetText` — over two API reads (`UnitGetTotalAbsorbs`, `UnitHealthMax`) and an
`AbbreviateNumbers`. At 0.0216 ms per paint that is entirely unremarkable, and the figure is Lua time
only: what the client spends behind `SetStatusBarTexture`-class calls is not in it
(`docs/perf-analysis/README.md`). Scaling: proportional to visible bars × passes, capped at three
bars.

**`absorbEvent` — 0.0365 ms/s, and the cheapest it has ever measured.** `addon:OnAbsorbChanged`
(`core/AbsorbTracker.lua:167-188`) publishes one bus message and does nothing else *when debug
logging is off*: the whole `UnitGetTotalAbsorbs` / `NS.IsConcatSafe` / `AbbreviateNumbers` rollup is
behind `unit == "player" and NS.State and NS.State.debug` at `core/AbsorbTracker.lua:169`. This
capture's paste carries **only** `[Perf]` lines, where the first capture's carried `[Bar]`,
`[Combat]`, `[World]` and `[Init]` narration — consistent with debug being off here and on there. The
per-call cost fell from 0.0527 ms to 0.0181 ms, a factor of 2.9, and that gate is the mechanism the
source offers for it. Scaling: driven by `UNIT_ABSORB_AMOUNT_CHANGED` on player/target/focus only —
the per-unit `RegisterUnitEvent` frames filter dispatch (`core/AbsorbTracker.lua:136-137`) — so it
does **not** grow with raid size.

**`visibility` — 0.0045 ms/s, the smallest line, and its 69 calls are exactly 3 × 23.**
`NS.ApplyVisibility` (`modules/Display.lua:306-321`) is driven from the `VISIBILITY` bus message,
whose sole subscriber fans out over all three units (`modules/Display.lua:406-408`). 69 = 3 × 23, so
**23 `VISIBILITY` publishes** landed during the arm — combat transitions and target swaps
(`core/AbsorbTracker.lua:201-231`). None of them came from inside `NS.UpdateBarAppearance`.

### Two instrumentation results

**`paintBar`'s containment is now observed — the first capture's Action 2 is closed by the source.**
20260807's analysis found `modules/Display.lua` calling `Perf.Note("paintBar", …)` with no third
argument, which made the declared `within: repaintPass` structurally unverifiable. The code now
threads it: `NS.UpdateAbsorbBar(unit, parentBucket)` at `modules/Display.lua:339`, supplied by
`doRepaint` as `local parent = t0 and "repaintPass" or nil` at `modules/Timer.lua:39`, noted at
`modules/Display.lua:389`. The record shows the consequence — `"observedWithin":"repaintPass"` is
present on `paintBar` in [`dump.json`](dump.json) and absent from the 20260807 record. This is the
first capture in the store where a nesting claim is **measured**.

**`appearance` never fired again, so `visibility`'s parent is unverified for a second run.**
`appearance` is declared at `core/PerfSetup.lua:68` and is absent from the table, so
`NS.UpdateBarAppearance` was never entered — no `APPEARANCE` bus message, no settings row touched
during the arm. That is a result about what the run exercised, not a defect: the descriptor's comment
at `core/PerfSetup.lua:69-72` argues that `within: appearance` is the honest declaration even so, and
this capture neither confirms nor contradicts it. Both captures in this store have now gone without
exercising it, which makes it a **capture-protocol** gap rather than a code one.

## What the capture did not hold constant

Much less than the first capture, and the improvement is the point. From the context block and run
log in [`report.md`](report.md):

- **Arm duration — the one real mismatch.** A ran 90.685 s, B ran 65.200 s: B is 28.1% shorter. Two
  aggregates over unequal windows.
- **A 73-second gap between the arms**, 01:27:42 to 01:28:55, with the suspend at 01:28:46. Nothing
  in the log runs in it.
- **No `/reload`, and no zone change.** There is no second `run started` banner and no world
  transition between the arms — the two failure modes that wrecked the first capture's delta. The
  `where:` line is still captured once, at 01:24:09, so arm B's zone is inferred from the absence of
  a transition rather than recorded.
- **Solo, both arms.** `group: solo` — the four other party members whose load contaminated
  20260807's sampler are gone. `performance-§7`'s "no other players" is now half-satisfied: the
  *group* is empty, but **The Bazaar is a capital-city subzone**, and passers-by, their mounts and
  their own addons are in the frame sampler and are not recorded by anything in this bundle. This is
  the largest remaining uncontrolled variable and it is a plausible source of a 0.26 ms/frame swing
  on its own.
- **Different pulls.** Nothing ties the two arms to the same target. Arm A logged 183 absorb events.
  Arm B's contribution to the buckets cannot be read off this bundle at all: `dump.json` carries one
  flat aggregate `buckets` object for the whole run with no per-arm split
  (`libs/LibKa0s/Perf.lua:702-722`), and `report.md` prints no per-arm bucket table. That arm B
  contributed nothing is an **assumption**, resting on the run log's `addon SUSPENDED — inert` line
  and on the library's design — `Perf.suspended` short-circuits `NS.ShouldShowBar` at
  `modules/Display.lua:282` and `RequestRepaint` bails at `modules/Timer.lua:55`, which is what
  `libs/LibKa0s/Perf.lua:209-210` states as "`secs` is the ACTIVE seconds only: no bucket can accrue
  while suspended". Every `ms/s` figure in this write-up inherits that assumption: had suspend
  leaked, each would be inflated and nothing in the record would show it.
- **Debug logging almost certainly differed from the previous capture.** Only `[Perf]` lines are in
  this paste. That is a difference *between captures*, not between arms, and it is why `absorbEvent`
  must not be read as a code improvement (see "What moved").

The suspend is clean in the log: `addon SUSPENDED — inert` at 01:28:46 before arm B armed, and
`addon RESUMED — events and frames restored` at 01:30:05 before the save, as `performance-§6`
requires. A canceled run at 01:15:02–01:15:28 preceded this one and saved nothing.

## What moved

Compared against [20260807-125002](../20260807-125002/dump.json) on `ms/s` and per-call ratios, never
on `totalMs` — that run was 26.601 s against this one's 90.685 s.

| Figure | 20260807 | 20260909 | Movement |
|---|---|---|---|
| Accounted cost | 0.3405 ms/s | 0.1421 ms/s | **−58%** |
| Cost as % of frame | 0.034% | 0.014% | **−58%** |
| ms per absorb event | 0.0527 | 0.0181 | **−66%** |
| ms per repaint pass | 0.0596 | 0.0705 | **+18%** |
| ms per bar paint | 0.0168 | 0.0216 | **+29%** |
| ms per visibility apply | 0.0114 | 0.0059 | −48% |
| passes per event | 0.837 | 0.710 | −15% |
| paints per pass | 1.986 | 1.985 | **−0.08%** |
| absorb events per second | 3.233 | 2.018 | −38% |
| worst single call | 0.0919 ms | 0.1862 ms | +103% |

The `% of frame` row is the `Accounted cost` row in other units — `% of frame` is `ms/s` ÷ 1000
(frames × ms/frame = seconds × 1000) — so its movement must equal the row above it. Both
cells are now that capture's *accounted* cost (its `ANALYSIS.md:58`). The 0.043% previously in this
row is 20260807's paintBar-as-disjoint **ceiling** (its `ANALYSIS.md:59`) — a quantity this run no
longer needs and which must not be compared against an accounted figure.

**None of this is a code change.** The addon is 1.9.0 in both records ([`dump.json`](dump.json) and
the previous bundle's), and the only source movement between them — threading `parentBucket` into
`paintBar` — changes what is *recorded*, not what runs. Read the rows as environment:

- **`ms per absorb event` fell 66%, and the source names the mechanism.** The debug rollup at
  `core/AbsorbTracker.lua:169-182` is gated on `NS.State.debug` (the `SendMessage` at `:183` sits
  outside the gate and runs unconditionally); with narration off the handler is a
  single `SendMessage`. The previous paste carried debug lines and this one does not. This is the one
  row with a concrete explanation, and it is a **measurement-condition** difference: it says the
  debug gate is doing its job (`debug-logging-§4`), not that the handler got faster.
- **`ms per repaint pass` and `ms per bar paint` rose 18% and 29%** on a run that is otherwise
  cheaper. Both are sub-0.03 ms figures on a machine running a different fight in a different zone at
  a different frame rate (76.6 fps against 60.4), and `debugprofilestop()` resolution and cache state
  are not held constant across captures. Worth **watching, not acting on** — two data points on two
  environments is not a trend.
- **`paints per pass` is 1.985 against 1.986 — a 0.08% difference**, across a party-of-five
  dungeon pull and a solo city fight. Two of three iterated bars painted in both. That stability is
  the best evidence in the store that the fan-out is behaving as `modules/Timer.lua:40-42` describes.
- **The worst single call doubled to 0.1862 ms**, still `repaintPass`, still 1.4% of a frame. No
  bracket in either capture has come near a frame budget.
- **`appearance` did not move: absent in both.** Still zero evidence for `visibility`'s parent.

## Actions

1. **`appearance` has now gone two captures without firing — make the next run exercise it.** A
   capture-protocol note, not a code change: touch a settings row (or publish `APPEARANCE`) during
   arm A and `NS.UpdateBarAppearance` will run, settling whether `visibility` is really nested inside
   it as `core/PerfSetup.lua:69-72` argues. Carried forward from 20260807's Action 1, still open.
2. **Re-run once more away from a capital city, with matched arm lengths.** The delta has been
   unresolved twice. The remaining uncontrolled variables are exactly two — The Bazaar's foot traffic
   and the 28% arm-length mismatch — and both are protocol, not code. Carried forward from 20260807's
   Action 3, now half-discharged (solo, one zone, no reload).
3. **Optional and small: hoist `doRepaint`'s fan-out closure.** `modules/Timer.lua:40` allocates a
   fresh closure per pass to capture `parent` and `painted`, which is the exact allocation the file's
   own comment at `modules/Timer.lua:13-16` hoisted `doRepaint` itself to avoid. At 130 passes over
   90.685 s it is 1.4 closures/second — **the saving is garbage, not time**, and it would not show in
   any bucket here. Risk: `painted` and `parent` would have to become module-locals, which is state
   where there is currently none. **Not recommended on this evidence** — recorded because the capture
   is what exposed it, and because the file already holds the opposite convention one function above.
4. **The TOC's `## Interface: 120007` is behind the client this was captured on.**
   [`dump.json`](dump.json) records `"interface":120100`. Not a perf finding and not a defect in the
   record — noted here because this bundle is where the two numbers sit side by side.
   `/wow-addon:bump-interface` owns it. **New here.**

**Baseline to carry forward:** 0.1421 ms/s accounted cost, 0.710 passes/event, 1.985 paints/pass,
0.0181 ms/event, 0.0705 ms/pass, 0.0216 ms/paint, 0.0059 ms/visibility, 0.1862 ms worst call.
