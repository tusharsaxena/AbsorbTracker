# Final summary — AbsorbTracker review cycle (2026-10-07)

*This is written on the assumption that every check in `03_SMOKE_TESTS.md` passed and that M1–M5 of `04_EXECUTION_PLAN.md` landed. Where an outcome depends on an in-client result that does not exist yet (S-05), it says so. Fill in the bracketed figures from the actual runs; none of them is estimated here.*

## Headline

This cycle made the addon's offline performance evidence measure the code that actually ships. It removed a small per-repaint allocation that the old evidence could not see. It closed two edge cases where the bars could sit in preview, or arm a timer, while the addon was meant to be inert or on live data. It retired one stale test claim. It handed two small fixes to LibKa0s: an inventory total that counted a skipped case, and a stub template carrying a dead field. Player-visible behavior changes in one place only. Re-enabling the addon in the middle of a fight now locks the bars and shows live absorbs, as entering combat already did.

## Counts

`Critical fixed: 0, High fixed: 0, Medium fixed: 1, Low fixed: 6` (F-002, F-003, F-004, F-006, plus the upstream F-007 and F-008 via the re-vendor).

- **Deferred:** **F-005** (Master scale moving placed bars) depends on in-client check S-05. If S-05 was **Refuted**, F-005 is closed with no change. If **Confirmed**, it goes to C-6, which needs an owner-approved spec because it changes the stored meaning of a saved position and needs a v6 migration.

## Changes by theme

### A. Perf evidence measures the shipped repaint pass

- **What changed:** `tests/perf.lua` gained a `repaintPass` scenario that runs the real coalesced pass through a suite-only seam (`NS.Timer.__doRepaint`), and the zero-overhead pair now measures that pass. The old direct-paint scenario is renamed `paintBars`. `doRepaint` iterates the unit list directly instead of building a closure on every pass.
- **Why it mattered:** The ceiling that exists to catch a new allocation on the repaint path was bounding a closure the test wrote itself. The hottest bracket, `repaintPass`, was never measured (performance-§9).
- **Findings / changes:** F-001, F-002 / C-1, C-2.
- **Files:** `modules/Timer.lua`, `tests/perf.lua`, `docs/performance.md`.

### B. Preview and stand-down edges

- **What changed:** `/at debug hold` now refuses whenever the addon is stood down, including during the suspended arm of a perf capture. The combat re-lock is one function (`NS.RelockForCombat`), reached from combat start and from any stand-up or login that happens during combat.
- **Why it mattered:** A hold could arm a timer inside a suspended capture. A mid-combat re-enable could leave the player looking at the "Absorb" placeholder for a whole fight.
- **Findings / changes:** F-003, F-004 / C-3, C-5.
- **Files:** `settings/Slash.lua`, `core/AbsorbTracker.lua`, `core/Lifecycle.lua`, `tests/test_debughold.lua`, `tests/test_disabled.lua`, `tests/test_events.lua` (or `tests/test_visibility.lua`), `docs/lifecycle.md`, `docs/ARCHITECTURE.md`, `docs/test-cases.md`, `README.md`.

### D. Stale evidence

- **What changed:** The degraded Perf stub no longer carries `suspended`, which nothing has read since Perf minor 12. The assertion claiming it covered the show ladder is gone.
- **Findings / changes:** F-006 / C-4. **Files:** `core/PerfSetup.lua`, `tests/test_perf.lua`.

### Upstream (LibKa0s)

- **What changed:** The testkit's `--list` Totals no longer count declared skips (U-1), and the Perf stub template dropped `suspended` (U-2). Both arrived here in one re-vendor commit.
- **Findings / changes:** F-007, F-008 / U-1, U-2 / T5.3.
- **Files here:** `tests/_kit/` (whole folder), `libs/LibKa0s/` (whole folder, if the release touched it), `CLAUDE.md`, `docs/test-cases.md`.

## API / behavior changes

- `/at debug hold` refuses with a one-line explanation while a perf capture has the addon suspended. Before, it printed `Holding …`, painted nothing and armed a timer.
- Re-enabling the addon (`/at enable` or the minimap menu's Enabled entry), or logging in or reloading, **during combat** with the bars stored unlocked now locks them and prints `Bars locked — combat started`.
- New suite-only seam: `NS.Timer.__doRepaint`. No addon code calls it.
- No slash verbs, schema rows, defaults or locale keys were added, renamed or removed.

## Saved-variable / migration notes

None. C-6 would bring a v6 step, and it is deferred with F-005.

## Deprecated-API migrations

None. No deprecated client API was found in scope.

## Performance impact

| Measurement | Before | After | Source |
|---|---|---|---|
| `repaintPass` scenario bytes/iter (offline) | [figure at T1.1's commit] | [figure at T2.1's commit] | `tests/perf.lua`, same machine, one run each |
| `probeOverheadOff` bytes/iter vs the re-derived ceiling | [figure] / [ceiling] | [figure] / [ceiling] | `tests/perf.lua` |
| In-game `repaintPass` bucket | 0.101 ms/s (130 calls, `docs/perf-analysis/20260909-013016/`) | [figure from the S-02 capture bundle] | `/at perf report`; compare bucket figures, never the frame-time delta |

## Test and complexity movement

- **Pass count:** Before, 876 passed + 1 declared skip (877 cases), badge `876/876`. After M3, three cases were added: 879 passed + 1 skip, badge `879/879`, with `docs/test-cases.md` regenerated in the same commits. After M5's re-vendor, the inventory's Totals agree with the badge. [Confirm against the final `--list`.]
- **Complexity:** Max CCN is expected to stay at 14. `tests/test_slashcmds.lua` (1079 lines today) should leave the watch list's 1000–1500 band at the next release regeneration (`/dev-copilot:bump-version`), not before.

## Known follow-ups

- **F-005 / C-6:** Pending S-05 (see Counts).
- **`docs/automated-tests/RESULTS.md`** is 57 commits behind HEAD. That is expected between releases, and the next release run regenerates it.

## Verification evidence

- `03_SMOKE_TESTS.md` sign-off table: [link to the filled table].
- Commit range: [first AT-RV commit]..[re-vendor commit] on `feat/2026-10-07-review-audit-remediation`.
- The headless gate at the final commit: [`lua tests/run.lua` summary line] and [`luacheck .` summary line].

## Suggested commit message / PR description

```
AbsorbTracker: review remediation (2026-10-07)

- Perf runner now measures the shipped coalesced repaint (doRepaint) and its
  repaintPass bracket; the zero-overhead pair moved onto it (F-001).
- doRepaint no longer allocates a closure per pass (F-002).
- /at debug hold refuses whenever the addon is stood down, including a perf
  capture's suspended arm (F-003).
- One combat re-lock (NS.RelockForCombat), also reached when the addon stands up
  or loads mid-combat, so a fight never runs on the placeholder (F-004).
- Dropped the unread Perf.suspended stub member and the assertion that pinned it (F-006).
- Re-vendored LibKa0s: inventory Totals exclude declared skips, Perf stub template
  cleaned (F-007, F-008).

Tests: 876/876 (+1 skip) -> 879/879 (+1 skip); docs/test-cases.md and the
README badge moved in the same commits. No version bump. F-005 deferred pending
in-client check S-05.
```
