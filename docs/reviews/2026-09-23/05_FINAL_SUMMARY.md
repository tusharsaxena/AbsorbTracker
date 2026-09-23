# Final summary — AbsorbTracker review-and-fix cycle (2026-09-23)

*This is written assuming every change in `02_PROPOSED_CHANGES.md` was applied and every check in `03_SMOKE_TESTS.md` passed. Fill in the commit range and the sign-off once that is true.*

## Headline

This cycle made Absorb Tracker's own chat commands tell the truth, and made its tests check the settings the addon actually has. Before it:

- `/at profile new` with an existing name quietly wiped that profile.
- `/at profile copy` threw a Lua error on a typo, and `/at profile delete` claimed to delete profiles that did not exist.
- `/at unlock` in combat said "Bar unlocked" right after refusing to unlock.
- Several tests were checking a setting key and settings pages that were removed releases ago.

Now the commands check first, refuse with a line that names the right command, and echo what was actually stored. The tests exercise real paths. The shared test kit's AceDB stand-in was fixed upstream in LibKa0s so every Ka0s addon's tests catch this class of bug. A set of stale comments, including one that described the disabled state backwards, was corrected.

## Counts

- Critical fixed: 0
- High fixed: 1 (F-001)
- Medium fixed: 5 (F-002, F-003, F-004, F-005, F-006 upstream)
- Low fixed: 7 (F-007 to F-013)

Deferred: none planned. If time is short, F-010 (C-09) and F-013 (C-12) are the safest to defer: both are cold-path or test-only.

## Changes by theme

### A. Truthful host verbs

- **What changed:** The profile sub-verbs validate the name before calling AceDB. `/at profile new` refuses an existing name. `lock`, `unlock`, `enable` and `disable` echo `locked = …` / `enabled = …` from the store and refresh an open panel. `/at test` validates its duration.
- **Why it mattered:** One verb destroyed data without warning; the others raised errors or printed success lines that contradicted what happened.
- **Findings:** F-001, F-002, F-003, F-011. **Changes:** C-01, C-02, C-03, C-10.
- **Files:** `settings/Slash.lua`, `tests/test_slashcmds.lua`, `docs/profiles.md`, `docs/smoke-tests.md`, and `README.md` / `docs/slash-dispatch.md` where they quoted the old lines.

### B. Tests that can fail

- **What changed:** The profile and reset cases assert on `units.player.barWidth`. The cleanups target the `appearance` page. The kit's AceDB fake raises where AceDB does.
- **Why it mattered:** Two cases compared `nil` to `nil`. The cleanups did nothing, so state leaked between suites. The fake hid F-002.
- **Findings:** F-004, F-006. **Changes:** C-04, U-01.
- **Files:** `tests/test_slashcmds.lua`, plus `tests/_kit/**` (re-vendored whole from LibKa0s, not edited).

### C. Code and comments that agree

- **What changed:**
  - Corrected the §7 comment on the enable verbs, and the sweep of stale comments.
  - Pruned eight unused lint globals.
  - The Options title reads `C.BRAND`.
  - Removed a dead printer fallback.
  - Moved the test-only bar aliases into the tests.
- **Why it mattered:** A comment that describes the removed draw gate invites re-introducing it (anti-pattern #85). The unused lint globals would let a future `hooksecurefunc`/`C_Timer` call lint clean.
- **Findings:** F-005, F-007, F-008, F-009, F-012, F-013. **Changes:** C-05, C-06, C-07, C-08, C-11, C-12.
- **Files:** `settings/Slash.lua`, `settings/General.lua`, `settings/OptionsSetup.lua`, `settings/Schema.lua`, `core/PerfSetup.lua`, `core/CoreSetup.lua`, `core/AbsorbTracker.lua`, `core/Constants.lua`, `defaults/Profile.lua`, `modules/Bar.lua`, `.luacheckrc`, `docs/ARCHITECTURE.md`, `tests/test_display.lua`, `tests/test_data.lua`.

### D. One appearance pass per profile adopt

- **What changed:** Dropped the no-op `Reevaluate()`. The adopt path no longer re-publishes what `StandUp` just published.
- **Findings:** F-010. **Changes:** C-09.
- **Files:** `core/AbsorbTracker.lua`, plus one characterization test.

## API / behavior changes

- `/at profile new <existing>` now **refuses**; it no longer resets that profile.
- `/at profile copy <missing|current>` and `/at profile delete <missing>` print a refusal instead of raising or claiming success.
- `/at lock` / `/at unlock` output changes from `Bar locked` / `Bar unlocked` to `locked = true` / `locked = false`, in the `slash-commands-§5` set shape. The help text now says "bars".
- `/at test <value> <secs>` rejects or clamps a duration ≤ 0 and announces fractional durations exactly.
- No schema rows, SavedVariables keys, defaults, locale keys or slash verbs were added or removed.

## Saved-variable / migration notes

None. There is no schema bump and no migration.

## Deprecated-API migrations

None. No deprecated calls were found in authored code.

## Performance impact

None claimed. No perf-tagged change shipped. F-010 removes one appearance pass on a rare profile-edge path. The measured basis is `tests/perf.lua` `appearancePass` at 48.0 api / 97.8 bytes per three-bar pass, but no before/after capture was taken, so no number is claimed.

## Test and complexity movement

- **Tests:** 710 → **716** (+1 C-01, +3 C-02, +1 C-03, +1 C-10). `docs/test-cases.md` and the README `[tests]` badge moved **in the same commits**.
- **Complexity:** no function is expected to cross CCN 15. `tests/test_slashcmds.lua` grows to about 1345 LOC and stays in the 1000–1500 band. The obsolete over-cap watch-list entry in `docs/automated-tests/RESULTS.md` (1745, now 1304) is for the next release's regeneration to confirm. It was not regenerated here.

## Known follow-ups

- `tests/test_helpers.lua` (1416 LOC) is still on notice for a peel by helper group before 1500. That was already dispositioned in `RESULTS.md`.
- Any sibling addon whose tests self-copy or delete a missing profile will go red after the U-01 re-vendor. Those are real bugs being exposed, and belong to those repos' own reviews.

## Verification evidence

- `03_SMOKE_TESTS.md`, with its sign-off table completed.
- Commit range: `<first>..<last>` on `feat/2026-09-23-review-audit-remediation` (fill in).

## Suggested commit / PR description

```
AbsorbTracker: truthful profile and lock verbs, live-key tests, comment sweep

- /at profile new refuses an existing name instead of silently resetting it (F-001)
- /at profile copy/delete name-check before AceDB: no Lua error, no false "Deleted" (F-002)
- /at lock|unlock echo the stored `locked` in the set shape and refresh the panel;
  no "Bar unlocked" after an in-combat refusal (F-003, slash-commands-§8/§5)
- /at test validates its duration (F-011)
- tests: profile/reset cases assert units.player.barWidth; cleanups target the
  appearance page (F-004)
- re-vendor LibKa0s testkit: AceDB fake raises like AceDB-3.0 (F-006, upstream)
- comments: enable-verb note describes the latch, not the removed draw gate (F-005);
  stale-comment sweep (F-007)
- .luacheckrc: drop eight unused read_globals (F-008); Options title reads C.BRAND (F-009);
  dead printer fallback removed (F-012); player-bar aliases moved into tests (F-013)
- profile adopt publishes once on an enable edge (F-010)

Tests 710 -> 716; docs/test-cases.md and the badge moved with them.
Review: docs/reviews/2026-09-23/
```
