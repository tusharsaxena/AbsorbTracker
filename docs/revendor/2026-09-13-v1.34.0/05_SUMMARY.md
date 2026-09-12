# 05 — Summary: LibKa0s v1.33.0 → v1.34.0

## The move

| | |
|---|---|
| From | v1.33.0 (tag `7d5e061`, commit `06ee368`) |
| To | **v1.34.0** (tag `9165044`, commit `33bae81`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (`MINOR` 17 → 18), `OptionsCompose.lua` (`_MINOR` 4 → 5), `Slash.lua` (`MINOR` 9 → 10) |
| Kit revision | 18 → **19** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **A multi-word value set through the slash is stored whole.** `/at set <font row> Friz Quadrata
  TT` used to store `"Friz"`, or be refused against the row's `values`. It now stores the full name.
- **The Reset-all tooltip says "current profile".** The descriptor supplies `resetProfile`, so on
  the copy alone the tooltip reads *"Reset the current profile to its defaults. Your other profiles
  are not affected."*
- Kit 19 changes nothing observable here (see 01_DELTA §3f).

## What was adopted, and what was declined

B1, `profilesPage = true`, is adopted in its own commit (see 04_EXECUTION_PLAN). Nothing was
declined. No issue was filed.

## Gates

| When | `lua tests/run.lua` | `luacheck .` | lizard `-C 15` |
|---|---|---|---|
| Baseline, `8dbda30` | 588 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |
| Re-vendor (this bundle's commit) | 588 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |
| Adoption (B1 + the slash pin) | 590 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |

The adoption commit adds two cases. `tests/test_optionssetup.lua`'s tooltip case fires the General
page's real *Reset all settings* button and reads the `GameTooltip:AddLine` body; it was red before
`profilesPage = true` (it read the `RESET_ALL_TIP_PROFILE` wording). `tests/test_slashcmds.lua`'s
case sets `units.player.fontFlags` to `OUTLINE, MONOCHROME` through `/at set`; it was red with
v1.33.0's `Slash.lua` swapped in (refused: `"OUTLINE,"` is not a value) and green on minor 10.

`tests/test_vendor_sync.lua` compared both payloads against the tag `CLAUDE.md` names and skipped
none. Both `diff -r` forms against `../LibKa0s` are empty for both payloads. Every changed file is
CRLF, with CR equal to LF. Nothing was pushed.
