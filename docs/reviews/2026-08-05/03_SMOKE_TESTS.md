# AbsorbTracker — In-Client Smoke Tests (for the 2026-08-05 review changes)

Everything that runs headless — `luacheck`, `lua tests/run.lua`, `lua tests/perf.lua`, `lizard` — was
already run in Step 0 and is recorded in `01_FINDINGS.md`. **This document is only for what needs a
logged-in client.**

**Single pre-flight command line, after the changes land and before you log in:**

```
luacheck . && lua5.1 tests/run.lua && lua5.1 tests/perf.lua
```

Expected: lint 0/0 over 28 files; the suite green at the new count from `02_PROPOSED_CHANGES.md`'s
table (**476** if every change lands); the perf runner exits 0 with 6 scenarios and no assertion
failures. If any of those is red, stop — do not proceed to the client.

---

## Pre-flight (in-client)

1. **Build/install.** Copy the working tree to
   `World of Warcraft/_retail_/Interface/AddOns/AbsorbTracker/`. Confirm
   `## Interface: 120007` in `AbsorbTracker.toc` matches the client's build (Midnight 12.0.7); a
   mismatch makes the addon show as out of date but still load, which will confuse step 3.
2. **Character.** Any max-level character that can generate absorbs on itself. A Discipline Priest,
   Blood DK or anyone with a Healthstone/Power Word: Shield source is ideal. You need **a target
   dummy** (Stormwind: Trade District training dummies; Valdrakken: Seat of the Aspects) for the
   combat and perf sections.
3. **Errors visible.** `/console scriptErrors 1`, then `/reload`. A red Lua error popup must be
   possible for the rest of this document to mean anything.
4. **Event tracing available** for the taint/registration sections: `/etrace` (Blizzard's built-in
   event trace) — leave it closed until a step asks for it.
5. **Fresh SavedVariables where a step says so.** To get one: log out fully, delete
   `WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` and
   `AbsorbTrackerPerfDB` if present (it lives in the same file), then log in. Do **not** delete these
   mid-session; the client rewrites them on logout and will restore what you removed.

---

## Per-change tests

### A1 — perf buckets no longer declare false nesting

**Change covered:** A1 — `appearance` and `visibility` render as top-level buckets.

**Setup.** Out of combat, at a training dummy, no other addons you care about. Debug console
available (`/at debug`).

**Steps.**
1. `/at perf` — read the printed workflow, note the exact start verb it names.
2. Start a capture with that verb.
3. Open the settings panel (`/at config`), switch to the **Bar** page, drag the **Bar width** slider
   through its range and back. This drives `appearance`.
4. Close the panel. Attack the dummy for ~30 seconds so absorbs tick — this drives `absorbEvent`,
   `repaintPass`, `paintBar`.
5. Leave combat, then target and un-target the dummy three times. This drives `visibility`.
6. Stop the capture and print the report.

**Expected.**
- The bucket table lists `absorbEvent`, `repaintPass`, `paintBar`, `appearance`, `visibility`.
- **`paintBar` is indented one level under `repaintPass`. `appearance` and `visibility` are NOT
  indented.**
- The nesting note reads exactly `repaintPass contains paintBar` — and names **no other pair**.
- `appearance` shows a non-zero call count (from step 3) and `visibility` shows a non-zero call count
  (from step 5).

**Pass/Fail.** PASS only if the nesting note names exactly one containment pair and the two
un-nested buckets both accrued calls. FAIL if either extra "contains" line still prints, or if
`appearance`/`visibility` render indented.

### A2 — the write-up leads with buckets

**Change covered:** A2 — documentation only; no client behavior.

**Steps.** Read `docs/performance.md` top to bottom as if you had never seen it.

**Expected.** The reading order presented is: bucket table first as the addon's cost; frame-time
delta second, as corroboration, with its ±0.3 ms/frame resolution floor stated **where the number
first appears**. A note near the nesting discussion says pre-2026-08-05 captures under
`docs/perf-runs/` carry a `within` on `visibility` that must be read as a correction.

**Pass/Fail.** PASS if a reader who follows the document would not build a conclusion on the delta
alone. FAIL if "delta is the headline" survives anywhere.

### B1 — `/at test` restores when its hold expires

**Change covered:** B1 — the timed preview actually ends.

**Setup.** Stand in a quiet spot **out of combat**, no target, no active shield on you. Player bar
enabled (`/at toggle player` if needed). This is the situation the old code could not recover from.

**Steps.**
1. `/at test 999999 5`
2. Read the chat acknowledgment.
3. Start a stopwatch. Do **nothing** — do not move, target, cast, or enter combat.
4. Watch the player bar.

**Expected.**
- Chat: `[AT] Testing display with value: 999.9K for 5 s` (cyan `[AT]` tag).
- The bar fills and reads `999.9K`.
- **Within ~1 second of the 5-second mark the bar returns to your real absorb value** (an empty bar
  reading `0` if you have no shield), with no further input.
- No Lua error.

**Pass/Fail.** PASS only if the bar self-restores while you are idle. FAIL if it still reads
`999.9K` at the 10-second mark.

**Second pass — re-arm.** Run `/at test 50000 10`, wait 2 seconds, then run `/at test 12345 3`. The
bar must show `12.3K` and restore ~3 seconds after the **second** command, not ~10 after the first
(this is the cancel-then-rearm path). No double restore.

### B2 — the combat gate repaints every enabled bar

**Change covered:** B2 — `showOnlyInCombat` no longer gates its repaint on the player bar.

**Setup — this configuration is the whole point, do not skip it.**
1. `/at toggle player` until the **player** bar is **disabled**.
2. On the General page, tick **Enable Target Bar**.
3. Target the training dummy so the target bar has a unit.
4. Ensure **Show only in combat** is **off**.

**Steps.**
1. Attack the dummy until it has a visible absorb (or, if it has none, note whatever the target bar
   shows) — then leave combat and wait for the bar to settle.
2. Tick **Show only in combat** ON. The target bar should hide.
3. Attack the dummy to enter combat. The target bar reappears.
4. Read the target bar's value the instant it appears.

**Expected.** The reappearing target bar shows the unit's **current** absorb, not the value it held
when it was hidden in step 2. No stale figure, no frozen fill.

**Pass/Fail.** PASS if the value is current on reveal. FAIL if the bar shows the pre-hide value until
something else happens.

**Restore afterwards:** `/at toggle player` back on, untick **Show only in combat**.

### B3 — Reset All acknowledges honestly

**Change covered:** B3 — the popup's ack moves inside its guard, and matches the slash wording.

**Setup.** Fresh-ish profile is fine. Change something visible first — set **Bar width** to 400 on
the Bar page — so a real reset is observable.

**Steps (normal path).**
1. `/at config` → General → **Reset All Settings** → **Yes**.
2. Read chat. Read the bar.
3. Now run `/at resetall` and read chat again.

**Expected.**
- Both print **the identical line**, character for character, with the cyan `[AT]` tag.
- The bar returns to its 200px default and recenters.

**Steps (degraded path — optional, and the one this change exists for).**
4. Rename `libs/LibKa0s/` to `libs/LibKa0s.off/` on disk, `/reload`.
5. `/at resetall`.

**Expected.** A single honest line naming the missing library — **not** "All settings reset to
defaults". Restore the folder name and `/reload` afterwards.

**Pass/Fail.** PASS if the two surfaces print identical text on the normal path, and if the degraded
path never claims success. FAIL on any wording divergence.

### C1 / C2 — harness changes

**No in-client step.** Both are headless-only and were covered by the pre-flight command line at the
top. Confirm only that `docs/test-cases.md` was regenerated (not hand-edited) and that the README
`[Tests]` badge matches the number the pre-flight run printed.

### D1 — comment and duplicate-copy cleanup

**Change covered:** D1 — one real code change (the shared `DeepCopy` on the migration path).

**Setup. Fresh SavedVariables** (see Pre-flight step 5) — this exercises the copy path the change
touched.

**Steps.**
1. Log in with no `AbsorbTracker.lua` saved variables.
2. `/at debug on`, then `/at config` and set **Target** bar's **Bar width** to 350 (Bar page, Unit
   dropdown → Target, untick "Use same styling as Player" first).
3. `/at profile new SmokeB` — creates and switches to a second profile.
4. On the new profile, set **Target** bar width to 111.
5. `/at profile use Default`.
6. Read the Target bar width on the Bar page.

**Expected.** Default profile still reads **350**. `SmokeB` still reads **111**. Neither profile's
nested per-unit tables leaked into the other — which is what the deduplicated deep copy protects.

**Pass/Fail.** PASS if the two profiles hold independent values across the switch. FAIL if changing
one moved the other.

### E1 — the migration ladder runs on a DB that materializes `global` fresh

**Change covered:** E1 — `global.schemaVersion` defaults to 1.

**Setup. Fresh SavedVariables** (Pre-flight step 5).

**Steps.**
1. Log in with no saved variables at all.
2. `/at debug on` — the console opens and prints the `[Init]` session summary.
3. Read the summary's `schema vN` field.
4. `/reload`, `/at debug on` again, read it again.

**Expected.** Both reads show **schema v4**. On the *first* login the ladder ran to 4 silently (the
debug flag is off at login, so no `[Migrate]` lines are visible — that is correct, not a failure);
on the reload it is already 4 and nothing migrates.

**Upgrade rehearsal (the case E1 actually protects).**
5. Log out. Edit `WTF/.../SavedVariables/AbsorbTracker.lua` and **delete the entire `global = { … }`
   table**, leaving `profiles` intact. Save.
6. Log in, `/at debug on`, read the `[Init]` summary.

**Expected.** `schema v4` again — the ladder re-ran against the re-created `global` section rather
than being stamped current and skipped. Your profile settings are unchanged (bar width, colors,
positions all as you left them).

**Pass/Fail.** PASS if step 6 reports v4 **and** no profile setting was lost. FAIL if it reports v4
having skipped the ladder in a way that also dropped a setting, or if any Lua error appears.

---

## Regression suite (not tied to one change)

Run all of these after the changes land, regardless of which were applied.

| # | Check | Expected |
|---|---|---|
| R1 | `/reload` from a settled session | No Lua error, bars reappear in their saved positions with their saved styling |
| R2 | Cold login on a **fresh** SavedVariables | Player bar visible and centered; target/focus bars absent (they ship disabled); no error popup |
| R3 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | Open `/etrace` before `/reload`; none of the three is followed by a red error |
| R4 | Enter and leave combat at the dummy, three times | Bars stay visible (with **Show only in combat** off), values track, no error |
| R5 | Enter combat with the settings panel **open** | Panel refuses further opens with a gray "cannot open settings during combat" line; already-open panel does not taint (no "Interface action failed because of an AddOn") |
| R6 | Profile switch: `/at profile new R6`, edit two settings, `/at profile use Default`, `/at profile delete R6` | Bars repaint on each switch, the open panel re-reads its values, no error |
| R7 | Every option toggled at least once | Walk General → Bar → Border → Font, flip every checkbox, drag every slider end to end, pick every dropdown entry once, open every color picker and move it. Zero Lua errors, bar updates live |
| R8 | Mirror round-trip | Bar page → Unit: Target → tick **Use same styling as Player** → target bar adopts player styling; untick → its own values return; **Copy styling from Player** → target takes a snapshot and unlinks |
| R9 | Drag and lock | `/at unlock`, drag all three bars apart (unit labels visible while unlocked), `/at lock` (labels vanish), `/reload` — positions survive |
| R10 | `/at resetposition` | All three bars snap back to the stacked center defaults |
| R11 | Every slash verb answers | Run each of the 17 verbs in `README.md:53-68` once; each prints a cyan `[AT]`-tagged response and none errors |
| R12 | Degraded load | Rename `libs/LibKa0s/` aside, `/reload`. The addon still loads, the bars still work, `/at` still answers, and chat carries **one** honest "LibKa0s is missing" line — not one per printed line. Restore and `/reload`. |

---

## Taint-specific tests

The review raised **no** taint findings, so this section is a confirmation pass only — run it because
the changes touch a bus publish and a timer, both of which execute during combat.

| # | Check | Expected |
|---|---|---|
| T1 | Enter combat at the dummy, then press action bar slots 1–4 repeatedly for 20 seconds | No `Interface action failed because of an AddOn` red text |
| T2 | With **Show only in combat** on, enter and leave combat 5 times in quick succession (B2's code path fires each time) | Bars hide/show cleanly; no blocked-action message |
| T3 | Run `/at test 50000 5` **while in combat**, and let the new B1 timer fire while still in combat | The restore lands mid-combat with no error and no blocked action |
| T4 | `/at config` **in combat** | Gray "cannot open settings during combat" line; the panel does not open; no taint message |
| T5 | Open the options panel via **Esc → Options → AddOns → Ka0s Absorb Tracker** out of combat, then again via `/at config` | Both routes reach the same panel; sub-pages (General/Bar/Border/Font/Profiles) each open; no error |

---

## Performance spot-checks

Only A1/A3 are perf-tagged; the offline scenarios already ran headless in Step 0 and are **not**
repeated here.

**In-client capture, following the standard's two-arm protocol** (`performance-§`):

1. At a training dummy, solo, with no other players nearby. Do **not** change your addon set between
   arms and do **not** `/reload` between them.
2. `/at perf` — read the workflow it prints and follow it exactly.
3. **Clean arm first:** capture with the addon fully active while sustaining combat on the dummy for
   the full window. Windows open on your combat *state*, which the probe handles.
4. **Suspend as the second arm**, in the same capture, same target, back to back.
5. Print the report and read the **bucket figures** — `absorbEvent`, `repaintPass`, `paintBar`,
   `appearance`, `visibility`. Treat the frame-time `delta` as unresolved below the harness's
   ±0.3 ms/frame floor; it is corroboration, not the headline (this is exactly what A2 rewrote).
6. **Commit the record** under `docs/perf-runs/` as `2026-08-05-ingame-<label>.json`. That directory
   is append-only — add the new file, never edit or remove
   `2026-07-30-ingame-post-extraction.json`.

**What the new record must show for A1 to be verified:** `paintBar` indented under `repaintPass`;
`appearance` and `visibility` un-indented; exactly one `contains` line. Compare `paintBar` calls
against `repaintPass` calls — the ratio should be (visible bars) × (passes), the arithmetic signature
of genuine nesting, as it was in the 2026-07-30 record (48 = 2 × 24).

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| A1 | | | |
| A2 | | | |
| A3 | | | (headless — pre-flight only) |
| B1 | | | |
| B2 | | | |
| B3 | | | |
| C1 | | | (headless — pre-flight only) |
| C2 | | | (headless — pre-flight only) |
| D1 | | | |
| E1 | | | |
| R1–R12 | | | |
| T1–T5 | | | |
| Perf capture | | | record committed as: |
