# 05 — Execution Plan

Ordered, checkable steps, each tied to its deviation ID. This is the hand-off to the remediation
engagement. **Upstream work comes first** (Sprint 0). The addon re-vendors once upstream has shipped
(Sprint 3). Addon-local work that depends on nothing upstream (Sprints 1–2) may run before or in
parallel with Sprint 0.

The **green gate applies to every step that touches code, tests or config**:
`ka0s-bounded lua tests/run.lua` must pass and `ka0s-bounded luacheck .` must be 0/0. Regenerate
`docs/test-cases.md` and the README `[tests]` badge in the same change whenever the case count moves.

Totals covered: **18 roots + 1 dependent**, plus the Info items that need action upstream (Info-4,
-5, -6, -7). Info-1, -3, -8, -9 and -10 need nothing. Info-2 is optional issue housekeeping (S2.8).

---

## Sprint 0 — Upstream (LibKa0s, WowAddonStandards): do first

- [ ] **S0.1 · AT-62 / AT-63 (LibKa0s).** Ship the Options composers from a unit that loads and
  answers without the `LibKa0s-Options-1.0` shell, keeping the Core floor. Add a library-side suite
  case: on a load missing the Options shell, `MasterControls{…}` still returns the canonical rows.
  Tag a release.
- [ ] **S0.2 · AT-79, kit half (LibKa0s `testkit`).** Respell the kit case names
  `localization-5`, `line-endings-5` and `layout-1` as `localization-§5`, `line-endings-§5` and
  `layout-§1` in `test_prose.lua`, `test_eol.lua` and `test_layout_cap.lua`. Bump the kit revision.
- [ ] **S0.3 · Info-4 (LibKa0s or the standard).** Reconcile `DebugLog.lua` `MAX_BUFFER = 1500` with
  `debug-logging-§1`'s 500.
- [ ] **S0.4 · Info-6, Info-7, Info-5, AT-77 (WowAddonStandards).** Put four questions upstream:
  - the options-ui-§1 fall-together bound versus live host verbs;
  - whether a one-shot value-hold verb is allowed in the lock-is-preview shape;
  - the `AUDIT.md` step 4 / step 5 grading conflict;
  - whether `compat` should carry an applicability condition for an addon with no deprecated API
    beyond `LibKa0s-Env-1.0`.

  Record each outcome, because S2.4, S2.5 and S3.2 branch on them.

## Sprint 1 — Addon-local, no upstream dependency: records and annotations

- [ ] **S1.1 · AT-64, AT-65, AT-69, AT-70, AT-71.** Add the five `# LOAD-BEARING:` comments to
  `AbsorbTracker.toc`, above `core\Namespace.lua`, `core\Bus.lua`, `core\CoreSetup.lua`,
  `core\PerfSetup.lua` and `core\Units.lua`, with the text in `04` §C2. Add one conventional-group
  note. **Check:** re-read each comment against the consumer it names. The gate passes, with no case
  count change.
- [ ] **S1.2 · AT-73.** Retire the `events-frames-taint-§1` row (`docs/ARCHITECTURE.md:652`).
  Turn `:676-697` into a design note citing the carve-out. Fix `docs/ARCHITECTURE.md:507` and the
  comment at `core/AbsorbTracker.lua:84`. **Check:** the register has 3 rows, and
  `grep -n 'events-frames-taint-§1 deviation' -r core docs/ARCHITECTURE.md` finds nothing.
- [ ] **S1.3 · AT-78.** Hand the parts to the printer at `core/DebugLogSetup.lua:47`,
  `core/Lifecycle.lua:173` and `settings/UnitPanel.lua:409`. Correct the `events-frames-taint-§8`
  row's count to the re-measured figure. **Check:** the recorded grep in `03` returns the Slash.lua
  sites only, and the gate passes.
- [ ] **S1.4 · AT-79, addon half.** Respell the citations at `tests/prose_waivers.lua:3` and `:7`,
  `tests/test_docs.lua:194`, `docs/module-map.md:852`, `.pkgmeta:17`, `:20` and `:21`, and
  `.luacheckrc:9`, `:14` and `:78`. **Check:** the malformed-reference grep from `03` returns only kit
  case names until S3.1. The gate passes.
- [ ] **S1.5 · AT-81.** Delete `chatPrint`'s hand-written-tag fallback (`settings/Schema.lua:236-238`).
  **Check:** the gate passes.
- [ ] **S1.6 · AT-80.** Do the doc and comment sweep in `04` §C10: all nine items, then run
  `/wow-addon:sync-docs`. **Check:** each claim re-verified against the tree with the commands in
  `03` §AT-80.

## Sprint 2 — Addon-local, no upstream dependency: code and tests

- [ ] **S2.1 · AT-74.** Add `safeRegister` / `safeRegisterUnit` (pcall per event) in
  `core/AbsorbTracker.lua` and route all seven registrations through them. Record rejects on
  `NS.State.rejectedEvents` and surface them through `/at debug events`, or through the `[Init]` line.
  Add a `M.__badEvents` case with a `red under:` comment. **Check:** `tests/test_disabled.lua` stays
  green, since steps 3 and 9 compare registration sets by name. The new case goes red with the
  `pcall` removed.
- [ ] **S2.2 · AT-67.** Add Perf and Lifecycle parity cases, register the live halves in
  `Kit.setSurfaceSource`, and change the header to "nine". **Check:** the new cases go red if a stub
  member is deleted, verified by mutation and restored from a `cp` backup.
- [ ] **S2.3 · AT-60.** Add the wrap-stability case in `tests/test_widgets.lua`, reading
  `M.__atlasSizes`. **Check:** it goes red under "pitch from the active atlas", and a red at the
  current tag is reported to LibKa0s rather than patched locally.
- [ ] **S2.4 · AT-76** (branch on S0.4). If the standard stands, move the value hold under
  `/at debug hold …`, remove `test` from `NS.COMMANDS`, and update the README (`:34-36`, `:120`,
  through the de-AI pass), `docs/slash-dispatch.md`, `docs/smoke-tests.md`, the slash and disabled
  suites and `docs/test-cases.md`. If upstream permits the verb, close `AT-76` as compliant.
- [ ] **S2.5 · AT-77** (branch on S0.4). Either add `core/Compat.lua` owning the metadata rung
  (loaded first, annotated, with a module-map row and the compat-layer N/A row at "1 shim"), or file
  the `compat` register row, or close it as out of scope under a new applicability condition.
- [ ] **S2.6 · AT-75.** Spill Settings Schema to `schema.md` and Message Bus detail to `data-flow.md`.
  Move the disabled-state essay to a Tier 3 `docs/lifecycle.md` registered under
  `### Addon-specific`. **Check:** `wc -l docs/ARCHITECTURE.md` is ≤ ~400, no mandated section is
  over ~60 lines, and the Documentation map still covers every `.md` exactly once.
- [ ] **S2.7 · AT-62 / AT-63, interim** (only if S0.1 has not shipped yet). Choose `04` §C14 (a),
  the register row, or (b), hollow composers plus degraded host verbs that refuse honestly with
  three-figure pins. The recommendation is (a).
- [ ] **S2.8 · Info-2 (optional).** Close issue #25 (resolved) and re-triage #26 (Widgets is now
  bound). This is issue-store housekeeping and not a deviation.

## Sprint 3 — Re-vendor and records (after Sprint 0 ships)

- [ ] **S3.1 · AT-62 / AT-63 / AT-79 (kit).** Re-vendor LibKa0s at the tag carrying S0.1 and S0.2.
  Copy the whole `LibKa0s/` and the whole `testkit/`, move the `CLAUDE.md:43` provenance line in the
  same commit, and run `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`. Delete the
  Options stub's composer copies (`settings/OptionsSetup.lua:237-377`, `composeBlock`, `ORDER_STEP`)
  in favor of the library's degraded composers. Retire the S2.7 row if one was filed. Re-point
  `tests/test_perf.lua:501` and `tests/test_optionssetup.lua:233-243` at the library's arms. Regenerate
  `docs/test-cases.md`. **Check:** both `diff -r` checks against the new tag are empty,
  `test_vendor_sync` passes, and `#NS2.Schema == #NS.Schema` holds with no host copy.
- [ ] **S3.2 · AT-72.** Write the consolidated re-vendor bundle
  `docs/revendor/<date>-v1.18.0-v<new-tag>/` (`01_DELTA.md` naming the span and the 24 backlog tags
  plus the S3.1 tag, and `05_SUMMARY.md`). **Check:** the `AUDIT.md` step 4 script reports **0**
  unrecorded tags.
- [ ] **S3.3 · Close-out.** Run the full four-suite bundle
  (`tests/_kit/run-automated-tests.sh`) so `RESULTS.md` gains its first row with commit and clean
  cells. This also re-aligns the band table with the census (Info-3). Then re-run
  `/wow-addon:standards-audit` into a new dated folder. Its target is **0 roots** beyond ratified
  register rows.

---

## Traceability

| ID | Sprint step(s) |
|---|---|
| AT-60 | S2.3 |
| AT-62 | S0.1 → S2.7 (interim) → S3.1 |
| AT-63 | S0.1 → S2.7 → S3.1 |
| AT-64 | S1.1 |
| AT-65 | S1.1 |
| AT-67 | S2.2 |
| AT-69 | S1.1 |
| AT-70 | S1.1 |
| AT-71 | S1.1 |
| AT-72 | S3.2 |
| AT-73 | S1.2 |
| AT-74 | S2.1 |
| AT-75 | S2.6 |
| AT-76 | S0.4 → S2.4 |
| AT-77 | S0.4 → S2.5 |
| AT-78 | S1.3 |
| AT-79 | S0.2 → S1.4 → S3.1 |
| AT-80 | S1.6 |
| AT-81 | S1.5 |
| Info-2 | S2.8 |
| Info-4 | S0.3 |
| Info-5 / 6 / 7 | S0.4 |
