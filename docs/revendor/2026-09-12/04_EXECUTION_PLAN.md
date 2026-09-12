# 04 — Execution plan

## B1. Delete the local `AceGUI:Release` shim

- **Files:** `tests/wow_mock.lua` (delete the block at `:15-38`, leave a two-line pointer to the
  kit), `docs/module-map.md` rows 31, 32 and 52.
- **Characterization, before the deletion:** with kit 16 copied in and the shim still present,
  run the suite. *the chrome block's widgets go back to AceGUI's pool, after the render and not
  before* (`tests/test_helpers.lua:768`) must pass. Result: 561 passed, 0 failed, 0 skipped. At this
  point the shim still overrides the kit's `Release`, so this pins the behavior the test expects.
- **The assertion that proves the change:** the same case, after the deletion. It asserts
  `w.__released` is `true` on every widget of the previous chrome block (`:795`) and `false` on the
  block the render just built (`:798`). With the shim gone, only the kit's `AceGUI:Release` sets
  that field. So a pass shows the kit's version is the one running, and that
  `settings/UnitPanel.lua:258` hits neither of the kit's raises (nil, double release). Result:
  561 passed, 0 failed, 0 skipped.
- **Commit boundary:** the re-vendor commit. The owner asked for the re-vendor and the shim
  adoption to land together, and the deletion only goes green once the kit that replaces it is in
  the tree. The upstream CHANGELOG also says to delete the shim in the re-vendor commit
  (`CHANGELOG.md:140` at the tag).

No production Lua changes. `libs/` and `tests/_kit/` are written only by the Step 4 copy.
