# 05 — Summary: LibKa0s v1.70.0 -> v1.71.0

Run 2026-10-07, plan item RV-AT, on branch `feat/2026-10-07-review-audit-remediation`. The addon
version was not bumped, no issue was filed, and `libs/` and `tests/_kit/` were not touched after the
copy.

## The move

The vendored LibKa0s moved from **v1.70.0** to **v1.71.0** (local tag, commit `cb274a4`). Six library
minors move: Env 2, Slash 20 / SlashParse 2, WidgetsLineChart 3, WidgetsAutocomplete 2, OptionsIdList
4. The kit moves from revision **37 to 38** and gains `secrets.lua`. Nothing is deleted.

## Delivered for free (class A)

- `docs/test-cases.md` Totals no longer count the declared skip: `| Skipped | 1 |`, Total 876, equal
  to the README badge (review finding `AT-R-07`).
- `/at set` refuses `nan` and the infinities on a number row.

## Contract blockers (3g)

None. Env 2's dropped bare-global rung does not reach `core/EnvSetup.lua`, whose own fallback reads
`C_AddOns` only.

## Also in the copy commit

- The `CLAUDE.md` provenance line moves to v1.71.0.
- The span bundle `docs/revendor/2026-10-07-v1.69.0-v1.70.0/` records v1.69.0 and v1.70.0 (audit
  finding `AT-A-01`).
- Prose that restates the vendored tag or kit revision elsewhere (`docs/testing.md`,
  `docs/module-map.md` row 31) is left to plan item AT-09's doc sweep.

## Adopted, declined, unreached

- **Adopted**: none.
- **Not adopted in this run**: `Kit.secret`, `ChartMath.ClipSegment`, the LineChart hover re-sync,
  the Autocomplete re-hook (see `02_CANDIDATES.md`).
- **Planned elsewhere**: the Widgets setup seam, AT-02.

## Gates on the copy commit

All run through `ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 69 files |
| `lua5.1 tests/run.lua` | 876 passed, 0 failed, 1 skipped, 877 total (the skip is the declared diagnostics opt-out case) |
| `tests/test_vendor_sync.lua` | passes against the v1.71.0 payload |
| `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | 0 warnings (no function above CCN 15), 2121 functions |
| vendor parity | `diff -r` against the tag is empty for both payloads |

In-game smoke (owner): `/reload` on the v1.71.0 payload, no Lua errors; `/at` opens help, the
settings panel opens, unlock shows the drag strips.
