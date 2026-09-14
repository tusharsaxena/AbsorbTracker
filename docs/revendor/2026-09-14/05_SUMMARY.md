# 05 — Summary: LibKa0s v1.34.0 → v1.35.0

**This bundle was written after the fact.** The re-vendor, the stub members and the doc sync were
already on `master` (`46de577`, `8506cea`, `30ad410`, merged at `17e3ada`). The bundle was written
later on 2026-09-14 to close the gap in `docs/revendor/`. Its numbers were measured then.

## The move

| | |
|---|---|
| From | v1.34.0 (tag `9165044`, commit `33bae81`) |
| To | **v1.35.0** (tag `f99cb36`, commit `6036c26`) |
| Files that moved in `libs/LibKa0s/` | `OptionsWidgets.lua` (`WIDGETS_MINOR` 15 → 16), so Options 18.15.5.3 → 18.16.5.3 |
| Kit revision | 19 → **20** (`README.md`, `framework.lua`, `mock_base.lua`, and the new `mock_ids.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |
| Both payloads vs the tag, after the copy | `diff -r` empty, with and without `--strip-trailing-cr` |

## What reached this addon for free

Nothing visible. AbsorbTracker calls none of the new members, passes no `opts.disabled` and has no
row carrying `disabledIf`, so its panel renders as it did at 18.15.5.3. Kit 20 is opt-in here.

## What was adopted, and what was declined

Nothing was adopted. The candidates (02_CANDIDATES) were `disabledIf` on every maker, `RenderRows`
`opts.disabled`, `ChoiceGrid`, `IdInput`, `IdList`, `ResolveId`, `UnnamedCandidates` and
`ID_NAME_HINT`. None has a use here. The owner re-vendored the six non-adopting consumers without
adoption. The six new members are on the degraded Options stub, inert, by owner decision
(2026-09-14), not because anything calls them. No issue was filed and none is owed.

## Gates

Measured when this bundle was written, in a scratch clone of this repo with a `../LibKa0s` sibling
link:

| Commit | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, `9590af5` | 590 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| Re-vendor, `46de577` | 590 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| Stub members, `8506cea` | 590 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| Doc sync, `30ad410` | 590 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |

The count holds at 590 throughout. The parity case that went red on the copy (01_DELTA) is one
existing case, and each fix turned it green again without adding a case. `lizard -l lua -x
"./libs/*" -x "./tests/_kit/*" -C 15 -w .` is clean at the head. The one code change in the range,
`8506cea`, adds five straight-line assignments. `docs/test-cases.md` and the README badge (590/590)
did not need to change. Nothing was pushed by the re-vendor run itself.
