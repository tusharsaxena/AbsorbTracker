# 05 — Summary: LibKa0s v1.66.0 -> v1.67.0

Plan item CA-AT-RV of the 2026-10-02 LibKa0s census adoption, run 2026-10-02 on branch
`feat/2026-10-02-libka0s-census-adoption`. Nothing was pushed, no issue was filed, and the addon
version was not bumped. `libs/` and `tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.66.0** to **v1.67.0** (tag object `749c42e`, commit `0bccf4c`),
base taken from the `CLAUDE.md` provenance line. Three files move a minor (Core 9 -> 10, Options
27 -> 28, OptionsIdList 2 -> 3). No file is added or deleted. The kit stays at revision 35 and is
byte-identical to v1.66.0's.

## Delivered for free (class A)

The IdList help-art guard (latent: no IdList here) and the Options 28 docblock correction
(`02_CANDIDATES.md` A).

## Contract blockers (3g)

None. No host code calls `MakeResizable`, and no host code draws an `O.IdList`.

## Also in the copy commit

- `CLAUDE.md` provenance line and `docs/testing.md:170` move to v1.67.0.
- `docs/test-cases.md` regenerated: byte-identical (856 cases). README badge unchanged at 855/855.
- No other live doc stamps a library file's minor, line count or file count that moved.

## Adopted, declined, unreached

- **Taken by a later item in this branch**: B1, the Options descriptor `addonName` (CA-AT-NM).
- **None for this host**: B2, the `MakeResizable` opts.
- **Declined**: none.

## Gates after the copy commit

All run through `/home/tushar/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 68 files |
| `lua tests/run.lua` | 855 passed, 0 failed, 1 skipped, 856 total (before: 855 / 0 / 1, 856) |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, sighted: 0 warnings, max CCN 14, 2144 functions |
| vendor parity | `diff -r` against the tag empty for both payloads |

The copy alone, before the provenance roll, ran 854 passed, 1 failed (the vendor-sync case that
checks the `CLAUDE.md` tag, as expected), 1 skipped.
