# 05 — Summary: LibKa0s v1.68.0 -> v1.68.1

Run 2026-10-04 on branch `feat/2026-10-04-revendor-libka0s-v1.68.1`, non-interactive with the
owner's pre-authorization. The addon version was not bumped, no issue was filed, and `libs/` and
`tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.68.0** to **v1.68.1** (tag object `9fb7956`, commit `9000cbd`),
the library's rename-only release. The base came from the `CLAUDE.md` provenance line and agrees with
the last payload commit (`63b0795`). Every library file is byte-identical between the two tags, so all
32 minors are unchanged (Core 10 through PerfPanel 6, listed in `01_DELTA.md` 3c). The kit moves from
revision **35 to 36**: three files change (`framework.lua`, `run-automated-tests.sh`, `test_eol.lua`),
comments and one printed string only. Nothing is added or deleted. There is no span bundle and no base
correction.

## Delivered for free (class A)

Kit revision 36 names the `dev-copilot` commands. The one visible effect is the runner's `RESULTS.md`
lead-in naming `/dev-copilot:bump-version`, which this addon's next automated-test run writes.

## Contract blockers (3g)

None. No major moved a minor, there is no `__Attach*` site, and the kit change touches no case,
member or mock.

## Also in the copy commit

- The `CLAUDE.md` provenance line and `docs/testing.md:170` move to v1.68.1.
- `docs/module-map.md` row 31 names the held kit as revision 36, as the kit's document asks
  (`version-36-docs.md:59-60`). The file line counts in that row do not change (every edit was
  line-for-line). Other `kit revision 35` mentions in the addon's own files date a feature to the
  revision that introduced it (`DEPENDENCIES.md:96`, `docs/testing.md:99`, `tests/run.lua:174`) and
  stay as they are.
- `docs/test-cases.md` is in sync (`diff <(lua tests/run.lua --list) docs/test-cases.md` is empty).
  The README badge stays at 876/876.

## Adopted, declined, unreached

- **Adopted**: none.
- **Declined**: none.
- **Unreached**: none. There were zero adoption candidates, so no interview was held.

## Gates on the copy commit

All run through `dev-copilot/bin/ka0s-bounded` (the dev-copilot checkout's runner).

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 69 files (`.luacheckrc` excludes `libs/` and `tests/_kit/`; nothing in this change is Lua the addon owns) |
| `lua tests/run.lua` | 876 passed, 0 failed, 1 skipped, 877 total. The skip is the declared diagnostics opt-out case |
| `tests/test_vendor_sync.lua` | all three cases pass: library at the tag, kit at the tag, runner recorded `100755` |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, sighted: 0 warnings, max CCN 14, 2219 functions |
| vendor parity | `diff -r` and `diff -r --strip-trailing-cr` against the tag are empty for both payloads, in both directions |

In-game smoke: none needed. No shipped byte changed.
