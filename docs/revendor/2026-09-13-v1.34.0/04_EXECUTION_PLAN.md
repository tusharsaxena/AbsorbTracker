# 04 — Execution plan

1. **Re-vendor**, one commit on `chore/2026-09-12-libka0s-1.33.0`, on top of `8dbda30`. Both
   payloads were copied whole from the tag. Only `Options.lua`, `OptionsCompose.lua`, `Slash.lua`
   and three kit files changed. CR equals LF in every changed file, and the runner stays `100755`.
2. **Docs in the same commit:**
   - the provenance line (`CLAUDE.md:69`) and `docs/testing.md:140`, v1.33.0 → v1.34.0;
   - `docs/module-map.md` row 31: kit revision 19, 3110 lines, `mock_base.lua` 1482;
   - `docs/smoke-tests.md:244`–`:245`, where the geometry flip moves from "revision 19 at the
     earliest" to 20, because kit 19 did not ship it.
3. **Gate:** `lua tests/run.lua` and `luacheck .`, with `tests/test_vendor_sync.lua` comparing both
   payloads against the tag and skipping none.
4. **Adoption (B1)**, its own commit: `profilesPage = true` on the descriptor in
   `settings/OptionsSetup.lua`; a test, red before, that the Reset-all tooltip names the
   equivalence; a test that a multi-word value set through the slash is stored whole; the
   settings-panel and smoke-test lines that describe the tooltip; `docs/test-cases.md` and the
   README badge regenerated.
