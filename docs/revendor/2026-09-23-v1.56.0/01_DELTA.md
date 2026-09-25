Delta: LibKa0s v1.55.0 -> v1.56.0

# 01 — Delta

Run: 2026-09-24, plan item RV-AT of the 2026-09-23 review and standards-audit remediation (the
folder carries the plan's date). An orchestrated session took steps 2–4 of the local
`../wow-addon/commands/revendor-libka0s.md` (as amended by WA-01) by hand, with no interview. Steps 5–8
(candidates, adoption) are not taken here. This addon's M3 items own them, so the bundle carries
`01_DELTA.md` and `05_SUMMARY.md` only. Nothing was filed or pushed. Target: this repo, branch
`feat/2026-09-23-review-audit-remediation` @ `460c51d`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.56.0` (tag object `4622018` -> commit
`514fc0a`)**, extracted with `git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree. The tag exists only in `../LibKa0s` and has not been pushed.

`git -C ../LibKa0s log --oneline v1.55.0..v1.56.0` lists 53 commits: the LK-* items of the same
plan, their review follow-ups, the merge and the review record.

## Base pre-flight

The newest single-tag bundle, `docs/revendor/2026-09-23-v1.55.0/`, names base v1.54.2 and new
v1.55.0 on line 1. Its line 1 uses the older `# 01 - Delta: ...` heading, which still reads
unambiguously. The provenance line named v1.55.0 before this run, and
`git log -- libs/LibKa0s tests/_kit` puts `27ccce6 Re-vendor LibKa0s v1.55.0` as the last copy. The
chain is unbroken, no tag went unrecorded and no span bundle is owed.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:43`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.55.0** (MIT). `README.md` has no provenance line.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?([A-Z_]*MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives
v1.55.0's block (the left column of 3c). `grep -n 'Kit.VERSION' tests/_kit/framework.lua` gives
kit revision 25. Before the copy, the provenance line and the vendored bytes named the same version.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml`: 21 `<Script>` rows, byte-identical to the
vendored v1.55.0 XML. Both columns come from the same grep.

| File | v1.55.0 | v1.56.0 |
|---|---|---|
| **`Core.lua`** | 7 | **8** |
| `Env.lua` | 1 | 1 |
| `Compat.lua` | 1 | 1 |
| **`Lifecycle.lua`** | 1 | **2** |
| **`Bus.lua`** | 1 | **2** |
| **`Schema.lua`** | 1 | **2** |
| `Pool.lua` | 3 | 3 |
| **`Item.lua`** | 1 | **2** |
| **`Media.lua`** | 3 | **4** |
| **`Widgets.lua`** | 9 | **10** |
| `WidgetsDragHandle.lua` | 2 | 2 |
| **`DebugLog.lua`** | 12 | **13** |
| **`Slash.lua`** | 14 | **15** |
| **`Launcher.lua`** | 1 | **2** |
| **`Options.lua`** | 23 | **24** |
| **`OptionsWidgets.lua`** | 30 | **31** |
| **`OptionsTabs.lua`** | 3 | **4** |
| `OptionsCompose.lua` | 7 | 7 |
| **`OptionsScroll.lua`** | 3 | **4** |
| **`Perf.lua`** | 12 | **13** |
| `PerfPanel.lua` | 5 | 5 |

Fifteen files move a minor. No major changes and no file is added or removed. Composite keys
per the v1.56.0 CHANGELOG: Options 24.31.4.7.4, Perf 13.5, Widgets 10.2.

## 3d — Both diffs

`diff -rq <scratch>/LibKa0s libs/LibKa0s` and `diff -rq --strip-trailing-cr` report the same 15
files: `Bus.lua`, `Core.lua`, `DebugLog.lua`, `Item.lua`, `Launcher.lua`, `Lifecycle.lua`,
`Media.lua`, `Options.lua`, `OptionsScroll.lua`, `OptionsTabs.lua`, `OptionsWidgets.lua`,
`Perf.lua`, `Schema.lua`, `Slash.lua`, `Widgets.lua`. Neither side has an `Only in` line. The two
diffs agree, so nothing was forked locally and the line endings have not drifted.

`diff -rq <scratch>/testkit tests/_kit` and the `--strip-trailing-cr` form report the same 11
lines. Three files are `Only in <scratch>`: `asserts.lua`, `mock_events.lua` and `prose_lists.lua`.
Eight differ: `README.md`, `framework.lua`, `mock_base.lua`, `mock_record.lua`,
`run-automated-tests.sh`, `test_eol.lua`, `test_layout_cap.lua` and `test_prose.lua`. There is no
`Only in tests/_kit` line, so nothing needs deleting.

The copy was `rm -rf` then `cp -r`, with the runner kept executable (git mode `100755`). After it,
both `diff -r` runs are empty.

## 3e — Consumption map

`grep -rn 'LibStub("LibKa0s-' core modules settings` (authored code only):

| Major | Lookup site | Minor moved? |
|---|---|---|
| Core | `core/CoreSetup.lua:25` | 7 -> 8 |
| Env | `core/EnvSetup.lua:54` | no |
| Bus | `core/Bus.lua:36` | 1 -> 2 |
| Lifecycle | `core/Lifecycle.lua:61` | 1 -> 2 |
| Perf | `core/PerfSetup.lua:15` | 12 -> 13 (Perf 13.5, PerfPanel unchanged) |
| DebugLog | `core/DebugLogSetup.lua:14` | 12 -> 13 |
| Media | `core/MediaSetup.lua:82` | 3 -> 4 |
| Launcher | `core/LauncherSetup.lua:62` | 1 -> 2 |
| Widgets | `modules/Bar.lua:17`, `modules/Display.lua:26` | 9 -> 10 (DragHandle unchanged) |
| Slash | `settings/Slash.lua:24`, `settings/Schema.lua:470` | 14 -> 15 |
| Schema | `settings/Schema.lua:322` | 1 -> 2 |
| Options | `settings/OptionsSetup.lua:71` | 23 -> 24 (and its three moved sub-files) |

This addon does not look up Compat, Pool or Item directly. Pool and Item reach it only through the
Options sub-files, so Item's move to 2 arrives as bytes.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **25 -> 26**.
Both payloads are copied whole in one commit, so the pairing rule holds by construction.

## 3g — Contract delta

`git -C ../LibKa0s diff --stat v1.55.0 v1.56.0 -- docs/api` shows 39 files changed. Each major
whose minor moved gets a new live document and member manifest: Bus 2, Core 8, DebugLog 13, Item 2,
Launcher 2, Lifecycle 2, Media 4, Options 24.31.4.7.4, Perf 13.5, Schema 2, Slash 15 and Widgets
10.2. `testkit/version-26-docs.md` is new too. The superseded documents change only header
metadata. The CHANGELOG calls the release additive: no `NEEDS_*` floor rises and no major changes.

### Blockers

None. On the copy, `luacheck .` reports 0 / 0 in 61 files and `tests/run.lua` reports 719 passed,
0 failed, 719 total.

- **Schema instance stub.** Schema minor 2 adds `SetMany`, `row.normalize` and `writeThrough`. The
  host's degradation stub in `settings/Schema.lua` already caught up with minor 2 in plan item
  AT-01 (`460c51d`), which landed before this copy for that reason. `tests/test_surface_parity.lua`
  stays green.
- **Widgets minor 10.** No test in this addon pins the Widgets minor, and the addon does not drive
  `ReorderList` (`grep -rn ReorderList core modules settings` is empty), so the ghost-poll move
  changes nothing here.

### Not blockers

- Core minor 8 adds the `SafeRegisterEvent` family. The Core seam parity case pins `NS` members, not
  the library's lib-level surface, so no stub here owes the family.
- The Slash `DisabledLine` pin with `Kit.assertLibraryConstant`
  (`../LibKa0s/docs/api/Slash/version-15-docs.md`) is recommended, not enforced.
  `tests/test_disabled.lua` already reads `NS.Slash:DisabledLine()` at runtime and stays green.
- Launcher minor 2 adds `isEnabled` / `disabledLine`. Nothing reddens without them, so taking them
  up is an adoption question for the M3 items.
- Kit revision 26's behavioral flips redden nothing here: frames start shown, the AceDB fake raises,
  `EventRegistry` callbacks are recorded, lone CRs are counted, prose checks the store root, kit
  case names carry `§`, and perf gets skip reason (2). `docs/test-cases.md` and the README Tests
  badge are not regenerated here. A later item owns them.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
  host-supplied `__Attach*` member, so `RenderTabbedSchema`'s move to `OptionsTabs.lua` does not
  touch this addon.
