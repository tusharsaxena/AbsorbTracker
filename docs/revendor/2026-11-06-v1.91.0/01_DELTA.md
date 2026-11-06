Delta: LibKa0s v1.90.0 -> v1.91.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/` (item `FU-RV-AT`). The tag is
**local**: `git -C ../LibKa0s ls-remote --tags origin v1.91.0` prints nothing, which is expected; it is
pushed only at the run's finalize. This is not a refresh (the provenance line names v1.90.0, not
v1.91.0). `git -C ../LibKa0s rev-parse --short v1.91.0` is `4566d85` (the annotated tag object), which
peels to commit `55bfbb4`. The payload was extracted with
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/fu-rv-at/new`.
This file was written before the copy.

## Step 0 pre-flight: skipped

Skipped, and stated as a skip, not a pass. The installed skill's roster regex
(`\]\(\.\./\.\./[A-Za-z]+/\)`) expects markdown links, but `ADDONS.md` writes `` `../../<Folder>/` ``,
so it matches nothing; and its `tag_at` helper arrives with `"Ka0s"` / `"repos:CLAUDE.md"` where
`"$1"` / `"$2:CLAUDE.md"` were meant. Both are fixed upstream in this run (dev-copilot item `FU-DC1`).
For this addon alone: the newest single-tag bundle, `2026-11-06-v1.90.0`, states base v1.89.0 on line 1,
and the v1.90.0 bundle was written against the provenance line its own run read, so no base correction
is owed here.

## 3a. Claimed version, and the base

    $ grep -n '[Bb]undles' CLAUDE.md
    46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).

    $ c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit); echo $c
    f5fe3d2635f10f168644f093b3599e2c5331e2c8
    $ git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
    Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0

The last payload commit is `f5fe3d2` (`SF2-RV-AT: Refresh LibKa0s v1.90.0`), whose line names v1.90.0.
The two agree, and the payload matches the library at v1.90.0 (`diff -rq --strip-trailing-cr` against a
v1.90.0 extract prints only the pruned `media/icons` lines; the kit is identical). **Base: v1.90.0.**

    $ git -C ../LibKa0s log --oneline v1.90.0..v1.91.0
    55bfbb4 FU-L3: Release v1.91.0 adds the release run's record and its notes
    1938837 FU-L3: Release v1.91.0 moves every version line to the tag and records the consumer sweep
    3f7be30 FU-L2: Peel the toast stack cases out of test_toast.lua into test_toast_stack.lua
    acc9640 FU-L2: Peel the confirmation box and the HUD looks out of SkinPaintExtras.lua
    c1ed261 FU-L2: Peel the dropdown and its shared menu out of Widgets.lua into WidgetsDropdown.lua
    d72dc4a FU-L2: Peel the pixel edges section out of Core.lua into CorePixel.lua
    55d3b0f FU-L1: The line chart's axis, grid, markers, crosshair and series are physical pixels at any UI scale
    f4be157 Merge feat/2026-11-06-revendor-libka0s-v1-89: LibKa0s v1.90.0 (...)
    06d97b0 V89-FIN: Sync docs to the v1.90.0 re-vendor run

    $ git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s testkit tools
     LibKa0s/Core.lua             | 139 +-------
     LibKa0s/CorePixel.lua        | 162 +++++++++
     LibKa0s/LibKa0s.xml          |   4 +
     LibKa0s/SkinAceConfirm.lua   | 189 ++++++++++
     LibKa0s/SkinPaintExtras.lua  | 309 +----------------
     LibKa0s/SkinPaintHud.lua     | 169 +++++++++
     LibKa0s/Widgets.lua          | 769 +----------------------------------------
     LibKa0s/WidgetsDropdown.lua  | 805 +++++++++++++++++++++++++++++++++++++++++++
     LibKa0s/WidgetsLineChart.lua |  71 +++-
     9 files changed, 1414 insertions(+), 1203 deletions(-)

The kit (`testkit/`) and `tools/` did not change in the range.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives the v1.90.0
minors (Core 16, Widgets 25, SkinPaintExtras 18, WidgetsLineChart 6, and the rest as below). Line and
bytes agree.

## 3c. Per-file minor delta

The loop over the tag's `LibKa0s/LibKa0s.xml`; only the files that moved or are new:

| File | Old | New |
|---|---|---|
| `Core.lua` | `"LibKa0s-Core-1.0", 16` | `"LibKa0s-Core-1.0", 17` |
| `CorePixel.lua` | (new) | `PIXEL_MINOR = 1` |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR = 18` | `EXTRAS_MINOR = 19` |
| `SkinPaintHud.lua` | (new) | `HUD_MINOR = 1` |
| `SkinAceConfirm.lua` | (new) | `CONFIRM_MINOR = 1` |
| `Widgets.lua` | `"LibKa0s-Widgets-1.0", 25` | `"LibKa0s-Widgets-1.0", 26` |
| `WidgetsDropdown.lua` | (new) | `DROPDOWN_MINOR = 1` |
| `WidgetsLineChart.lua` | `CHART_MINOR = 6` | `CHART_MINOR = 7` |

Every other file in the XML is at its v1.90.0 minor. No cross-major skew: the consumer is behind on no
file it already has. No `NEEDS_*` floor rises (CHANGELOG v1.91.0).

## 3d. Both diffs (before the copy)

    $ diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s | grep -v 'Only in /tmp.*media/icons'
    Files .../Core.lua and libs/LibKa0s/Core.lua differ
    Only in .../new/LibKa0s: CorePixel.lua
    Files .../LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
    Only in .../new/LibKa0s: SkinAceConfirm.lua
    Files .../SkinPaintExtras.lua and libs/LibKa0s/SkinPaintExtras.lua differ
    Only in .../new/LibKa0s: SkinPaintHud.lua
    Files .../Widgets.lua and libs/LibKa0s/Widgets.lua differ
    Only in .../new/LibKa0s: WidgetsDropdown.lua
    Files .../WidgetsLineChart.lua and libs/LibKa0s/WidgetsLineChart.lua differ
    $ diff -rq --strip-trailing-cr <scratch>/new/testkit tests/_kit
    (empty)

Content differs exactly where the range says it should. No `Only in libs/LibKa0s` line: nothing was
removed upstream. The remaining `Only in <scratch>/LibKa0s/media/icons` lines are the undeclared icons.

## 3e. Consumption map

    $ grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

The addon looks up Env (`core/EnvSetup.lua:62`), Core (`core/CoreSetup.lua:26`), DebugLog
(`core/DebugLogSetup.lua:14`), Media (`core/MediaSetup.lua:82`), Lifecycle (`core/Lifecycle.lua:61`),
Bus (`core/Bus.lua:36`), Launcher (`core/LauncherSetup.lua:79`), Skin (`core/SkinSetup.lua:81`,
`core/Database.lua:174`, `:285`), Widgets (`core/WidgetsSetup.lua:24`), Perf (`core/PerfSetup.lua:16`),
Sim (`modules/Sim.lua:160`), Schema (`settings/Schema.lua:328`), Slash (`settings/Schema.lua:497`,
`settings/Slash.lua:24`) and Options (`settings/OptionsSetup.lua:76`). The same set as at v1.90.0. No
major is new in this range.

## 3f. Kit revision, and the pairing rule

    $ grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
    .../new/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 51

Revision 51 on both sides. A consumer on LibKa0s v1.9.0 or newer takes kit revision 11 or newer in the
same commit as the library; both payloads are copied whole in one commit, so the rule holds by
construction.

## 3g. Contract delta

Majors that moved a minor and that this addon looks up: Core (16 -> 17), Widgets (25 -> 26, with
WidgetsLineChart 7 and the new WidgetsDropdown 1) and Skin (SkinPaintExtras 19 and the new SkinPaintHud 1
and SkinAceConfirm 1). The tag's documents:

- `docs/api/Core/version-17.1-docs.md:14`: "the same members, with the pixel edges section in
  `Core.lua`" (now `CorePixel.lua`). Internal `__` members only; nothing a host calls.
- `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md:33`: "**What a host owes**: nothing." for the line
  chart; the dropdown peel moves `lib.Dropdown`, `lib.ContextMenu`, `lib.CloseMenu` to a new file with
  no member change (CHANGELOG v1.91.0, *The band files peeled*).
- `docs/api/Skin/version-17.1.27.8.19.19.1.1.17.4.9-docs.md:21`: "A pure move ... no member of the
  major or of a facade and no behavior changes ... a host's Skin facade owes nothing." `S.BarGloss` and
  `S.HudFont`, which this addon uses (`core/Data.lua:221`, `core/SkinSetup.lua:416`, `:452`), keep their
  names and contracts; only their file moves.

    $ grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
    (empty)

The addon passes no `__Attach*` members.

### Blockers

None. Checked against the run's blocker classes:

- **Library file lists.** Every loader in the suite derives the library list from the vendored
  `LibKa0s.xml` (`tests/run.lua:23`, `tests/perf.lua:60`, `tests/test_debuglog.lua:42`,
  `tests/test_launcher.lua:774`, `tests/test_optionssetup.lua:421`, `:517`, `tests/test_ltrap.lua:184`),
  and `tests/test_loadorder.lua:152-173` compares against the XML itself. No hand list names library
  files, so the four new files load in XML order with no edit.
- **Exact minor pins.** `grep -rnE 'Core-1\.0.{0,40}(16|17)|Widgets-1\.0.{0,40}(25|26)|EXTRAS|CHART_MINOR'`
  outside `libs/` and `tests/_kit/` finds nothing; no test pins a moved minor.
- **Stub mirrors.** The degradation stubs mirror member names (`core/WidgetsSetup.lua:35`
  `ContextMenu`, `core/SkinSetup.lua:416` `BarGloss`, `:452` `HudFont`); no member was added, removed or
  renamed, so none moves.
- `tests/test_ltrap.lua:160` reads `libs/LibKa0s/Core.lua`'s source for `STRINGS` / `d.L`; the peel
  moves neither into or out of Core.

## 3h. Tags vendored and never recorded

Run with the `tag_at` helper rewritten with a named variable (`rev=$1`), since the installed text shows
`"Ka0s"` where `"$1"` was meant:

    horizon=2026-08-25
    $ grep -vxF -f recorded.txt vendored.txt
    (empty)

Nothing to back-fill; no span bundle.

## 3i. The icon declaration

    $ grep -n 'LibKa0s icons:' CLAUDE.md
    47:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.

Directly under the provenance line, and kept unchanged (decided by the run's plan: nothing to adopt).
No provenance split is needed. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`,
WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'

`tests/test_mediasetup.lua:121` reads `lib.ICONS` only as a known-name set and `:153` opens declared
names only; `tests/test_optionssetup.lua:562` opens `info.tga`, which is declared. Both were narrowed at
v1.75.0. Not a blocker.
