# 01 - Delta: LibKa0s v1.54.2 -> v1.55.0

Written on 2026-09-23, before the copy, on branch `suite/2026-09-22-standards-sweep`. Steps 2-4 of
`/wow-addon:revendor-libka0s` only; candidates and adoption (Steps 5-8) are a later run's, so this
bundle carries no `02`-`05` files yet. Every figure below is followed by the command that produced it.

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1
# v1.55.0
git -C ../LibKa0s rev-parse v1.55.0 'v1.55.0^{commit}' 'v1.54.2^{commit}'
# bb161b730f2691be39a0dfbbe5c66fd7ca5e8db1   (v1.55.0 tag object)
# 6f9c5e076a7ea29d69b81e11a576e6094f80cd1d   (v1.55.0 commit)
# 85d32f278ff2d590c83dafadf6c658c50b76609d   (v1.54.2 commit)
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/new/
```

## 3a. Claimed version

```sh
grep -n -i 'bundles' CLAUDE.md
# 43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.54.2 (MIT).
```

## 3b. Actual version

Every vendored file's LibStub minor (3c's "old" column) is exactly what v1.54.2 shipped, so the claim
and the bytes agree before the copy. No skew.

## 3c. Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml`, which gains three rows (`Compat.lua` after
`Env.lua`; `Bus.lua` and `Schema.lua` after `Lifecycle.lua`).

```sh
RE='local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+'
for f in <scratch>/new/LibKa0s/*.lua; do b=$(basename "$f"); \
  echo "$b | old: $(grep -hoE "$RE" libs/LibKa0s/$b | head -1) | new: $(grep -hoE "$RE" "$f" | head -1)"; done
```

| File | Constant | Old (v1.54.2) | New (v1.55.0) |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | 7 |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Compat-1.0`)** |
| `Lifecycle.lua` | `MINOR` | 1 | 1 |
| `Bus.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Bus-1.0`)** |
| `Schema.lua` | `MINOR` | absent | **1 (new major `LibKa0s-Schema-1.0`)** |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | 1 |
| `Media.lua` | `MINOR` | 3 | 3 |
| `Widgets.lua` | `MINOR` | 9 | 9 |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 12 | 12 |
| `Slash.lua` | `MINOR` | 14 | 14 |
| `Launcher.lua` | `MINOR` | 1 | 1 |
| `Options.lua` | `MINOR` | 23 | 23 |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 30 | 30 |
| `OptionsTabs.lua` | `TABS_MINOR` | 3 | 3 |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | 3 |
| `Perf.lua` | `MINOR` | 12 | 12 |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

No existing file's minor moved. Each new major floors on Core minor 1 (`NEEDS_CORE = 1`,
`Compat.lua:81`, `Bus.lua:41`, `Schema.lua:36`) and returns before `NewLibrary` without it.

## 3d. Both diffs

```sh
diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s
# Only in <scratch>/new/LibKa0s: Bus.lua
# Only in <scratch>/new/LibKa0s: Compat.lua
# Files .../LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ    (the three <Script> rows)
# Only in <scratch>/new/LibKa0s: Schema.lua
diff -rq <scratch>/new/LibKa0s libs/LibKa0s                     # bytes: the same four lines
diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
# Files differ: README.md, framework.lua, run-automated-tests.sh, test_eol.lua, test_prose.lua
# Only in <scratch>/new/testkit: test_layout_cap.lua
diff -rq <scratch>/new/testkit tests/_kit                       # bytes: the same six lines
```

Content dirty in both payloads, which is the release itself, not a fork. Content and bytes list the
same paths, so there is no line-ending-only drift. No `Only in libs/LibKa0s` or `Only in tests/_kit`
line: nothing was removed upstream, so the copy deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '^libs/' | grep -v '^tests/'
```

| Major | Lookup site |
|---|---|
| Core | `core/CoreSetup.lua:25` |
| Env | `core/EnvSetup.lua:54` |
| Lifecycle | `core/Lifecycle.lua:61` |
| Media | `core/MediaSetup.lua:82` |
| DebugLog | `core/DebugLogSetup.lua:14` |
| Launcher | `core/LauncherSetup.lua:62` |
| Perf | `core/PerfSetup.lua:15` |
| Slash | `settings/Slash.lua:24`, `settings/Schema.lua:317` |
| Options | `settings/OptionsSetup.lua:69` |

Unadopted majors present in the payload: Pool, Item, Widgets (reached through Options/DebugLog), and
the three new ones, **Compat, Bus and Schema**. The three new majors are Step 5 class C candidates
for the next run; this run adopts nothing. The harness derives its library load list from
`libs/LibKa0s/LibKa0s.xml` (`tests/run.lua:23`, `Loader.xmlFiles`), so the three new files load in
the harness with no edit, the case the release notes describe as needing no action.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
# <scratch>/new/testkit/framework.lua:20:Kit.VERSION = 25
# tests/_kit/framework.lua:20:Kit.VERSION = 24
```

Kit revision 24 -> 25. Both payloads are copied whole in one commit, so the v1.9.0+ pairing rule
(kit revision 11 or newer beside the library) holds by construction.

## 3g. Contract delta

**No blockers.** The majors whose minor moved (3c) intersected with the majors this addon looks up
(3e) is the empty set: every consumed major keeps its v1.54.2 minor and therefore its v1.54.2 API
document, so there is no old/new document pair to diff. The three new majors have no prior contract
and no consumer here.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
# (no hits outside docs/)
```

No `__Attach*` entry point is called, so no host-supplied member can have had its call site moved.

The kit's own contract does move, and it binds this run as wiring rather than as a blocker:

- **Suite declaration is keyed by (basename, directory).** The runner already declares `test_prose`
  and `test_eol` in pair form (`tests/run.lua:103`, `:114`), and this repo has no local
  `tests/test_prose.lua`, `tests/test_eol.lua` or `tests/test_layout_cap.lua`, so there is no shadow
  to fix.
- **`tests/_kit/test_layout_cap.lua` arrives and must be declared**, as
  `{ name = "test_layout_cap", dir = "tests/_kit/" }`. It reads the `### Files over the 1500-line cap`
  census under `## Documented deviations` in `docs/ARCHITECTURE.md`, which landed ahead of this copy
  in `b6360c9`. No exempt set is passed: nothing here is generated data.
- **`test_eol.lua` gains case two**, `.gitattributes` against line-endings-§5's canonical body. The
  body was re-vendored to canonical in `35f92ea`.
- **The automated-test runner records the commit sha** in RESULTS.md and manifest.json. No action
  until the next battery run.
