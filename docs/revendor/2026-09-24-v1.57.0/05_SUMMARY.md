# 05 — Summary: LibKa0s v1.56.0 -> v1.57.0

Plan item M5-AT of the 2026-09-23 review and standards-audit remediation, run 2026-09-24 on branch
`feat/2026-09-23-review-audit-remediation`. Nothing was pushed and the addon version was not bumped.
`libs/` and `tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.56.0** to **v1.57.0** (tag object `d03e836`, commit `aa37bc9`).
One commit copied both payloads whole and rolled the `CLAUDE.md` provenance line, and the prose
restatement at `docs/testing.md:170`. One library file moves a minor, `Launcher.lua` 2 -> 3, and no
file is added or removed (`01_DELTA.md` 3c). The kit stays at revision 26, byte-identical.

## Contract blockers (3g)

None. The library now always owns the LDB object's `OnTooltipShow`, and this addon never passed one.

## Adopted, declined, skipped

- **Adopted** in the second `M5-AT:` commit, not this one: the Launcher minor-3 descriptor fields
  `version` (the TOC's `## Version`), `leftClickLabel` (`Lock / unlock`, rung (b), through `NS.L`)
  and `isLocked` (the `locked` setting).
- **Not applicable**: `isTestMode`, because this addon has no Test mode (options-ui-§15's exemption;
  the lock is the preview switch). `slash`, because the disabled hint reads its command out of
  `NS.Slash:DisabledLine()`, which already names `/at enable`.

## Gates on the copy

| Gate | Result |
|---|---|
| `ka0s-bounded luacheck .` | 0 warnings / 0 errors in 63 files |
| `ka0s-bounded lua5.1 tests/run.lua` | 766 passed, 0 failed, 0 skipped, 766 total |
| `ka0s-bounded lizard` (authored code) | 0 warnings, no function above CCN 15 |
| layout-§1 cap | largest authored file `tests/test_helpers.lua`, 1447 lines |

## OPEN

None.
