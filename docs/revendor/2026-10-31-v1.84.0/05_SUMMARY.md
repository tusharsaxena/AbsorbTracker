# 05 — Summary: LibKa0s v1.83.0 -> v1.84.0

Run 2026-10-31, item AT-RV, on branch `feat/2026-10-31-findings-remediation`. The addon version was not
bumped, no issue was filed, and `libs/` and `tests/_kit/` were not touched after the copy and the
declaration-driven prune.

## The move

From **v1.83.0** (the base the provenance line named) to **v1.84.0** (local tag, commit `e917ccd`). The
per-file minors are in `01_DELTA.md`. Now twenty majors across sixty-four files, with nine new files, and
kit revision 46 to **47**. Nothing was deleted on inference. No span bundle or base correction was owed.

## Reached the addon for free

The drag strip's fit (WidgetsDragHandle minors 9 and 10), the peels, and DebugLogDiagnostics minor 6.

## Contract blockers (3g)

One, fixed in the copy commit: `O.PositionBlock` is owed by the Options stub (tag `CHANGELOG.md`, the
LibKa0s#59 block; Options document line 43). The copy turned the Options parity case red; the stub in
`settings/OptionsSetup.lua` now answers no rows and an inert hook, and `tests/test_optionssetup.lua`
pins that.

## The icon subset

`LibKa0s icons: clear, close, copy, help, settings.` is kept. The prune kept 6 files and removed 5,834.
The README's `## Credits` is unchanged. No dead stub mirror exists.

## Adopted, declined, unreached

Nothing adopted (AT-ADOPT: no named adoption), so no adoption commit. All class B and C candidates are
declined in `03_DECISIONS.md`, none filed, by the run's brief.

LibKa0s#67: none. Every `disabledIf` here (`settings/Appearance.lua`'s `followsSkin`) is a row that only
matters while a check box is off, which options-ui §22 keeps. No dropdown or check box picks a group of
rows, and a linked unit's rows are replaced by the library's `disabledReplaces` notice, not dimmed.

LibKa0s#68: fits by computation. `modules/Display.lua` calls `ApplyWidth(barWidth)` on each pass, floored
at the bar's width, and a bar narrower than its strip's natural 126 px at most gets a wider strip. No
fix. SKIN-34 is the owner's in-client check.

## Gates

After the copy, before the stub: 971 passed, 1 failed (the Options parity case above), 1 skipped; luacheck 0/0 in 80 files. At the commit: 973 passed, 0 failed, 1 skipped; luacheck 0/0 in 80 files.

The drag strip's in-client sweep is SKIN-34 in `docs/smoke-tests.md`, the owner's to run.
