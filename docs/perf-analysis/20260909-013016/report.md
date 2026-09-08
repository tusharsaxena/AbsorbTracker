# Capture — 20260909-013016

What the client printed, copied out of the debug console after `/at perf finish`. Nothing here is
edited; the JSON record the summary was built from is beside it in [`dump.json`](dump.json).

## The report

```
01:30:06 | [Perf] capture: 2026-09-09 01:24  (AbsorbTracker, schema 2, v1.9.0)
01:30:06 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:30:06 | [Perf] where:     Silvermoon City — The Bazaar
01:30:06 | [Perf] group:     solo
01:30:06 | [Perf] active:       90.7s    6947 frames    76.6 fps   13.05 ms/frame
01:30:06 | [Perf] suspended:    65.2s    5097 frames    78.2 fps   12.79 ms/frame
01:30:06 | [Perf] delta:                                                   +0.26 ms/frame
01:30:06 | [Perf] 
01:30:06 | [Perf] bucket            calls   total ms       ms/s    max ms
01:30:06 | [Perf] absorbEvent         183       3.31      0.037     0.065
01:30:06 | [Perf] repaintPass         130       9.16      0.101     0.186
01:30:06 | [Perf]   paintBar          258       5.57      0.061     0.125
01:30:06 | [Perf]   visibility         69       0.41      0.005     0.014
01:30:06 | [Perf] (buckets nest: paintBar observed inside repaintPass, visibility declares itself within appearance — not observed — do not sum)
```

## The run log

The capture's provenance (`performance-§7`): both arms combat-gated, arm B genuinely suspended, no
`/reload` between them. Kept with the client's own `HH:MM:SS | [Tag]` prefixes.

```
01:15:02 | [Perf] run started — 2026-09-09 01:15
01:15:02 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:15:02 | [Perf] where:     Silvermoon City — The Bazaar
01:15:02 | [Perf] group:     solo
01:15:02 | [Perf] perf run STARTED — 2026-09-09 01:15
01:15:28 | [Perf] run CANCELED — measurements discarded, nothing saved
01:24:09 | [Perf] run started — 2026-09-09 01:24
01:24:09 | [Perf] who:       Sacrìlege-Frostmourne, level 90 Protection Paladin
01:24:09 | [Perf] where:     Silvermoon City — The Bazaar
01:24:09 | [Perf] group:     solo
01:24:09 | [Perf] perf run STARTED — 2026-09-09 01:24
01:26:03 | [Perf] experiment A armed (addon active) — waiting for combat
01:26:11 | [Perf] Experiment A RECORDING — combat started
01:27:42 | [Perf] Experiment A ENDED — 90.7s, 6947 frames, 76.6 fps
01:28:46 | [Perf] addon SUSPENDED — inert
01:28:46 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
01:28:55 | [Perf] Experiment B RECORDING — combat started
01:30:00 | [Perf] Experiment B ENDED — 65.2s, 5097 frames, 78.2 fps
01:30:05 | [Perf] run finished — A 90.7s / 6947 frames, B 65.2s / 5097 frames
01:30:05 | [Perf] addon RESUMED — events and frames restored
01:30:05 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```

The `01:15:02`–`01:15:28` run is a **canceled** run: it was discarded in the client and saved
nothing. It is kept here because it is part of the session's provenance — the run that this bundle
records began nine minutes later, at `01:24:09`.

Only `[Perf]` lines appear in this paste. The previous capture's log carried `[Bar]`, `[Combat]`,
`[World]` and `[Init]` narration alongside them; its absence here is consistent with debug logging
being off for this run, which is not a neutral difference — see [`ANALYSIS.md`](ANALYSIS.md).

## The dump

One line of JSON, committed verbatim in [`dump.json`](dump.json) rather than re-printed here. It was
emitted at `01:30:16`, which is the `timestamp` this bundle's directory name is derived from.
