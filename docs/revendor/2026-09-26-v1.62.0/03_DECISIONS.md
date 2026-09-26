# Decisions (AbsorbTracker)

- No adoption in this item. The sweep plan puts the candidate interview out of scope, and there is
  no candidate to offer.
- The library-absent stub in `settings/OptionsSetup.lua` needs no new member, because the surface
  did not move. Its comment now names the id members' new home.
- `tests/test_ltrap.lua`'s Options tripwire read a hand-typed list of three files, so the code
  v1.62.0 peeled out of `OptionsWidgets.lua` and `Options.lua` would have left it unseen. It now reads
  every `Options*.lua` off the vendored `LibKa0s.xml` (ten files). Same case, same count.
- The library census in `docs/module-map.md`, `docs/ARCHITECTURE.md` and `docs/performance.md`
  moves from twenty-two files (already one short at v1.61.0) to twenty-seven, with the load order.
- Plan: `Ka0sAddonsCommonTasks/docs/2026-09-26-AUTOMATED_TESTS_SWEEP/`.
