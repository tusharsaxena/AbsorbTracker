# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Recorded **before** anything was copied. Every finding carries the command that produced it. The
payload was extracted from the tag, not from the sibling's working tree:

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1          # v1.32.0 (the orchestrator named it too)
git -C ../LibKa0s rev-parse 'v1.32.0^{commit}'             # e18dd12b98bc745afbe4d81c44ecbf5061848341
git -C ../LibKa0s archive v1.32.0 LibKa0s testkit | tar -x -C <scratch>/
```

This is the third re-vendor dated 2026-09-12. The first two are frozen at `docs/revendor/2026-09-12/`
(v1.29.0 → v1.30.0) and `docs/revendor/2026-09-12-v1.31.0/`, so this bundle carries the tag in its
folder name.

## 3a. Claimed version

```sh
grep -n '[Bb]undles' CLAUDE.md
# 69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.31.0 (MIT).
```

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' \
  libs/LibKa0s/*.lua
```

Options 15 and Slash 7, with every other file at the minor the v1.31.0 release shipped. The claim and
the bytes agree.

## 3c. Per-file minor delta

| File | Constant | Old | Tag |
|---|---|---|---|
| `Options.lua` | `MINOR` | 15 | **16** |
| `Slash.lua` | `MINOR` | 7 | **8** |
| every other shipped file | its `MINOR` / `*_MINOR` | unchanged | unchanged |

This matches the v1.32.0 block of `CHANGELOG.md` at the tag ("Slash minor 8, Options minor 16 …
kit revision 17"). `LibKa0s.xml` lists the same fourteen scripts. No file is behind after the copy,
so there is no cross-major skew.

## 3d. Both diffs

```sh
diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua differ
diff -rq                     <scratch>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit     # (empty)
diff -rq                     <scratch>/testkit tests/_kit     # (empty)
```

- **Library:** content differs in exactly the two files whose minors moved. That is the release,
  not a fork.
- **Kit:** identical. The tag says `testkit/` does not move, and it does not.
- No `Only in` lines, so nothing needs deleting.

## 3e. Consumption map

Unchanged from the v1.31.0 bundle. `Options` is looked up at `settings/OptionsSetup.lua:45`, and
`Slash` at `settings/Slash.lua:24` and `settings/Schema.lua:202`. Both majors that moved are
consumed.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
# both :20: Kit.VERSION = 17
```

Kit revision 17 on both sides. The pairing rule holds by construction, because both payloads are
copied whole in one commit.

## Upstream range

```sh
git -C ../LibKa0s log --oneline v1.31.0..v1.32.0
# e18dd12 The v1.32.0 release record, re-taken on the final tree
# c6314d6 CLAUDE.md: the luacheck scope is fifty-four files at v1.32.0
# 4083889 v1.32.0 review: bulkEnd's info names a profile reset (debug-logging-§10 final ruling)
# 4353908 The v1.32.0 release record
# f7d78cd v1.32.0: Options 16 and Slash 8 bracket their reset walks (debug-logging-§10)
# 807925a v1.31.0 post-tag docs and test: the verifier's findings
```

## Baseline (before the copy)

```sh
lua tests/run.lua   # 565 passed, 0 failed, 0 skipped, 565 total
luacheck .          # 0 warnings / 0 errors in 54 files
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" -C 15 -w .   # no warnings
```
