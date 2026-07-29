# Measuring the addon's performance

Two harnesses, one record format. Issue
[#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17).

- **Offline** — `tests/perf.lua`, a headless runner over the real addon code. Catches algorithmic
  regressions (broken coalescing, new allocations in the repaint path). Cannot see anything the
  game does on the C side.
- **In-game** — `/at debug perf`, a probe inside the live addon. Measures our Lua *and*, through
  the FPS arms, the total frame cost of having the addon active at all.

The second exists because the first cannot answer the question that matters. Almost all of a WoW
addon's real cost is on the far side of an API call.

---

## 1. Offline

```sh
lua tests/perf.lua
lua tests/perf.lua --label "after-my-change" --out docs/perf-runs/2026-08-01-offline-mychange.json
```

**Not part of the green gate.** `lua tests/run.lua` does not invoke it and no commit depends on it.
Wall-clock numbers on a developer machine are not stable enough to fail a build on, and a perf suite
that fails spuriously gets switched off within a week.

What it *does* assert is the deterministic half — repaint counts, WoW API call counts, and bytes
allocated per pass. Those are machine-independent, so a real regression fails loudly while a busy
CPU never does. Exit code is non-zero on an assertion failure.

### Scenarios

| Scenario | Question |
|----------|----------|
| coalescing | Do 1,000 absorb events collapse into exactly one repaint? |
| `absorbEvent` | What does one absorb event cost with the throttle already armed? |
| `paintPass` | What does one coalesced repaint over three bars cost? |
| `appearancePass` | What does a full restyle cost (`SetBackdrop` ×2 + four LSM fetches per bar)? |
| `settingsRead` | Does the `Units.Get` hot read path allocate? |
| `probeOverheadOff` / `On` | Is the instrumentation itself free when capture is off? |

### Reading the output

Compare scenarios **within one run**. Never compare a millisecond figure across machines, and never
treat the mock's API calls as real costs — under the headless mock every WoW API call is a no-op, so
`ms/iter` measures our Lua and nothing else. That is the whole limitation, and it is why the
in-game harness exists.

`bytes/iter` and `api/iter` are the durable numbers. If `api/iter` for `paintPass` changes, someone
added or removed a UI call in the repaint path and should know it.

---

## 2. In-game

`/at debug perf` — a sub-verb of the debug suite. Works whether or not debug *logging* is on;
output goes to the debug console (which is ungated) plus a one-line chat acknowledgement.

| Command | Effect |
|---------|--------|
| `/at debug perf` | Status + usage |
| `/at debug perf on [label]` | Reset counters, start capture and the FPS sampler. The optional label is appended to the timestamp — use it when comparing runs (`on solo`, `on full addon set`) |
| `/at debug perf off` | Stop, append to the ring, print the summary, lift any suspend |
| `/at debug perf report` | Print the summary without stopping |
| `/at debug perf dump` | Render the capture as JSON in the copy window |
| `/at debug perf suspend` | Make the addon inert |
| `/at debug perf resume` | Restore it |

### Suspend

`suspend` unregisters every event, cancels any pending repaint, and hides all bars — **without a
reload**. `NS.ShouldShowBar` checks the suspended flag as step 0 of its ladder, so nothing (a combat
transition, a target swap, a settings edit) can re-show a bar mid-measurement.

It is session-only and resets on `/reload`. `/at debug perf off` lifts it automatically so a capture
can't leave the addon switched off by accident.

Suspend matters because **disabling an addon is not a clean experiment**. WoW's built-in Addon
Profiler bills a shared library's dispatch frame to whichever addon created it — the first to load
that LibStub copy — and addons load alphabetically. `AbsorbTracker` sorts near the top, so it
typically owns the shared AceEvent/CallbackHandler frame and is billed for *every* Ace addon's event
traffic. Disabling it hands that frame, and the blame, to the next alphabetical Ace addon. See
[docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md](investigations/2026-07-14-addon-profiler-attribution/analysis.md).

Suspend holds load order and frame ownership fixed, and changes only whether our code runs.

---

## 3. The A/B protocol

Run this when you want a defensible number rather than an impression.

### Controlled environment

1. **Disable every other addon.** AbsorbTracker plus stock Blizzard UI only. This is the strongest
   arm available — with no other Ace addon present there is nothing to inherit the dispatch frame
   and attribution is not arguable.
2. Pick a **repeatable fight**: a training dummy, same spec, same rotation, same camera angle. Do
   not compare a dummy to a raid.
3. **Uncap the frame rate**: `/console maxFPS 0`, `/console maxFPSBk 0`, and VSync off. This is not
   optional. A capped client absorbs the addon's cost in headroom, so both arms sit on the ceiling
   and the delta reads ~0 whether or not the addon is free — indistinguishable from a genuine null
   result. This has already wasted one real capture (both arms returned 8.37 ms/frame, i.e. exactly
   1/120 s). The probe now records the limiter CVars at capture start and prints a
   `DELTA IS INVALID` banner if any is set, but it is far better not to trip it.
4. Set a fixed graphics preset and don't touch it between arms.

### Capture

```
/at debug perf on
   … fight for 60 seconds …
/at debug perf suspend
   … fight for another 60 seconds, identically …
/at debug perf off
/reload
```

The `/reload` is what flushes SavedVariables. Without it the capture stays in memory and is lost on
a crash or a logout.

### Reading the result

```
capture: 2026-07-29 21:14  (schema 1, v1.9.0)
limits:    maxFPS=0  maxFPSBk=30  targetFPS=60  vsync=0
active:      62.3s    4821 frames    77.4 fps   12.92 ms/frame
suspended:   60.1s    5903 frames    98.2 fps   10.18 ms/frame
delta:                                          +2.74 ms/frame

bucket            calls   total ms       ms/s    max ms
absorbEvent        1284      31.20      0.501     0.310
repaintPass         623     122.40      1.965     1.840
paintBar           1869      98.10      1.575     0.920
(buckets nest: repaintPass contains paintBar — do not sum)
```

**`delta` is the headline.** It is the per-frame cost of having the addon active, measured with
everything else held constant.

Then compare it against the bucket totals. `ms/s` divided by the frame rate gives the Lua cost per
frame. In the example above the buckets account for roughly 2.0 ms/s ≈ **0.026 ms/frame** at 77 fps,
against a measured delta of **2.74 ms/frame**. That gap — two orders of magnitude — is the finding:
the cost is not in our Lua, it is on the other side of the API calls our Lua makes.

If instead the buckets roughly *equal* the delta, the cost is ours and the bucket breakdown says
which function to look at.

Both readings are useful. A near-zero delta is also a result: it means the sluggishness is not this
addon's, and the investigation should move elsewhere.

### Caveats

- **A capped frame rate invalidates the delta.** The report says so when it detects one — but note
  it warns only when the capture actually *ran at* the cap, not merely when a cap is configured.
  WoW keeps `maxFPS` at its last slider value even when the limiter checkbox is off, so unticking
  the slider in the graphics options does **not** zero the CVar. Use `/console maxFPS 0` and confirm
  with `/dump GetCVar("maxFPS")`. The bucket figures are unaffected either way — they time our code
  directly, independently of frame pacing.
- **Unequal combat between the arms invalidates the delta too**, and nothing detects that for you.
  Combat costs frame time on its own, so an active arm that was 78% combat against a suspended arm
  that was 100% combat shows a *negative* delta that has nothing to do with the addon. Watch the
  `[Combat] entered` / `[Combat] left` lines in the console and keep the arms comparable.
- Buckets **nest**. `repaintPass` contains `paintBar`. Never sum the column.
- Bucket `ms/s` divides by the *active* seconds only — nothing accrues while suspended.
- The sampler itself runs an `OnUpdate` during capture. It is in both arms, so it cancels out of the
  delta, but it is not free in absolute terms.
- One 60-second arm is a small sample. Two runs that disagree by more than about 1 ms/frame mean the
  environment was not held constant.

---

## 4. Where the numbers go

Records land in [`docs/perf-runs/`](perf-runs/README.md) — schema, naming, and field meanings are
documented there.

In-game captures persist to the `AbsorbTrackerPerfDB` SavedVariables global (a ring of the last 10),
written to `_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` on `/reload` or logout.
Reading that file directly is the normal path — no copy-paste. `/at debug perf dump` is the fallback
for when the client is somewhere you can't read from disk.

---

## 5. Complexity

Reported separately in [docs/complexity.md](complexity.md), measured with `lizard`. Advisory only,
and outside the green gate pending an upstream rule in the Ka0s WoW Addon Standard.
