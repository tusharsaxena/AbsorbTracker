Delta: LibKa0s v1.85.0 -> v1.89.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (item `V89-AT`). The tag is
pushed: `git -C ../LibKa0s ls-remote --tags origin v1.89.0` prints `0bd4839` (the annotated tag
object), which peels to commit `df00e5f`. The payload was extracted with
`git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/v89-at/new`.
This file was written before the copy.

## Step 0 pre-flight

From the run's `inputs/step0-preflight.txt` (run with the plan's corrected roster regex):

    AbsorbTracker  2026-11-01-v1.85.0  base v1.84.0  vendored-before v1.84.0@1d7ac3e  ok

No base correction is owed.

## 3a. Claimed version, and the base

    $ grep -n '[Bb]undles' CLAUDE.md
    46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).

    $ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)   # 50847a2
    $ git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
    Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0
    $ git log --format='%h %s' "$c..HEAD" -- CLAUDE.md
    (none)

The two agree. As a further check, the v1.85.0 extract against the vendored payload: `tests/_kit`
matches exactly; `libs/LibKa0s` differs only by `Only in <v1.85.0 extract>/media/icons` lines, the
icons the declaration does not name. **Base: v1.85.0.**

    $ git -C ../LibKa0s log --oneline v1.85.0..v1.89.0     # 27 commits
    df00e5f LK-K2: Release v1.89.0 adds the release run's record and its notes
    f11b9c0 LK-K2: Release v1.89.0 moves every version line to the tag and records the consumer sweep
    367a9f1 LK-K1: Kit revision 51 clears a callback only where one exists, as CallbackHandler does
    3555d43 LK-T2: Release v1.88.0 adds the release run's record and its notes
    1fdaed5 LK-T2: Release v1.88.0 moves every version line to the tag and records the consumer sweep
    ff2c4f8 .. ef66de6  LK-T1: Toast minor 4, the opt-in stack (six commits)
    758cbd4 Release v1.87.0: the release run's record and its notes
    95feb1b Release v1.87.0: cascading context menus
    b8da2ce Review fixes: cascading menus (Task 1)
    fb2bf89 Widgets minor 23: cascading W.ContextMenu submenus, the parent kept
    cad1609 .. 566d981  Release v1.86.0 and the IconBrowser major (seven commits)
    06eae81 R7-FIN: Merge feat/2026-11-04-smoke-round7 (smoke round 7)
    5021559, 54ae61c, 5491d29, 293040c  (the round 6 and round 7 merges into the library master, and their doc commits)
    $ git -C ../LibKa0s diff --stat v1.85.0 v1.89.0 | tail -1
    83 files changed, 125301 insertions(+), 321 deletions(-)

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives the
v1.85.0 minors exactly (Toast 3, Widgets 22, DebugLogDiagnostics 6, no IconBrowser file). Claim and
bytes agree.

## 3c. Per-file minor delta

The loop over the tag's `LibKa0s/LibKa0s.xml` (3c's command). Every file not listed is unchanged.

| File | v1.85.0 | v1.89.0 |
|---|---|---|
| `Toast.lua` | `LibKa0s-Toast-1.0` 3 | 4 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` 22 | 23 |
| `DebugLogDiagnostics.lua` | `DIAG_MINOR` 6 | 7 |
| `IconBrowserSources.lua` | (new) | `LibKa0s-IconBrowser-1.0` 1 |
| `IconBrowserWindow.lua` | (new) | `WINDOW_MINOR` 1 |
| `IconBrowser.lua` | (new) | `BROWSER_MINOR` 1 |

No file is behind: no cross-major skew.

## 3d. Diffs before the copy

    $ diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v '^Only in .*/media/icons'
    Files .../DebugLogDiagnostics.lua and libs/LibKa0s/DebugLogDiagnostics.lua differ
    Only in <scratch>/LibKa0s: IconBrowser.lua
    Only in <scratch>/LibKa0s: IconBrowserSources.lua
    Only in <scratch>/LibKa0s: IconBrowserWindow.lua
    Files .../LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
    Files .../Toast.lua and libs/LibKa0s/Toast.lua differ
    Files .../Widgets.lua and libs/LibKa0s/Widgets.lua differ
    $ diff -rq <scratch>/testkit tests/_kit
    Files .../README.md, framework.lua, mock_ace.lua differ

The byte and content readings agree (no line-ending drift). 213 `Only in <scratch>/LibKa0s/media/icons`
lines are the undeclared icons (the declaration working). No `Only in libs/LibKa0s` line: nothing
was removed upstream.

## 3e. Consumption map

    $ grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Eighteen host lookup sites over fifteen majors: Bus (`core/Bus.lua:36`), Core (`core/CoreSetup.lua:26`),
DebugLog (`core/DebugLogSetup.lua:14`), Env (`core/EnvSetup.lua:62`), Launcher
(`core/LauncherSetup.lua:79`), Lifecycle (`core/Lifecycle.lua:61`), Media (`core/MediaSetup.lua:82`),
Perf (`core/PerfSetup.lua:16`), Skin (`core/SkinSetup.lua:81`, `core/Database.lua:174`, `:285`),
Widgets (`core/WidgetsSetup.lua:24`), Sim (`modules/Sim.lua:160`), Options
(`settings/OptionsSetup.lua:76`), Schema (`settings/Schema.lua:328`), Slash (`settings/Slash.lua:24`,
`settings/Schema.lua:497`).

Not looked up: `Toast`, `IconBrowser` (new), plus the earlier unconsumed `Compat`, `Pool`, `Item`,
`Glow`, `Charts`.

## 3f. Kit revision

    $ grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
    <scratch>/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 50

Kit 50 -> 51 moves with the library payload in the same commit (the pairing rule: from v1.9.0 both
payloads travel together; the copy is whole, so it holds by construction).

## 3g. Contract delta

Majors that moved a minor and that this addon looks up: **Widgets** (22 -> 23) and **DebugLog**
(diagnostics 6 -> 7). Toast and IconBrowser moved but are not consumed.

- Widgets: `diff` of `docs/api/Widgets/version-22.5.12.6.7.5-docs.md` (v1.85.0) against
  `version-23.5.12.6.7.5-docs.md` (v1.89.0). The only prose outside new `Since` rows is the version
  header and the "`Widgets.lua` moves to minor 23. Additive ... Every single-level menu, a dropdown's
  and a host's, is unchanged." paragraph. AbsorbTracker calls no `W.ContextMenu` (its
  `core/WidgetsSetup.lua:35` stub carries `ContextMenu` only because the v1.85.0 release owed it;
  nothing reaches it). `DragHandle` and `DRAG_HANDLE`, which it does use, are untouched
  (`WidgetsDragHandle.lua` stays at 12).
- DebugLog: `version-22.6.1.4-docs.md` against `version-22.7.1.4-docs.md`: "**No member change.**"
  The report's `LibKa0s running:` line also lists `IconBrowser` when the winning copy has it.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`
  prints nothing: the addon hands the library no `__Attach*` members.

**Blockers: none.**

## 3h. Tags vendored and never recorded

The 3h listing (horizon `2026-08-25`, 63 vendored tags walked over both payloads and the `CLAUDE.md`
rolls) against the store's recorded tags prints nothing. **No span bundle.**

## 3i. The icon declaration

    $ grep -n 'LibKa0s icons:' CLAUDE.md
    47:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.

It is the next non-blank line under the provenance line; the provenance sentence ends its line, so
there is no split to make. **Kept unchanged** (run override: keep it unless a fact forces a change).
No fact does: the range's new library-drawn marks (`search` and `close` in the icon browser,
`docs/releasing.md` *Library-drawn icons*) are drawn only for a host that builds an `IB:New`
browser, and the Widgets 23 submenu arrow only on a `W.ContextMenu` row this addon never opens.
Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop for a forgotten name.

## 3j. Tests that assume the whole icon folder

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
    tests/test_mediasetup.lua:121   known[] from lib.ICONS (the catalog of names, not files)
    tests/test_mediasetup.lua:153   opens each DECLARED name's .tga
    tests/test_optionssetup.lua:562 opens info.tga (declared)

All three are already narrowed to declared names (the v1.75.0 fix). **No blocker.**

## Dead stub mirrors

    $ grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
    (none)

No `__` member was removed in the range.
