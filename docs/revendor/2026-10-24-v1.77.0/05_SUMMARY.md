# 05 — Summary: LibKa0s v1.76.0 -> v1.77.0

Run 2026-10-24, plan item AT-RV, on branch `feat/2026-10-24-keybinds-layout-strata`. The addon
version was not bumped, the TOC is unchanged, no issue was filed, and `libs/` and `tests/_kit/` were
not touched after the copy and the declaration-driven prune.

## The move

The vendored LibKa0s moved from **v1.76.0** (the base the provenance line named) to **v1.77.0** (local
tag, commit `78240f7`). Twelve files move (`01_DELTA.md` 3c): Core 12, Widgets 15, WidgetsDragHandle
5, WidgetsAutocomplete 3, DebugLog 21, Options 30, OptionsIds 3, OptionsCombat 2, OptionsCompose 8,
PerfPanel 9, SimPanel 6, and the new `OptionsKeybinds.lua` at 3. Now seventeen majors across
forty-one files; the kit moves from revision **41** to **42**. Nothing was deleted on inference.

## Span bundle

None owed (3h printed nothing). No base correction was owed (Step 0 agrees).

## Reached the addon for free

- The debug console and the perf panel are toplevel and re-raise a shown confirmation on show.
- Dropdown menus clamp to the screen.

## Contract blockers (3g)

One, fixed in the copy commit. The Options degradation stub owes `KeybindingsTab`, `KeybindRows`,
`KEYBINDS_UNCHANGED` and `StrataTooltip` (tag `CHANGELOG.md:373-377`;
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:1994`, `:2787-2789`). The copy turned
`parity: the Options stub carries every helper the degraded build can reach` red; the stub in
`settings/OptionsSetup.lua` now answers all four inert, and `tests/test_optionssetup.lua` pins that
(`docs/common-tasks.md`'s test row says so too).

## The icon subset

`LibKa0s icons: clear, close, copy, help.` is kept. `tools/prune-icons.lua` at the tag kept those four
Open Iconic marks and `LICENSE-open-iconic.txt` (5 files) and removed 5,835. The README's
`## Credits` is unchanged (JetBrains Mono and Open Iconic). No dead stub mirror exists
(`grep -rn '__releaseChrome'` outside `libs/` and `tests/_kit/` finds nothing).

## Adopted, deferred, unreached

- **Adopted here**: none. `W.DragHandle`'s `level` / `ignoreParentAlpha` / `ApplyLevel` and the kit's
  `mock_layers.lua` are AT-ZS's.
- **Deferred (run 2026-10-24)**: `O.StrataTooltip`, the Keybindings tab members, `Core.RaiseStaticPopups`,
  the kit's binding mock and checks, `LibKa0s-Glow-1.0`, `LibKa0s-Sim-1.0` (see `02_CANDIDATES.md`).

## Gates on the copy commit

All run through `ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 70 files |
| `lua tests/run.lua` (Lua 5.1.5) | 886 passed, 0 failed, 1 skipped, 887 total (the skip is the declared diagnostics opt-out case) |
| `tests/test_vendor_sync.lua` | passes against the v1.77.0 payload and the declaration |
| vendor parity | kit diff empty; library diff empty apart from the pruned `media/icons` lines |
| line cap | largest authored `.lua` file 1079 lines (`tests/test_slashcmds.lua`) |

## In-game smoke (owner; not run here)

- `/console scriptErrors 1`, then `/reload` twice: no Lua error and no LibKa0s minor-mismatch line.
- `/at debug` opens the console; clicking the Settings panel and then the console raises each in
  turn.
- `/at unlock`: each bar's drag handle still shows its ? and X marks. `/at lock` afterwards.
