# 04 — Execution plan

**Written after the fact** (see 01_DELTA). This is the plan as it was carried out, reconstructed
from the commits on `chore/2026-09-14-libka0s-v1.35.0` (merged to `master` at `17e3ada`).

1. **Re-vendor** (`46de577`, on top of `9590af5`). Both payloads were copied whole from tag v1.35.0
   (`6036c26`). Only `OptionsWidgets.lua` and four kit files changed (three modified, `mock_ids.lua`
   added). The runner stays `100755`.
2. **Docs in the same commit:**
   - the provenance line (`CLAUDE.md:69`) and `docs/testing.md:140`, v1.34.0 → v1.35.0;
   - `docs/module-map.md` row 31: kit revision 20, 3319 lines, `mock_base.lua` 1487, and a
     `mock_ids.lua` (204) clause saying no suite here installs it;
   - `tests/test_surface_parity.lua`: the six new members were exempted by name, with the reason.
3. **Stub members** (`8506cea`), by owner decision. Test first: the six left the parity case's
   ignore list and the case went red naming all six. Then `settings/OptionsSetup.lua` gained them
   inert, and `docs/module-map.md`'s count for that file went from 438 to 443.
4. **Doc sync** (`30ad410`). `docs/module-map.md` row 20 and `docs/settings-panel.md:58` describe
   the inert members. `docs/smoke-tests.md`'s geometry-flip note moves to "revision 21 at the
   earliest", because kit 20 shipped the id-lookup fakes rather than the flip. Three module-map
   line counts were corrected.
5. **Gate** at each step: `lua tests/run.lua` and `luacheck .`, with `tests/test_vendor_sync.lua`
   comparing both payloads against the tag and skipping none.
6. **This bundle** (`chore/2026-09-14-last-nits`), written afterwards. It is documentation only and
   touches no code, `libs/` or `tests/_kit/`.
