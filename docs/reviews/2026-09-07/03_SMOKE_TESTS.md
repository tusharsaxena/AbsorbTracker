# AbsorbTracker — in-client smoke tests, 2026-09-07

Execute **after** the changes in `02_PROPOSED_CHANGES.md` have been applied. Everything here needs a
logged-in game client; everything that runs in a shell was already run in Step 0 and lives in
`01_FINDINGS.md`'s measurement block.

**Pre-flight (shell, one line, before you log in):** `luacheck . && lua5.1 tests/run.lua` from the
repo root. Both must be green before any step below is worth running.

---

## Pre-flight (client)

1. **Build.** Copy the working tree to `<WoW>/_retail_/Interface/AddOns/AbsorbTracker/`. The TOC
   pins `## Interface: 120007` — confirm the client is on that build; a mismatch shows as
   *"Out of date"* in the AddOns list and will not by itself break anything here, but note it.
2. **Character.** Any character on **retail**. Several steps need a **target** and a **focus**, so
   a capital city with an NPC to target and `/focus` is the easiest setup. Steps 6-8 need a
   **target dummy** (Stormwind: Trade District dummies; Valdrakken: the training-ground dummies).
3. **Fresh SavedVariables for step 9 only.** Before that step, log out, move
   `<WoW>/_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` aside, and log back in.
   Restore it afterward.
4. **Make failures visible.** `/console scriptErrors 1`, then `/reload`. Leave it on for the whole
   pass. Optionally `/etrace` filtered to `UNIT_ABSORB_AMOUNT_CHANGED` for step 6.
5. **Baseline.** `/at version` should print the cyan `[AT]` tag followed by `v1.9.0`. If it prints
   green text with a trailing colon and no `[AT]`, the AceConsole reclaim at
   `core/AbsorbTracker.lua:25` has broken and nothing else in this document is trustworthy.

---

## C-01 — `paintBar` reports observed containment

**Change covered:** `C-01` — `doRepaint` hands `"repaintPass"` down to `NS.UpdateAbsorbBar` so the
capture records the nesting it saw.

**Setup:** out of combat, at a target dummy. `/at toggle player` until the player bar is on.
Bars **locked** (`/at lock`) — an unlocked bar stands down from live paints and `paintBar` never
fires.

**Steps:**
1. `/at perf` — the step panel opens.
2. Click **Start perf run** (or `/at perf start smoke-c01`).
3. Click **Measure A (with the addon)**.
4. Attack the dummy for **at least 30 seconds**. Use an absorb-generating ability if the class has
   one; if not, the pass still runs on `UNIT_MAXHEALTH` and the throttle.
5. Click **Measure B (without the addon)**, fight another 30 seconds.
6. Click **Finish perf run**, then **Report**.

**Expected:** the report's nesting line reads that `paintBar` nests in `repaintPass` **and that the
run observed it** — not "declared". Before this change the same line reported the declaration alone.
`visibility` inside `appearance` is unchanged.

**Pass / Fail:** PASS when the nesting sentence for `paintBar` names an observed parent **and** the
`paintBar` and `repaintPass` bucket rows both carry non-zero `calls`. FAIL if `paintBar` still reads
as declared-only, or if `paintBar` shows calls but `repaintPass` shows none (which would mean the
parent is being supplied from somewhere it should not be).

**Also:** `/at perf dump`, then the console's **Copy** button, and check the JSON carries
`"observedWithin": "repaintPass"` on the `paintBar` bucket. Keep this dump — step "Perf capture"
below turns it into the committed evidence.

---

## C-02 — Copy styling logs every key it copies

**Change covered:** `C-02` — `Units.CopyFromPlayer` writes through `NS.SetByPath`.

**Setup:** target something. `/at toggle target` so the target bar is on. `/at debug on` — the
console opens and logging is live. `/at debug` to bring the window forward if it is hidden.

**Steps:**
1. Open the settings: **Esc → Options → Ka0s Absorb Tracker → Appearance**.
2. Set **Unit** to **Target**. Uncheck **Use same styling as Player** so the tabs become editable.
3. Change one thing so the copy is visibly a copy — e.g. on the **Size** tab set *Bar Width* to 400.
4. Clear the console (`/at debug`, then the console's **Clear** control).
5. Click **Copy styling from Player**.

**Expected:**
- The console shows **twenty** `[Set] units.target.<key> = <value>` lines — nineteen appearance keys
  plus `units.target.mirror = false`. Before this change it showed **none**.
- The target bar visibly snaps back to the player bar's width (200 by default), i.e. the copy
  actually landed.
- **Use same styling as Player** stays **unchecked** — the copy unlinks, it does not re-link.
- No Lua error.

**Pass / Fail:** PASS when all twenty lines appear **and** the bar changed **and** the checkbox is
unchecked. FAIL on any missing line, on a re-checked box, or on the bar not moving.

**Watch for the regression this change risks:** the click now fires twenty `APPEARANCE` publishes
instead of one. It should feel instantaneous. If there is a perceptible hitch, stop and go to
mitigation (2) in `02_PROPOSED_CHANGES.md` `C-02` — and measure it with the perf capture below
rather than by feel.

---

## C-04 — the settings panel refuses during combat on every page

**Change covered:** `C-04` — the three sub-pages go through `Helpers.SetRenderer`.

**Setup:** at a target dummy. Settings window **closed**.

**Steps — the sidebar path, which is the one that was unguarded:**
1. Out of combat, open **Esc → Options → Ka0s Absorb Tracker → Appearance**. Confirm it renders:
   the **Unit** dropdown, the tab strip (*Size / Bar / Background / Border / Text*), and rows.
2. Close the settings window with Esc.
3. Start attacking the dummy. **While in combat**, press Esc → **Options**. Blizzard reopens on the
   last-viewed category, which is *Appearance*.

**Expected:** the settings window **closes itself** and one gray `[AT]`-tagged line appears in chat:
*cannot open settings during combat — Blizzard's category-switch is protected*. Before this change
the Appearance page rendered instead.

4. Repeat step 3 for **General** and for **Profiles** (open each out of combat first so it becomes
   the last-viewed category).
5. **In combat**, type `/at config`.

**Expected:** the same gray refusal, no window. (This path was already guarded; it is here to
confirm the change did not break it.)

6. Leave combat. `/at config`.

**Expected:** the panel opens on the landing page. It **must not** have popped open by itself when
combat dropped — `options-ui-§2` forbids defer-and-replay.

**Pass / Fail:** PASS when all three sub-pages refuse in combat with the gray line and the window
closes, `/at config` refuses in combat, nothing auto-opens on leaving combat, and every page renders
normally out of combat. FAIL on any page that renders during combat.

---

## C-04b — the Defaults button is built once, and skinned

**Change covered:** `C-04` — the risk that `SetRenderer` and the page file both call
`EnsureDefaultsButton`.

**Setup:** out of combat. If an AceGUI-skinning addon (ElvUI and friends) is installed, run this
**with it enabled** — that is the case `options-ui-§5` is about.

**Steps:**
1. `/at config`, then click **General**.
2. Look at the top right of the page.
3. Click **Appearance**, then back to **General**, then **Appearance** again — five or six times.

**Expected:** exactly **one** *Defaults* button, top right, on both pages. It must not stack, must
not shift position, and must not appear twice offset by a few pixels. With a skinning addon
installed it should carry the skin, not Blizzard's stock red stone art.

**Pass / Fail:** PASS on exactly one correctly-skinned button per page after six page switches.
FAIL on two buttons, on a button that moves, or on stock red art where every other AceGUI button in
the same window is skinned.

---

## C-04c — page refresh still lands, and the dirty re-render works

**Change covered:** `C-04` — the registry's two-tier refresh replaces the `rendered` latch.

**Setup:** two profiles. `/at profile new SmokeB`, then `/at profile use Default`.

**Steps:**
1. `/at config` → **Appearance**, Unit = **Player**, **Size** tab. Note *Bar Width*.
2. Leave the window **open** and switch pages to **General**.
3. In chat: `/at set units.player.barWidth 350`.
4. Click back to **Appearance** → **Size**.
5. In chat: `/at profile use SmokeB`, with the settings window still open on **Appearance**.
6. Click to **General** and back to **Appearance**.

**Expected:**
- Step 4: *Bar Width* reads **350**. (The value refresh must survive the page having been hidden.)
- Step 5: the open page re-reads the new profile — *Bar Width* returns to the default **200** —
  without a `/reload`.
- Step 6: no stacked widgets, no duplicated rows, no Lua error. The **Unit** dropdown still works.
- Throughout: no *"Unit panel render failed: …"* line in chat.

**Pass / Fail:** PASS when both values track and no page shows a duplicated or empty body.
FAIL on a stale value, a doubled row, or a render-failed line.

---

## C-05 — a junk throttle value degrades instead of erroring

**Change covered:** `C-05` — `NS.GetThrottleWindow` clamps.

**Setup:** this needs a hand-edited SavedVariables, which is the only way to reach it.

**Steps:**
1. `/reload`, then log out fully (so the DB is flushed).
2. Open `<WoW>/_retail_/WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` and change
   `["throttleWindow"] = 0.1,` to `["throttleWindow"] = "banana",` in the active profile.
3. Log back in. Target a dummy and attack it for 15 seconds.

**Expected:** the bar repaints normally at the default 0.1 s cadence. **No** Lua error popup, and in
particular no *"attempt to compare string with number"* from `AceTimer-3.0.lua`. Before this change
that error fired once per absorb event.

4. `/at get throttleWindow`.

**Expected:** it echoes the stored `banana` (the CLI reports what is stored — the clamp is on the
read path that feeds the timer, not on the store).

5. `/at set throttleWindow 0.2` — repairs the value. Confirm no error.
6. Repeat steps 1-3 with `["throttleWindow"] = 99,`. Expect the bar to repaint at the 1 s ceiling,
   not once every 99 seconds.
7. Restore the SavedVariables file you set aside.

**Pass / Fail:** PASS when neither junk value produces a Lua error and the bar keeps repainting.
FAIL on any error, or on the bar freezing.

---

## C-06 / C-07 — nothing user-visible changed

**Changes covered:** `C-06` (comments, the `forEachProfile` collapse, two `onChange` no-ops) and
`C-07` (`NS.PartitionUnitRows` deleted).

**Setup:** the multi-profile store from C-04c, plus a **pre-v3 profile** if one can be manufactured:
log out, and in the SavedVariables file add a profile block carrying flat `["barWidth"] = 333,` and
`["schemaVersion"] = 1,` with no `units` table.

**Steps:**
1. `/at debug on`, then `/reload`.
2. Read the console for `[Migrate]` lines.
3. `/at profile use <the pre-v3 profile>`.
4. `/at get units.player.barWidth`.
5. `/at config` → **General** → **Bars** tab. Drag the *Update throttle* slider one step.
6. On the same tab, click the **Debug console** checkbox twice.

**Expected:**
- Step 2: exactly the `[Migrate]` lines the old build produced — `lifted N profile(s) to v3` and the
  `vX → vY` ladder. The `forEachProfile` collapse must not change the counts.
- Step 4: **333**. The flat key was lifted onto the player unit; a wrong walk would report 200.
- Step 5: the throttle changes and the bars do **not** visibly re-style (no border flicker). Before
  `C-06` this fired a full three-bar restyle per slider step.
- Step 6: the console window toggles; the bars do not re-style.
- No Lua errors anywhere.

**Pass / Fail:** PASS when the `[Migrate]` output is identical to the pre-change build, the lifted
width is 333, and neither the slider nor the checkbox restyles the bars. FAIL on a changed migration
count or a lost setting.

---

## Regression suite (not tied to one change)

| # | Check | Expected |
|---|---|---|
| R1 | `/reload` twice in a row, out of combat | No Lua error. Bars reappear at their saved positions with their saved styling. |
| R2 | Fresh login on a **clean** SavedVariables (pre-flight step 3) | Player bar visible and centered; target and focus bars absent (they ship disabled). No error. `/at get schemaVersion` reports the migrated stamp. |
| R3 | `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | With `scriptErrors 1`, no popup at any point in the login sequence. |
| R4 | Enter and leave combat with all three bars enabled and a target | Bars stay visible, no error, no flicker beyond one repaint. |
| R5 | Target swap, then `/focus`, then clear focus | Target bar appears/disappears with the target; focus bar likewise. No error on clearing focus. |
| R6 | `/at profile new R6`, `/at profile use R6`, `/at profile use Default`, `/at profile delete R6` | Each acknowledges with an `[AT]`-tagged line. Deleting the *current* profile is refused. Bars repaint on each switch. |
| R7 | Open the settings panel and toggle **every** option on **General** and on **Appearance** for **all three units** at least once | No Lua error, no widget stacking, every change visible on the bar. |
| R8 | `/at list`, `/at help`, `/at profile` with no argument | Each prints its full block. `/at list` shows both pages and all three units. Every row's key is gold and its value white. |
| R9 | `/at unlock`, drag each bar somewhere, `/at lock` | Unit labels appear above the bars while unlocked and the placeholder fill shows; positions persist across `/reload`; labels vanish when locked. |
| R10 | `/at test 250000 4` while unlocked, then again while locked | Announces the value and the duration; the fake value clears after exactly 4 seconds and the bar returns to live data (locked) or to the placeholder (unlocked). |
| R11 | `/at resetall`, accept the confirm | The popup text ends in a period and warns that everything configured is discarded. Every setting returns to default; **other profiles are untouched** — verify with `/at profile list` and by switching. |
| R12 | `/at resetposition` | All three bars return to the stacked default positions, player centered. |
| R13 | Rename the folder to `AbsorbTracker` with `libs/LibKa0s/` **removed**, log in | The addon loads. One honest line names the missing library. `/at` still answers; `/at config` says the panel is unavailable; `/at resetall` still works. **No** Lua error. (This is the degraded path the suite exercises headlessly — confirm it in-client once.) |

---

## Localization sanity

Not required: no change in this cycle touches a user-facing string beyond the two comment edits, and
`locales/enUS.lua:8-12` records that the addon ships English-only with strings still hardcoded. If a
future pass wraps strings in `NS.L`, re-run C-02, C-04 and R7-R11 under `deDE`.

---

## Perf capture — the evidence for the C-01 and C-02 claims

This is the in-client half of the perf work. The offline scenarios already ran in Step 0 and are
**not** repeated here.

**Protocol (`performance-§9`, and the write-up at `docs/performance.md` §3):**
1. **Disable every other addon.** AbsorbTracker plus stock Blizzard UI only.
2. **Uncap the frame rate** — untick *Max Foreground FPS*, VSync off. Do **not** trust
   `GetCVar("maxFPS")`; verify from the report itself. If both arms land on the same frame time, or
   on 8.33 ms / 6.94 ms, you were pinned and the capture is void.
3. Fixed graphics preset, same dummy, same spec, same rotation, same camera angle.
4. `/at perf` → **Start** → **Measure A** (fight ≥ 60 s) → **Measure B** (fight ≥ 60 s) →
   **Finish** → **Report**. **No `/reload` between arms.**
5. `/at perf dump`, lift the JSON with the console's **Copy** button.

**Read the bucket figures, not the frame-time delta.** The committed capture
`docs/perf-analysis/20260807-125002/dump.json` records
`deltaMsPerFrame: -0.1777` against arms of 16.56 and 16.74 ms/frame — a delta *below* the harness's
own run-to-run spread and therefore **unresolved**. Do not build a claim on it. What is readable:

| Bucket | 2026-08-07 capture | What this cycle should show |
|---|---|---|
| `absorbEvent` | 86 calls, 4.5313 ms total | unchanged — `C-01` does not touch this path |
| `repaintPass` | 72 calls, 4.2879 ms total | unchanged |
| `paintBar` | 143 calls, 2.4014 ms total, `within: repaintPass` | same magnitude, **plus** `observedWithin: "repaintPass"` — that new key is the whole point of `C-01` |
| `visibility` | 21 calls, 0.2388 ms total | unchanged |
| `appearance` | **absent** — never entered during that capture | present if you touch a setting mid-capture; absent otherwise, and that is correct |

**For `C-02` specifically:** run one capture in which you click *Copy styling from Player* during
Measure A. The `appearance` bucket should then show **20** calls where the old build showed 1. That
is the cost this review predicted from the offline `appearancePass` figure (0.034 ms, 384.5 bytes per
pass) and it is the number that decides whether mitigation (2) is needed.

**Record it** as a frozen bundle via `/wow-addon:perf-analysis` — `docs/perf-analysis/<YYYYMMDD-HHMMSS>/`
with `report.md`, the verbatim `dump.json` and its own `ANALYSIS.md`. Do not edit, tidy or delete the
existing `20260807-125002` bundle; it predates the settings revamp and that is exactly what makes it
useful to compare against.

**Cheap fallback if the full protocol is impractical:** `/run collectgarbage("count")` immediately
before and after clicking *Copy styling from Player*, and again before and after a slider drag on
the *Update throttle*. The second should be flat after `C-06`.

---

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| C-01 | | | |
| C-02 | | | |
| C-03 | n/a — headless | | verified in Step 0 / re-run of `tests/perf.lua` |
| C-04 | | | |
| C-04b | | | |
| C-04c | | | |
| C-05 | | | |
| C-06 | | | |
| C-07 | | | |
| C-08 | n/a — no code change | | |
| C-U1 | | | upstream; verify after the re-vendor, not in this pass |
| R1–R13 | | | |
| Perf capture | | | bundle path: |
