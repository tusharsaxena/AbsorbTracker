# 01 — Delta: LibKa0s v1.34.0 → v1.35.0

**Written after the fact.** The re-vendor landed on 2026-09-14 as `46de577` without a bundle. This
record was written later the same day, on `chore/2026-09-14-last-nits`, from the commits already on
`master` (`46de577` the copy, `8506cea` the stub members, `30ad410` the doc sync, merged at
`17e3ada`). Every number below was measured when this record was written, against those commits and
the tag. None of it was recorded during the original run.

```sh
git -C ../LibKa0s rev-parse v1.35.0 'v1.35.0^{commit}'
# f99cb368cd4f12f6c06e42d5006fcab02de1082d   (tag object)
# 6036c263e002804e199b1fcd396d5c32f4d057c4   (commit)
git -C ../LibKa0s archive v1.35.0 LibKa0s testkit | tar -x -C <scratch>/tag/
```

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# before 46de577:  69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.34.0 (MIT).
# after  46de577:  69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.35.0 (MIT).
```

## 3b. Actual version

Before the copy every file sat at the minor v1.34.0 shipped, so the claim and the bytes agreed.
After the copy they agree at v1.35.0.

## 3c. Per-file minor delta

```sh
git diff 46de577^ 46de577 -- libs/LibKa0s tests/_kit | grep -E '^[-+].*(MINOR|Kit.VERSION)'
# -local WIDGETS_MINOR = 15
# +local WIDGETS_MINOR = 16
# -Kit.VERSION = 19
# +Kit.VERSION = 20
```

| File | Constant | Old | Tag |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 15 | **16** |
| every other shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |
| `testkit/framework.lua` | `Kit.VERSION` | 19 | **20** |

This matches the v1.35.0 block of `CHANGELOG.md` at the tag ("One file in `LibKa0s/` moves,
`OptionsWidgets.lua` 15 → 16, and so does the kit"). The Options API document names the combined
version 18.16.5.3. No file is behind after the copy, so there is no cross-major skew.

## 3d. What moved, and both diffs

```sh
git diff --name-status 46de577^ 46de577 -- libs/LibKa0s tests/_kit
# M libs/LibKa0s/OptionsWidgets.lua   (+1646 / −10; 3645 lines at the tag)
# M tests/_kit/README.md              (+32)
# M tests/_kit/framework.lua          (Kit.VERSION)
# M tests/_kit/mock_base.lua          (+5: EditBox GetText, CheckBox SetType, EditBox DisableButton)
# A tests/_kit/mock_ids.lua           (204 lines, new)
```

That is the same set `git -C ../LibKa0s diff --name-status v1.34.0 v1.35.0 -- LibKa0s testkit`
names. Nothing was deleted upstream. Both payloads compared against the tag archive:

```sh
diff -r --strip-trailing-cr <scratch>/tag/LibKa0s libs/LibKa0s   # (empty)
diff -r                     <scratch>/tag/LibKa0s libs/LibKa0s   # (empty)
diff -r --strip-trailing-cr <scratch>/tag/testkit tests/_kit     # (empty)
diff -r                     <scratch>/tag/testkit tests/_kit     # (empty)
git ls-files -s tests/_kit/run-automated-tests.sh                # 100755
```

Against the sibling's working tree, `libs/LibKa0s` is also empty. `tests/_kit` is not, and the
reason is upstream: at the time of writing `../LibKa0s` was on its own
`chore/2026-09-14-last-nits`, whose `testkit/README.md` rewords nine lines after the tag (repo
counts, the id-lookups sentence). `git -C ../LibKa0s diff --stat v1.35.0 -- testkit LibKa0s`
names that one file. `tests/test_vendor_sync.lua` compares against the tag `CLAUDE.md` names, not
the working tree, and passes.

## 3e. Consumption map

AbsorbTracker looks up seven majors:

| Major | Where |
|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:25` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:14` |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua:54` |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua:82` |
| `LibKa0s-Perf-1.0` | `core/PerfSetup.lua:15` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua:45` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:24`, `settings/Schema.lua:313` |

The one file that moved, `OptionsWidgets.lua`, is part of `LibKa0s-Options-1.0`, so it is
consumed. None of the new members is:

```sh
grep -rnE 'ChoiceGrid|IdInput|IdList|ResolveId|UnnamedCandidates|ID_NAME_HINT' core modules settings
# settings/OptionsSetup.lua:376-379   (the inert stub members, 8506cea, and nothing else)
```

**Contract change under an unmoved signature.** `RenderField` and every maker kept their
signatures, but from W16 each maker reads `row.disabledIf`, where before only the color picker did.
A non-color row that already carried `disabledIf` would start dimming on the copy. There is none
here. `settings/Schema.lua:44` says no row carries `disabledIf`, `tests/test_schema.lua:324` pins
it for color rows, and `tests/test_schema.lua:386` checks that any row that has one resolves. So
the change is not an adoption blocker in this addon.

## 3f. Kit revision, and the pairing rule

`Kit.VERSION` goes from 19 to **20**. Both payloads were copied whole in `46de577`, so the pairing
rule holds by construction. Kit 20 adds `mock_ids.lua` (opt-in, called on a finished mock) and
three AceGUI-fake methods in `mock_base.lua`. No suite here installs `mock_ids.lua`, and none calls
the three methods, so no case can see the difference. The kit's own API document says the same:
"Neither changes what an existing suite sees."

## The one case the copy moved

As the v1.35.0 CHANGELOG predicted for nine of the ten consumers, `tests/test_surface_parity.lua`'s
Options stub parity case went red on the copy and named all six new members as missing from the
degraded stub. `46de577` answered by adding the six to the case's ignore list, under the
RefreshPanel rule (no caller, so no stub member). `8506cea` then reversed that by owner decision:
the six left the ignore list and joined the stub inert (see 03_DECISIONS).

## Upstream range

```sh
git -C ../LibKa0s log --oneline v1.34.0..v1.35.0 | wc -l    # 31 commits
# 6036c26 v1.35.0: release test record 20260914-010923 (re-cut)
# 07e55cd LibKa0s v1.35.0: disabledIf everywhere, ChoiceGrid, IdInput/IdList (Options 18.16.5.3, kit 20)
# 54ac640 Options: ChoiceGrid - a matrix of radio cells over rows sharing one value list
# c64e5ee Options: disabledIf on every maker (path or predicate) + RenderRows opts.disabled
# … (IdInput suggestions and the shared-name refusal, issue #31, and release re-cuts)
```

## Baseline (before the copy, at `9590af5`)

Measured afterwards in a scratch clone with a `../LibKa0s` sibling link, so the vendor-sync pair
ran rather than skipped:

```sh
lua tests/run.lua   # 590 passed, 0 failed, 0 skipped, 590 total
luacheck .          # 0 warnings / 0 errors in 54 files
```
