# Refresh 2 of v1.85.0

The tag is still local-only (`git -C ../LibKa0s ls-remote --tags origin v1.85.0` prints nothing) and was re-cut again before any push, so this is a second refresh and not a new re-vendor.

- **Old:** `a68f83f`. `libs/LibKa0s/` and `tests/_kit/` matched it, content, before this copy.
- **New:** `97761300cbd2fc4c14c214928eb9e8e0dd8aa419`, tag object `09a835c`.

| File | Constant | Old | New |
|---|---|---|---|
| `Toast.lua` | `MINOR` | 1 | 2 |

No other shipped file moved, and `testkit/` did not move (`git -C ../LibKa0s diff --stat a68f83f 9776130 -- LibKa0s testkit tools`). `Toast.lua` gains `d.soundFile`, which is additive.

**Blocker:** none. No addon code changed.

**Prune:** 12 icons declared, kept 13 files, removed 5827, the declaration unchanged. After it, `diff -rq` against the tag lists only the pruned icons, and `git status` shows `libs/LibKa0s/Toast.lua` as the only payload change, CRLF kept.

**Gate:** 997 passed, 0 failed, 1 skipped; luacheck 0/0 in 81 files.
