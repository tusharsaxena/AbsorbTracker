# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Recorded **before** anything was copied. Every finding carries the command that produced it. The
payload was extracted from the tag, not from the sibling's working tree:

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1          # v1.31.0 (the orchestrator named it too)
git -C ../LibKa0s rev-parse v1.31.0^{commit}               # 30db4edeabfffe2ec64b9d638d6d8018b2c5d890
git -C ../LibKa0s archive v1.31.0 LibKa0s testkit | tar -x -C <scratch>/
```

This is the second re-vendor dated 2026-09-12. The first (v1.29.0 → v1.30.0) is frozen at
`docs/revendor/2026-09-12/`, so this bundle carries the tag in its folder name.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.30.0 (MIT).
```

`README.md` carries no provenance line, so there is nothing to migrate out of it.

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' \
  libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, OptionsCompose 3, OptionsScroll 3,
OptionsWidgets 14, Perf 10, PerfPanel 5, Pool 3, Slash 7, Widgets 9. These are the minors the
v1.30.0 release shipped, so the claim and the bytes agree.

`COMPOSE_MINOR` is added to the spec's grep here. `OptionsCompose.lua` carries its own constant name
and is one of the two files that moved, so the spec's pattern as written would have missed the move.

## 3c. Per-file minor delta

The same grep over `<scratch>/LibKa0s/*.lua`. The file list comes from the tag's
`LibKa0s/LibKa0s.xml`: fourteen scripts, the same fourteen as before.

| File | Constant | Old | Tag |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| every other shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |

This matches the v1.31.0 block of `CHANGELOG.md` at the tag ("OptionsWidgets minor 15,
OptionsCompose minor 4"). The consumer is behind on no file after the copy, so there is no
cross-major skew.

## 3d. Both diffs

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua differ
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua differ
diff -rq                     <scratch>/testkit tests/_kit     # the same three
```

- **Library:** content differs in exactly the two files whose minors moved. That is the release,
  not a fork.
- **Kit:** content differs in three files: `Kit.VERSION` 16 → 17 in `framework.lua`, the Ace
  surfaces in `mock_base.lua`, and their documentation in `README.md`.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` lines, so nothing needs deleting.

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
| Slash | `settings/Slash.lua:24`, `settings/Schema.lua:202` |
| Options | `settings/OptionsSetup.lua:45` |

This is the same map as last time. `settings/Schema.lua`'s Slash lookup moved from `:198` to `:202`
with the #30 commits on this branch. It is still the one second lookup site, and it is recorded.
Unconsumed majors: `Item`, `Pool` and `Widgets`. Pool and Widgets are reached through Options and
DebugLog. None of the three moved, so none is a new candidate.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/testkit/framework.lua:20:Kit.VERSION = 17
# tests/_kit/framework.lua:20:Kit.VERSION = 16
```

Kit revision 16 → 17. The pairing rule (LibKa0s v1.9.0 or newer takes kit revision 11 or newer in
the same commit) is satisfied by construction: both payloads are copied whole, in one commit.

## Upstream range

```sh
git -C ../LibKa0s log --oneline v1.30.0..v1.31.0
# 30db4ed The v1.31.0 release record
# 2b312db v1.31.0: release pointers, standards v2.44.0, the case list
# f355fdc Kit 17: the Ace surfaces six consumer harnesses migrate onto
# 3162e53 Options 15.15.4.3: a record-backed bind arm for the composers (PanelMaster#48)
# 09099b1 docs(releasing): v1.30.0 is merged in all ten consumers
# 853c62e Merge branch 'fix/kit-27-30'
# 5193ebe Post-tag v1.30.0: consumers table sweep; AuraMaster is the tenth consumer
```

## Baseline (before the copy)

```sh
lua tests/run.lua   # 565 passed, 0 failed, 0 skipped, 565 total
luacheck .          # 0 warnings / 0 errors in 54 files
```
