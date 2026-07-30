# Extraction parity — 2026-07-30

Did moving the performance harness into `LibKa0s-Perf-1.0` change what it measures? The rollout gate
(spec §Rollout step 2) says an extraction that changes the measurements is a bug in the extraction,
so this note is the evidence that it did not.

Record: [`docs/perf-runs/2026-07-30-ingame-post-extraction.json`](../../perf-runs/2026-07-30-ingame-post-extraction.json).
Baseline: capture 1 of [`2026-07-29-combat-fps-drop/raw-captures.md`](../2026-07-29-combat-fps-drop/raw-captures.md)
— the only pre-extraction in-game run with AbsorbTracker as the sole addon.

## Verdict: parity holds

Call counts scale with the fight, so the comparable quantities are the **rates** and the **structural
ratios** — those are properties of the code, not of the pull.

| | pre-extraction | post-extraction |
|---|---|---|
| where | Silvermoon dummies, solo, 72.5 s | Falconwing Square, solo, 40.0 s |
| `repaintPass` ms/s | 0.037 | 0.036 |
| `paintBar` ms/s | 0.020 | 0.020 |
| `paintBar` calls per `repaintPass` | 94 / 47 = 2.0 | 48 / 24 = 2.0 |
| `repaintPass` ms per call | 0.0568 | 0.0604 |
| `paintBar` ms per call | 0.0153 | 0.0169 |

Two bars painted per coalesced pass, same per-call cost inside noise, same rate per second of combat.

Two further independent checks, both from the extraction commits rather than from this capture:

- The bracket call sites in `core/AbsorbTracker.lua`, `modules/Display.lua` and `modules/Timer.lua`
  are unchanged across the whole branch — `git diff 1d37a96 HEAD` over those three files yields zero
  non-comment lines.
- The offline runner's allocation figures are identical to the digit: `probeOverhead` 312.0 bytes per
  iteration with capture off, 312.3 with it on, and `appearancePass` 901.9 — the same numbers a
  worktree at the pre-extraction commit produces.

## The delta in this capture is noise, not a result

`deltaMsPerFrame` reads **−1.18 ms/frame**: the suspended arm was *slower* (120.3 fps) than the
active one (140.2 fps). Suspending the addon cannot cost frames, so the sign alone says the arms
differed by something other than the addon.

The bucket totals bound how large a real effect could be. `repaintPass` accrued 1.45 ms across 40 s
of combat — 0.036 ms/s, or about **0.00026 ms/frame** at 140 fps. The measured delta is roughly four
thousand times larger than the addon's entire accounted cost. It is describing Falconwing Square:
other players, camera, and whatever else moved between 16:12 and 16:13.

This is the same failure the July 14 investigation ran into from the other direction, and the reason
the windows are combat-gated in the first place. Combat gating makes the arms *equal in duration*; it
cannot make them equal in *environment*. A city square with live players in it is not a repeatable
arm.

**For a delta that means something:** same training dummies for both arms, back to back, 60 s+ each,
somewhere without other players. Capture 1 managed +0.06 ms/frame under those conditions, which is
the honest shape of this addon's cost — indistinguishable from zero.

The trustworthy figure from this run is the bucket column: **~0.04 ms per second of combat**, all
paths combined.

## Known-wrong field: `interface`

The record carries `"interface":0` where the TOC says `120007`. This is **pre-existing, not a
regression** — the library's accessor is semantically identical to the `NS.Compat.GetAddOnMetadata`
path it replaced (same API, same addon name, same fallback chain), so the field has read 0 for every
in-game capture ever taken. The cause is that WoW's `GetAddOnMetadata` does not expose the
`Interface` TOC field at all.

Left as-is here because reproducing the old behaviour faithfully is what the parity gate asked for.
Worth fixing in the library before rollout step 5 widens the number of emitters — `select(4,
GetBuildInfo())` gives the client's interface version, which is the more useful number when reading a
capture months later anyway.

## Buckets absent from the report

`appearance` does not appear. That is correct: `NS.UpdateBarAppearance` runs off the APPEARANCE bus
message (a settings change), not off anything combat does, and `FormatReport` omits buckets that
never fired. The nesting footer likewise lists only the two nested buckets present in the record.
The addon's integration suite drives all five declared buckets explicitly, so coverage does not
depend on a fight happening to touch them.
