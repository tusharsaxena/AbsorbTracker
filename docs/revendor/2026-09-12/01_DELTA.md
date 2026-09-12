# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Recorded **before** anything was copied. Every finding carries the command that produced it.
The payload was extracted from the tag, not from the sibling's working tree:

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1          # v1.30.0
git -C ../LibKa0s rev-parse v1.30.0^{commit}               # e369e0fc99e22063200893d15c68237072222ed3
git -C ../LibKa0s archive v1.30.0 LibKa0s testkit | tar -x -C <scratch>/
```

The tag sits on the library's `fix/kit-27-30` branch and is not on its `master` yet. That does not
matter here: `tests/test_vendor_sync.lua` compares against the **tag** `CLAUDE.md` names.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.29.0 (MIT).
```

`README.md` carries no provenance line, so there is nothing to migrate out of it.

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' \
  libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, OptionsScroll 3, OptionsWidgets 14, Perf 10,
PerfPanel 5, Pool 3, Slash 7, Widgets 9. These are exactly the minors the v1.29.0 release block
names, so the claim and the bytes agree.

## 3c. Per-file minor delta

The same grep over `<scratch>/LibKa0s/*.lua` (the file list is the tag's `LibKa0s/LibKa0s.xml`)
returns the identical set. **No file in `LibKa0s/` moved its minor.** The upstream CHANGELOG says
the same thing in its v1.30.0 block (`CHANGELOG.md:13-21` at the tag).

| File | Constant | Old | Tag |
|---|---|---|---|
| every shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |

No cross-major skew.

## 3d. Both diffs

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # (empty)
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # (empty)
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua, vendor_sync.lua differ
diff -rq                     <scratch>/testkit tests/_kit     # the same four
```

- **Library:** content clean, bytes clean. Nothing to copy that is not already here.
- **Kit:** content dirty in four files. This is the release itself, not a fork:
  `git -C ../LibKa0s diff --stat v1.29.0 v1.30.0 -- LibKa0s testkit` shows exactly these four
  (`README.md` 33 lines changed, `framework.lua` 2, `mock_base.lua` 208, `vendor_sync.lua` 52;
  263 insertions and 32 deletions in all).
- No `Only in tests/_kit` or `Only in libs/LibKa0s` lines, so nothing needs deleting.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

| Major | Lookup site(s) |
|---|---|
| Core | `core/CoreSetup.lua:25` |
| DebugLog | `core/DebugLogSetup.lua:14` |
| Env | `core/EnvSetup.lua:54` |
| Media | `core/MediaSetup.lua:82` |
| Perf | `core/PerfSetup.lua:15` |
| Slash | `settings/Slash.lua:24`, `settings/Schema.lua:198` |
| Options | `settings/OptionsSetup.lua:45` |

Unconsumed majors: `Item`, `Pool` and `Widgets` (Pool and Widgets are reached through Options and
DebugLog). None moved in this release, so none is a new candidate. `Item` has no role in an absorb
tracker.

## 3f. Kit revision and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 16
# tests/_kit/framework.lua:20:Kit.VERSION = 15
```

Kit **15 → 16**. The pairing rule (a consumer on LibKa0s v1.9.0 or newer carries kit revision 11 or
newer in the same commit) is satisfied by construction: both payloads are copied whole, together,
in one commit with the provenance line.

The runner-mode case kit 16 adds (`VendorSync.register`, issue #28) will pass here as-is:

```sh
git ls-files -s tests/_kit/run-automated-tests.sh
# 100755 f6cd8b0a86aaf87d394e9ebaf0decf9e13c4e10c 0	tests/_kit/run-automated-tests.sh
```

## Baseline gate (master, before the copy)

```sh
lua tests/run.lua   # 560 passed, 0 failed, 0 skipped, 560 total
luacheck .          # 0 warnings / 0 errors in 54 files
```
