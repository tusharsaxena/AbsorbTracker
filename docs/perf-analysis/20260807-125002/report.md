# Capture — 20260807-125002

What the client printed, copied out of the debug console after `/at perf report` and `/at perf dump`.
Nothing here is edited: the `HH:MM:SS | [Tag] ` prefixes are the capture's own clock, and the gaps
between lines are facts about the run.

## The report

```
12:50:01 | [Perf] capture: 2026-08-07 12:47  (AbsorbTracker, schema 2, v1.9.0)
12:50:01 | [Perf] who:       Lânfear-Frostmourne, level 90 Destruction Warlock
12:50:01 | [Perf] where:     Murder Row
12:50:01 | [Perf] group:     party (5) / party
12:50:01 | [Perf] active:       26.6s    1606 frames    60.4 fps   16.56 ms/frame
12:50:01 | [Perf] suspended:    21.5s    1287 frames    59.7 fps   16.74 ms/frame
12:50:01 | [Perf] delta:                                                   -0.18 ms/frame
12:50:01 | [Perf] 
12:50:01 | [Perf] bucket            calls   total ms       ms/s    max ms
12:50:01 | [Perf] absorbEvent          86       4.53      0.170     0.075
12:50:01 | [Perf] repaintPass          72       4.29      0.161     0.092
12:50:01 | [Perf]   paintBar          143       2.40      0.090     0.045
12:50:01 | [Perf]   visibility         21       0.24      0.009     0.091
12:50:01 | [Perf] (buckets nest: paintBar declares itself within repaintPass — not observed, visibility declares itself within appearance — not observed — do not sum)
```

## The run log

The capture's provenance. This is how a later reader confirms both arms opened and closed on the
player's combat state, that arm B really was suspended, and what happened between the arms
(`performance-§7`).

```
12:47:54 | [Perf] run started — 2026-08-07 12:47
12:47:54 | [Perf] who:       Lânfear-Frostmourne, level 90 Destruction Warlock
12:47:54 | [Perf] where:     Murder Row
12:47:54 | [Perf] group:     party (5) / party
12:47:54 | [Perf] perf run STARTED — 2026-08-07 12:47
12:47:59 | [Debug] logging enabled
12:47:59 | [Init] AbsorbTracker v1.9.0, schema v4, profile 'Default'
12:48:01 | [Perf] experiment A armed (addon active) — waiting for combat
12:48:06 | [Combat] entered
12:48:06 | [Perf] Experiment A RECORDING — combat started
12:48:32 | [Bar] target: hidden (no unit)
12:48:32 | [Combat] left: 86 events, 72 repaints
12:48:32 | [Perf] Experiment A ENDED — 26.6s, 1606 frames, 60.4 fps
12:48:51 | [World] entering world
12:49:11 | [World] entering world
12:49:30 | [Perf] addon SUSPENDED — inert
12:49:30 | [Bar] player: hidden (perf suspended)
12:49:30 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
12:49:34 | [Perf] Experiment B RECORDING — combat started
12:49:56 | [Perf] Experiment B ENDED — 21.5s, 1287 frames, 59.7 fps
12:50:00 | [Perf] run finished — A 26.6s / 1606 frames, B 21.5s / 1287 frames
12:50:00 | [Perf] addon RESUMED — events and frames restored
12:50:00 | [Bar] player: shown (always)
12:50:00 | [Perf] perf run FINISHED — saved; `Report` or `Dump` in the panel to read it, `/reload` to flush it to SavedVariables
```

## The dump

One line of JSON, committed verbatim beside this file as [`dump.json`](dump.json).

```
12:50:02 | [Perf] {"addon":"AbsorbTracker","buckets":{"absorbEvent":{"calls":86,"maxMs":0.0752,"totalMs":4.5313},"paintBar":{"calls":143,"maxMs":0.0454,"totalMs":2.4014,"within":"repaintPass"},"repaintPass":{"calls":72,"maxMs":0.0919,"totalMs":4.2879},"visibility":{"calls":21,"maxMs":0.0915,"totalMs":0.2388,"within":"appearance"}},"context":{"character":"Lânfear","class":"Warlock","group":"party (5) / party","level":90,"realm":"Frostmourne","spec":"Destruction","subZone":"","zone":"Murder Row"},"fps":{"active":{"avgFps":60.3737,"frames":1606,"msPerFrame":16.5635,"seconds":26.6010},"deltaMsPerFrame":-0.1777,"suspended":{"avgFps":59.7327,"frames":1287,"msPerFrame":16.7413,"seconds":21.5460}},"interface":120007,"label":"2026-08-07 12:47","schema":2,"source":"ingame","timestamp":1786087202,"version":"1.9.0"}
```
