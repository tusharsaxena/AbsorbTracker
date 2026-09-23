# Smoke tests — AbsorbTracker (2026-09-23)

These are the in-client checks for the changes in `02_PROPOSED_CHANGES.md`. The headless suites already ran in Step 0 (see the measurement block in `01_FINDINGS.md`).

**Headless pre-flight, one line.** After applying the changes, run `~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua` and `~/.claude/wow-addon/bin/ka0s-bounded luacheck .`. Expect **716/716** and **0/0** before logging in.

## Pre-flight (in client)

1. Retail client, `## Interface: 120100`. Install the working tree as `Interface\AddOns\AbsorbTracker`.
2. `/console scriptErrors 1`, then `/reload`. Keep BugSack or the default error frame visible.
3. Use a character with at least two AceDB profiles. Create `Keep` and `Other` via the Profiles page if needed. Give `Keep` a visible difference: **Appearance → Size → Bar Width** = 333 on Player.
4. Have a target dummy nearby for the combat steps.
5. Type `/at debug on`, so the `[Profile]`/`[Set]` lines are visible in the console.

---

## C-01 — `/at profile new` refuses an existing name (F-001)

- **Setup:** Profiles `Keep` (width 333) and `Default` exist. The current profile is `Default`.
- **Steps:**
  1. `/at profile new Keep`
  2. `/at profile current`
  3. `/at profile use Keep`, then `/at get units.player.barWidth`
  4. `/at profile use Default`, then `/at profile new SmokeFresh`
- **Expected:**
  1. One `[AT]` line: `Profile 'Keep' already exists — /at profile use Keep switches to it, /at profile reset resets the current one`. No Lua error.
  2. `Current profile: Default`.
  3. `units.player.barWidth = 333 px`.
  4. `Created and switched to new profile 'SmokeFresh'`. The bar redraws at the defaults. The console shows a `[Profile] changed → SmokeFresh` line and a `(0 rows)` reset line.
- **Pass/Fail:** PASS if `Keep` still holds 333 and step 1 switched nothing. FAIL on any reset of `Keep`.

## C-02 — `copy`/`delete` name checks (F-002)

- **Setup:** Current profile `Default`. `Keep` exists. `Nope` does not.
- **Steps:**
  1. `/at profile copy Nope`
  2. `/at profile copy Default`
  3. `/at profile delete Nope`
  4. `/at profile copy Keep`
- **Expected:**
  1. `Profile 'Nope' not found — /at profile list shows them`, with no Lua error.
  2. `Cannot copy a profile onto itself`, with no Lua error.
  3. The not-found line. Nothing claims a deletion.
  4. `Copied settings from profile 'Keep'`. The player bar becomes 333 wide.
- **Pass/Fail:** PASS if steps 1–3 produce no error popup and no false success line.

## C-03 — `lock`/`unlock` echo the stored value (F-003)

- **Setup:** Out of combat. Open `/at config` → General → Master controls and leave the panel open, with the *Lock frame* checkbox visible.
- **Steps:**
  1. `/at unlock`
  2. `/at lock`
  3. Close the panel. Attack the dummy and, while in combat, type `/at unlock`.
- **Expected:**
  1. The chat line reads `locked = false`. The checkbox unticks **immediately**. The bars show placeholder fills and drag strips.
  2. `locked = true`. The checkbox ticks.
  3. Two lines, `Cannot unlock the bars during combat` then `locked = true`. The bars stay locked, and there is **no** "unlocked" wording.
- **Pass/Fail:** PASS if the chat never contradicts the bars and the checkbox follows the verbs without reopening the panel.

## C-04 / C-05 / C-06 / C-07 / C-11 / C-12 — tests, comments, lint, dead code

These have no in-client surface beyond the regression suite below. The headless pre-flight covers them.

## C-08 — brand title (F-009)

- **Steps:** Esc → Options → AddOns.
- **Expected:** The category reads **Ka0s Absorb Tracker**, exactly as before.
- **Pass/Fail:** The string is unchanged.

## C-09 — profile adopt publishes once (F-010)

- **Setup:** Profile `Off` with **Enable Absorb Tracker** unticked, and profile `Default` enabled. `/at debug on`.
- **Steps:**
  1. `/at profile use Off`. The bars disappear.
  2. `/at profile use Default`.
- **Expected:** After step 2 the bars reappear at their saved positions with the correct styling and repaint on the next absorb. There are no errors, and no bar is left at the default anchor.
- **Pass/Fail:** The visual state is correct after the edge.

## C-10 — `/at test` duration (F-011)

- **Steps:**
  1. `/at test 50000 -3`
  2. `/at test 50000 2.5`
- **Expected:**
  1. The usage line, or a clamped duration, but never `for -3 s`.
  2. The announcement matches the hold (`2.5 s`). The fake value clears after about 2.5 s.
- **Pass/Fail:** The announcement equals the observed hold.

---

## Regression suite

1. `/reload`: no errors. The bars appear at their saved positions, with no flash of three stacked bars at center.
2. Fresh login on a character with no SavedVariables for the addon: the defaults populate, only the Player bar shows, and `/at list` prints every row.
3. Enter and leave combat with the bars visible. An unlocked session re-locks on the pull with `Bars locked — combat started`.
4. `/at disable`: the bars vanish. `/at help`, `/at config` and bare `/at` still answer. `/at unlock` prints the one disabled line naming `/at enable`. `/at enable` restores everything.
5. Minimap left-click toggles the lock (refused while disabled). Right-click opens the panel.
6. On the General and Appearance pages, toggle every row once, and press Defaults on each page. The minimap button stays hidden if it was hidden.
7. Profiles page: switch, copy and reset through the AceDBOptions UI.

**Cross-addon (fold into any session with several Ka0s addons loaded).** Type each of the ten roots and confirm each reaches its own addon: `/at /am /bl /cm /kcd /lh /mm /pm /pc /wg`. Then open Settings → AddOns and confirm each addon appears exactly once, and each multi-page addon's pages appear once each.

No taint, locale or performance findings were raised, so those sections are omitted.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | | | |
| C-04 | | | headless only |
| C-05 | | | comment only |
| C-06 | | | comment only |
| C-07 | | | lint only |
| C-08 | | | |
| C-09 | | | |
| C-10 | | | |
| C-11 | | | headless only |
| C-12 | | | headless only |
| U-01 (re-vendor) | | | headless: suite still green |
| Regression 1–7 | | | |
| Cross-addon | | | |
