# Performance run records

Captured measurements from both harnesses. See [docs/performance.md](../performance.md) for how to
produce them.

This directory is standing and cumulative rather than tied to one investigation, so runs can be
compared across addon versions. Records are committed — the raw evidence should outlive the
write-up that interprets it.

## Naming

```
<YYYY-MM-DD>-<source>-<label>.json
```

`source` is `offline` or `ingame`. Examples:

- `2026-07-29-offline-baseline.json`
- `2026-07-29-ingame-dummy-blooddk.json`

## Schema

One shape for both sources, so a single reader handles either. `schema` is the version stamp;
increment it on any breaking field change.

```jsonc
{
  "schema": 1,
  "source": "offline" | "ingame",
  "version": "1.9.0",          // addon version
  "interface": 120007,          // TOC interface; 0 for offline runs
  "timestamp": 1785110400,      // epoch seconds
  "label": "baseline-v1.9.0",

  // Who / where / what, captured once at the start of an in-game run. Absent for offline runs.
  "context": {
    "character": "Kaosdk", "realm": "Silvermoon", "level": 80,
    "class": "Death Knight", "spec": "Blood",
    "zone": "Nexus-Point Xenas", "subZone": "The Approach",
    "group": "party (5) / party"
  },

  // Per-bucket totals. In-game buckets are the probe's brackets; offline buckets are the
  // runner's scenarios. THESE NEST — repaintPass contains paintBar. Never sum the column.
  "buckets": {
    "paintBar": {
      "calls": 1869,
      "totalMs": 98.1,
      "maxMs": 0.92,
      "apiPerIter": 12.0,       // offline only
      "bytesPerIter": 312.0     // offline only
    }
  },

  // Frame sampling. Offline runs carry the fixed zeroed shape (no frames to sample).
  "fps": {
    "active":    { "seconds": 62.3, "frames": 4821, "avgFps": 77.4, "msPerFrame": 12.92 },
    "suspended": { "seconds": 60.1, "frames": 5903, "avgFps": 98.2, "msPerFrame": 10.18 },
    "deltaMsPerFrame": 2.74
  },

  // Offline only.
  "coalescing": { "events": 1000, "repaints": 1 },
  "failures": []
}
```

Object keys are emitted in sorted order so two records diff cleanly.

One encoding wart worth knowing: Lua has a single table type, so an **empty** list and an empty map
are indistinguishable to the encoder and both come out as `{}`. A run with no failures therefore
emits `"failures": {}`, not `[]`. Non-empty lists encode as proper arrays. Treat an empty `failures`
as "none" regardless of which bracket it wears.

## Field notes

- **`fps.deltaMsPerFrame`** is the number the whole in-game harness exists to produce: the per-frame
  cost of the addon being active, with load order and shared-frame ownership held fixed by suspend
  rather than by disabling the addon. It is reported as `0` unless **both** arms were sampled —
  with one arm empty a subtraction would report the entire frame time as the addon's cost.
- **`buckets[*].totalMs`** is Lua execution time only. Under the offline mock every WoW API call is
  a no-op, so offline timings exclude all client-side cost by construction.
- **`buckets[*].bytesPerIter`** (offline) is garbage produced per iteration, isolated by a full
  collect either side. Allocation in a path that runs at combat frequency matters more than its
  wall time.
- **`interface`** is `0` for offline runs — there is no client involved.
- **Frame limiters are not recorded.** They were, briefly, and it was removed: `maxFPS` retains its
  last slider value whether or not the limiter is enabled, so the reading proved nothing (a client
  reporting `maxFPS=120` measured 200 fps). Judge a capped run from the arms — two arms at the same
  frame time, or at a round one like 8.33 ms, means the client was pinned and the delta is unusable.

## Reading captures off disk

In-game runs persist to the `AbsorbTrackerPerfDB` global — a ring of the last 10 — inside the
addon's SavedVariables file:

```
_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua
```

Note the filename: WoW names the file after the **addon**, not after the saved-variable globals it
declares, so both `AbsorbTrackerDB` and `AbsorbTrackerPerfDB` live in `AbsorbTracker.lua`.

The perf ring is deliberately a separate top-level global rather than part of the AceDB tree, so it
is never copied by "copy profile", wiped by "reset profile", or swapped out by a profile switch.
