# Cyclomatic complexity

_Generated — do not hand-edit._ Measured 2026-07-29 against **v1.9.0**, addon source only
(`libs/` and `tests/` excluded).

**Regeneration has been pending since the five-module LibKa0s extraction (issue #17); every number
below predates it.** `lizard` is not available in this environment, so the numbers cannot be
re-derived here. Five extractions have moved code out of the addon since the measurement:

| Extraction | Deleted from the addon | What took its place |
|---|---|---|
| `LibKa0s-Core-1.0` | `core/Util.lua` | `core/CoreSetup.lua` (78 lines) |
| `LibKa0s-DebugLog-1.0` | `core/DebugLog.lua` | `core/DebugLogSetup.lua` (110 lines) |
| `LibKa0s-Slash-1.0` | — (`settings/Slash.lua` gutted in place) | `settings/Slash.lua`, now the verb table and host verbs only |
| `LibKa0s-Options-1.0` | `settings/Panel.lua`, `Helpers.lua`, `ScrollPatch.lua`, `Widgets.lua` | `settings/OptionsSetup.lua` (199 lines) + `settings/UnitPanel.lua` (193 lines) |
| `LibKa0s-Perf-1.0` | `core/Perf.lua`, `core/PerfPanel.lua` | `core/PerfSetup.lua` (130 lines) |

Rows for the deleted files have been hand-removed rather than renamed. The numbers would not carry
over: what is left in the addon is a descriptor plus a degradation stub, not the algorithms. The
extracted code's complexity is the LibKa0s repo's to report, not this file's.

Part of issue [#17](https://github.com/tusharsaxena/AbsorbTracker/issues/17). This report is
**advisory**: it is not part of the green gate (`lua tests/run.lua` + `luacheck .`) and no build
fails on a number here. The Ka0s WoW Addon Standard does not yet define a complexity rule — that is
upstream work in [WowAddonStandards](https://github.com/tusharsaxena/WowAddonStandards), and these
numbers exist partly to inform it.

## Regenerating

`lizard` is an **optional dev dependency**, not required to build, test, or ship the addon.

```sh
pipx install lizard          # or: python3 -m venv .venv && .venv/bin/pip install lizard
lizard -l lua core modules settings defaults locales
```

On a PEP 668 "externally managed" system without `pipx` or `python3-venv`, the wheel can be run
without installing anything:

```sh
pip3 download lizard --no-deps -d /tmp/lz
python3 -m zipfile -e /tmp/lz/lizard-*.whl /tmp/lz/x
PYTHONPATH=/tmp/lz/x python3 -m lizard -l lua core modules settings defaults locales
```

## Totals

| Metric | Value |
|--------|-------|
| Files | 30 |
| Functions | 297 |
| Total NLOC | 3,185 |
| Average NLOC per function | 9.4 |
| **Average CCN** | **3.6** |
| Functions over CCN 15 | 7 (2.4%) |

The only figure here re-verified by hand is the file count: addon source is now **28** `.lua` files
across `core/ modules/ settings/ defaults/ locales/`, not 30. The rest await a `lizard` run.

An average CCN of 3.6 is low. The addon is overwhelmingly made of small, single-purpose functions;
the outliers below are concentrated in a handful of places and are all structural rather than
algorithmic. That shape survives regeneration even where the number moves.

## Functions over the default threshold (CCN > 15)

| CCN | NLOC | Function | Why |
|-----|------|----------|-----|
| 21 | 68 | `runProfile` — `settings/Slash.lua:296` | Sub-verb dispatch ladder for `/at profile` |
| 20 | 38 | ~~`Helpers.RenderRows`~~ — `settings/Widgets.lua:275` | Moved to `LibKa0s-Options-1.0`'s `OptionsWidgets.lua` |
| 19 | 44 | `NS:InitDB` — `core/Database.lua:5` | Schema migration branches (v2 → v3 → v4) |
| 18 | 21 | ~~`setEnabled`~~ — `settings/ScrollPatch.lua:36` | Moved to `LibKa0s-Options-1.0`'s `OptionsScroll.lua` |
| 17 | 25 | ~~`Helpers.PatchAlwaysShowScrollbar`~~ — `settings/ScrollPatch.lua:20` | Moved to `LibKa0s-Options-1.0`'s `OptionsScroll.lua` |
| 16 | 48 | `Helpers.BuildMainContent` — `settings/About.lua:38` | Optional metadata fields, each guarded |
| 16 | 18 | ~~`NS.FormatSchemaValue`~~ — now a five-line delegate | The branching moved to `LibKa0s-Slash-1.0`'s `lib.FormatValue` |

The struck rows are kept visible rather than deleted so the record of what the addon used to carry
survives; they are the library's to report now, not this file's. Of the three live rows, none is a
hot path: `runProfile` runs on user command, the `About` function runs once at panel build, `InitDB`
runs once at load. The repaint path — the only code that runs at combat frequency — is entirely in
the low single digits:

| CCN | Function |
|-----|----------|
| 5 | `NS.UpdateAbsorbBar` — `modules/Display.lua` |
| 4 | `NS.ShouldShowBar` — `modules/Display.lua` |
| 3 | `doRepaint` — `modules/Timer.lua` |
| 3 | `NS.RequestRepaint` — `modules/Timer.lua` |
| 4 | `NS.GetSetting` — `core/Data.lua` |

## Per-file averages

| File | NLOC | Functions | Avg CCN |
|------|------|-----------|---------|
| core/AbsorbTracker.lua | 142 | 14 | 4.1 |
| core/Bus.lua | 16 | 1 | 1.0 |
| core/Compat.lua | 12 | 1 | 4.0 |
| core/Data.lua | 136 | 14 | 2.9 |
| core/Database.lua | 121 | 7 | 7.9 |
| core/LSMPatch.lua | 26 | 2 | 6.0 |
| core/Units.lua | 71 | 12 | 3.2 |
| modules/Bar.lua | 57 | 2 | 1.5 |
| modules/Display.lua | 130 | 14 | 4.2 |
| modules/Timer.lua | 29 | 5 | 3.0 |
| settings/About.lua | 67 | 3 | 6.0 |
| settings/Bar.lua | 146 | 4 | 1.8 |
| settings/Border.lua | 81 | 4 | 1.5 |
| settings/Font.lua | 83 | 4 | 1.5 |
| settings/General.lua | 125 | 10 | 1.9 |
| settings/Schema.lua | 209 | 18 | 5.7 |
| settings/Slash.lua | 392 | 38 | 3.9 |
| defaults/Profile.lua | 44 | 2 | 1.0 |
| locales/enUS.lua | 2 | 1 | 1.0 |

Nineteen rows for twenty-eight files. Six rows were removed with their files (`core/Util.lua`,
`core/DebugLog.lua`, `settings/Helpers.lua`, `Panel.lua`, `ScrollPatch.lua`, `Widgets.lua`); the
other nine addon files — `core/Constants.lua`,
`Namespace.lua`, `State.lua`, `CoreSetup.lua`, `PerfSetup.lua`, `DebugLogSetup.lua`,
`settings/OptionsSetup.lua`, `UnitPanel.lua`, `Profiles.lua` — have never had one, some because they
postdate the measurement and some because they predate it and were missed. A `lizard` run fixes both.

The highest per-file average used to belong to `settings/ScrollPatch.lua` (11.4) by a wide margin.
That was expected and hard to avoid — it patched Blizzard's scrollbar internals and was mostly
defensive branching against fields that may or may not exist on a given client build. The same code,
and the same shape, now lives in `LibKa0s-Options-1.0`'s `OptionsScroll.lua`.

## Note on this change

Two functions touched by the performance-instrumentation work were refactored *because* of this
report rather than after it:

- `runPerf` (`settings/Slash.lua`) first landed as an if/elseif ladder measuring **CCN 24** — which
  would have made it the single most complex function in the addon. It is now a dispatch table of
  CCN 1–3 handlers.
- `NS.ApplyVisibility` (`modules/Display.lua`) reached **CCN 21** when a suspended-state rung was
  added to its inline debug-reason chain. The chain is now `visibilityReason`, a separate function.

Neither appears above.
