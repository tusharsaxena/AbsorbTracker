# Measuring the addon's performance

Two harnesses, one record format. Issue
[#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17).

- **Offline** — `tests/perf.lua`, a headless runner over the real addon code. Catches algorithmic
  regressions (broken coalescing, new allocations in the repaint path). Cannot see anything the
  game does on the C side.
- **In-game** — `/at perf`, a probe inside the live addon. Measures our Lua *and*, through
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

`/at perf` — a top-level verb. **Works whether or not debug logging is on**: perf output writes
straight to the console sink rather than through the gated `NS.Debug`, because a run only happens
when you explicitly ask for one. Everything also acknowledges in chat.

| Command | Effect |
|---------|--------|
| `/at perf` | Status + usage |
| `/at perf start [label]` | Begin a run. Records nothing until an experiment is armed. Captures character, spec, zone and group |
| `/at perf measure a` | Arm **Experiment A** — addon active. Records while in combat |
| `/at perf measure b` | Arm **Experiment B** — addon suspended (done for you). Same combat gating |
| `/at perf finish` | End the run, append to the ring, lift any suspend. Does **not** print the summary — use `report` |
| `/at perf cancel` | Abandon the run — discards it unsaved and restores the addon. Only while a run is in flight |
| `/at perf show` / `hide` / `toggle` | Drive the step panel. Never touches the run |
| `/at perf report` | Print the summary. The only thing that does — `finish` deliberately stays quiet |
| `/at perf dump` | Write the run as one line of JSON into the debug console. Same data the summary is built from; the console's own **Copy** button lifts it out |

### Suspend

Experiment B suspends the addon: every event unregistered, any pending repaint cancelled, all bars
hidden — **without a reload**. `NS.ShouldShowBar` checks the suspended flag as step 0 of its ladder,
so nothing (a combat transition, a target swap, a settings edit) can re-show a bar mid-measurement.

There is no manual `suspend` verb — `measure b` owns it, which is what guarantees the two
experiments differ by the addon and nothing else. It is session-only, `/at perf finish` lifts it
before it saves or formats anything (so no later failure can strand the addon inert), and `/reload`
clears it regardless.

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
3. **Uncap the frame rate.** Untick **Max Foreground FPS** in the graphics options, and turn VSync
   off. This is not optional: a capped client absorbs the addon's cost in headroom, so both arms sit
   on the ceiling and the delta reads ~0 whether or not the addon is free — indistinguishable from a
   genuine null result. It has already wasted one capture (both arms returned 8.37 ms/frame, i.e.
   exactly 1/120 s).

   **Verify by measurement, not by CVar.** `GetCVar("maxFPS")` keeps the slider's last value even
   when the limiter is off, so it is not evidence either way — a client reading `maxFPS=120` was
   measured at 200 fps. The only reliable check is the report itself: if both arms land on the same
   frame time, or on a round number like 8.33 ms (120 fps) or 6.94 ms (144 fps), you were pinned.
4. Set a fixed graphics preset and don't touch it between arms.

### The step panel

`/at perf start` opens a small panel listing the run's steps. It is **strictly linear** — only the
next legal step is clickable, completed steps go green with a tick, and everything else is greyed
out. An armed or recording experiment shows gold, so it is obvious mid-fight that a capture is
running.

```
  Absorb Tracker — Perf Run                                            ×
  ──────────────────────────────────────────────────────────────────────
  ●  Start perf run                                        /at perf start
  ●  Measure A (with the addon)                       /at perf measure a
  ●  Measure B (without the addon)                    /at perf measure b   ← clickable
  ○  Finish perf run                                      /at perf finish
  ○  Report                                               /at perf report
  ○  JSON Dump                                              /at perf dump
  ○  Cancel perf run                                      /at perf cancel
```

Three columns: status dot, step, slash command. The command column is the point — it teaches the
typed form while you click, so the panel is a crutch you can stop needing.

The dot is green behind you, gold on the step actually happening, dim grey ahead. It is drawn with
`SetColorTexture` rather than a text glyph or an art path: a tick character renders as tofu in the
default font, and an `Interface\…` path that does not exist fails silently as a green box.

**Cancel perf run** sits outside the progression, in a muted red. It is clickable for as long as there is a
run to abandon — not before `start`, and not after `finish`, where the run is already saved and a
live-looking button that discarded nothing would only worry you. It discards the run unsaved,
restores the addon if Experiment B suspended it, and zeroes the counters so the next `start` begins
clean. Nothing an earlier `finish` wrote to the ring is touched.

**Report** and **JSON Dump** turn green once used but stay clickable — re-reading a summary or re-dumping the
JSON costs nothing and is regularly wanted twice.

**Closing the panel never touches the run.** The × hides it, Esc hides it, and `/at perf show`,
`hide` and `toggle` drive it from chat. A hidden window is not an abandoned capture; abandoning is
Cancel's job alone.

It exists because the *ordering* is what makes a run valid, and a numbered list in chat scrolls away
the moment combat starts. The buttons dispatch through the slash layer, so a click and a typed
command are the same code path.

The panel is draggable and has no close button — a half-finished run is the failure it exists to
prevent. `/at perf` re-shows it if it ends up somewhere forgotten. The slash verbs are **not** gated
this way: if a run cannot complete Experiment B, `/at perf finish` still closes it from chat.

### Capture

Each window opens the moment **you** enter combat and closes the moment you leave it. Everything
between windows — walking to the pull, resetting a dungeon, waiting on respawns — is not measured
and cannot contaminate the result.

```
/at perf start        (out of combat)
/at perf measure a    arms Experiment A; walk in and pull
   … fight …                A records on combat, ends when combat ends
/at perf measure b    arms Experiment B and suspends the addon; reset, pull again
   … same fight …           B records and ends the same way
/at perf finish
/reload
```

`measure b` suspends the addon and `measure a` resumes it, so the two experiments differ by the addon
and nothing else — there is no separate suspend step to forget. Re-arming a window zeroes it, so a
botched pull is simply redone with the same command.

**Blizzard's stopwatch is driven for you**: reset when an experiment is armed, started when
recording begins, paused when it ends. It gives you an on-screen timer for exactly the slice being measured. (Driven
by calling the FrameXML functions, not by running `/sw` as a macro — `RunMacroText` is protected and
would fail in combat.)

`finish` saves the run but prints nothing: it fires the moment a fight ends, when the console is
buried under combat output and a dozen unasked-for lines would scroll straight past. Click **Report**
(or **Dump**) in the panel when you actually want to read it.

The `/reload` is what flushes SavedVariables. Without it the capture stays in memory and is lost on
a crash or a logout.

**Making the arms comparable is on you.** The harness guarantees both windows contain only combat;
it cannot know whether they contain the *same* combat. A dungeon first-room pull reset and repeated,
or two one-minute dummy runs, both work well. Comparing a 20-mob pull against a single dummy does
not.

### Reading the result

```
capture:   2026-07-29 21:14 solo  (schema 1, v1.9.0)
who:       Kaosdk-Silvermoon, level 80 Blood Death Knight
where:     Nexus-Point Xenas — The Approach
group:     party (5) / party
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

- **A capped frame rate invalidates the delta**, and nothing detects it for you. The probe reports
  measurements and draws no conclusions about frame limiters: an earlier version tried and got the
  verdict wrong twice, because `maxFPS` is not a reliable signal (it holds the slider's last value
  regardless of whether the limiter is enabled). Judge it from the arms themselves — two arms at the
  same frame time, or at a round one, means you were pinned. The bucket figures are unaffected
  either way; they time our code directly, independently of frame pacing.
- **Unequal combat between the arms invalidates the delta**, which is what the measurement windows
  exist to prevent — they contain only in-combat frames by construction. What they cannot check is
  whether the two fights were *equivalent*. Keep the pull, spec and rotation the same, and check the
  `[Perf] Experiment … ENDED` lines, which carry each one's duration and frame rate: two
  experiments of wildly different duration are a warning sign.
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
Reading that file directly is the normal path — no copy-paste. `/at perf dump` is the fallback
for when the client is somewhere you can't read from disk.

---

## 5. Complexity

Reported separately in [docs/complexity.md](complexity.md), measured with `lizard`. Advisory only,
and outside the green gate pending an upstream rule in the Ka0s WoW Addon Standard.
