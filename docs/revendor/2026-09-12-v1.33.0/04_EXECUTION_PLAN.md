# 04 — Execution plan

1. **Re-vendor**, one commit on `chore/2026-09-12-libka0s-1.33.0`, on top of the Profiles `Show()`
   fix (`6aa8fbc`). Both payloads were copied whole from the tag. Only `Options.lua`, `Slash.lua`
   and three kit files changed. CR equals LF in every changed file, and the runner stays `100755`.
2. **Docs in the same commit:**
   - the provenance line (`CLAUDE.md:69`) and `docs/testing.md:140`, v1.32.0 → v1.33.0;
   - `docs/module-map.md` row 31, which is kit revision 18 with 3106 lines. `mock_base.lua` is
     now 1478 lines; the row said 1424 although the file was already 1471 at `6aa8fbc`;
   - `docs/smoke-tests.md`, where the geometry-flip note moves from "revision 18 at the earliest"
     to 19, because kit 18 did not ship the flip;
   - the stale comment at `tests/test_slashcmds.lua:638`.
3. **Gate:** `lua tests/run.lua` and `luacheck .`, with `tests/test_vendor_sync.lua` comparing both
   payloads against the tag and skipping none.

No adoption commit follows, because nothing in Class B exists.
