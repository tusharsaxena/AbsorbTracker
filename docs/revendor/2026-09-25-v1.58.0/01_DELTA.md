Delta: LibKa0s v1.57.0 -> v1.58.0

# 01 — Delta

Run: 2026-09-25, plan item M6-AT of the 2026-09-23 review and standards-audit remediation (milestone
M6, the launcher's left-click settings and right-click options menu). An orchestrated session took
steps 2–4 of the local `../wow-addon/commands/revendor-libka0s.md` by hand, with no interview. The
copy reddens seven cases on its own (3g), so the copy and the descriptor adoption land together in
one `M6-AT:` commit, and the bundle carries `01_DELTA.md` and `05_SUMMARY.md` only. Nothing was
filed or pushed. Target: this repo, branch `feat/2026-09-23-review-audit-remediation` @ `a45c975`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.58.0` (tag object `93cf3ad` -> commit
`34931c9`)**, extracted with `git -C ../LibKa0s archive v1.58.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree. The tag exists only in `../LibKa0s` and has not been pushed.

`git -C ../LibKa0s log --oneline v1.57.0..v1.58.0` lists 2 commits: LK-37's Launcher minor 4
(`02999d0`) and its release run (`34931c9`).

## Base pre-flight

The newest single-tag bundle, `docs/revendor/2026-09-24-v1.57.0/`, names base v1.56.0 and new
v1.57.0 on line 1. The provenance line named v1.57.0 before this run, and
`git log -- libs/LibKa0s tests/_kit` puts `310112c M5-AT: Re-vendor LibKa0s v1.57.0` as the last
copy. The chain is unbroken, no tag went unrecorded and no span bundle is owed.

## 3a — Claimed version, before this run

`CLAUDE.md`'s provenance line: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.57.0** (MIT). `README.md` has no provenance line. `docs/testing.md`'s re-vendor paragraph
restates the vendored tag in prose and moves with it.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?([A-Z_]*MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives
v1.57.0's block (the left column of 3c). `grep -n 'Kit.VERSION' tests/_kit/framework.lua` gives
kit revision 26. Before the copy, the provenance line and the vendored bytes named the same version.

## 3c — Per-file minor delta

The tag's `LibKa0s/LibKa0s.xml` is byte-identical to the vendored v1.57.0 XML (21 `<Script>` rows).

| File | v1.57.0 | v1.58.0 |
|---|---|---|
| `Core.lua` | 8 | 8 |
| `Env.lua` | 1 | 1 |
| `Compat.lua` | 1 | 1 |
| `Lifecycle.lua` | 2 | 2 |
| `Bus.lua` | 2 | 2 |
| `Schema.lua` | 2 | 2 |
| `Pool.lua` | 3 | 3 |
| `Item.lua` | 2 | 2 |
| `Media.lua` | 4 | 4 |
| `Widgets.lua` | 10 | 10 |
| `WidgetsDragHandle.lua` | 2 | 2 |
| `DebugLog.lua` | 13 | 13 |
| `Slash.lua` | 15 | 15 |
| **`Launcher.lua`** | 3 | **4** |
| `Options.lua` | 24 | 24 |
| `OptionsWidgets.lua` | 31 | 31 |
| `OptionsTabs.lua` | 4 | 4 |
| `OptionsCompose.lua` | 7 | 7 |
| `OptionsScroll.lua` | 4 | 4 |
| `Perf.lua` | 13 | 13 |
| `PerfPanel.lua` | 5 | 5 |

One file moves a minor. No major changes and no file is added or removed.

## 3d — Both diffs

`diff -rq <scratch>/LibKa0s libs/LibKa0s` and `diff -rq --strip-trailing-cr` both report one file,
`Launcher.lua`, and no `Only in` line. The two diffs agree, so nothing was forked locally and the
line endings have not drifted.

`diff -rq <scratch>/testkit tests/_kit` is empty: the kit bytes are v1.57.0's.

The copy was `rm -rf` then `cp -r` of both payloads, with the runner kept executable (git mode
`100755`). After it, both `diff -r` runs are empty.

## 3e — Consumption map

Only the Launcher major moved. `core/LauncherSetup.lua` is the one lookup site of
`LibKa0s-Launcher-1.0`. Every other major's consumption is as recorded in
`docs/revendor/2026-09-23-v1.56.0/01_DELTA.md` 3e and is unchanged.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **26 -> 26**.
Both payloads are copied whole in one commit, so the pairing rule holds by construction.

## 3g — Contract delta

`git -C ../LibKa0s diff --stat v1.57.0 v1.58.0 -- docs/api` adds `Launcher/version-4-docs.md` and
`Launcher/members-4.json` (the same member surface as version 3) and touches the header of the
superseded `version-3-docs.md`. No `NEEDS_*` floor rises and no major changes, but **version 4 is the
first Launcher version to retire descriptor fields**, and it changes both buttons under unchanged
signatures (launcher-§2, standard v2.67.0):

- **Left-click opens the settings panel**, in either state. `onClick` (this addon's rung-(b) lock
  toggle) is ignored, and so is version 2's disabled left-click refusal (`disabledLine`).
- **Right-click opens the client's context menu** (`MenuUtil.CreateContextMenu`) built from the
  descriptor's accessor-and-toggle pairs; with no pair, or no `MenuUtil`, it opens the panel.
- **The tooltip hints are fixed**: `Left-click: Open settings`, `Right-click: Options menu`;
  `leftClickLabel` and `slash` are ignored.

### Blockers

On the copy alone, the lint gate reports 0 / 0 in 63 files and `tests/run.lua` reports **765 passed,
7 failed**, 772 total. Every red is a pinned contract that moved, not a regression:

| Case | Why it reddened |
|---|---|
| `launcher: LEFT-click toggles the lock, through the seam the checkbox writes through` | left-click opens the panel now |
| `launcher: the disabled gate is the descriptor's, asked on every click and never cached` | the left-click gate is retired |
| `launcher tooltip: enabled and locked, the whole tooltip is exactly five lines` | hints fixed by the library |
| `launcher tooltip: Locked follows the lock on every show, green Yes and red No` | drove the lock through the left click |
| `launcher tooltip: disabled, it still draws, says No, and the left hint names /at enable` | the disabled hint is retired |
| `launcher tooltip: the left-click label goes through the locale, asked on every show` | `leftClickLabel` is retired |
| `disabled 8: the left click is refused and writes nothing; the right click still opens the panel` | no refusal; the menu grays instead |

Each is resolved by the adoption in the same commit rather than by a copy commit that sits red.

### Owed by launcher-§2 (v2.67.0)

The pairs this addon has, and ADDONS.md's row for it (`Enabled · Locked`): `isEnabled` +
`setEnabled` and `isLocked` + `toggleLock`, each toggle wired to its slash verb's handler. No
`isTestMode` / `toggleTestMode` (options-ui-§15's exemption; the lock is the preview) and no
`isWindowShown` / `toggleWindow` (no primary window). The retired `onClick`, `leftClickLabel` and
`disabledLine` are dropped (launcher-§5: dead configuration).
