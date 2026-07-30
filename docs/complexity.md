# Cyclomatic complexity

_Generated — do not hand-edit._ Measured 2026-07-29 against **v1.9.0**, addon source only
(`libs/` and `tests/` excluded).

**Stale since the `LibKa0s-Perf-1.0` extraction (issue #17):** `core/Perf.lua` and
`core/PerfPanel.lua` are gone (deleted, moved into the vendored library) and `core/PerfSetup.lua`
(~111 lines) has taken their place, but `lizard` is not available in this environment to regenerate
the numbers below. The `core/Perf.lua` row has been hand-removed so the table doesn't cite a deleted
file; everything else below (including `core/PerfPanel.lua`'s absence, which predates this table)
is un-regenerated and should be treated as informative rather than current until the next
`lizard` run. **Regeneration is pending.**

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

An average CCN of 3.6 is low. The addon is overwhelmingly made of small, single-purpose functions;
the outliers below are concentrated in a handful of places and are all structural rather than
algorithmic.

## Functions over the default threshold (CCN > 15)

| CCN | NLOC | Function | Why |
|-----|------|----------|-----|
| 21 | 68 | `runProfile` — `settings/Slash.lua:434` | Sub-verb dispatch ladder for `/at profile` |
| 20 | 38 | `Helpers.RenderRows` — `settings/Widgets.lua:275` | Row pairing / layout decisions |
| 19 | 44 | `NS:InitDB` — `core/Database.lua:138` | Schema migration branches (v2 → v3 → v4) |
| 18 | 21 | `setEnabled` — `settings/ScrollPatch.lua:36` | Blizzard scrollbar state permutations |
| 17 | 25 | `Helpers.PatchAlwaysShowScrollbar` — `settings/ScrollPatch.lua:20` | Defensive nil-guards over Blizzard internals |
| 16 | 48 | `Helpers.BuildMainContent` — `settings/About.lua:36` | Optional metadata fields, each guarded |
| 16 | 18 | `NS.FormatSchemaValue` — `settings/Schema.lua:173` | One branch per schema value type |

None is a hot path. `runProfile` and `FormatSchemaValue` run on user command; the `ScrollPatch` and
`About` functions run once at panel build; `InitDB` runs once at load. The repaint path — the only
code that runs at combat frequency — is entirely in the low single digits:

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
| core/DebugLog.lua | 296 | 41 | 2.3 |
| core/LSMPatch.lua | 26 | 2 | 6.0 |
| core/Units.lua | 71 | 12 | 3.2 |
| core/Util.lua | 22 | 4 | 2.2 |
| modules/Bar.lua | 57 | 2 | 1.5 |
| modules/Display.lua | 130 | 14 | 4.2 |
| modules/Timer.lua | 29 | 5 | 3.0 |
| settings/About.lua | 67 | 3 | 6.0 |
| settings/Bar.lua | 146 | 4 | 1.8 |
| settings/Border.lua | 81 | 4 | 1.5 |
| settings/Font.lua | 83 | 4 | 1.5 |
| settings/General.lua | 125 | 10 | 1.9 |
| settings/Helpers.lua | 302 | 24 | 3.7 |
| settings/Panel.lua | 78 | 8 | 3.6 |
| settings/Schema.lua | 209 | 18 | 5.7 |
| settings/ScrollPatch.lua | 97 | 5 | 11.4 |
| settings/Slash.lua | 392 | 38 | 3.9 |
| settings/Widgets.lua | 221 | 32 | 3.2 |
| defaults/Profile.lua | 44 | 2 | 1.0 |
| locales/enUS.lua | 2 | 1 | 1.0 |

`settings/ScrollPatch.lua` has the highest per-file average (11.4) by a wide margin. That is
expected and hard to avoid: it patches Blizzard's scrollbar internals and is mostly defensive
branching against fields that may or may not exist on a given client build.

## Note on this change

Two functions touched by the performance-instrumentation work were refactored *because* of this
report rather than after it:

- `runPerf` (`settings/Slash.lua`) first landed as an if/elseif ladder measuring **CCN 24** — which
  would have made it the single most complex function in the addon. It is now a dispatch table of
  CCN 1–3 handlers.
- `NS.ApplyVisibility` (`modules/Display.lua`) reached **CCN 21** when a suspended-state rung was
  added to its inline debug-reason chain. The chain is now `visibilityReason`, a separate function.

Neither appears above.
