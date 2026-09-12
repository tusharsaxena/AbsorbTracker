# 04 — Execution plan

1. **Re-vendor** (`291ee44`). Both payloads were copied whole from the tag. Only `Options.lua` and
   `Slash.lua` changed, and the kit is identical. CR equals LF in both files that changed, and the
   runner stays `100755`. The provenance line (`CLAUDE.md:69`) and `docs/testing.md:140` moved in
   the same commit. Gate: 565/565, luacheck 0/0.
2. **Tests first.** Sixteen cases were written before any code. Fourteen were red against
   `291ee44`. The other two pass on both sides, because they pin behaviour that already held: a
   switch keeps its `[Profile]` line, and a raising reset still reaches the caller and unmutes the
   seam. The case that asserted twenty per-row lines was flipped into two cases: one line with the
   changed count, and the twenty seam writes.
3. **Code** (`aebd427`): `NS.Bulk` and `NS.ProfileRowCount` in `settings/Schema.lua`; the
   descriptor pair and the bracketed degraded stub in `settings/OptionsSetup.lua`; one handler per
   event in `core/Database.lua` and `core/AbsorbTracker.lua`; `NS.Bulk.Run` in
   `Units.CopyFromPlayer`.
4. **Docs, in the same commit:** `ARCHITECTURE.md` (the seam paragraph and the AceDB bus
   paragraph), `data-flow.md`, `profiles.md`, `schema.md`, `settings-panel.md`, `module-map.md`
   (API notes and line counts), `smoke-tests.md` (60a rewritten, 60b added), `test-cases.md`
   (regenerated) and the README `Tests` badge (581/581).

Assertion standard: 581 cases, and `lua tests/run.lua --list` matches `docs/test-cases.md` byte
for byte (CR stripped).
