# 03 — Manual smoke tests

Run these **in-client, after the changes in `02_PROPOSED_CHANGES.md` have been applied**, to confirm each fix
works and nothing else regressed. Derived one-for-one from the change IDs.

Existing in-game checks live in `docs/smoke-tests.md`; this file is the delta for this review and does not
replace it.

---

## Pre-flight

1. **Build / install.** Copy the repo folder to `World of Warcraft/_retail_/Interface/AddOns/AbsorbTracker`
   (or symlink it). The folder name must be exactly `AbsorbTracker` — `core/Constants.lua:13,16` hardcodes
   `Interface\AddOns\AbsorbTracker\media\…` for the debug font and the About logo.
2. **Client.** Retail only. TOC declares `## Interface: 120007`; if your client reports a different build,
   the addon may show as out of date — enable *Load out of date AddOns* rather than editing the TOC.
3. **Headless gate first.** From the repo root:
   `lua tests/run.lua` → expect `0 failed`, and `luacheck .` → expect `0 warnings / 0 errors`. Do not go
   in-game on red.
4. **Make failures visible.** `/console scriptErrors 1` — several tests below assert the *absence* of a Lua
   error, which is unobservable with error display off. `/etrace` is useful for section 5 only.
5. **Character.** Any character with an absorb source is easiest (Discipline Priest, Mage with Ice Barrier,
   any class with an absorb trinket), but a target dummy plus a healer friend also works. One test needs a
   **non-default class** to be meaningful — see C-3.
6. **Fresh SavedVariables where stated.** To reset: log out, delete
   `WTF/Account/<ACCOUNT>/SavedVariables/AbsorbTracker.lua` (and `AbsorbTracker.lua.bak`), log back in.
   Sections that need this say so; the rest run on your existing config.
7. **Back up your profiles before section 1.** C-1's tests deliberately poke destructive verbs.

---

## C-1 — `/at profile` guards

**Change covered:** C-1 — `runProfile` refuses bad names instead of erroring, wiping, or lying
(F-001, F-002, F-003, F-018).

**Setup:** log in with at least **two** profiles. If you have only one:
`/at profile new SmokeTest` → `/at profile use Default`. Confirm with `/at profile list` that both are
listed and `Default` is marked `(current)`.

### 1.1 — copy onto self (was: Lua error)

1. `/at profile current` — note the name (assume `Default`).
2. `/at profile copy Default`

**Expected:** one cyan `[AT]` line, `Cannot copy a profile onto itself`. **No red Lua error, no error popup.**

**Pass/Fail:** PASS only if no Lua error appears *and* the refusal line is printed.

### 1.2 — copy an unknown profile (was: Lua error)

1. `/at profile copy Nonexistent`

**Expected:** `[AT] No profile named 'Nonexistent' — try /at profile list`. No Lua error.

**Pass/Fail:** PASS only if no Lua error appears.

### 1.3 — `new` over an existing profile (was: silent data loss)

1. `/at profile use SmokeTest`
2. Change something visible: `/at set units.player.barWidth 333`
3. `/at profile use Default`
4. `/at profile new SmokeTest`
5. `/at profile use SmokeTest`
6. `/at get units.player.barWidth`

**Expected:** step 4 prints
`[AT] Profile 'SmokeTest' already exists — use /at profile use SmokeTest, or /at profile reset to restore its
defaults`, and step 6 still reports **333**.

**Pass/Fail:** PASS only if step 6 reports 333. Any other value means the profile was wiped — this is the
regression this change exists to prevent.

### 1.4 — delete an unknown profile (was: false success)

1. `/at profile delete Nonexistent`

**Expected:** `[AT] No profile named 'Nonexistent' — try /at profile list`. **Not** `Deleted profile
'Nonexistent'`.

### 1.5 — `use` an unknown profile (was: silent creation)

1. `/at profile list` — note the exact set.
2. `/at profile use Typoo`
3. `/at profile list`

**Expected:** step 2 prints a not-found line naming `/at profile new Typoo` as the way to create it; step 3
lists exactly the same set as step 1 — **no new `Typoo` profile**, and the current profile is unchanged.

### 1.6 — the happy paths still work

1. `/at profile new SmokeTest2` → expect `Created and switched to new profile 'SmokeTest2'`; `/at profile
   current` reports `SmokeTest2`.
2. `/at profile copy Default` → expect `Copied settings from profile 'Default'`, and the bar visibly takes
   Default's styling.
3. `/at profile use Default` → expect the switch line.
4. `/at profile delete SmokeTest2` → expect `Deleted profile 'SmokeTest2'`; `/at profile list` no longer
   shows it.
5. `/at profile delete Default` while on `Default` → expect `Cannot delete the current profile` (unchanged
   behavior).

**Pass/Fail for C-1:** all six subsections behave as stated, and `/at profile` (bare) still prints the
seven-row help block.

---

## C-2 — `showOnlyInCombat` repaints every bar

**Change covered:** C-2 — the repaint is no longer gated on the player bar (F-004).

**Setup:** out of combat, in a quiet spot.

1. `/at toggle player` until the **Player** bar is **off** (`/at get units.player.enabled` → `false`).
2. `/at set units.target.enabled true`
3. Target a friendly player or an NPC that exists, so the target bar passes its `UnitExists` rung.
4. `/at set showOnlyInCombat true` — the target bar disappears.
5. `/at debug on` (so the `[Bar]` transition lines are visible), then `/at debug` to open the console.
6. `/at set showOnlyInCombat false`

**Expected:** the target bar reappears **and immediately shows the current absorb value and fill** for that
target (0 and empty is a correct value if the target has no shield — what must **not** happen is a full-fill
bar with stale or blank text). The debug console shows a `[Bar] target: shown (always)` line.

**Pass/Fail:** PASS if the reappearing bar's text/fill matches the target's actual absorb within the same
moment, with no absorb event needed to correct it.

**Regression side:** repeat with only the **Player** bar enabled and confirm the old behavior is unchanged.

---

## C-3 — Background class color from the live API

**Change covered:** C-3 — `bgClassColors` deleted; the tint derives from `C_ClassColor` (F-005).

**Setup:** best run on **two different classes** (any two you have). Fresh SavedVariables not required.

1. `/at set units.player.useClassColorBg true`
2. `/at set units.player.enabled true`, `/at unlock` so the bar is clearly visible.
3. Observe the bar's **background** (the area behind the fill) — it should be a dark version of your class
   color, roughly one fifth as bright.
4. Screenshot it.
5. Log to a character of another class and repeat steps 1-3.

**Expected:** each character's background is a recognizably darkened version of that class's color
(Warrior tan, Priest very dark gray-white, Shaman deep blue, and so on), and the two characters differ.
Compare against the pre-change screenshots if you have them — the values should be **visually identical**,
since the deleted table held the same colors the API returns.

**Pass/Fail:** PASS if the background is a dark class tint on both characters and neither is plain white.
White is the fallback and means the class token did not resolve.

**Also verify unchanged:** `/at set units.player.useClassColorBar true` — the **fill** still takes the full
class color, and `/at set units.player.useClassColorBg false` restores the picked background color.

---

## C-4 — Repaint path allocates nothing per pass

**Change covered:** C-4 — plain loops on the hot path (F-008).

**Setup:** a training dummy (Stormwind/Orgrimmar) and a way to generate absorbs (self-shield, or a healer).
`/reload` first so the session starts clean.

### 4.1 — behavior unchanged

1. `/at toggle` until all three bars are enabled, target the dummy, and set a focus.
2. Attack the dummy while shielded for ~30 seconds.

**Expected:** all three bars track their unit's absorb, with the same smoothness as before. No Lua error.

### 4.2 — allocation spot-check

1. `/run collectgarbage("collect"); print(collectgarbage("count"))` — note the number.
2. Stand at the dummy generating absorbs for exactly 60 seconds.
3. `/run print(collectgarbage("count"))` — note the number.
4. Repeat with the addon disabled (`/console scriptErrors 1`, disable AbsorbTracker, `/reload`) for a
   baseline.

**Expected:** the addon's contribution over 60 seconds is lower than before the change, and in any case
small. This is a **spot-check, not a gate** — Lua's shared heap makes the number noisy, which is exactly why
the real assertion is the deterministic allocation scenario in `tests/perf.lua`.

### 4.3 — the authoritative check is offline

From the repo root: `lua tests/perf.lua` (or whatever invocation `docs/performance.md` documents) and
confirm the allocation scenario added by C-4 passes. **Never** assert wall-clock time here — performance-§9
forbids it, and the harness will not help you.

### 4.4 — the test seam survived

Confirm `lua tests/run.lua` is still green, specifically the `tests/test_display.lua` cases that stub
`NS.ApplyVisibility` / `NS.UpdateBarAppearance`. Those cases are the proof that the bus handlers still look
their functions up on `NS` at dispatch time rather than freezing a load-time reference.

---

## C-5 — Profiles page builds lazily

**Change covered:** C-5 — the AceGUI container moves into first `OnShow` (F-009).

**Setup:** `/reload` so the session is fresh and the Profiles page has never been shown.

1. `/at config` — the panel opens on the landing page.
2. **Without** clicking Profiles, open the left tree and confirm **Ka0s Absorb Tracker** and all five
   sub-entries (General, Bar, Border, Font, Profiles) are listed.
3. Click **Profiles**.
4. Click **General**, then **Profiles** again.
5. Use one control on the Profiles page (e.g. the profile dropdown) to switch profile and switch back.

**Expected:** step 2 — the Profiles entry is present in the tree even though nothing has been drawn (this is
the eager-category rule; if the entry is missing, the change went too far). Step 3 — the AceDBOptions UI
renders in full inside the panel. Step 4 — it renders again with **no duplicated widgets** stacking on top of
each other. Step 5 — the switch works and the bar updates.

**Pass/Fail:** PASS if the tree entry exists before first show, the page renders on first show, and a second
show shows exactly one copy of each control.

---

## C-6 / C-7 / C-8 — README and version consistency

These are documentation changes; verify at the repo, not in the client.

1. `lua tests/run.lua --list > /tmp/cases.md` and compare its `**Total**` row to the `[tests]` badge in
   `README.md` — they must be the same number, and the badge must keep the `%2F` escape.
2. `lua tests/run.lua` — the new `tests/test_docs.lua` cases (badge-matches-inventory, version-in-three-places)
   must pass. Deliberately break one (edit the badge to a wrong number) and confirm the suite goes **red**;
   restore it. A gate that cannot fail is not a gate.
3. Read `## What's new in 1.9.0` and the top `## Version History` row side by side — they must carry the same
   highlights, and the breaking slash-path change must appear in both.
4. `grep -n "profile" README.md` — the `/at profile` row must describe the stricter `use` and the refusing
   `new`.
5. **CurseForge render check:** paste the changed README section into the CurseForge description editor's
   preview (or any strict-HTML markdown preview) and confirm no `<…>` placeholder is swallowed and the badge
   row renders five badges.

---

## C-9 — Dead-code sweep

**Change covered:** C-9 — deletions and comment corrections (F-011…F-015, F-017).

1. `lua tests/run.lua` → green; `luacheck .` → clean. These deletions are exactly the kind lint catches if a
   caller was missed.
2. In game: `/at debug on` → expect the `debug logging ON` line and, if the console is closed, `/at debug` to
   open it. `/at debug off` → expect the OFF line. (This exercises the two branches C-9 deleted around.)
3. `/at unlock` → drag the player bar → `/at lock`. `/reload`. The bar must return to where you dropped it —
   this exercises `NS.Units.SetPosition`, whose neighbor `Units.Set` was deleted.
4. `/at config` → **Bar** page → switch the Unit dropdown to **Target** → tick and untick **Use same styling
   as Player** → click **Copy styling from Player**. All three must work: they are the surviving callers of
   the `core/Units.lua` mirror API.

---

## Regression suite

Not tied to any one change; run all of it before signing off.

| # | Check | Expected |
|---|---|---|
| R-1 | `/reload` with the addon loaded | No Lua error; all enabled bars return to position and value |
| R-2 | Fresh SavedVariables → log in | Defaults populate; player bar shows, target/focus do not; `/at get units.player.barWidth` → `200` |
| R-3 | Login sequence `ADDON_LOADED` → `PLAYER_LOGIN` → `PLAYER_ENTERING_WORLD` | No error; `/at debug on` then `/reload` and re-enable to read the `[Init]` summary line |
| R-4 | Enter and leave combat with all three bars visible | Bars stay visible and keep updating; no error; with debug on, one `[Combat] left: N events, M repaints` rollup |
| R-5 | `showOnlyInCombat true`, enter/leave combat | Bars appear on entering, disappear on leaving, with correct values both ways |
| R-6 | Profile switch via the Profiles page and via `/at profile use` | Bar re-styles and re-positions to the new profile; open panel refreshes |
| R-7 | Open every settings page and toggle **every** option at least once | No error; each change takes effect immediately; the always-shown scrollbar stays visible on the short pages |
| R-8 | Per-page **Defaults** button on General, Bar, Border, Font — and the Blizzard **footer** defaults control on each | Both restore that page's defaults; they agree with each other |
| R-9 | **Reset All Settings** button → confirm | Popup appears; everything resets; every bar recenters; Profiles are untouched |
| R-10 | `/at resetall`, then `/at resetposition` | Same outcomes as R-9's button and the Reset Position button |
| R-11 | `/at list`, `/at get`, `/at set`, `/at reset` on one path each | Values echo in the gold-key/white-value shape; a mirrored unit's appearance row carries the gray `(mirrored …)` note |
| R-12 | `/at test 250000 8` | All visible bars fill with `250K` and hold for 8 seconds, then resume live values |
| R-13 | `/at perf` bare | The guided workflow prints; `/at perf start` … a full run … `/at perf report` completes and the report names all five buckets |
| R-14 | Perf **suspend** arm | With suspend active, every bar is hidden and stays hidden through a combat transition and a target swap |
| R-15 | `/at version`, `/at help` | Version matches the TOC; help lists all 17 commands |

---

## Taint-specific checks

The review raised **no** taint findings — the addon calls no protected API. These two are confirmation, not
remediation:

1. Enter combat, then `/at config`. **Expected:** one gray `[AT]` notice that settings cannot be opened
   during combat; the panel does **not** open. Leave combat, `/at config` again — it opens.
2. In combat, click several action bar slots and use a couple of abilities.
   **Expected:** no `Interface action failed because of an AddOn` message.
3. Open the panel from **Esc → Options → AddOns → Ka0s Absorb Tracker** as well as from `/at config` — both
   must land on the same category and render identically.

---

## Localization checks

The review raised no locale findings requiring a locale switch (F-019 is informational; F-010 is upstream).
Optional confirmation if a deDE/frFR client is convenient: switch locale, run R-7 and R-11, and confirm the
addon's English strings render as English rather than as missing-key garbage — they are literals, so they
should be unchanged.

---

## Performance spot-checks

Covered under C-4 above (4.2 and 4.3). If you want a frame-time reading as well:
`/console scriptProfile 1` → `/reload` → generate absorbs at a dummy for 60 s →
`/run UpdateAddOnCPUUsage(); print(GetAddOnCPUUsage("AbsorbTracker"))`. Treat the number as indicative only:
`docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md` in this repo documents why the
profiler misattributes shared-frame cost, which is the whole reason the addon carries its own harness.

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
| U-1 (after re-vendor) | | | |
| R-1 … R-15 | | | |
| Taint 1-3 | | | |
