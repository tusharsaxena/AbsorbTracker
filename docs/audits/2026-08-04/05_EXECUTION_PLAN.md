# 05 — Execution Plan

Ordered, checkable remediation steps for `02_DEVIATIONS.md`, designed in `04_TECHNICAL_DESIGN.md`.
This is the hand-off to the separate remediation engagement; **this audit changed nothing**.

**Gate for every commit** (`testing-§4`, `versioning-git`): `lua tests/run.lua` green **and**
`luacheck .` at 0/0. Work trunk-based on `master` — no branch unless the user asks
(anti-pattern #21). Do not bump `## Version:` as part of this work: nothing here is a user-facing
feature or fix, and a version bump would drag the `## What's new` roll-forward rule in with it.

**Whole-plan constraint.** Sprints 2 and 3 each add test cases, which moves the total. The README
`[tests]` badge is therefore set **once, in Sprint 4**, from whatever the total is at that point —
not three times. If a sprint is taken in isolation, update the badge in that sprint's own commit
instead (`testing-§5` forbids deferring it past the change that moved the count).

---

## Sprint 1 — Documentation truth (AT-33, AT-36, AT-37, AT-40)

No runtime risk, no test movement. Doing it first clears the noise so the two code sprints are read
against an accurate register.

| # | Step | ID | Done when |
|---|---|---|---|
| 1.1 | Rewrite the 1.9.0 `## Version History` row (`README.md:159`) so its highlights match the eight `## What's new in 1.9.0` bullets — leading with the target/focus bars and the breaking fully-qualified slash paths, keeping the existing four. Preserve the `<br>` cell format. | AT-33 | The row and the section name the same features; `docs/reviews/2026-08-03/` F-007 is answered |
| 1.2 | Sweep every retired `§N.M` reference to `filename-§N` using the mapping table in `04_TECHNICAL_DESIGN.md` D-4. 15 source files plus `docs/ARCHITECTURE.md`. | AT-36 | `grep -rnE '§[0-9]+\.[0-9]+' core modules settings locales defaults docs/ARCHITECTURE.md` returns only `core/Units.lua:8` (the addon's own spec ref) |
| 1.3 | Fix the malformed `slash-commands-§:` at `settings/Slash.lua:199` → `slash-commands-§3`, and close the two half-converted refs at `core/DebugLogSetup.lua:107` and `core/AbsorbTracker.lua:79`. | AT-36 | Included in 1.2's grep |
| 1.4 | In `docs/ARCHITECTURE.md` `## Standards Deviations`: delete the `X-Wago-ID` entry outright; convert the `AbsorbTrackerPerfDB`, `lizard` and bracket-idiom entries to one-line "adopted by the standard in v2.12.0" notes and delete their "Pending promotion" paragraphs. Keep the four live entries. | AT-37 | The section lists only genuine open decisions |
| 1.5 | `modules/Bar.lua:6` — replace the reference to the deleted `core/DebugLog.lua` with the real readers. | AT-40 | Comment names files that exist |
| 1.6 | Green gate; commit as one docs commit. | — | `lua tests/run.lua` green, `luacheck .` 0/0 |

**Do not touch** `docs/audits/2026-07-12/`, `docs/audits/2026-07-18/` or `docs/reviews/2026-08-03/` —
frozen runs (`audit-review-history`).

---

## Sprint 2 — Lazy-build the Profiles page (AT-34)

The one deviation with a real in-game symptom. Small, isolated, and needs a smoke test.

| # | Step | ID | Done when |
|---|---|---|---|
| 2.1 | **Test first.** Register `AceDBOptions-3.0`, `AceConfig-3.0` and `AceConfigDialog-3.0` fakes through `M.__libs` in `tests/wow_mock.lua` so the Profiles builder stops self-skipping headlessly. Confirm the existing "the Profiles page self-skips when AceDBOptions is unavailable" case still passes with the fakes absent. | AT-34 | Both paths reachable from the suite |
| 2.2 | **Failing case.** Assert no AceGUI widget is created during `build`, exactly one `SimpleGroup` after the first `OnShow`, and still one after a second. It must be **red** against today's code — that is the point of writing it first. | AT-34 | Case red |
| 2.3 | Move the `AceGUI:Create("SimpleGroup")` and its five anchoring lines from `build` into the `OnShow` handler behind a `container` nil-check, per D-2. Leave `AceConfig:RegisterOptionsTable` in the builder. | AT-34 | Case green |
| 2.4 | Comment the move with **both** reasons — zero container width at registration (`options-ui-§5`) and the AceGUI skin-hook race (anti-pattern #42) — so neither is lost to a later "simplification". | AT-34 | Comment names both |
| 2.5 | Add a `docs/smoke-tests.md` entry: open Settings → Ka0s Absorb Tracker → Profiles, confirm the AceDBOptions controls fill the page, switch away and back, confirm the profile list reflects a `/at profile new` made in the same session. | AT-34 | Entry present |
| 2.6 | Green gate; commit. | — | 0/0 and green |

**In-game verification is required before this is considered done.** The failure mode this fixes is
a layout/skin symptom that no headless test can observe; the suite proves *when* the widget is
created, the client proves it still looks right.

---

## Sprint 3 — Route every chat line through the secret-safe seam (AT-35)

| # | Step | ID | Done when |
|---|---|---|---|
| 3.1 | Publish `NS.Format = printer.Format` in `core/CoreSetup.lua` beside `NS.Print`, **and** add a matching `NS.Format` to the library-absent branch built on that branch's own stringifier. | AT-35 | Both branches answer `NS.Format` |
| 3.2 | Add a case pinning that `NS.Format` exists and secret-stringifies on **both** paths — the degraded one via `tests/degraded_env.lua`, not a hand-built stub (`testing-§8`). | AT-35 | Case green on both arms |
| 3.3 | Convert the 15 convertible call sites (list with line numbers in `03_EVIDENCE.md` §AT-35): `:format` → `NS.Format(fmt, …)`, `..` → varargs `print(a, b, c)`. Read each line individually — quoted-name messages need the `NS.Format` form or the quotes end up spaced. | AT-35 | No `print(… .. …)` or `print((…):format(…))` outside the two allow-listed indents |
| 3.4 | Leave `settings/Slash.lua:33` and `:403` as concatenation (pure two-space indent on an already-formatted library row) and add a one-line comment saying why, so the next sweep does not change the help block's indentation. | AT-35 | Comment present |
| 3.5 | Add the tripwire: a source scan in `tests/test_slash.lua` for `print%(.*%.%.` and `print%(%(".*"%):format`, allow-listing the two indent sites by content. Same shape as the existing US-spelling scan. Prove it can fail (`testing-§12`) by reintroducing one concatenation, watching it go red, and restoring from a `cp` backup — **not** `git checkout`. | AT-35 | Case red under the mutation, green after restore |
| 3.6 | Smoke: `/at profile list`, `/at profile use <name>`, `/at profile new <name>`, `/at profile delete <name>`, `/at toggle target`, `/at test 40000 5`, `/at version` — every line still carries the cyan `[AT]` tag, no trailing colon, spacing unchanged. | AT-35 | Output identical to before |
| 3.7 | Green gate; commit. | — | 0/0 and green |

---

## Sprint 4 — Close the count loop (AT-32, AT-39)

Runs last so it sets the badge from the final total rather than a moving one.

| # | Step | ID | Done when |
|---|---|---|---|
| 4.1 | Regenerate the inventory: `lua tests/run.lua --list > docs/test-cases.md`. Verify with `diff <(lua tests/run.lua --list) docs/test-cases.md` — no output. | AT-32 | Inventory matches the run |
| 4.2 | Update `README.md:7` to `Tests-<N>%2F<N>_passing-green` where `N` is the new `## Totals` figure (469 today, higher after Sprints 2–3). Keep `%2F`; do not touch the standard badge's underscores. | AT-32 | Badge, inventory and run agree |
| 4.3 | Add the badge-vs-inventory case to `tests/test_docs.lua` per D-1 — parse `| **Total** | **N** |` and the badge's `X`/`Y`, assert all three equal. Prove it can fail by editing the badge to `468`, watching it go red, restoring from a `cp` backup. | AT-32 | Case red under the mutation, green after restore |
| 4.4 | Re-run 4.1/4.2 once more, since 4.3 itself added a case. | AT-32 | All three agree again |
| 4.5 | Optionally narrow `.luacheckrc:7` to the template's `{ "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`; re-run `luacheck .` and confirm 0/0 unchanged. If keeping the wider exclude, extend the existing comment to say the widening is deliberate. | AT-39 | `luacheck .` still 0/0 |
| 4.6 | Green gate; commit. | — | 0/0 and green |

---

## Sprint 5 — Preview mode (AT-38) — optional, user-gated

SHOULD-level and the only sprint that touches the measured paint path. Take it only if the
positioning experience is worth the change; both halves are independent.

| # | Step | ID | Done when |
|---|---|---|---|
| 5.1 | **The cheap half.** Teach `runTest` to accept `off` / `0`, clearing `NS.testHoldUntil` and publishing `REPAINT` so live values return at once. Update the `NS.COMMANDS` description and the README `### Slash commands` row in the same change. | AT-38 | `/at test off` returns the bars to live data immediately |
| 5.2 | **The larger half.** Add `NS.PreviewActive()` / `NS.PreviewValue(unit)` and branch the read inside `NS.UpdateAbsorbBar`, per D-6. Derive the placeholder from `UnitHealthMax`, not a constant. Do **not** relax `ShouldShowBar` — a target bar with no target stays hidden while unlocked. | AT-38 | Unlocking shows a representative fill through the real render path; locking restores live data with no timer |
| 5.3 | Confirm no perf regression: run `lua tests/perf.lua` before and after and compare `paintBar`'s api/iter and bytes/iter. If the branch shows up, move the `locked` read to a module-local upvalue refreshed from the setter (`events-frames-taint-§7`). | AT-38 | api/iter and bytes/iter unchanged for the capture-off scenario |
| 5.4 | Add cases: preview active while unlocked, inactive while locked, cleared on lock, and that the value comes from the same paint path. Add a smoke entry for unlock → drag → lock. | AT-38 | Cases green; smoke entry present |
| 5.5 | Regenerate `docs/test-cases.md` and update the badge in the same commit (`testing-§5`). Green gate; commit. | AT-38, AT-32 | 0/0, green, badge current |

---

## Not scheduled — decision items

These are put to the user, not planned.

- **AT-30 — localization.** Deferred twice (`docs/pending/LEDGER.md` PLAN-02). Either record it as
  an accepted deviation with its reason and stop re-raising it, or schedule the `NS.L` wrap as its
  own milestone. No MUST is currently breached either way — the metatable seam and `enUS.lua` both
  exist, which is what `localization-§1` and `localization-§3` require.
- **AT-31 — per-unit event frames.** Justified, documented, and better solved upstream than here: if
  `events-frames-taint-§1` gained a sanctioned exception for unit-filtered registration, this would
  stop recurring for every addon in the collection rather than just this one. Until then it stays in
  `docs/ARCHITECTURE.md` and re-surfaces each audit with its reason.
- **AT-41 — the extra README section.** No change; recorded so the judgment is not re-derived.

---

## Definition of done for this remediation

- `02_DEVIATIONS.md`'s four MUSTs (AT-32, AT-33, AT-34, AT-35) are closed, each with a test or a
  smoke entry behind it — not just an edit.
- AT-36, AT-37, AT-39 and AT-40 are closed; AT-38 is closed or explicitly deferred.
- AT-30 and AT-31 carry an explicit user decision recorded in `docs/ARCHITECTURE.md` and
  `docs/pending/LEDGER.md`.
- `lua tests/run.lua` green, `luacheck .` 0/0, `docs/test-cases.md` regenerated and the README badge
  matching it.
- The two vendor diffs still empty:
  `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/testkit tests/_kit` — nothing in
  this plan touches either tree, and a non-empty diff afterwards means something was edited that
  should have been fixed upstream (`library-stack-§7`, anti-pattern #45).
