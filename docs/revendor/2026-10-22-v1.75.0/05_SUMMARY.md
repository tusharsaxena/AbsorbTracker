# 05 — Summary: LibKa0s v1.71.0 -> v1.75.0

Run 2026-10-22, plan item AT-RV, on branch `feat/2026-10-22-libka0s-issues-45-58`. The addon version
was not bumped, the TOC is unchanged, no issue was filed, and `libs/` and `tests/_kit/` were not
touched after the copy and the declaration-driven prune.

## The move

The vendored LibKa0s moved from **v1.71.0** to **v1.75.0** (local tag, commit `265a89e`), carrying
the never-vendored v1.72.0, v1.73.0 and v1.74.0 with it. Two majors arrive (Glow, Sim) and the
library is seventeen majors across forty files; nothing here consumes the new ones. The kit moves
from revision **38 to 41** and gains `latch.lua`. Nothing was deleted on inference.

## The icon subset

`CLAUDE.md` now carries, directly under the provenance line:

`LibKa0s icons: clear, close, copy, help.`

`tools/prune-icons.lua` at the tag kept those four Open Iconic marks and `LICENSE-open-iconic.txt`
and removed 5,835 files, including the whole `phosphor/` and `game-icons/` sets. The README's
`## Credits` now names exactly what ships: JetBrains Mono (SIL OFL 1.1) and Open Iconic (MIT), with
the license file path.

## Contract blockers (3g), fixed in the copy commit

- `O.Drawer` (OptionsDrawer 1): exempt in `tests/test_surface_parity.lua`'s Options parity case
  (no caller here).
- The two whole-catalog icon cases are rewritten to the declaration
  (`tests/test_mediasetup.lua`, `tests/test_optionssetup.lua`), reading it through the kit's parser.
- Kit 39's `__fireUnconditional`: `tests/test_disabled.lua` stays green, no change.
- No dead `O.__releaseChrome` mirror exists here.

## Also in the copy commit

- `docs/module-map.md`: the `tests/_kit/` row (revision 41, re-measured line counts, `latch.lua`,
  the icon gate, the `crashed` bucket) and the `libs/LibKa0s/` row and load-order paragraph
  (seventeen majors, the new files, the regenerated XML order, the four shipped icons).
- `docs/testing.md` and `DEPENDENCIES.md`: the prune step and the expected `Only in .../media/icons`
  lines; `DEPENDENCIES.md`'s kit line citations re-pointed to the revision-41 lines.
- `docs/test-cases.md` regenerated (two renamed cases); Total 885, equal to the README badge.

## Adopted, declined, unreached

- **Adopted**: none.
- **Not adopted in this run**: `Perf.Note` `parentKey = false`, `Kit.assertLatchHoldOrder`, `O.Drawer`,
  `W.SearchBox`, `W.TestStrip`, `Item.BonusIDsFromLink`, `LibKa0s-Glow-1.0`, `LibKa0s-Sim-1.0`
  (see `02_CANDIDATES.md`). `W.StepPanel` is not in the payload.

## Gates on the copy commit

All run through `ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 70 files |
| `lua tests/run.lua` (Lua 5.1.5) | 885 passed, 0 failed, 1 skipped, 886 total (the skip is the declared diagnostics opt-out case) |
| `tests/test_vendor_sync.lua` | 3 of 3 pass against the v1.75.0 payload and the declaration |
| vendor parity | kit `diff -r --strip-trailing-cr` empty; library diff empty apart from the pruned `media/icons` lines |
| line cap | largest authored `.lua` file 1079 lines (`tests/test_slashcmds.lua`) |

## In-game smoke (owner; not run here)

- SM-AT-1: `/console scriptErrors 1`, then `/reload` twice: no Lua error and no LibKa0s minor-mismatch line.
- SM-AT-2: `/at debug`: the console's close X, COPY and CLEAR marks draw as art; Copy opens a window
  whose close X draws.
- SM-AT-3: the perf step panel's close X draws and closes it.
- SM-AT-4: `/at unlock`: each bar's drag handle shows the ? and X marks; tooltips show; X turns that
  bar off. `/at lock` afterwards.
- SM-AT-5: `/at config`: every page and tab renders as before, with no blank icon.
