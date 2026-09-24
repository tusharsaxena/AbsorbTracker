# 05 — Summary: LibKa0s v1.57.0 -> v1.58.0

Plan item M6-AT of the 2026-09-23 review and standards-audit remediation, run 2026-09-25 on branch
`feat/2026-09-23-review-audit-remediation`. Nothing was pushed and the addon version was not bumped.
`libs/` and `tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.57.0** to **v1.58.0** (tag object `93cf3ad`, commit `34931c9`).
One commit copied both payloads whole, rolled the `CLAUDE.md` provenance line and the prose
restatement in `docs/testing.md`, and adopted the new contract. One library file moves a minor,
`Launcher.lua` 3 -> 4, and no file is added or removed (`01_DELTA.md` 3c). The kit stays at
revision 26, byte-identical.

## Contract blockers (3g)

Seven cases pinned Launcher minor 3's buttons and hints and reddened on the copy. They are rewritten
against minor 4 in the same commit; none was a regression.

## Adopted, declined, skipped

- **Adopted** in the same `M6-AT:` commit: the options-menu pairs `isEnabled` / `setEnabled` and
  `isLocked` / `toggleLock`. Each toggle runs the slash verb's own `NS.COMMANDS` handler
  (`/at enable|disable`, `/at lock|unlock`), so the write seam, the combat refusal and the echo are
  the verb's. The entries match WowAddonStandards' `ADDONS.md` row (`Enabled · Locked`).
- **Dropped**: the retired `onClick`, `leftClickLabel` and `disabledLine`, and the now-unread
  `Lock / unlock` locale key (localization-§3).
- **Not applicable**: `isTestMode` / `toggleTestMode` (no Test mode: options-ui-§15's exemption) and
  `isWindowShown` / `toggleWindow` (no primary window).

## Gates after the adoption

| Gate | Result |
|---|---|
| `ka0s-bounded luacheck .` | 0 warnings / 0 errors in 64 files |
| `ka0s-bounded lua5.1 tests/run.lua` | 776 passed, 0 failed, 0 skipped, 776 total |
| `ka0s-bounded lizard` (authored code) | 0 warnings, no function above CCN 15 |
| layout-§1 cap | largest authored file `tests/test_helpers.lua`, 1447 lines |

## OPEN

The in-client check of the menu (`docs/smoke-tests.md` section U, steps 3–5 and 14) waits for the
owner's M6 smoke pass.
