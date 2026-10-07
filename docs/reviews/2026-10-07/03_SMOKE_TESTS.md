# In-client smoke tests — AbsorbTracker (2026-10-07)

These are for the owner to run in the game client after the changes in `02_PROPOSED_CHANGES.md` land. The headless suites already ran in Step 0b (`01_FINDINGS.md`, Measurement run). After the changes, re-run only this one headless pre-flight line:

`~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/run.lua && ~/.claude/dev-copilot/bin/ka0s-bounded luacheck . && ~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/perf.lua`

Never mark a check below as passed on the owner's behalf.

## Pre-flight

- Retail Midnight client, `## Interface: 120100`. The game loads `GIT/AbsorbTracker` through its symlink. Test from that folder, never from a side worktree.
- `/console scriptErrors 1`, then `/reload`.
- Use a character with an absorb (a Discipline Priest, a Protection Paladin, or any class with a shield trinket) and a target dummy.
- Turn on `/at debug on` for the checks that read the console.

---

## S-01 · C-1/C-2: The repaint pass behaves identically after the closure removal (F-001, F-002)

- **Setup:** Bars locked. Player, target and focus all enabled (`/at toggle target`, `/at toggle focus` as needed). Target and focus set to the dummy.
- **Steps:** 1. `/at debug on`. 2. Enter combat on the dummy and apply shields for about 20 s. 3. Leave combat.
- **Expected:** All three bars repaint live during combat. The console's `[Combat] left: N events, M repaints` line shows M ≤ N, so the throttle is still coalescing. No Lua error.
- **Pass / Fail:** Pass if all three bars tracked their unit's absorb throughout, the rollup line appeared with M ≤ N, and no error was raised.

## S-02 · C-1: The in-game capture still reports `repaintPass` with `paintBar` nested (F-001)

- **Setup:** The same addon set as the previous capture (`docs/perf-analysis/20260909-013016/`), solo, at a dummy.
- **Steps:** Follow the standard two-arm protocol. `/at perf start`, `/at perf measure a` (combat about 90 s), `/at perf measure b` (combat about 60 s), `/at perf finish`, `/at perf report`. Arm B is suspended by the addon itself. Do not `/reload` between the arms. Record the run as a frozen bundle with `/dev-copilot:wow-perf-analysis`.
- **Expected:** The report lists `repaintPass` with `paintBar` "observed inside repaintPass". Read the bucket figures, not the frame-time delta.
- **Pass / Fail:** Pass if both buckets appear, the nesting line says *observed*, and the run is saved as a new `docs/perf-analysis/<stamp>/` bundle.

## S-03 · C-3: `/at debug hold` refuses while a capture has the addon suspended (F-003)

- **Setup:** Bars locked, player bar enabled.
- **Steps:** 1. `/at perf start`, then `/at perf measure b` (the addon goes suspended, and the bars hide). 2. Type `/at debug hold 50000 5`. 3. Wait 6 s. 4. `/at perf cancel`.
- **Expected:** Step 2 prints one refusal line naming the suspended capture, not `Holding 50K on the bars for 5 s`. Nothing appears on screen during step 3. After step 4 the bars return with live data.
- **Pass / Fail:** Pass if no "Holding" line printed, no bar appeared while suspended, and the bars came back after the cancel.

## S-04 · C-5: Re-enabling mid-combat starts on live data (F-004)

- **Setup:** Out of combat: `/at unlock` (the bars show the "Absorb" placeholder and drag strips), then `/at disable`.
- **Steps:** 1. Enter combat on the dummy. 2. While still in combat, right-click the minimap button and choose **Enabled**. (Repeat once with `/at enable` instead.) 3. Apply a shield.
- **Expected:** One `Bars locked — combat started` line appears in chat. The bars show live absorb values, not "Absorb", and have no drag strips. **Lock frame** is ticked in the open settings panel once combat ends.
- **Pass / Fail:** Pass if the bars painted live values for the rest of that fight via both routes.

## S-05 · F-005 confirmation (run BEFORE C-6 is designed): Does Master scale move a placed bar?

- **Setup:** `/at unlock`, drag the player bar about 400 px right of center, then `/at lock`. Note its on-screen position (take a screenshot).
- **Steps:** 1. Open settings → General → Master controls, and set **Master scale** to 2.0 (or `/at set scale 2`). 2. Note the bar's position. 3. Set it back to 1.0.
- **Expected (the finding's hypothesis):** At 2.0 the bar's center moves to about twice its distance from screen center, or clamps at the edge. At 1.0 it returns.
- **Pass / Fail:** Record **Confirmed** (the bar moved, so F-005 stands and C-6 proceeds) or **Refuted** (the bar stayed put and only grew, so F-005 closes with no change). This is a finding check, not a fix check.

## S-06 · C-4: The degraded build still loads and answers `/at perf` (F-006)

- **Setup:** Optional, and only if the owner wants the degraded path in-client. Temporarily rename `libs/LibKa0s` outside the game folder, then restore it right after. Never commit this.
- **Steps:** `/reload`, then `/at perf`.
- **Expected:** One "The LibKa0s library is missing … so performance measurement is unavailable." line. No Lua error.
- **Pass / Fail:** Pass if the line printed and no error popped.

---

## Regression suite

- `/reload` cleanly. Then log out and back in: the bars appear at their saved positions with no flash at screen center.
- Fresh profile (`/at profile new SmokeTest`): the player bar shows unlocked with the placeholder. Entering combat re-locks it with one chat line. Delete the profile afterwards (`/at profile use Default`, `/at profile delete SmokeTest`).
- Combat enter and leave with **Visibility** set to each of Always, Only in combat, Only out of combat and Never. The bars follow each mode.
- Target swap and focus set/clear: the target and focus bars appear and hide with the unit and repaint its absorb.
- `/at disable` → no bar is visible and `/at diagnostics` reports "stood down". `/at enable` → the bars return at their saved positions.
- Settings panel: open every page (General, Appearance with each Unit choice, Profiles) and toggle at least one option on each. No errors.

## Cross-addon (the in-client half of the measured clean pass)

With several Ka0s addons loaded together: type each of the eleven roots (`/at`, `/am`, `/bl`, `/cm`, `/kcd`, `/lh`, `/mm`, `/pm`, `/pfe`, `/pc`, `/wg`) and confirm each reaches its own addon. Then open Settings → AddOns and confirm each addon appears exactly once, and each multi-page addon's pages appear once each.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| S-01 (C-1, C-2) | | | |
| S-02 (C-1) | | | |
| S-03 (C-3) | | | |
| S-04 (C-5) | | | |
| S-05 (F-005 check) | | Confirmed / Refuted | |
| S-06 (C-4) | | | |
| Regression suite | | | |
| Cross-addon | | | |
