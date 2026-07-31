# Smoke tests — 2026-07-31 review

Run these **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. They confirm the
fixes work in-client and that the extraction seams did not regress.

---

## Pre-flight

1. **Build / install.** Copy the repo folder to `World of Warcraft/_retail_/Interface/AddOns/AbsorbTracker`
   (or symlink it). Confirm the TOC still reads `## Interface: 120007` and that
   `libs/LibKa0s/LibKa0s.xml` lists eight `<Script>` entries.
2. **Vendor sync gate (run before logging in).**
   `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` → must print nothing.
   `diff -r ../LibKa0s/testkit tests/_kit` → must print nothing.
   If C-9/C-10 were applied upstream, this is the check that proves the re-vendor commit landed.
3. **Headless gate.** `lua tests/run.lua` → all green. `luacheck .` → 0 warnings / 0 errors.
   `docs/test-cases.md` regenerated (`lua tests/run.lua --list > docs/test-cases.md`) and the README
   `[tests]` badge updated to the new X/Y.
4. **In-client error visibility.** `/console scriptErrors 1` then `/reload`. Any Lua error must pop
   a visible frame — several checks below are "no error popup".
5. **Character / environment.** Any character. You need: a target dummy (Stormwind Trade District
   or your capital's training-dummy area) for the combat cases, and any second unit you can target
   and focus for the mirror cases. A shield-casting class (Priest / Mage / Paladin) makes the bar
   checks easier but is not required — `/at test` substitutes.
6. **Fresh-state arm.** For the first-run cases, exit the client, move
   `WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` aside, and start clean.
7. **Degraded arm (used by several cases).** Exit the client, rename `libs/LibKa0s` to
   `libs/_LibKa0s_off`, start the client. **Rename it back before the regression suite.**

---

## Per-change tests

### C-1 — `/at resetall` acks inside its guard

- **Change covered:** C-1 — the success line can no longer be printed when the reset did not run.
- **Setup:** normal (library present) install, character logged in, out of combat.
- **Steps:**
  1. `/at set units.player.barWidth 400`
  2. `/at resetall`
  3. `/at get units.player.barWidth`
  4. Enter the **degraded arm** (pre-flight 7), log in, and run `/at resetall`.
- **Expected:** step 2 prints `[AT] All settings reset to defaults` (cyan tag, no trailing period);
  step 3 shows the default width. Step 4 also prints the success line — the degraded stub *does*
  provide `RestoreAllDefaults`, so this must still succeed and must **not** print the failure text.
- **Pass / Fail:** PASS if the ack and the actual reset always agree; FAIL if any run prints success
  while `/at get` still shows the modified value.

### C-2 — README `/at reset` row

- **Change covered:** C-2 — angle-bracket placeholder removed.
- **Setup:** none in-client.
- **Steps:** `grep -nE "<[a-z|]+>" README.md`.
- **Expected:** the only remaining `<…>` hits are the deliberate `<br>` tags inside the Version
  History and FAQ table cells. No `<path>`, `<name>`, `<value>`, `<setting>`.
- **Pass / Fail:** PASS if zero placeholder hits and every `<br>` still present.

### C-3 — the Profiles reset veto

- **Change covered:** C-3 — one predicate, both call paths.
- **Setup:** library present. Create a second profile: `/at profile new SmokeTest`, then
  `/at profile use Default`.
- **Steps:**
  1. `/at profile list` — note both profiles exist.
  2. `/at resetall`
  3. `/at profile list`
  4. Repeat 1–3 in the **degraded arm**.
- **Expected:** both profiles still listed after every `/at resetall`, in both arms. `Default` is
  still the current profile.
- **Pass / Fail:** PASS only if no profile is deleted or reset by `resetall` in either arm.

### C-4 — degraded/live dispatcher parity

- **Change covered:** C-4 — the second dispatcher behaves like the first.
- **Setup:** run each step twice — once library-present, once in the degraded arm.
- **Steps:**
  1. `/at options` (the legacy alias)
  2. `/at TOGGLE Target`
  3. `/at nosuchverb`
  4. `/at` (bare)
- **Expected:**
  - 1: library present → the Settings panel opens. Degraded → a line naming LibKa0s. Neither prints
    `unknown command 'options'` (the alias must resolve in both).
  - 2: the Target bar toggles in both arms; the verb is case-folded and the argument is not.
  - 3: both arms print `unknown command 'nosuchverb'` **followed by the help list**.
  - 4: both arms print the help list.
- **Pass / Fail:** PASS if the *dispatch outcome* matches in both arms for all four. Formatting
  differences on the help rows are expected in the degraded arm and are not a failure.

### C-5 / C-6 — schema value formatting

- **Change covered:** C-5 (LibStub resolved once), C-6 (degraded fallback restored).
- **Setup:** library present; `/at debug on` so the `[Set]` line is emitted; console open.
- **Steps:**
  1. `/at set units.player.barColor 1 0 0`
  2. Read the console's newest `[Set]` line.
  3. `/at get units.player.barWidth` and `/at list`.
  4. Degraded arm: `/at debug on`, then `/at set units.player.barWidth 300`.
- **Expected:** step 2 shows `[Set] units.player.barColor = {1.00, 0.00, 0.00, 1.00}` — a rendered
  color, **never** `table: 0x…`. Step 3 shows gold key / white value pairs with a `%.2f sec`-style
  formatted throttle. Step 4 raises no error (there is no console in that arm, so nothing is
  displayed — the check is only that nothing breaks).
- **Pass / Fail:** PASS if no `table: 0x` ever appears and no error popup fires.

### C-7 — structural rebuild is on-screen only

- **Change covered:** C-7 — off-screen unit panels go dirty instead of rebuilding.
- **Setup:** library present, out of combat, `/at debug on` with the console open (so you can see
  the `[Set]` traffic).
- **Steps:**
  1. `/at config` → open **Bar**, switch its Unit dropdown to **Focus**. Open **Border**, switch to
     **Focus**. Open **Font**, switch to **Focus**. (All three now have a rendered ctx.)
  2. Leave the panel on the **Font** page. Close the Settings window.
  3. `/at set units.focus.mirror true`
  4. `/at config` → open **Bar**.
  5. `/at set units.focus.mirror false`, then open **Border**.
- **Expected:** no error popup at any step. At step 4 the Bar page shows the **mirror checkbox
  ticked**, the "Linked to Player" hint, and **no** appearance rows — i.e. it picked up the change
  it was not on-screen for. At step 5 the Border page shows the appearance rows back.
- **Pass / Fail:** PASS if every backgrounded page is correct on its next open, with no stale
  partition and no error.

### C-8 — the render guard survives an error

- **Change covered:** C-8 — `ctx.__rendering` clears on the failure path.
- **Setup:** library present, Settings panel open on the **Bar** page.
- **Steps:** (headless is the reliable arm for this; in-client is a sanity pass)
  1. In-client: switch the Unit dropdown Player → Target → Focus → Player, six times in a row,
     quickly.
  2. Toggle "Use same styling as Player" on and off five times on Target.
  3. Click **Defaults** on the Bar page.
- **Expected:** the page re-renders every time and never goes blank or unresponsive. No error popup.
  If an error *does* fire, the panel must still respond to the next dropdown change (that is the
  actual thing C-8 fixes).
- **Pass / Fail:** PASS if the page never stops re-rendering.

### C-9 / C-10 — upstream library changes re-vendored

- **Change covered:** C-9 (hook-table mutation), C-10 (US English in library comments).
- **Setup:** the upstream LibKa0s commits are merged and this addon carries its re-vendor commit.
- **Steps:**
  1. `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` → empty.
  2. `grep -rniE "colour|colours" libs/LibKa0s` → no hits.
  3. In-client: `/at config` → **General**. Confirm the row `[Enable Focus Bar] | [Debug console]`
     renders side by side and that the `[Reset Position] | [Reset All Settings]` pair is present and
     the right button's border is **not** clipped.
  4. `/reload`, reopen **General**, confirm both again.
- **Expected:** the paired widgets survive step 4 — that is the one-shot hook regression C-9 guards.
- **Pass / Fail:** PASS if `diff -r` is empty and both inline pairs render on every open.

### C-11 — US English sweep

- **Steps:** `grep -rniE "colour|grey|behaviour|generalis|honour" --include="*.lua" --include="*.md"
  core settings modules defaults tests README.md CLAUDE.md`
- **Expected:** no hits. (`docs/audits/` and `docs/reviews/` are frozen and excluded;
  `libs/` is covered by C-10.)
- **Pass / Fail:** PASS on zero hits in the listed paths.

### C-12 — corrected comments + trimmed stub constants

- **Change covered:** C-12 — the stub no longer carries copies of the library's layout constants.
- **Setup:** the **degraded arm**.
- **Steps:**
  1. Log in with `libs/LibKa0s` renamed away. Watch chat.
  2. `/at list`
  3. `/at set units.player.barWidth 275` then `/at get units.player.barWidth`
  4. `/at config`
- **Expected:** step 1 prints a LibKa0s-missing line and no Lua error. Step 2 prints the schema-CLI
  unavailable line **but** the addon has still loaded its full schema — verify with step 3, which
  must store and read back `275`. Step 4 prints the settings-unavailable line.
- **Pass / Fail:** PASS only if a *write and read-back* works in the degraded arm. That is the
  half-loaded-schema regression the stub exists to prevent, and it is the single highest-value case
  here.

### C-13 — one voice for the missing-library message

- **Setup:** the **degraded arm**, fresh login.
- **Steps:** log in, then `/at debug`, then `/at config`, then `/at list`.
- **Expected:** every line carries the cyan `[AT]` tag and the same cause clause, differing only in
  what is unavailable. No line is green, none ends in a colon, none is untagged.
- **Pass / Fail:** PASS if all four lines share the cause wording and the tag.

### C-14 — removals

- **Steps:** `grep -rn "PARENT_TITLE\|CliVersion\|__lastUnitCtx" --include="*.lua" core settings tests`
- **Expected:** `PARENT_TITLE` only as a file-scope local in `settings/OptionsSetup.lua`; no
  `CliVersion` outside `libs/`; no `__lastUnitCtx` anywhere.
- **In-client:** `/at version` still prints `[AT] v1.9.0`; `/at config` still opens.
- **Pass / Fail:** PASS if the greps are clean and both verbs behave.

---

## Regression suite

Not tied to a single change — these cover behavior the changes could plausibly break.

- [ ] **Clean login.** Fresh SavedVariables → log in. No Lua error. `AbsorbTrackerDB` and
      `AbsorbTrackerPerfDB` both appear after `/reload`.
- [ ] **Load sequence.** `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` with no error
      popup. `/etrace` if you want to watch it.
- [ ] **`/reload` cycle.** Reload three times in a row with the Settings panel open on a unit page.
      No error, no duplicated widgets, no stacked anchors.
- [ ] **Every slash verb once.** `help`, `config`, `list`, `get`, `set`, `reset`, `resetall`,
      `resetposition`, `lock`, `unlock`, `toggle`, `debug`, `perf`, `update`, `version`, `test`,
      `profile`. All 17 answer; none prints a green untagged line with a trailing colon (that would
      be the AceConsole `:Print` clobber, architecture-§2).
- [ ] **About page.** `/at config` → landing page. Logo, tagline, "Slash Commands" heading, and one
      row per command — gold command, single-spaced em dash, white description. The row count must
      equal `NS.COMMANDS` (17).
- [ ] **Every settings page opens.** General, Bar, Border, Font, Profiles. Each shows the breadcrumb
      title, the gold divider, and (except Profiles) a **Defaults** button in the standard dark/gold
      skin — **not** the red stone button (anti-patterns #42).
- [ ] **Every option toggled once.** On General: all three enable toggles, Lock, Show only in combat,
      Debug console, the throttle slider. On Bar/Border/Font for **each** unit: every dropdown,
      slider, checkbox and color swatch. No error, and the bar visibly reacts.
- [ ] **Scrollbar always shown.** The short General page and the long Bar page must have the **same**
      body width and right margin; the bar is visible and inert on the short one (options-ui-§10,
      anti-patterns #30).
- [ ] **Profile switch.** `/at profile new SmokeTest` → the open panel re-reads the new profile's
      values in place. `/at profile use Default` → back. `/at profile delete SmokeTest`.
- [ ] **Drag + reset position.** Unlock, drag all three bars off-centre, `/at resetposition` → all
      three snap back. Then drag again and use the General page's **Reset Position** button → same
      result. Then `/at resetall` → positions also cleared.
- [ ] **Mirror + copy.** On Target: tick "Use same styling as Player" → appearance rows disappear and
      the bar takes the Player look. Untick → rows return. "Copy styling from Player" → unlinks and
      keeps the look.
- [ ] **Combat enter/leave.** Attack a dummy with all three bars enabled and "Show only in combat"
      on → bars appear on entering combat and hide on leaving, with no error and no frozen bar.

---

## Taint-specific tests

The review found no taint defect, but the extraction moved the combat gate into the library, so the
gate itself must be re-proven.

- [ ] **Combat refusal.** Attack a target dummy. While in combat run `/at config`.
      **Expected:** exactly one gray line — `cannot open settings during combat — Blizzard's
      category-switch is protected` — with the cyan `[AT]` tag. The Settings window must **not**
      open. Leave combat; `/at config` opens normally (options-ui-§2).
- [ ] **No deferred replay.** After the refusal above, leave combat and **do nothing**. The panel
      must **not** open by itself (options-ui-§2 forbids defer-and-replay).
- [ ] **Programmatic caller is gated too.** In combat, `/run AbsorbTrackerNS = nil` is not available
      — instead run `/click` nothing and use the General page's route: while in combat, open the
      Blizzard Esc → Options → AddOns → Ka0s Absorb Tracker entry. It must be present in the list
      (registration is eager) even though `/at config` refuses.
- [ ] **No action blocked.** With the addon loaded and all three bars visible, enter combat and press
      several action-bar keybinds. No `Interface action failed because of an AddOn` red text.
- [ ] **Options entry present before first open.** Fresh login, never run `/at config`; open Esc →
      Options → AddOns. `Ka0s Absorb Tracker` must already be listed (options-ui-§1/§9).

---

## Localization sanity

The review flagged locale findings (F-002, F-017), but they are comments and prose, not runtime
strings — the addon ships English-only by design (`locales/enUS.lua`). One confirmation pass only:

- [ ] Switch the client to **deDE**, log in, `/at config`, open every page, `/at list`. Everything
      renders in English with no missing-key artifacts and no error. (This proves the metatable
      fallback still resolves after the extraction moved the printers into the library.)

---

## Performance spot-checks

Only C-5 and C-7 are perf-tagged.

- [ ] **C-5 (LibStub per call).** `/at debug on`. `/run collectgarbage("collect");
      print(collectgarbage("count"))` → note. Drag the Bar page's *Bar Color* swatch continuously
      for ~10 seconds. Re-run the count. Record before/after. Compare against the same drag with
      `/at debug off`.
- [ ] **C-7 (structural rebuild).** `/console scriptProfile 1` → `/reload`. Open Bar, Border and Font
      (all three now rendered). Run `/at set units.focus.mirror true` ten times alternating
      true/false. `/run UpdateAddOnCPUUsage(); print(GetAddOnCPUUsage("AbsorbTracker"))`. Record.
      Expect a lower figure than the same sequence on the pre-change build — three page rebuilds per
      write become one.
- [ ] **Offline allocation runner.** `lua tests/perf.lua` still completes and reports a probe
      overhead figure. It is **not** part of the green gate (testing-§7) — this is a "did it still
      run" check, not an assertion.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-1 | | | |
| C-2 | | | |
| C-3 | | | |
| C-4 | | | |
| C-5 | | | |
| C-6 | | | |
| C-7 | | | |
| C-8 | | | |
| C-9 | | | |
| C-10 | | | |
| C-11 | | | |
| C-12 | | | |
| C-13 | | | |
| C-14 | | | |
| Regression suite | | | |
| Taint suite | | | |
| Localization | | | |
| Performance | | | |
