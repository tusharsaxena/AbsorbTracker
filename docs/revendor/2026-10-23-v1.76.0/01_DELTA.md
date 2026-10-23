Delta: LibKa0s v1.75.2 -> v1.76.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-23, plan item **AT-RV** of the sim auto-run, QC preview selector, mode strips and MM/KCD
simulators run (`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`), on branch
`feat/2026-10-23-sim-preview-mode-strips`. The run follows the installed
`/dev-copilot:wow-revendor-libka0s` (dev-copilot 2.4.0) mechanically under the item spec: no
interview and no GitHub issue filing. AbsorbTracker is not an adopter of anything in this release
(OWNER_SCOPE names BankLedger, DropWatcher, LootHistory, MultiMeters and KickCD), so every candidate
is listed as not adopted in this run.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.76.0` (commit `9949368`)**, not yet pushed
(`git -C ../LibKa0s ls-remote --tags origin v1.76.0` prints nothing). The payloads were extracted with
`git -C ../LibKa0s archive v1.76.0 LibKa0s testkit tools | tar -x -C <scratch>`, never a branch tip;
`tools/` only for `prune-icons.lua`, which is not copied into the addon.
`git -C ../LibKa0s log --oneline v1.75.2..v1.76.0` lists 8 commits.
`git -C ../LibKa0s diff --shortstat v1.75.2 v1.76.0 -- LibKa0s` reports 3 files changed (148
insertions, 53 deletions), and `-- testkit` prints nothing.

## Step 0 — Pre-flight

The newest single-tag bundle, `docs/revendor/2026-10-22-v1.75.0/`, states `v1.71.0 -> v1.75.0`. The
provenance line before its re-vendor commit `aee2459` named v1.71.0, so the bundle agrees with the
history. No correction is owed.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` gave
`CLAUDE.md:43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.75.2 (MIT).` The last
payload commit (`git log -1 --format=%H -- libs/LibKa0s tests/_kit`, `d8de275`) leaves the same line.
Payload check against the claimed tag: `diff -rq` of `<v1.75.2>/LibKa0s` against `libs/LibKa0s`
printed only `Only in <v1.75.2>/LibKa0s/media/icons` lines (the icons the addon does not declare), and
`<v1.75.2>/testkit` against `tests/_kit` printed nothing (`payload-matches`). **Base: v1.75.2.**

## 3b — Actual version, before this run

The vendored `LibStub` minors were v1.75.2's (the left column of 3c) and `Kit.VERSION` was **41**
(`grep -n 'Kit.VERSION' tests/_kit/framework.lua`). Claim and bytes agree.

## 3c — Per-file minor delta

Walked over the tag's `LibKa0s.xml` rows (40 files, unchanged). Only three move:

| File | v1.75.2 | v1.76.0 |
|---|---|---|
| `Widgets.lua` (`MINOR`) | 13 | **14** |
| `SimTimeline.lua` (`TIMELINE_MINOR`) | 2 | **3** |
| `SimPanel.lua` (`SIM_PANEL_MINOR`) | 4 | **5** |

Every other file is at its v1.75.2 minor. No file is behind: no cross-major skew.

## 3d — Both diffs

Before the prune, against the whole copy: `diff -r --strip-trailing-cr` and `diff -r` of
`<scratch>/LibKa0s` against `libs/LibKa0s` both printed nothing, and the same for `<scratch>/testkit`
against `tests/_kit`. After the prune, the library diff prints only
`Only in <scratch>/LibKa0s/media/icons…` lines for the undeclared icons; nothing is `Only in` the
addon and nothing differs.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`
lists the same lookup sites as v1.75.0: `core/DebugLogSetup.lua`, `core/EnvSetup.lua`,
`core/Lifecycle.lua`, `core/LauncherSetup.lua`, `core/MediaSetup.lua`, `core/Bus.lua`,
`core/CoreSetup.lua`, `core/WidgetsSetup.lua`, `core/PerfSetup.lua`, plus `settings/OptionsSetup.lua`,
`settings/Schema.lua` (Schema and Slash) and `settings/Slash.lua`. Of the moved majors, Widgets is
consumed (`core/WidgetsSetup.lua`; `modules/Bar.lua` and `modules/Display.lua` read `DragHandle` and
`DRAG_HANDLE`) and Sim is not.

## 3f — Kit revision

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua`: **41** on both sides.
The kit is unchanged in this range; both payloads were still copied whole, as the pairing rule
requires.

## 3g — Contract delta

The majors to read are the consumed one that moved: Widgets (13 -> 14). Read
`docs/api/Widgets/version-14.1.4.3.2-docs.md` at the tag against `version-13.1.4.3.2-docs.md` at
v1.75.2. The only change is `TestStrip`'s `opts.kind` and `strip.kind` (both **Since 14**, additive):
"every existing call draws exactly what it drew at 13", and no member is added, removed or renamed.
`DragHandle`, `DRAG_HANDLE` and `CopyWindow`, the members this addon reaches, are unchanged.
`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
host-supplied member affected by Widgets or Sim.

Sim (SimTimeline 3, SimPanel 5: a started simulation plays on its own; Run all and `RUN_ALL` are
gone) is not consumed. `grep -rn 'RUN_ALL\|Run all\|sim run' . --include='*.lua'` outside `libs/`
and `tests/_kit/` finds nothing, so no host string overrides the removed key.

**Blockers: none.**

## 3h — Tags vendored and never recorded

The listing (vendored tags from both payload paths and the provenance-rolling `CLAUDE.md` commits,
minus the tags the bundles record) printed:

```
v1.75.1
v1.75.2
```

Both arrived as standalone re-vendors (`196511a`, `d8de275`) with no bundle. They are recorded in the
consolidated span bundle `docs/revendor/2026-10-23-v1.75.1-v1.75.2/`, written in this run.

## 3i — The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `CLAUDE.md:44:LibKa0s icons: clear, close, copy, help.`, the
next non-blank line after the provenance line. Kept unchanged: this release adds no library-drawn
icon (the tag's `CHANGELOG.md` *What a consumer owes*: "Nothing for the strip"), and this addon calls
no new surface. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop.

## 3j — Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds only
the cases v1.75.0's re-vendor already narrowed to the declaration (`tests/test_mediasetup.lua`,
`tests/test_optionssetup.lua`). No blocker.
