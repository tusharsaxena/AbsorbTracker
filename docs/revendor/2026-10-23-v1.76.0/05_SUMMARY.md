# 05 — Summary: LibKa0s v1.75.2 -> v1.76.0

Run 2026-10-23, plan item AT-RV, on branch `feat/2026-10-23-sim-preview-mode-strips`. The addon
version was not bumped, the TOC is unchanged, no issue was filed, and `libs/` and `tests/_kit/` were
not touched after the copy and the declaration-driven prune.

## The move

The vendored LibKa0s moved from **v1.75.2** (the base the provenance line named) to **v1.76.0** (local
tag, commit `9949368`). Three files move: `Widgets.lua` 13 -> 14, `SimTimeline.lua` 2 -> 3 and
`SimPanel.lua` 4 -> 5. Still seventeen majors across forty files; the kit stays at revision **41**.
Nothing was deleted on inference.

## Span bundle

`docs/revendor/2026-10-23-v1.75.1-v1.75.2/` records the two tags vendored on 2026-10-23 without a
bundle (v1.75.1, v1.75.2). No base correction was owed (Step 0 agrees).

## Reached the addon for free

Nothing visible: Sim is not consumed, and Widgets 14 draws every existing call as 13 did.

## Contract blockers (3g)

None. Widgets 14 is additive (`opts.kind`, `strip.kind`); the members this addon reaches
(`DragHandle`, `DRAG_HANDLE`, `CopyWindow`) are unchanged, and no host string overrides the removed
`RUN_ALL`.

## The icon subset

`LibKa0s icons: clear, close, copy, help.` is kept. `tools/prune-icons.lua` at the tag kept those four
Open Iconic marks and `LICENSE-open-iconic.txt` (5 files) and removed 5,835. The README's
`## Credits` is unchanged (still JetBrains Mono and Open Iconic). No dead stub mirror exists.

## Adopted, declined, unreached

- **Adopted**: none.
- **Not adopted in this run**: `W.TestStrip` `kind = "sim"`, `LibKa0s-Sim-1.0` (see
  `02_CANDIDATES.md`).

## Gates on the copy commit

All run through `ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 70 files |
| `lua tests/run.lua` (Lua 5.1.5) | 885 passed, 0 failed, 1 skipped, 886 total (the skip is the declared diagnostics opt-out case) |
| `tests/test_vendor_sync.lua` | 3 of 3 pass against the v1.76.0 payload and the declaration |
| vendor parity | kit diff empty; library diff empty apart from the pruned `media/icons` lines |
| line cap | largest authored `.lua` file 1079 lines (`tests/test_slashcmds.lua`) |

## In-game smoke (owner; not run here)

- `/console scriptErrors 1`, then `/reload` twice: no Lua error and no LibKa0s minor-mismatch line.
- `/at unlock`: each bar's drag handle still shows its ? and X marks. `/at lock` afterwards.
