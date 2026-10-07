Delta: LibKa0s v1.70.0 -> v1.71.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-07, plan item RV-AT of the 2026-10-07 review and standards-audit remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`), on branch
`feat/2026-10-07-review-audit-remediation`. The run follows `/dev-copilot:wow-revendor-libka0s`
mechanically under the owner's scope ruling for this plan: no interview and no GitHub issue filing;
adoption candidates the plan does not already require are listed as not adopted in this run.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.71.0` (commit `cb274a4`)**, not yet pushed.
The payloads were extracted with `git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x -C
<scratch>`, never a branch tip. `git -C ../LibKa0s log --oneline v1.70.0..v1.71.0` lists 20 commits.
`git -C ../LibKa0s diff --stat v1.70.0 v1.71.0 -- LibKa0s testkit` names 10 files (369 insertions,
140 deletions).

## 3a — Claimed version, before this run

`CLAUDE.md:43` read `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).`, set
by the last payload commit `4c16982`. Payload check against the claimed tag: `diff -rq` of
`<v1.70.0>/LibKa0s` against `libs/LibKa0s` and `<v1.70.0>/testkit` against `tests/_kit` both printed
nothing. **Base: v1.70.0.**

## 3b — Actual version, before this run

The vendored `LibStub` minors were v1.70.0's (the left column of 3c) and `Kit.VERSION` was 37.
Claim and bytes agree.

## 3c — Per-file minor delta

Walked over the tag's `LibKa0s.xml` rows (34 files, unchanged in number):

| File | v1.70.0 | v1.71.0 |
|---|---|---|
| `Env.lua` | 1 | **2** |
| `Slash.lua` | 19 | **20** |
| `SlashParse.lua` | 1 | **2** |
| `WidgetsLineChart.lua` | 2 | **3** |
| `WidgetsAutocomplete.lua` | 1 | **2** |
| `OptionsIdList.lua` | 3 | **4** |

Every other file keeps its v1.70.0 minor: Core 10, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 12 (WidgetsReorder 1, WidgetsDragHandle 4), DebugLog 19 (DebugLogDiagnostics
2, DebugLogGates 1), Launcher 5, Options 28 (OptionsRegistry 2, OptionsWidgets 34, OptionsIds 2,
OptionsTabs 8, OptionsCombat 1, OptionsCompose 7, OptionsScroll 4, OptionsNav 2), Perf 14
(PerfSampler 1, PerfCommands 1, PerfPanel 6). Keys: Slash 20.2, Widgets 12.1.4.3.2, Options
28.2.34.2.4.8.1.7.4.2. No file or major is added, no `NEEDS_*` floor rises.

## 3d — Both diffs

- `libs/LibKa0s`: six files differ (the six in 3c), 174 changed lines in all. No `Only in` line.
- `tests/_kit`: `framework.lua` (91 changed lines; the `--list` renderer moves out, the file drops to
  916 lines), `inventory.lua` (the renderer moves in, with the new Totals), `README.md`, and
  **`secrets.lua` added** (112 lines, `Kit.secret`). Nothing is deleted on either side.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, outside `libs/` and
`tests/`: Env (`core/EnvSetup.lua:62`), Core (`core/CoreSetup.lua:26`), Bus (`core/Bus.lua:36`),
Lifecycle (`core/Lifecycle.lua:61`), Launcher (`core/LauncherSetup.lua:70`), Media
(`core/MediaSetup.lua:82`), DebugLog (`core/DebugLogSetup.lua:14`), Perf (`core/PerfSetup.lua:16`),
Widgets (`modules/Display.lua:26`, `modules/Bar.lua:15`), Options (`settings/OptionsSetup.lua:71`),
Slash (`settings/Slash.lua:24`, `settings/Schema.lua:498`) and Schema (`settings/Schema.lua:328`).
Moved and consumed: **Env, Slash, Widgets, Options.**

## 3f — Kit revision, and the pairing rule

`Kit.VERSION` **37 -> 38**. Both payloads are copied whole in one commit, so the pairing rule holds by
construction. Revision 38's `--list` Totals count only the cases that run: a declared skip moves to a
`| Skipped | N |` row before Total. `docs/test-cases.md` is regenerated in the same commit: the
diagnostics contract's opt-out case (this addon's one declared skip) leaves the
`test_diagnostics_contract.lua` row (9 -> 8) for `| Skipped | 1 |`, and Total goes **877 -> 876**,
which now equals the README badge (876/876, unchanged). This closes review finding `AT-R-07`.

## 3g — Contract delta (under unmoved signatures)

- **Env 2: `Env.GetAddOnMetadata` no longer falls back to the bare `GetAddOnMetadata` global.** It
  answers `C_AddOns.GetAddOnMetadata` or nil. `core/EnvSetup.lua`'s `NS.Meta` calls the library when
  present and, library absent, has its own fallback that reads `C_AddOns.GetAddOnMetadata` only (lines
  74-78), never the bare global. Every supported client has `C_AddOns`. **Confirmed unaffected.**
- **SlashParse 2: `lib.ParseValue` refuses `nan`, `inf`, `-inf` and an overflowing literal on a
  number row** with `ERR_NUMBER`. AbsorbTracker has number rows (`settings/General.lua`,
  `settings/Appearance.lua`) and parses `/at set` through this seam (`settings/Schema.lua`), so `/at
  set <number path> nan` is now refused where it stored a NaN. No case here pinned the old acceptance;
  the suite is green. A fix delivered on the copy, not a blocker.
- **Slash 20**: one comment; nothing that runs moves.
- **OptionsIdList 4**: the help-art guard reads `C_AddOns.IsAddOnLoaded` only. This addon builds no
  IdList (its helper stub in `settings/OptionsSetup.lua` is a no-op), so nothing is reached.
- **WidgetsLineChart 3 / WidgetsAutocomplete 2**: this addon draws no chart and hooks no autocomplete
  box; nothing is reached.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
  site.

**No blockers.**

## 3h — Tags vendored and never recorded

v1.69.0 and v1.70.0 (commits `5075fd5`, `4c16982`) had no bundle. They are recorded by the span bundle
written in the same commit, `docs/revendor/2026-10-07-v1.69.0-v1.70.0/`.
