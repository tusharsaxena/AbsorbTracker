# 05 — Summary: LibKa0s v1.29.0 → v1.30.0

## The move

| | |
|---|---|
| From | v1.29.0 |
| To | **v1.30.0** (tag commit `e369e0f`) |
| Files that moved in `libs/LibKa0s/` | **none**. Every minor is what v1.29.0 shipped |
| Kit revision | **15 → 16** (`README.md`, `framework.lua`, `mock_base.lua`, `vendor_sync.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **The runner-mode case** (#28). `tests/test_vendor_sync.lua` passes no opts, so
  `VendorSync.register` adds *the automated-test runner is recorded executable (100755)* on its own.
  It passes. The total moves 560 → 561, and `docs/test-cases.md` and the README `Tests` badge move
  with it.
- **AceEvent's event half on an Embed** (#29) and **`Printf`** (#30) change nothing here. This addon
  registers events only on the `NewAddon` target, and it has no `Printf`.

## What was adopted

- **B1: the local `AceGUI:Release` shim is deleted** (`tests/wow_mock.lua`, formerly `:15-38`). The
  kit's `Release` sets the same `w.__released` field, and it is now what
  `tests/test_helpers.lua:768-803` exercises. Landed in the re-vendor commit, with
  `docs/module-map.md` rows 31, 32 and 52 corrected.

## Other live references moved with the tag

`CLAUDE.md:69` (the provenance line), `docs/testing.md:140`, `DEPENDENCIES.md` (the vendor-sync
citations moved with `vendor_sync.lua`'s growth, and the third case is named),
`docs/smoke-tests.md:242` (the geometry flip did not ship at kit 16).

## What was declined

Nothing. No issue was filed, and none is owed.

## Skipped or unreached

Nothing.

## Gates

| When | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, master | 560 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| Kit 16 copied, shim still present (characterization) | 561 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| Shim deleted, docs updated | 561 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |

`luacheck` excludes `libs/` and `tests/_kit/` by design (`.luacheckrc`), and it does lint
`tests/wow_mock.lua`, the one file the adoption changed. `tests/test_vendor_sync.lua` passed all
three cases with the sibling present, so none was skipped. Nothing was pushed.
