# Raw capture transcripts — 2026-07-29

Debug-console output from the four in-game captures analysed in
[analysis.md](analysis.md). Verbatim, including the `[Combat]` and `[Bar]` lines interleaved with
`[Perf]`, because the interleaving is what makes the arms auditable after the fact.

All four: Helyâ-Frostmourne, level 90 Blood Death Knight, AbsorbTracker v1.9.0, schema v4.

| # | Environment | Addon set | A (active) | B (suspended) |
|---|-------------|-----------|-----------:|--------------:|
| 1 | Silvermoon dummies, solo | AbsorbTracker only | 220.7 fps | 223.5 fps |
| 2 | Silvermoon dummies, solo | All addons | 117.0 fps | 111.9 fps |
| 3 | Nexus-Point Xenas, party of 5 | AbsorbTracker only | 135.6 fps | 137.5 fps |
| 4 | Nexus-Point Xenas, party of 5 | All addons | 66.8 fps | 68.0 fps |

---

## 1. Only AbsorbTracker — Silvermoon training dummies

```
19:15:12 | [Debug] logging enabled
19:15:12 | [Init] AbsorbTracker v1.9.0, schema v4, profile 'SmokeTest 2026-07-29'
19:15:53 | [Perf] experiment A armed (addon active) — waiting for combat
19:15:58 | [Bar] target: shown (always)
19:16:02 | [Combat] entered
19:16:02 | [Perf] Experiment A RECORDING — combat started
19:17:15 | [Combat] left: 65 events, 47 repaints
19:17:15 | [Perf] Experiment A ENDED — 72.5s, 16007 frames, 220.7 fps
19:17:23 | [Perf] addon SUSPENDED — inert, bars hidden, events unregistered
19:17:23 | [Bar] player: hidden (perf suspended)
19:17:23 | [Bar] target: hidden (perf suspended)
19:17:23 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
19:17:28 | [Perf] Experiment B RECORDING — combat started
19:18:34 | [Perf] Experiment B ENDED — 66.1s, 14771 frames, 223.5 fps
19:18:41 | [Perf] run finished — A 72.5s / 16007 frames, B 66.1s / 14771 frames
19:18:41 | [Perf] capture: 2026-07-29 19:15 testing dummies solo  (schema 1, v1.9.0)
19:18:41 | [Perf] who:       Helyâ-Frostmourne, level 90 Blood Death Knight
19:18:41 | [Perf] where:     Silvermoon City — Falconwing Square
19:18:41 | [Perf] group:     solo
19:18:41 | [Perf] active:       72.5s   16007 frames   220.7 fps    4.53 ms/frame
19:18:41 | [Perf] suspended:    66.1s   14771 frames   223.5 fps    4.47 ms/frame
19:18:41 | [Perf] delta:                                                   +0.06 ms/frame
19:18:41 | [Perf]
19:18:41 | [Perf] bucket            calls   total ms       ms/s    max ms
19:18:41 | [Perf] absorbEvent          65       2.36      0.033     0.118
19:18:41 | [Perf] repaintPass          47       2.67      0.037     0.119
19:18:41 | [Perf] paintBar             94       1.44      0.020     0.086
19:18:41 | [Perf] visibility            3       0.02      0.000     0.010
19:18:41 | [Perf] (buckets nest: repaintPass contains paintBar — do not sum)
19:18:41 | [Perf] perf run FINISHED — saved; `/reload` to flush it to SavedVariables
19:18:41 | [Perf] addon RESUMED — events and bars restored
19:18:41 | [Bar] player: shown (always)
19:18:41 | [Bar] target: shown (always)
```

---

## 2. All addons — Silvermoon training dummies

```
19:20:45 | [Debug] logging enabled
19:20:45 | [Init] AbsorbTracker v1.9.0, schema v4, profile 'SmokeTest 2026-07-29'
19:20:56 | [Perf] experiment A armed (addon active) — waiting for combat
19:21:00 | [Bar] target: shown (always)
19:21:02 | [Combat] entered
19:21:02 | [Perf] Experiment A RECORDING — combat started
19:22:10 | [Combat] left: 58 events, 49 repaints
19:22:10 | [Perf] Experiment A ENDED — 68.6s, 8035 frames, 117.0 fps
19:22:17 | [Perf] addon SUSPENDED — inert, bars hidden, events unregistered
19:22:17 | [Bar] player: hidden (perf suspended)
19:22:17 | [Bar] target: hidden (perf suspended)
19:22:17 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
19:22:22 | [Perf] Experiment B RECORDING — combat started
19:23:38 | [Perf] Experiment B ENDED — 76.0s, 8509 frames, 111.9 fps
19:23:46 | [Perf] run finished — A 68.6s / 8035 frames, B 76.0s / 8509 frames
19:23:46 | [Perf] capture: 2026-07-29 19:20 silvermoon training dummies ALL ADDONS  (schema 1, v1.9.0)
19:23:46 | [Perf] who:       Helyâ-Frostmourne, level 90 Blood Death Knight
19:23:46 | [Perf] where:     Silvermoon City — Falconwing Square
19:23:46 | [Perf] group:     solo
19:23:46 | [Perf] active:       68.6s    8035 frames   117.0 fps    8.54 ms/frame
19:23:46 | [Perf] suspended:    76.0s    8509 frames   111.9 fps    8.93 ms/frame
19:23:46 | [Perf] delta:                                                   -0.39 ms/frame
19:23:46 | [Perf]
19:23:46 | [Perf] bucket            calls   total ms       ms/s    max ms
19:23:46 | [Perf] absorbEvent          58       2.15      0.031     0.070
19:23:46 | [Perf] repaintPass          49       2.59      0.038     0.096
19:23:46 | [Perf] paintBar             98       1.44      0.021     0.059
19:23:46 | [Perf] visibility            3       0.02      0.000     0.008
19:23:46 | [Perf] (buckets nest: repaintPass contains paintBar — do not sum)
19:23:46 | [Perf] perf run FINISHED — saved; `/reload` to flush it to SavedVariables
19:23:46 | [Perf] addon RESUMED — events and bars restored
19:23:46 | [Bar] player: shown (always)
19:23:46 | [Bar] target: shown (always)
```

---

## 3. Only AbsorbTracker — Nexus-Point Xenas, first pull

```
19:34:47 | [Perf] run started — 2026-07-29 19:34
19:34:47 | [Perf] who:       Helyâ-Frostmourne, level 90 Blood Death Knight
19:34:47 | [Perf] where:     Nexus-Point Xenas
19:34:47 | [Perf] group:     party (5) / party
19:34:47 | [Perf] perf run STARTED — 2026-07-29 19:34
19:34:48 | [Debug] logging enabled
19:34:48 | [Init] AbsorbTracker v1.9.0, schema v4, profile 'SmokeTest 2026-07-29'
19:35:11 | [Perf] experiment A armed (addon active) — waiting for combat
19:35:16 | [Bar] target: shown (always)
19:35:17 | [Combat] entered
19:35:17 | [Perf] Experiment A RECORDING — combat started
19:36:04 | [Bar] target: hidden (no unit)
19:36:04 | [Bar] target: shown (always)
19:36:23 | [Bar] target: hidden (no unit)
19:36:24 | [Combat] left: 146 events, 121 repaints
19:36:24 | [Perf] Experiment A ENDED — 67.2s, 9105 frames, 135.6 fps
19:36:27 | [Bar] target: shown (always)
19:36:28 | [Bar] target: hidden (no unit)
19:36:44 | [World] entering world
19:37:01 | [World] entering world
19:37:07 | [Perf] addon SUSPENDED — inert, bars hidden, events unregistered
19:37:07 | [Bar] player: hidden (perf suspended)
19:37:07 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
19:37:22 | [Perf] Experiment B RECORDING — combat started
19:38:40 | [Perf] Experiment B ENDED — 78.2s, 10750 frames, 137.5 fps
19:38:54 | [Perf] run finished — A 67.2s / 9105 frames, B 78.2s / 10750 frames
19:38:54 | [Perf] addon RESUMED — events and bars restored
19:38:54 | [Bar] player: shown (always)
19:38:54 | [Perf] capture: 2026-07-29 19:34  (schema 1, v1.9.0)
19:38:54 | [Perf] who:       Helyâ-Frostmourne, level 90 Blood Death Knight
19:38:54 | [Perf] where:     Nexus-Point Xenas
19:38:54 | [Perf] group:     party (5) / party
19:38:54 | [Perf] active:       67.2s    9105 frames   135.6 fps    7.38 ms/frame
19:38:54 | [Perf] suspended:    78.2s   10750 frames   137.5 fps    7.27 ms/frame
19:38:54 | [Perf] delta:                                                   +0.10 ms/frame
19:38:54 | [Perf]
19:38:54 | [Perf] bucket            calls   total ms       ms/s    max ms
19:38:54 | [Perf] absorbEvent         168       5.55      0.083     0.083
19:38:54 | [Perf] repaintPass         121       7.07      0.105     0.125
19:38:54 | [Perf] paintBar            241       3.85      0.057     0.086
19:38:54 | [Perf] visibility           66       0.63      0.009     0.141
19:38:54 | [Perf] (buckets nest: repaintPass contains paintBar — do not sum)
19:38:54 | [Perf] perf run FINISHED — saved; `/reload` to flush it to SavedVariables
```

---

## 4. All addons — Nexus-Point Xenas, first pull

```
19:40:55 | [Perf] run started — 2026-07-29 19:40
19:40:55 | [Perf] who:       Helyâ-Frostmourne, level 90 Blood Death Knight
19:40:55 | [Perf] where:     Nexus-Point Xenas
19:40:55 | [Perf] group:     party (5) / party
19:40:55 | [Perf] perf run STARTED — 2026-07-29 19:40
19:40:59 | [Debug] logging enabled
19:40:59 | [Init] AbsorbTracker v1.9.0, schema v4, profile 'SmokeTest 2026-07-29'
19:41:10 | [Perf] experiment A armed (addon active) — waiting for combat
19:41:19 | [Bar] target: shown (always)
19:41:20 | [Combat] entered
19:41:20 | [Perf] Experiment A RECORDING — combat started
19:41:58 | [Bar] target: hidden (no unit)
19:41:58 | [Bar] target: shown (always)
19:42:18 | [Bar] target: hidden (no unit)
19:42:18 | [Bar] target: shown (always)
19:42:22 | [Bar] target: hidden (no unit)
19:42:22 | [Combat] left: 141 events, 126 repaints
19:42:22 | [Perf] Experiment A ENDED — 62.2s, 4152 frames, 66.8 fps
19:42:23 | [Bar] target: shown (always)
19:42:24 | [Bar] target: hidden (no unit)
19:42:39 | [World] entering world
19:43:22 | [World] entering world
19:43:29 | [Perf] addon SUSPENDED — inert, bars hidden, events unregistered
19:43:29 | [Bar] player: hidden (perf suspended)
19:43:29 | [Perf] experiment B armed (addon SUSPENDED) — waiting for combat
19:43:45 | [Perf] Experiment B RECORDING — combat started
19:44:55 | [Perf] Experiment B ENDED — 70.2s, 4775 frames, 68.0 fps
19:45:18 | [Perf] run finished — A 62.2s / 4152 frames, B 70.2s / 4775 frames
19:45:18 | [Perf] addon RESUMED — events and bars restored
19:45:18 | [Bar] player: shown (always)
19:45:18 | [Perf] capture: 2026-07-29 19:40  (schema 1, v1.9.0)
19:45:18 | [Perf] who:       Helyâ-Frostmourne, level 90 Blood Death Knight
19:45:18 | [Perf] where:     Nexus-Point Xenas
19:45:18 | [Perf] group:     party (5) / party
19:45:18 | [Perf] active:       62.2s    4152 frames    66.8 fps   14.97 ms/frame
19:45:18 | [Perf] suspended:    70.2s    4775 frames   68.0 fps   14.71 ms/frame
19:45:18 | [Perf] delta:                                                   +0.26 ms/frame
19:45:18 | [Perf]
19:45:18 | [Perf] bucket            calls   total ms       ms/s    max ms
19:45:18 | [Perf] absorbEvent         184       5.29      0.085     0.076
19:45:18 | [Perf] repaintPass         126       6.93      0.111     0.132
19:45:18 | [Perf] paintBar            250       3.87      0.062     0.081
19:45:18 | [Perf] visibility           63       0.73      0.012     0.095
19:45:18 | [Perf] (buckets nest: repaintPass contains paintBar — do not sum)
19:45:18 | [Perf] perf run FINISHED — saved; `/reload` to flush it to SavedVariables
```

## A note on the event counts

The `[Combat]` rollup and the `absorbEvent` bucket disagree in runs 3 and 4 — 146 against 168, and
141 against 184. That is not an inconsistency. The rollup counts the **player's** absorb events only
(by design, see `core/AbsorbTracker.lua`), while the bucket counts every tracked unit. Runs 1 and 2
match exactly because nothing but the player had absorbs at a training dummy.
