# 06 — Refresh 1 (AbsorbTracker)

LibKa0s v1.84.0 was re-cut locally before its release was pushed (`git ls-remote --tags origin v1.84.0`
prints nothing), so this is a refresh under the same tag and no new bundle. `01_DELTA.md` stays as it is.

- Old commit: `e917ccd` (`git -C ../LibKa0s rev-parse` at the re-vendor, `05_SUMMARY.md` line 9).
- New commit: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` (`git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'`).
- What moved: LK-M3, the owner's ruling of 2026-11-01 that `Ka0sMedia_*` is the only media picker
  (LibKa0s#73). The test kit did not move.

## Per-file minors, old commit to new

| File | Constant | Old | New |
|---|---|---:|---:|
| `Options.lua` | `MINOR` | 35 | 36 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 15 | 16 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 1 | 2 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 9 | 10 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 40 | 41 |
| `SkinAce.lua` | `ACE_MINOR` | 5 | 6 |

## What the consumer owed

The tag `CHANGELOG.md`, *One media picker*: a test pinning `LSM30_*` on a composed row or expecting
`__PatchLSM30Border` to wrap moves. Three cases went red on the copy and moved in the refresh commit:
two in `tests/test_widgets.lua` were rewritten for the picker, and the wrap case in
`tests/test_optionssetup.lua` is gone, because the member is a no-op that answers false.

## Icons

`LibKa0s icons: clear, close, copy, help, settings.` is kept. The prune kept 6 files and removed 5,834,
all of them restored by the copy a moment earlier, so git shows no icon change.

## Gate

Before the test moves: 970 passed, 3 failed, 1 skipped. After them: 972 passed, 0 failed, 1 skipped, and
`luacheck` at 0 warnings / 0 errors in 80 files. The test count drops by one, so the README badge moves
to 972/972.
