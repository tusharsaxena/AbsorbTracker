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

## Where the in-game probe actually lives

The in-game harness — the probe, its record schema, and the clickable step panel — is
`LibKa0s-Perf-1.0`, a Ka0s-owned shared library vendored into `libs/LibKa0s/` the same way Ace3 is
(copied in, not depended on at runtime). If the vendored copy is ever absent, `core/PerfSetup.lua`
degrades to a stub whose `Note` is a no-op but whose `OnCommand` answers honestly — one line naming
the missing library and where it is expected — which is the same degradation philosophy every setup
file in this addon follows. This addon supplies only a **descriptor**: `core/PerfSetup.lua` calls
`lib:New(descriptor)` with this addon's name, its `AbsorbTrackerPerfDB` SavedVariables global, the
ordered bucket declarations, and what
"suspend"/"resume" mean for *this* addon's events and frames. That call returns the `NS.Perf`
instance every bracket and slash verb below reads.

**Nesting is declared *and* observed.** A bucket's `within` is what the descriptor claims;
`Perf.Note(key, ms, parentKey)` reports what the run actually saw, and the report distinguishes the
two (`performance-§3`). Two nestings exist here: `paintBar` inside `repaintPass` (doRepaint fans out
over `NS.UpdateAbsorbBar`), and `visibility` inside `appearance` (`NS.UpdateBarAppearance` ends by
calling `NS.ApplyVisibility` inside its own open bracket). `appearance` itself is a **root** — it is
entered from the `APPEARANCE` bus message and from a settings row's `onChange`, never from a
repaint pass — and declares no parent, which is why the report says nothing about containing it.
`visibility` is also reached directly by the `VISIBILITY` message; that path supplies no parent, so
the record claims containment only for the calls that actually had one.

The descriptor contract and the full public surface `lib:New` returns are documented in the
library's own repo, not duplicated here:
[LibKa0s README](https://github.com/tusharsaxena/LibKa0s/blob/master/README.md). What follows on
this page — the protocol, the A/B methodology, how to read a report — is unchanged by the extraction
and is still this addon's own to explain, since it is about how *this* addon should be measured, not
about the library's mechanics.

---

## 1. Offline

```sh
lua tests/perf.lua
lua tests/perf.lua --label "after-my-change" --out /tmp/at-offline-mychange.json
```

An ad-hoc `--out` goes to a scratch path, not into `docs/`. Offline records worth keeping are the
ones the vendored runner writes into that run's own bundle under
[`docs/automated-tests/`](./automated-tests/) (`automated-tests-§7`);
[`docs/perf-analysis/`](./perf-analysis/README.md) is the **in-game** store and takes nothing from
this harness.

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
| `/at perf` | Status + usage, **and** shows the step panel — Start is clickable from it, so this is the entry point. Any unrecognized sub-verb lands here too |
| `/at perf start [label]` | Begin a run. Records nothing until an experiment is armed. Captures character, spec, zone and group |
| `/at perf measure a` | Arm **Experiment A** — addon active. Records while in combat |
| `/at perf measure b` | Arm **Experiment B** — addon suspended (done for you). Same combat gating |
| `/at perf finish` | End the run, append to the ring, lift any suspend. Does **not** print the summary — use `report` |
| `/at perf cancel` | Abandon the run — discards it unsaved and restores the addon. Only while a run is in flight |
| `/at perf show` / `hide` / `toggle` | Drive the step panel. Never touches the run |
| `/at perf report` | Print the summary. The only thing that does — `finish` deliberately stays quiet |
| `/at perf dump` | Write the run as one line of JSON into the debug console. Same data the summary is built from; the console's own **Copy** button lifts it out |

### Suspend

Experiment B suspends the addon: every event unregistered, any pending repaint canceled, all bars
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

**`/at perf` opens the panel, and the panel starts the run.** The first row is clickable whenever no
run is in flight, so one command is all anyone has to remember — every other step is a click from
there. It is **strictly linear** — only the next legal step is clickable, completed steps go green, and
everything else is grayed out. An armed or recording experiment shows gold, so it is obvious
mid-fight that a capture is running.

```
  Absorb Tracker — Perf Run                                            ×
  ──────────────────────────────────────────────────────────────────────
  ○  Start perf run                                        /at perf start   ← clickable
  ○  Measure A (with the addon)                       /at perf measure a
  ○  Measure B (without the addon)                    /at perf measure b
  ○  Finish perf run                                      /at perf finish
  ○  Report                                               /at perf report
  ○  JSON Dump                                              /at perf dump
  ○  Cancel perf run                                      /at perf cancel
```

Three columns: status dot, step, slash command. The command column is the point — it teaches the
typed form while you click, so the panel is a crutch you can stop needing.

The dot is green behind you, gold on the step actually happening, dim gray ahead. It is drawn with
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
the moment combat starts. Each button hands its own full command string back to `LibKa0s-Perf-1.0`'s
`OnCommand` — the same entry point a typed `/at perf …` reaches, and *not* this addon's slash layer —
so a click and a typed command produce identical output and identical panel state by construction.

The panel is draggable. `/at perf` re-shows it if it ends up somewhere forgotten. The slash verbs are
**not** gated by the panel: if a run cannot complete Experiment B, `/at perf finish` still closes it
from chat.

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
capture:   2026-07-29 21:14 solo  (schema 2, v1.9.0)
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
(buckets nest: paintBar declares itself within repaintPass — not observed, visibility observed inside appearance — do not sum)
```

**The bucket figures are the headline** (`performance-§7`). They time this addon's own code
directly, so they are what the capture actually resolves. `ms/s` divided by the frame rate gives the
Lua cost per frame: in the example above the buckets account for roughly 2.0 ms/s ≈ **0.026
ms/frame** at 77 fps. That is the addon's cost.

**`delta` is the frame you read them in, not the answer.** It is a difference of two noisy
aggregates, and this harness's run-to-run spread is roughly ±0.3 ms/frame on a 60–80 s arm (see the
caveats below — one of four captures came back negative). Below that spread the delta is
**unresolved**, and "unresolved" is the honest word: not zero, not free, not a pass. The example's
**+2.74 ms/frame** is comfortably above the spread, so it is a real difference — and the two orders
of magnitude between it and the 0.026 ms/frame the buckets account for is the finding: whatever that
cost is, it is not in our Lua. It is on the other side of the API calls our Lua makes, or it is the
environment.

If instead the buckets roughly *equal* a resolved delta, the cost is ours and the bucket breakdown
says which function to look at. And a delta inside the spread — including a near-zero or negative one
— resolves nothing on its own: read the buckets, and if they are small too, the sluggishness is not
this addon's and the investigation should move elsewhere.

### Caveats

- **The delta has a resolution floor of roughly ±0.3 ms/frame** on a 60–80 s arm. Below that it
  cannot distinguish a cheap addon from a free one — measured across four captures, one of which
  came back negative. If the addon under test costs less than that, the bucket table is the only
  instrument that will see it.
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

An in-game capture worth keeping is committed as a **frozen dated bundle** under
[`docs/perf-analysis/`](perf-analysis/README.md):

```
docs/perf-analysis/<YYYYMMDD-HHMMSS>/
  report.md      what the client printed - the `/at perf report` summary plus the run's lifecycle lines
  dump.json      the `/at perf dump` record, verbatim: one line, byte for byte, keys as sorted
  ANALYSIS.md    the write-up, following the root PERF_ANALYSIS.md playbook's uniform prompt
```

The directory stamp is **local time derived from the record's own `timestamp` field**, so it names
when the capture happened rather than when it was written up and a run analyzed a week later still
sorts against its neighbors. Bundles are frozen once written and never pruned; the store's
`README.md` — naming, a schema summary, the capture index — is the one file in there that is
rewritten. Offline scenario runs are not part of this store (`automated-tests-§7`).

`dump.json` goes in **unedited**. The library emits object keys in sorted order so two records diff
cleanly, and pretty-printing or rounding it destroys exactly that. The record shape is **schema 2**,
defined by `LibKa0s-Perf-1.0`; the authoritative field-by-field contract is
[LibKa0s docs/record-schema.md](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/record-schema.md).

In-game captures persist to the `AbsorbTrackerPerfDB` SavedVariables global (a ring of the last 10),
written to `_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` on `/reload` or logout.
Reading that file directly is the normal path — no copy-paste. `/at perf dump` is the fallback
for when the client is somewhere you can't read from disk.

---

## 5. Complexity

Reported in each automated-test bundle's `complexity.txt`, with the watch list in [automated-tests/RESULTS.md](automated-tests/RESULTS.md), measured with `lizard`. Advisory only,
and outside the green gate pending an upstream rule in the Ka0s WoW Addon Standard.

## Profiler attribution and measured cost

Spilled from `ARCHITECTURE.md` under `documentation-§3`'s hub rule (standard v2.23.0); the hub now
carries the one-paragraph summary and links here.

The addon is purely reactive — **no `OnUpdate`, no repeating ticker, no combat-log parsing, no
hot-path hooks.** Its entire runtime cost is: a player/target/focus `UNIT_*` event (C-filtered) →
`OnAbsorbChanged` / `OnMaxHealthChanged` → `NS.RequestRepaint` (coalescing one-shot AceTimer,
`throttleWindow` default 0.1 s) → `NS.UpdateAbsorbBar` (fanned out over all three units). The
measurements below predate the multi-unit-bars feature (player-only at the time) and have not been
re-run; after Finding 1 (above) the real cost was ~1.8 ms/s ≈ 0.18 % of one core for the single-bar
build.

**Reading the in-game Addon Profiler (`C_AddOnProfiler`) — important caveat.** The profiler bills a
shared library's dispatch frame to **whichever addon created it (first to load that LibStub copy)**,
not to the addons whose callbacks it later serves. Because WoW loads addons **alphabetically** and
`AbsorbTracker` sorts near the top, it typically **owns the shared AceEvent/CallbackHandler event
frame** and is billed for *every* Ace-based addon's event dispatch. This makes it rank far higher
than its own work warrants (it out-ranked ElvUI). This is **not** waste and is **not fixable from the
addon** — a standalone Ace addon must ship AceEvent and may legitimately load first. It was proven by
a controlled disable test (the blame transferred to the next alphabetical Ace addon, AlterEgo).

Full analysis, exact numbers, and profiler screenshots:
[docs/investigations/2026-07-14-addon-profiler-attribution/](./investigations/2026-07-14-addon-profiler-attribution/analysis.md).

**Measuring it yourself (issue #17).** Because the built-in profiler cannot attribute cost past the
shared-frame problem above, the addon ships its own harnesses:

- `lua tests/perf.lua` — offline, headless, over the real addon code. Asserts deterministic counters
  (repaints per event burst, API calls per pass, bytes allocated per pass) and reports timings.
  **Outside the green gate** — wall-clock numbers are not stable enough to gate a commit on.
- `/at perf` — in-game, via `LibKa0s-Perf-1.0` (vendored, `libs/LibKa0s/`), wired to this addon by
  `core/PerfSetup.lua`'s descriptor. `debugprofilestop()` brackets on the addon's own entry points,
  plus an FPS sampler bucketed by suspend state so one session yields both arms of an A/B. `suspend`
  makes the addon inert **without a reload**, holding load order and shared-frame ownership fixed —
  the one thing the July 14 confound cannot reach.

#### Five extracted libraries, one descriptor each

The instrumentation harness was the first thing to leave this addon for a shared library; it is now
one of five. `LibKa0s` is a Ka0s-owned library, vendored into `libs/LibKa0s/` the same way Ace3 is —
copied in, not depended on at runtime. The payload now ships **ten majors across fourteen files**,
load-ordered by `libs/LibKa0s/LibKa0s.xml`; the five that take a descriptor are carried by
`Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua` (+ `OptionsWidgets.lua`,
`OptionsCompose.lua`, `OptionsScroll.lua`) and `Perf.lua` (+ `PerfPanel.lua`).
`LibKa0s-Core-1.0` is the root; every other major declares a `NEEDS_CORE` guard and, if Core is absent or too old, `return`
before `LibStub:NewLibrary` — the major is simply never registered, which is what the addon's setup
files detect.

Every one of them follows the same shape: the algorithms are lib code, and this addon supplies only a
**descriptor** naming what is genuinely its own.

| Major | Wired by | What the descriptor carries | Published as |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | the `[AT]` prefix, passed as a **function** so a later `NS.PREFIX` change is not frozen in | `NS.Print`, `NS.Util.print`, `NS.IsConcatSafe`, `NS.SafeToString` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | frame-name prefix, title, monospace font, `/at`, call-time `print`/`safeToString`, the `[Init]` summary, and `isEnabled`/`setEnabled` over `NS.State.debug` | `NS.DebugLog`, `NS.Debug` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` (no separate setup file) | `NS.COMMANDS`, the schema read/write/default seams, `groupKey`, the mirror annotator | `NS.Slash`, an addon-owned table wrapping the private dispatcher instance |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | the brand, the schema seams, the reset policy hooks, the color codec, AceTimer, LSM | `NS.Helpers` (the instance itself), `NS.AceGUI`, the four `NS.*OptionsPanel*` wrappers |
| `LibKa0s-Perf-1.0` | `core/PerfSetup.lua` | name, SavedVariables global, bucket declarations, and what "suspend"/"resume" mean for *this* addon | `NS.Perf` |

Each setup file also carries a degradation stub, so the addon still loads and runs with the library
absent. The stubs are honest rather than silent: they answer each member the addon calls with a line
naming what is missing. `settings/OptionsSetup.lua` is the one exception, and deliberately so — it is
load-completing rather than member-answering, because its members are reached at *file load* by the
page files rather than at click time.

The descriptor contracts, the full public surface each `lib:New` returns, and the perf record schema
(now schema 2 — see below) are documented in the library's own repo, not duplicated here:
[LibKa0s README](https://github.com/tusharsaxena/LibKa0s/blob/master/README.md) and
[LibKa0s docs/record-schema.md](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/record-schema.md).
The design work sits in that repo too, as
`docs/superpowers/specs/2026-07-29-libka0s-perf-extraction-design.md` (Perf) and
`docs/superpowers/specs/2026-07-30-libka0s-five-module-extraction-design.md` (the other four).

For Perf specifically, the frozen hot-path bracket idiom (`local t0 = Perf.on and debugprofilestop()` /
`if t0 then Perf.Note(k, debugprofilestop()-t0) end`) is unchanged at every call site — that
byte-identity is what proves the extraction didn't change what is measured. The same rule was applied
to the other four: `NS.Print`, `NS.Debug`, `NS.Slash` and `NS.Helpers` all kept their names and their
member lists, so the call sites did not move either.

Protocol, caveats and how to read the numbers: [docs/performance.md](./performance.md). Captured
records: [docs/perf-analysis/](./perf-analysis/README.md). Automated test records: [docs/automated-tests/](./automated-tests/).
The current investigation into the reported in-combat FPS drop:
[docs/investigations/2026-07-29-combat-fps-drop/](./investigations/2026-07-29-combat-fps-drop/analysis.md).
