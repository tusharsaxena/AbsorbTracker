# 06 — Refresh 2 (AbsorbTracker)

LibKa0s v1.84.0 was re-cut locally again before its release was pushed (`git ls-remote --tags origin
v1.84.0` prints nothing), so this is a refresh under the same tag and no new bundle. `01_DELTA.md` stays
as it is.

- Old commit: `7a8bc0f133ed118d2c79c7c5288b97964e24fae5` (`06_REFRESH_1.md`).
- New commit: `b5229b876e803768322fb4d8c66be69f01c8e4a1` (`git -C ../LibKa0s rev-parse 'v1.84.0^{commit}'`).
- What moved: LK-M4, the owner's ruling of 2026-11-01 that `lib.__PatchLSM30Border` is deleted with no
  stub. The test kit did not move and stays at revision 47.

## Per-file minors, old commit to new

| File | Constant | Old | New |
|---|---|---:|---:|
| `Options.lua` | `MINOR` | 36 | 37 |
| `OptionsDrawer.lua` | `DRAWER_MINOR` | 3 | 4 |
| `OptionsMedia.lua` | `MEDIA_MINOR` | 2 | 3 |

## What the consumer owed

Nothing. The tag `CHANGELOG.md` asks a consumer to move a test calling `__PatchLSM30Border`, and this
addon has none left: refresh 1 removed the wrap case. The authored Lua, the tests and the living docs
hold no reference to the member, by
`grep -rn '__PatchLSM30Border' . --exclude-dir=.git --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=revendor`,
which prints nothing. The frozen bundles keep theirs. No test pins an `Options.lua` minor, and no new
stub or guard was added.

## Icons

`LibKa0s icons: clear, close, copy, help, settings.` is kept. The prune kept 6 files and removed 5,834,
all of them restored by the copy a moment earlier, so git shows no icon change.

## Gate

974 passed, 0 failed, 1 skipped, and `luacheck` at 0 warnings / 0 errors in 80 files.
