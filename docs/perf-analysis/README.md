# Perf analysis — the in-game capture store

**In-game captures only.** A human runs the `perf` verb in a live client and copies the result out;
no script can produce one, which is exactly why this store is worth trusting (`performance-§8`).
**Offline** scenario runs are a different measurement entirely — they are produced by
`tests/_kit/run-automated-tests.sh` and live in the bundle for the run that produced them, under
[`../automated-tests/`](../automated-tests/) (`automated-tests-§7`). Offline `bytes/iter` and
`api/iter` say nothing about frame time; an in-game capture says nothing about allocation. Do not
read one as the other.

The store is **standing and cumulative** — it is not tied to one investigation — so captures compare
across addon versions. See [docs/performance.md](../performance.md) for the protocol and for how to
read the numbers.

## Bundle naming

```
docs/perf-analysis/<YYYYMMDD-HHMMSS>/
```

One directory per capture. The stamp is **local time**, derived from the record's own `timestamp`
field (epoch seconds) — it names when the capture **happened**, not when it was written up, so a run
analyzed a week later still sorts against its neighbors. A stamp that had to be reconstructed is
said to be one, in that bundle's `ANALYSIS.md`.

## The three artifacts

Every bundle carries exactly three files:

| File | What it is |
|---|---|
| `report.md` | What the client printed — the `/at perf report` summary, plus the run's lifecycle log lines (`run started`, `armed`, `RECORDING`, `ENDED`, `SUSPENDED`, `RESUMED`) |
| `dump.json` | The schema-2 JSON record the summary was built from, committed verbatim |
| `ANALYSIS.md` | The write-up, following the uniform prompt in the standards repo's root `PERF_ANALYSIS.md` playbook |

The run log is kept deliberately. It is the capture's provenance: it is how a later reader confirms
both arms were combat-gated, that arm B really was suspended, and that no `/reload` landed between
the arms. None of those three conditions is recorded by the report itself.

### `dump.json` is verbatim

**One line, byte for byte as the client emitted it.** Not pretty-printed, not re-keyed, not rounded,
not stripped of a field that looks wrong. The library emits object keys in **sorted order** precisely
so that two records diff cleanly, and pretty-printing destroys that property — a reformatted record
diffs as a whole-file rewrite against the one before it, which is the one thing the store exists to
make cheap. The encoder's quirks (`%.4f` on every non-integer, and the empty-table wart below) are
part of the record's identity. Read it with `jq`; never write it with one.

Bundles are **frozen once written** and are never pruned. This README is the one file in the store
that gets rewritten. If a reading turns out to have been wrong, the **next** capture's `ANALYSIS.md`
says so — the old bundle stays as it was measured.

## Schema summary

The record shape is the **library's**, versioned in the library, not here. This addon emits
**schema 2** as of the `LibKa0s-Perf-1.0` extraction (issue #17). The full field-by-field contract is
the source of truth:
[LibKa0s docs/record-schema.md](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/record-schema.md).
What follows is a summary of the **shape** for orientation only. Every value below is a type
placeholder, not a measurement — there is no capture in this store to quote, and inventing plausible
figures for a README is how a reader ends up citing a number nobody ever recorded (anti-pattern #61).
A real record's values are whatever the client emitted.

```jsonc
{
  "schema": 2,
  "addon": "AbsorbTracker",     // which host produced this record
  "source": "ingame",           // "offline" records exist, but not in this store
  "version": "<x.y.z>",         // addon version at capture time
  "interface": <int>,           // client interface, from select(4, GetBuildInfo())
  "timestamp": <epoch seconds>, // THE BUNDLE'S STAMP IS DERIVED FROM THIS, in local time
  "label": "<YYYY-MM-DD HH:MM> <optional text>",   // the stamp is always prepended

  // Who / where / what, captured once at the start of the run.
  "context": {
    "character": "<name>", "realm": "<realm>", "level": <int>,
    "class": "<class>", "spec": "<spec>",
    "zone": "<zone>", "subZone": "<subZone, may be \"\">",
    "group": "solo" // or "party (N)" / "raid (N)", suffixed " / <instanceType>" in an instance
  },

  // Per-bucket totals — the probe's brackets. THESE MAY NEST, see `within`.
  // Never sum a parent and its children. A bucket that never fired is ABSENT, not zero.
  "buckets": {
    "<bucketKey>": {
      "calls": <int>, "totalMs": <ms>, "maxMs": <ms>,
      "within": "<declared parent>",        // present only if the descriptor declares one
      "observedWithin": "<actual parent>",  // present only if a call site passed one —
      "observedMixed": <bool>               // a `within` with no `observedWithin` is UNVERIFIED
    }
  },

  // Frame sampling, one entry per arm. An arm that never ran is zeroed, not absent.
  "fps": {
    "active":    { "seconds": <s>, "frames": <int>, "avgFps": <fps>, "msPerFrame": <ms> },
    "suspended": { "seconds": <s>, "frames": <int>, "avgFps": <fps>, "msPerFrame": <ms> },
    // active.msPerFrame - suspended.msPerFrame, but hard-coded 0 unless BOTH arms have frames.
    // A 0 here from a one-armed run is an ABSENT result, not a null one.
    "deltaMsPerFrame": <ms>
  },

  "failures": {}                // offline records only; {} not [] — see the encoder note below
}
```

## Taking a capture

Everything is driven by this addon's own `perf` verb, which works whether or not debug logging is on.
`/at perf` with no sub-verb prints status and opens the step panel, from which the same steps are
clickable.

```
/at perf start [label]     out of combat — begins the run, captures character/spec/zone/group
/at perf measure a         arms Experiment A (addon active); walk in and pull
/at perf measure b         arms Experiment B (addon suspended, done for you); reset and pull again
/at perf finish            ends the run and appends it to the ring — prints nothing by design
/at perf report            prints the human-readable summary
/at perf dump              writes the run as one line of JSON into the debug console
```

Then hit the debug-log window's **Copy** button (`Ctrl+C`, `Esc`). One paste carries the report, the
dump and the lifecycle lines — the three inputs a bundle needs.

The same record is also on disk after a `/reload`, under `AbsorbTrackerPerfDB.runs` (a ring of the
last 10) in:

```
_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua
```

WoW names that file after the **addon**, not after the saved-variable globals it declares, so both
`AbsorbTrackerDB` and `AbsorbTrackerPerfDB` live in it. The perf ring is a separate top-level global
rather than part of the AceDB tree, so it is never copied by "copy profile", wiped by "reset
profile", or swapped out by a profile switch.

## Capture index

| Stamp | Addon version | Label | What it measured | Bundle |
|---|---|---|---|---|
| — | — | — | — | — |

**This store is currently empty — there are no captures.** That is a real gap, not a missing tool:
the harness is wired, the verbs work, and the only thing standing between here and a first row is
somebody running the protocol in a live client. Until then this addon has no in-game measurement of
its own cost on the current version.

## Field notes

- **`fps.deltaMsPerFrame` has a resolution floor.** Four captures of a very cheap addon put the
  run-to-run spread of a 60–80 s A/B at roughly **±0.3 ms/frame**, and one of the four came back
  negative. Treat any delta below about **0.5 ms/frame** as **unresolved**, not as zero — "no
  measurable impact" written from an unresolved delta is a statement about the instrument wearing
  the clothes of a statement about the addon. Read the bucket figures instead: they measure this
  addon's code directly and are unaffected by arm mismatch or frame pacing. See
  [2026-07-29-combat-fps-drop](../investigations/2026-07-29-combat-fps-drop/analysis.md).
- **`fps.deltaMsPerFrame` is otherwise the number the in-game harness exists to produce** — the
  per-frame cost of the addon being active, with load order and shared-frame ownership held fixed by
  suspend rather than by disabling the addon. It reports `0` unless **both** arms were sampled; with
  one arm empty a subtraction would bill the entire frame time to the addon.
- **`buckets[*].totalMs` is Lua execution time only.** It does not include client-side cost behind a
  WoW API call.
- **Buckets nest — never sum the column.** `within` names the declared parent; an analysis says
  whether that containment was actually **observed** in the calls, because a declared parent that
  never fired inside its child is an unverified claim rather than a measurement.
- **Empty tables encode as `{}`.** Lua has one table type, so an empty list and an empty map are
  indistinguishable to the encoder. A run with no failures emits `"failures": {}`, not `[]`.
  Non-empty lists encode as proper arrays. Treat an empty `failures` as "none" whichever bracket it
  wears.
- **Frame limiters are not recorded.** They were, briefly, and it was removed: `maxFPS` retains its
  last slider value whether or not the limiter is enabled, so the reading proved nothing (a client
  reporting `maxFPS=120` measured 200 fps). Judge a capped run from the arms instead — two arms at
  the same frame time, or at a round one like 8.33 ms, means the client was pinned and the delta is
  unusable.
