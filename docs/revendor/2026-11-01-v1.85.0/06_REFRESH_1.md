# Refresh 1 of v1.85.0

The tag was local-only (`git -C ../LibKa0s ls-remote --tags origin v1.85.0` prints nothing) and was re-cut before any push, so this is a refresh and not a new re-vendor.

- **Old:** `3407f43`, tag object `a2432e4`. `libs/LibKa0s/` and `tests/_kit/` matched it, content, before this copy.
- **New:** `a68f83ff67f585012d946fb1d69cf52e6d24aa43`.

| File | Constant | Old | New |
|---|---|---|---|
| `Skin.lua` | `MINOR` | 13 | 14 |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` | 13 | 15 |

No other shipped file moved, and `testkit/` did not move: kit revision 49 on both sides (`git -C ../LibKa0s diff --stat 3407f43 a68f83f -- LibKa0s testkit`).

**Blocker, fixed in this commit:** `tests/test_surface_parity.lua`'s facade parity went red with `BarGloss` and `HudFont` missing from the degraded facade in `core/SkinSetup.lua`. `BarGloss` is a no-op; `HudFont` draws, because a no-op would leave the value text with no face.

**Prune:** 12 icons declared, kept 13 files, removed 5827, the declaration unchanged. Both diffs were empty before the prune, content and bytes.

**Gate:** 996 passed, 0 failed, 1 skipped; luacheck 0/0 in 81 files.
