# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.76.0..v1.77.0` (15 commits) and the `CHANGELOG.md`
v1.77.0 block at the tag. The run's bundle decides the adoptions: AbsorbTracker's are its AT-ZS item
(item 030, frame strata, held for the owner at this launch). AbsorbTracker ships no key binding, so
it has no KB item. Every other candidate is **deferred (run 2026-10-24)**. The Options stub's four
members are a blocker (`01_DELTA.md` 3g), not a candidate, and are not listed here.

## A. Delivered on the copy

- **Toplevel tool windows** (Core 12, DebugLog 21, PerfPanel 9; tag `CHANGELOG.md:71-98`): the
  debug console and the perf panel raise among their DIALOG peers on click and re-raise a shown
  StaticPopup on show, so a console opened over the *Reset all settings* confirmation no longer
  buries it.
- **Clamped popups** (Widgets 15, WidgetsAutocomplete 3; `CHANGELOG.md:128-150`): a dropdown menu
  near a screen edge stays on screen.
- **OptionsKeybinds 3, OptionsIds 3, OptionsCombat 2**: nothing visible here; the addon draws no
  Keybindings tab and no id list.

## B. New surfaces (host change required)

- `W.DragHandle` `level`, `ignoreParentAlpha` and `handle:ApplyLevel()` (WidgetsDragHandle 5,
  `CHANGELOG.md:99-127`; `docs/api/Widgets/version-15.1.5.3.3-docs.md`) — **AT-ZS** (the library's
  `docs/api/CONSUMERS.md` plans AbsorbTracker for it). Touches `modules/Bar.lua`,
  `modules/Display.lua`. Additive.
- Kit revision 42 `mock_layers.lua` (`docs/api/testkit/version-42-docs.md`) — **AT-ZS**, for its
  strata tests. Additive, opt-in.
- `O.StrataTooltip(values, strings)` (OptionsCompose 8, `CHANGELOG.md:181-211`) — deferred (run
  2026-10-24): the addon has no player strata row. Additive.
- `O.KeybindingsTab`, `O.KeybindRows`, `O.KEYBINDS_UNCHANGED` (OptionsKeybinds 2,
  `CHANGELOG.md:257-311`) — deferred (run 2026-10-24): no `Bindings.xml`, no binding to list.
  Additive.
- `Core.RaiseStaticPopups()` (Core 12, `CHANGELOG.md:71-98`) — deferred (run 2026-10-24): the addon
  owns no window of its own that a confirmation could fall under. Additive.
- Kit `mock_bindings.lua`, `Kit.assertBindingsXml`, `Kit.keybindThroughTab` — deferred (run
  2026-10-24): no bindings to test. Additive, opt-in.

## C. Whole-module adoption

- `LibKa0s-Glow-1.0` — deferred (run 2026-10-24): the addon draws no glow (unchanged since v1.75.0's
  `02_CANDIDATES.md`).
- `LibKa0s-Sim-1.0` — deferred (run 2026-10-24): the addon has no simulator; the unlocked bar is the
  preview (unchanged since v1.76.0's `02_CANDIDATES.md`).
