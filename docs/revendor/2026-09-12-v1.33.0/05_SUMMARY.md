# 05 — Summary: LibKa0s v1.32.0 → v1.33.0

## The move

| | |
|---|---|
| From | v1.32.0 (`e18dd12`) |
| To | **v1.33.0** (tag `7d5e061`, commit `06ee368`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (`MINOR` 16 → 17), `Slash.lua` (`MINOR` 8 → 9) |
| Kit revision | 17 → **18** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **Font dropdowns draw every row on their first open.** The library loads every LSM face the first
  time a Ka0s settings panel is shown, after the combat refusal. The Appearance page's
  `H.FontGroup` rows are the `LSM30_Font` dropdowns that benefit. This still needs an in-game
  check. Open Settings → Absorb Tracker → Appearance → any font dropdown, on a fresh session, and
  every row should draw on the first open.
- **The kit's `OnProfileCopied` names the source profile**, as real AceDB does. No test changes
  outcome.

## What was adopted, and what was declined

Nothing needed a host change, so there was nothing to adopt or decline. No issue was filed.

## Gates

| When | `lua tests/run.lua` | `luacheck .` | lizard `-C 15` |
|---|---|---|---|
| Baseline, `6aa8fbc` | 588 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |
| Re-vendor (this bundle's commit) | 588 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |

`tests/test_vendor_sync.lua` compared both payloads against the tag `CLAUDE.md` names and skipped
none. Both `diff -r` forms against `../LibKa0s` are empty for both payloads. Every changed file is
CRLF, with CR equal to LF. Nothing was pushed.
