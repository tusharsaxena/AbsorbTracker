# 01 — Delta: LibKa0s v1.33.0 → v1.34.0

Recorded before anything was copied. Every finding carries the command that produced it. The
payload was extracted from the tag, not from the sibling's working tree:

```sh
git -C ../LibKa0s rev-parse v1.34.0 'v1.34.0^{commit}'
# 916504409cb3508bd71af77c1b1a70a00bcd249c   (tag object)
# 33bae81ecf6de8e8d196ea87663882aceb140945   (commit)
git -C ../LibKa0s archive v1.34.0 LibKa0s testkit | tar -x -C <scratch>/
```

The tag is local to `../LibKa0s` (branch `feat/2026-09-13-v1.34.0`). `tests/test_vendor_sync.lua`
compares against the sibling at the tag `CLAUDE.md` names, so a local tag is enough.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.33.0 (MIT).
```

## 3b. Actual version

Options 17, OptionsCompose 4 and Slash 9, with every other file at the minor v1.33.0 shipped. The
claim and the bytes agree.

## 3c. Per-file minor delta

| File | Constant | Old | Tag |
|---|---|---|---|
| `Options.lua` | `MINOR` | 17 | **18** |
| `OptionsCompose.lua` | `_MINOR` | 4 | **5** |
| `Slash.lua` | `MINOR` | 9 | **10** |
| every other shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |
| `testkit/framework.lua` | `Kit.VERSION` | 18 | **19** |

This matches the v1.34.0 block of `CHANGELOG.md` at the tag. No file is behind after the copy, so
there is no cross-major skew.

## 3d. What moved, and both diffs

```sh
git -C ../LibKa0s diff --name-status v1.33.0 v1.34.0 -- LibKa0s testkit
# M LibKa0s/Options.lua   M LibKa0s/OptionsCompose.lua   M LibKa0s/Slash.lua
# M testkit/README.md     M testkit/framework.lua        M testkit/mock_base.lua
```

No additions or deletions. The copy was `rsync -rt --delete` of both folders from the extracted
archive, which is CRLF and byte-identical to the sibling checkout. After it:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s   # (empty)
diff -r                     ../LibKa0s/LibKa0s libs/LibKa0s   # (empty)
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit     # (empty)
diff -r                     ../LibKa0s/testkit tests/_kit     # (empty)
git ls-files -s tests/_kit/run-automated-tests.sh             # 100755
```

## 3e. Consumption map

`Options` is looked up at `settings/OptionsSetup.lua:45`; its descriptor supplies `resetProfile`
at `:93`, and `settings/General.lua:88` draws the Master controls through `H.MasterControls`, the
composer whose Reset-all tooltip moved. `Slash` is looked up at `settings/Slash.lua:24` and
`settings/Schema.lua:313`. All three files that moved are consumed.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION` goes from 18 to **19**. Both payloads were copied whole in one commit, so the
pairing rule holds by construction.

Kit 19's one behavioural change is the AceDB fake's `OnProfileReset`, which now fires with the
database alone. This harness runs on the kit's AceDB, and the reset handler
(`core/AbsorbTracker.lua:283`) takes no parameters and names the profile from
`NS.db:GetCurrentProfile()`, so no case can see the difference.

## Upstream range

```sh
git -C ../LibKa0s log --oneline v1.33.0..v1.34.0
# 33bae81 v1.34.0: release test record 20260913-002423
# b9d64c7 v1.34.0: string rows keep every word; Reset-all tooltip follows the reset; kit 19
```

## Baseline (before the copy, at `8dbda30`)

```sh
lua tests/run.lua   # 588 passed, 0 failed, 0 skipped, 588 total
luacheck .          # 0 warnings / 0 errors in 54 files
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .   # no warnings
```
