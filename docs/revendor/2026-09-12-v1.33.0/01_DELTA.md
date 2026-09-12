# 01 — Delta: LibKa0s v1.32.0 → v1.33.0

Recorded before anything was copied. Every finding carries the command that produced it. The
payload was extracted from the tag, not from the sibling's working tree:

```sh
git -C ../LibKa0s rev-parse v1.33.0 'v1.33.0^{commit}'
# 7d5e0615e69a426ffcd8903dd3289068f691daab   (tag object)
# 06ee3680a16b3bcac8e17a5313a3243fae1a5508   (commit)
git -C ../LibKa0s archive v1.33.0 LibKa0s testkit | tar -x -C <scratch>/
```

The tag is local to `../LibKa0s` (branch `feat/2026-09-12-v1.33.0`). `tests/test_vendor_sync.lua`
compares against the sibling at the tag `CLAUDE.md` names, so a local tag is enough. This is the
fourth re-vendor dated 2026-09-12, so the folder name carries the tag.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.32.0 (MIT).
```

## 3b. Actual version

```sh
grep -hoE 'local MAJOR, MINOR *= *"[^"]+", *[0-9]+' libs/LibKa0s/Options.lua libs/LibKa0s/Slash.lua
```

Options 16 and Slash 8, with every other file at the minor v1.32.0 shipped. The claim and the bytes
agree.

## 3c. Per-file minor delta

| File | Constant | Old | Tag |
|---|---|---|---|
| `Options.lua` | `MINOR` | 16 | **17** |
| `Slash.lua` | `MINOR` | 8 | **9** |
| every other shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |

This matches the v1.33.0 block of `CHANGELOG.md` at the tag ("Slash minor 9, Options minor 17 …
kit revision 18"). No file is behind after the copy, so there is no cross-major skew.

## 3d. What moved, and both diffs

```sh
git -C ../LibKa0s diff --name-status v1.32.0 v1.33.0 -- LibKa0s testkit
# M LibKa0s/Options.lua
# M LibKa0s/Slash.lua
# M testkit/README.md
# M testkit/framework.lua
# M testkit/mock_base.lua
```

No `A` or `D` lines, so nothing needed deleting. The copy was `rsync -a --delete` of both folders
anyway, then a re-checkout through the CRLF filter. After it:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s   # (empty)
diff -r                     ../LibKa0s/LibKa0s libs/LibKa0s   # (empty)
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit     # (empty)
diff -r                     ../LibKa0s/testkit tests/_kit     # (empty)
git ls-files -s tests/_kit/run-automated-tests.sh             # 100755
```

## 3e. Consumption map

`Options` is looked up at `settings/OptionsSetup.lua:45`, and `Slash` at `settings/Slash.lua:24`
and `settings/Schema.lua:313`. Both majors that moved are consumed.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua
# 20:Kit.VERSION = 18      (17 before the copy)
```

Both payloads were copied whole in one commit, so the pairing rule holds by construction.

## Upstream range

```sh
git -C ../LibKa0s log --oneline v1.32.0..v1.33.0
# 06ee368 v1.33.0: release test record 20260912-214123
# 25d59a9 v1.33.0: preload LSM fonts on first panel show; count docstrings; kit 18
# 2bd4c56 docs(releasing): v1.32.0 is merged in all ten consumers
# 0741fe6 Merge branch 'feat/2026-09-12-v1.32.0': LibKa0s v1.32.0 (bulk bracket)
# 7a019a6 Merge branch 'feat/2026-09-12-v1.31.0': LibKa0s v1.31.0
# bf8ed91 v1.32.0 docs: Slash 8's bulkEnd row no longer calls count "rows actually written"
# 6233e3e v1.32.0 docs: the reviewer's findings on the bulk bracket (post-tag, docs only)
```

## Baseline (before the copy, at `6aa8fbc`)

```sh
lua tests/run.lua   # 588 passed, 0 failed, 0 skipped, 588 total
luacheck .          # 0 warnings / 0 errors in 54 files
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .   # no warnings
```
