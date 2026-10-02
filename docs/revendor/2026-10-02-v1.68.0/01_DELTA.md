Delta: LibKa0s v1.67.0 -> v1.68.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-02, plan item TP-AT-01 of the LibKa0s tooltip-place hook bundle
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/`, milestone M2). An orchestrated
session ran the `/wow-addon:revendor-libka0s` playbook non-interactively: the owner delegated every
decision, so the one candidate was decided in-run and the reasoning is in `03_DECISIONS.md`. Target:
this repo, branch `feat/2026-10-02-drag-attach`, cut from `master` @ `db9dee0`.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.68.0` (tag object `6d83731` -> commit
`cc9f5eb`)**. That checkout's `HEAD` is the tag commit, and
`git -C ../LibKa0s diff --quiet v1.68.0 -- LibKa0s testkit` exits 0. The payloads were still
extracted with `git -C ../LibKa0s archive v1.68.0 LibKa0s testkit | tar -x -C <scratch>/new`, never a
branch tip. `git -C ../LibKa0s log --oneline v1.67.0..v1.68.0` lists 8 commits: DA-LK-01 (the
widget change), DA-LK-02 to DA-LK-07R (release records, the test split and doc fixes).

## Step 0 — Base pre-flight (roster-wide, report only)

All eleven roster addons report `ok`: each newest single-tag bundle is `2026-10-02-v1.67.0` with
base v1.66.0, which matches the provenance line before its re-vendor commit (AbsorbTracker's is
`7ed3af6`). No misstated base, so no correction paragraph.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.67.0 (MIT).` The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit` ->
`7ed3af6`, left the line at v1.67.0, so the two agree. Payload check against the claimed tag:
`diff -rq <v1.67.0>/LibKa0s libs/LibKa0s && diff -rq <v1.67.0>/testkit tests/_kit` printed
`payload-matches`. `docs/testing.md:170` restates the tag in prose and moves with it. `README.md`
has no provenance line.

## 3b — Actual version, before this run

The vendored minors are v1.67.0's (left column of 3c), and `Kit.VERSION` is 35. Claim and bytes agree.

## 3c — Per-file minor delta

`git -C ../LibKa0s diff --quiet v1.67.0 v1.68.0 -- LibKa0s/LibKa0s.xml` exits 0: the XML is
unchanged, with 32 script rows in the same order. Walking those rows with the playbook's grep
(the old value from `libs/LibKa0s/<f>`, the new from `git show v1.68.0:LibKa0s/<f>`), exactly one file
moves:

| File | v1.67.0 | v1.68.0 |
|---|---|---|
| **`WidgetsDragHandle.lua`** (`DRAG_MINOR`) | 3 | **4** |

The other 31 files keep their minors (Core 10, Env 1, Compat 1, Lifecycle 3, Bus 2, Schema 2,
Pool 3, Item 2, Media 4, Widgets 12, WidgetsReorder 1, DebugLog 19 with its two satellites, Slash 19
with SlashParse 1, Launcher 5, Options key 28.2.34.2.3.8.1.7.4.2 and Perf key 14.1.1.6). The Widgets
key moves 12.1.3 -> 12.1.4. No file and no major is added, and no `NEEDS_*` floor rises. The consumer
was behind on no file before the copy (no cross-major skew).

## 3d — Both diffs

Before the copy:

- `libs/LibKa0s`: only `WidgetsDragHandle.lua` differs (69 insertions, 15 deletions). There is no
  `Only in` line on either side.
- `tests/_kit`: no difference (`git -C ../LibKa0s diff --quiet v1.67.0 v1.68.0 -- testkit` exits 0).

Nothing is deleted. After the copy, `diff -r` and `diff -r --strip-trailing-cr` against
`<scratch>/new/LibKa0s` and `<scratch>/new/testkit` are empty for both payloads. The archive writes
CRLF, so the vendored file keeps its line endings.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings`: Core
(`core/CoreSetup.lua:26`), DebugLog (`core/DebugLogSetup.lua:14`), Lifecycle (`core/Lifecycle.lua:61`),
Media (`core/MediaSetup.lua:82`), Launcher (`core/LauncherSetup.lua:70`), Bus (`core/Bus.lua:36`), Env
(`core/EnvSetup.lua:62`), Perf (`core/PerfSetup.lua:16`), Widgets (`modules/Display.lua:26`,
`modules/Bar.lua:15`), Schema (`settings/Schema.lua:328`), Slash (`settings/Schema.lua:496`,
`settings/Slash.lua:24`) and Options (`settings/OptionsSetup.lua:71`). This is unchanged from the
v1.67.0 bundle. The moved major, Widgets, is consumed. `Widgets.DragHandle` is called once, at
`modules/Bar.lua:65` (`buildHandle`), and builds one strip per bar (player, target, focus).

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua` -> **35 -> 35**. The
kit does not move. Both payloads are still copied whole, as the pairing rule requires, and
`tests/run.lua` is untouched.

## 3g — Contract delta

The one major that moved a minor and that this addon consumes is Widgets, at
`docs/api/Widgets/version-12.1.3-docs.md` -> `version-12.1.4-docs.md` (the latter's header row
`Supersedes`: "no tooltip placement hook").

- `version-12.1.4-docs.md:20-48` ("What changed at 12.1.4"): the spec gains the optional
  `tooltipPlace` and the descriptor gains `place`, both **Since 4**. Line 44: "Without a hook nothing
  changes. A host that sets neither field gets minor 3's calls in minor 3's order (one `SetOwner`,
  the lines, one `Show`), for the cursor owner and the frame owner alike." Line 47: "What a host
  must change: nothing."
- `modules/Bar.lua:65-113` passes neither `tooltipPlace` nor `place`, and neither `tooltipOwner` nor
  `owner`. Every hover therefore stays on the frame-owner path (`libs/LibKa0s/WidgetsDragHandle.lua:285`,
  `dhOwnTooltip`). The strip owns at the default `ANCHOR_TOP`, and the help and close marks own at
  their descriptors' `ANCHOR_TOPRIGHT`, exactly as at minor 3. The tooltip drawing is now split into
  evaluate and draw, but the calls are the same and in the same order. `tests/test_draghandle.lua`'s
  tooltip cases record those calls through the mock `GameTooltip`, and they stay green.
- `grep -rn '__Attach[A-Za-z]*' --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit .`
  finds no site, so no host-supplied callback moved.

**No blockers.**

## 3h — Tags vendored and never recorded

Running the playbook's listing from horizon `2026-08-25` gives an empty
`grep -vxF -f recorded.txt vendored.txt`. Every tag this addon vendored has a bundle, so there is no
span bundle.
