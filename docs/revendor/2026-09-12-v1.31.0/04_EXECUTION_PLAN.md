# 04 — Execution plan

No adoption was implemented, so there is no characterization test to write. The run had one code
boundary, and two follow-ups the triage brief asks every addon to do in wave B2:

1. **Re-vendor** (commit `93bf7ad`). Both payloads copied whole from the tag. CRLF restored
   through git's filter; CR equals LF in every changed file, and the runner is still recorded
   `100755`. The provenance line (`CLAUDE.md:69`) moves in the same commit, with the live
   references:
   - `docs/testing.md:140`, the tag;
   - `docs/module-map.md` row 31, the kit revision, the kit line count 2405 → 3052, and
     `mock_base.lua` 777 → 1424;
   - `docs/smoke-tests.md:242-243`, where the geometry flip is now revision 18 at the earliest.

   `DEPENDENCIES.md:157` and `tests/wow_mock.lua:15` name kit revision 16 as the revision that
   **introduced** something. That stays true, so both are left alone.
2. **Brief §9, the named-state sweep** (commit `8099786`). The perf capture ring
   `AbsorbTrackerPerfDB` is named in `docs/ARCHITECTURE.md` → Settings Schema: the owner is
   `core/PerfSetup.lua`, and the one writer is the library's `P.Save`, reached by
   `/at perf finish`. `docs/data-flow.md` stops linking to a deviation row that retired on
   2026-08-05. Documentation only.
3. **Brief §8, the purge-trace check.** No code change: the addon has no forget, purge or delete
   verb over learned or recorded data. See 05_SUMMARY.

Assertion standard: the suite total (565) and `docs/test-cases.md` are unchanged, and
`lua tests/run.lua --list` still matches the committed inventory byte for byte (CR stripped).
