Delta: LibKa0s v1.56.0 -> v1.57.0

# 01 — Delta

Run: 2026-09-24, plan item M5-AT of the 2026-09-23 review and standards-audit remediation (milestone
M5, the always-on launcher status tooltip). An orchestrated session took steps 2–4 of the local
`../wow-addon/commands/revendor-libka0s.md` by hand, with no interview. The one adoption this release
asks for (the Launcher minor-3 descriptor fields) is the rest of the same plan item and lands in its
own `M5-AT:` commit, so the bundle carries `01_DELTA.md` and `05_SUMMARY.md` only. Nothing was filed
or pushed. Target: this repo, branch `feat/2026-09-23-review-audit-remediation` @ `8a7818a`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.57.0` (tag object `d03e836` -> commit
`aa37bc9`)**, extracted with `git -C ../LibKa0s archive v1.57.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree. The tag exists only in `../LibKa0s` and has not been pushed.

`git -C ../LibKa0s log --oneline v1.56.0..v1.57.0` lists 2 commits: LK-36's Launcher minor 3
(`281f26f`) and its release run (`aa37bc9`).

## Base pre-flight

The newest single-tag bundle, `docs/revendor/2026-09-23-v1.56.0/`, names base v1.55.0 and new
v1.56.0 on line 1. The provenance line named v1.56.0 before this run, and
`git log -- libs/LibKa0s tests/_kit` puts `aa4c783 RV-AT: Re-vendor LibKa0s v1.56.0` as the last
copy. The chain is unbroken, no tag went unrecorded and no span bundle is owed.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:43`: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
**v1.56.0** (MIT). `README.md` has no provenance line. `docs/testing.md:170` restates the vendored
tag in prose and moves with it.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?([A-Z_]*MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives
v1.56.0's block (the left column of 3c). `grep -n 'Kit.VERSION' tests/_kit/framework.lua` gives
kit revision 26. Before the copy, the provenance line and the vendored bytes named the same version.

## 3c — Per-file minor delta

The tag's `LibKa0s/LibKa0s.xml` is byte-identical to the vendored v1.56.0 XML (21 `<Script>` rows).

| File | v1.56.0 | v1.57.0 |
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
| **`Launcher.lua`** | 2 | **3** |
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

`diff -rq <scratch>/testkit tests/_kit` and the `--strip-trailing-cr` form are both empty: the kit
bytes are v1.56.0's.

The copy was `rm -rf` then `cp -r` of both payloads, with the runner kept executable (git mode
`100755`). After it, both `diff -r` runs are empty.

## 3e — Consumption map

Only the Launcher major moved. `grep -rn 'LibStub("LibKa0s-Launcher' core modules settings` ->
`core/LauncherSetup.lua:62`, the one lookup site. Every other major's consumption is as recorded in
`docs/revendor/2026-09-23-v1.56.0/01_DELTA.md` 3e and is unchanged.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **26 -> 26**.
Both payloads are copied whole in one commit, so the pairing rule holds by construction.

## 3g — Contract delta

`git -C ../LibKa0s diff --stat v1.56.0 v1.57.0 -- docs/api` adds `Launcher/version-3-docs.md` and
`Launcher/members-3.json` (the same member surface as `members-2.json`) and touches only the header
of the superseded `version-2-docs.md`. The CHANGELOG calls the release additive: no `NEEDS_*` floor
rises and no major changes.

One contract moved under an unchanged signature: **the LDB object's `OnTooltipShow` is now always
the library's**, drawing the status tooltip (title and version, `Enabled`, optional `Locked` /
`Test mode`, the host's appended lines, the two click hints), including while the addon is disabled.
A descriptor `onTooltipShow` is now called to APPEND lines, not handed over as the whole hook.

### Blockers

None. On the copy, `luacheck .` reports 0 / 0 in 63 files and `tests/run.lua` reports 766 passed,
0 failed, 766 total.

- **The `OnTooltipShow` flip.** This addon has never passed `onTooltipShow`, and no case in
  `tests/test_launcher.lua` reads the object's `OnTooltipShow`, so the flip reddens nothing. On the
  copy alone the button gains the library's tooltip with the default `Left-click: Toggle`, and no
  version or lock line until the descriptor passes them.

### Not blockers, and owed by launcher-§1 (v2.66.0)

- `version`, `leftClickLabel` (rung (b), ADDONS.md's *lock / unlock*) and `isLocked` (the `locked`
  setting the Master-controls checkbox reads). This addon has no Test mode (options-ui-§15's
  exemption: the unlocked view is the preview), so `isTestMode` is not passed. Adopted in the second
  `M5-AT:` commit.
