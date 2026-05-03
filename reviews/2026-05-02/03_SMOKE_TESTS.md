# Smoke Tests — Ka0s Absorb Tracker (2026-05-02 review)

Manual QA recipe to validate the three milestones (M1 / M2 / M3) shipped from this review. Pair this with the general manual recipe in [`docs/smoke-tests.md`](../../docs/smoke-tests.md) — that doc covers normal user-facing functionality; this one walks the *specific* findings the review identified, so a regression in any item maps directly back to a finding ID and the commit that introduced the change.

Run on retail Midnight (Interface 12.0.x) with a clean `/reload` between sections. Where a test references a chat output, the literal string includes the cyan `[AT]` prefix that `AddonTable.Print` prepends; the prefix is omitted from the expected output column for brevity.

---

## Setup (~1 minute)

- [ ] **Branch is on the review tip.** `git -C $REPO log --oneline -5` shows `dabad81`, `c145ccd`, `db43379`, `91db404`, `a0a0a34` as the five most-recent commits before `3415c29` (the review-doc commit). Five commits ahead of `origin/main`.
- [ ] **Addon loads without error.** `/reload` produces no error frame, no `[AT]` chat error, and the bar is visible (or hidden, if your last session set `hidden = true`). Watch the chat for any `Lua error` toast; the file split is mechanical, so any load-time syntax error is a regression in M2.
- [ ] **TOC includes the four `Panel/*.lua` lines** and the original `Options/*.lua` order is unchanged. `cat AbsorbTracker.toc` shows, in order: `OptionsPanel.lua`, `Panel\Helpers.lua`, `Panel\ScrollPatch.lua`, `Panel\Widgets.lua`, `Panel\About.lua`, `Options\General.lua`, `Options\Bar.lua`, `Options\Border.lua`, `Options\Font.lua`, `Options\Profiles.lua`.
- [ ] **`/at debug` is OFF** (the default). If you're not sure, run `/at debug` once and watch for `Debug mode DISABLED`; if it printed `Debug mode ENABLED`, run `/at debug` once more.

---

## C-A — M1 correctness fixes (~5 minutes)

The four M1 tasks each gate a specific finding. Run all five tests; if any fails, the issue is in commit `a0a0a34`.

### F-001 — `/at help` shows the actual version (not `v?`)

- [ ] `/at help` — first line reads `v1.7.0 — slash commands (/absorbtracker is an alias for /at):` (or whatever the current `## Version:` in `AbsorbTracker.toc` is). The `v?` placeholder would mean both `getVersion` API branches returned nil, which is the bug F-001 hardened against.

### F-002 — AceDB-missing fallback path doesn't alias defaults (latent)

This path is dormant in the shipped configuration (AceDB ships in-tree under `libs/Ace3/AceDB-3.0/`), so a normal smoke test can't exercise it. The defensive deep-copy is verified by code review; the only runtime check is:

- [ ] **`/reload` produces no error and `/at list` shows colors as RGBA tables.** Specifically: `/at get barColor` prints `barColor = {r=0.40, g=0.70, b=1.00, a=0.80}` (or the user's saved value). The values are *correct* under the AceDB path; F-002's deep-copy only matters if a future contributor adds an in-place mutation to the `else` branch in `Events.lua`.

### F-003 — Panel writes route through `SetByPath`

- [ ] `/at config` → **General** sub-page. Toggle **Show Bar** off → bar hides. Toggle on → bar shows. The toggle calls `set(row, value)` which now goes through `AddonTable.SetByPath`; the resulting `onChange` is what triggers `UpdateBarAppearance` / `UpdateAbsorbBar`. If the bar doesn't react to the toggle, `set` is bypassing the dispatch.
- [ ] **Class-color pairing still works.** `/at config` → **Bar** → toggle **Use Class Color** under Bar Fill. The **Bar Color** picker greys out within one frame (no `/reload` needed). Toggle off → picker un-greys. The greying is driven by the `disabledIf` refresher closure, which only fires if `Helpers.RefreshAllPanels()` runs after the toggle. F-003 preserves that.
- [ ] **Slash + panel converge.** `/at config` open. `/at set borderSize 16`. The Border sub-page's slider (if you click into it) shows `16`, not the previous value. This proves that `/at set` (which uses `SetByPath` directly) and the panel widget's internal `set` (which now also routes via `SetByPath`) reach the same `db.profile`.

### F-004 + F-013 — `/at test` hold + hidden-bar warning

- [ ] **Hold survives the next ticker tick.** `/at test 999999`. Bar paints `999K` and stays painted for ~5 seconds (the default `hold`). After the hold expires, the next ticker tick resumes and the bar reverts to your real absorb value. The bug F-004 hardened against would have shown `999K` for at most one ticker interval (default 1 s).
- [ ] **Custom hold respected.** `/at test 50000 2`. Bar paints `50K` and reverts after ~2 seconds.
- [ ] **Hidden bar prints warning.** `/at toggle` (bar hides) → `/at test 50000`. Chat prints `Bar is hidden; run /at toggle to show it before testing` (no terminal period — F-016 normalized this), and the bar stays hidden. `/at toggle` again to restore.
- [ ] **Test message format.** `/at test 50000 5` (with bar visible) prints `Testing display with value: 50K for 5 s`.

---

## C-B — M2 file split + `lsmValues` dedupe (~15 minutes)

The split is mechanical — every panel widget should behave identically to before M2. Any visible delta is a regression in commit `91db404` and bisects to one of the four slices (M2.1 Helpers, M2.2 ScrollPatch, M2.3 Widgets, M2.4 About).

Run with `/reload` from character select before starting this section so widget state is fresh.

### Settings panel opens and tree expands

- [ ] `/at config` opens the Blizzard Settings UI on the **Ka0s Absorb Tracker** parent page. The left tree shows the parent expanded with five sub-pages visible: **General**, **Bar**, **Border**, **Font**, **Profiles**. Each is clickable.
- [ ] **About page renders** on the parent page: logo (300×300 absorbtracker.logo.v2.tga, top-left), the addon's `Notes` blurb, a "Slash Commands" heading, and one row per `AddonTable.SlashCommands` entry formatted as `/at <cmd>  —  <desc>`. M2.4 moved the about page builder; if any of these blocks is missing or misaligned, regression is in `Panel/About.lua`.
- [ ] **About page slash list matches `/at help`.** Count the rows on the about page; they should match `/at help`'s slash entries (15 rows: help / config / list / get / set / reset / resetall / resetposition / lock / unlock / toggle / debug / update / test / profile).

### Every sub-page renders

For each sub-page (General, Bar, Border, Font, Profiles):

- [ ] **Header is correct breadcrumb form.** Sub-pages show `Ka0s Absorb Tracker  |  <Page>` in `GameFontNormalHuge`. About page shows just `Ka0s Absorb Tracker`. M2.1 (`Panel/Helpers.lua`'s `buildHeader`) reads `AddonTable.PARENT_TITLE` for the prefix.
- [ ] **`Options_HorizontalDivider` atlas is present** below the title, tinted to the title's font color (gold).
- [ ] **Defaults button at TOPRIGHT** on General / Bar / Border / Font (110 px wide, says "Defaults"). Profiles deliberately has no Defaults button (AceDBOptions owns its own UI).

### Schema row count matches `/at list`

- [ ] `/at list` prints rows under four `[page]` headings: `[general]`, `[bar]`, `[border]`, `[font]`. Total row count: **17** (general: 3, bar: 8, border: 4, font: 3). The same 17 rows appear as widgets on their respective sub-pages.

### Each widget type renders and writes

Use Bar sub-page for the comprehensive widget audit (it has all four types):

- [ ] **CheckBox** — toggle **Use Class Color** (Bar Fill). The checkbox state flips, the bar repaints with class color, the **Bar Color** picker greys.
- [ ] **Slider** — drag **Bar Width**. On mouse-up, the bar resizes. Snapping to the 1 px step is enforced (you can't end at 124.5 px).
- [ ] **Dropdown (LSM swatch)** — open **Bar Texture**. Hover entries; preview swatch updates. Pick a different texture; bar repaints. M2.5 routes the values list through `Helpers.LSMValues("statusbar")`.
- [ ] **ColorPicker** — open **Bar Color**. Drag the picker; bar fill updates with ~50 ms throttle (drag is smooth, not staircase-steppy). Click out (commit) — bar holds the new color. Open again, hit Cancel — bar reverts to the pre-drag color (the throttle redesign in M3.8 preserves the cancel-to-original behavior; if cancel doesn't revert, regression is in `Panel/Widgets.lua`'s `OnValueConfirmed` wiring).

### Per-page Defaults button restores values

For each schema-driven sub-page (General, Bar, Border, Font):

- [ ] Make at least one change (e.g. flip a checkbox, drag a slider). The change shows in the bar.
- [ ] Click the page's **Defaults** button. Every schema row on *that page only* reverts to its `flatDefaults` value; widgets on the page re-sync within one frame; bar reflects the reverted state.
- [ ] Other pages' values stay untouched (e.g. resetting Bar doesn't reset Font's `font` to default).

### Scrollbar always visible

- [ ] **General** (short page, ~3 rows). Open it and confirm the AceGUI scrollbar gutter on the right is present, with the scrollbar greyed out (no content to scroll). Width of the body content is the same as Bar's. M2.2 (`Panel/ScrollPatch.lua`) is what enforces this.
- [ ] **Bar** (longer page). Scrollbar is active; thumb fills proportionally; up/down buttons enabled.
- [ ] **`/reload` and re-open Settings**, switch between sub-pages. Each panel's scrollbar persists with the same gutter; switching from General to Bar to Font doesn't move the body's right edge.

### Profile switch refreshes panels

- [ ] `/at config` → **Profiles** → create a new profile **SmokeTest** via the AceDBOptions UI. Bar resets to defaults; the General / Bar / Border / Font widgets re-sync to default values within one frame. M2.1 (`Helpers.RefreshAllPanels` registry) is what drives the re-sync.
- [ ] Switch back to **Default** profile. Panels re-sync to your saved values. Bar appearance reverts.
- [ ] Delete **SmokeTest** profile via the UI. No errors.

### `/at set` mirrors panel state

- [ ] `/at config` open on **Bar** sub-page (so the **Bar Width** slider is visible). Run `/at set barWidth 250`. The slider on the Bar page updates to 250 within one frame; the bar resizes. Refresh path: `/at set` → `SetByPath` → `RefreshOptionsPanel` → `Helpers.RefreshAllPanels`.

### Combat-lockdown gate (regression check)

- [ ] In a low-stakes combat (a target dummy, or pull a low-level mob), run `/at config`. Chat prints `Cannot open settings panel during combat. Try again after combat ends.` (this string has a terminal period — it lives in `OptionsPanel.lua` and was outside F-016's SlashCommands.lua scope). The Settings UI does **not** open. Drop combat; `/at config` opens normally.

---

## C-C — M3 polish sweep (~3 minutes)

M3 is supposed to be invisible. If anything looks different, the regression is in commit `db43379` and bisects to one of the eight tasks (F-007 / F-008 / F-009 / F-010 / F-011 / F-012 / F-016 / F-017).

### F-007 — DebugPrint hot-path gate

- [ ] `/at debug` (toggles DEBUG on; chat prints `Debug mode ENABLED`). Watch the chat — every ticker tick (default 1 s) now prints `UpdateAbsorbBar - Absorb: ... MaxHP: ... Timestamp: ...`. The line should appear at exactly the configured `updateInterval` cadence. Run `/at debug` once more; the per-tick chat spam stops. If it doesn't, F-007's gate is broken.
- [ ] **With debug OFF**, the per-tick line does NOT appear. (This was already true before M3; the M3 change is that the `AbbreviateNumbers` + `format` calls inside the line don't run either, which is invisible to the user but observable in a profiler.)

### F-008 / F-009 / F-010 — dead-code sweep (invisible)

- [ ] **`/reload`** with no errors. The `Timer.lua:6` local was unused, `Core.lua:7` `AddonTable.min` was unused, `Display.lua:80-81` re-declared locals were redundant — removing them changes nothing visible. Confirm no Lua errors at load.
- [ ] **`/at update`** triggers a repaint. `Display.UpdateAbsorbBar` lost two file-local re-declarations in M3.4; the function still has access to `GetSetting` / `DebugPrint` via the file-scope locals.

### F-011 + F-012 — Color picker throttle redesign

The original throttle had a small but non-zero per-event garbage cost. The redesign keeps a single timer and reuses `pendingArgs`. Behavior should be indistinguishable to a user.

- [ ] **Sustained drag is smooth.** Open **Bar Color**, drag the saturation/brightness picker for several seconds in a circle. The bar fill updates fluidly (no visible stutter or staircase). Final color (when you let go) matches the picker's final state.
- [ ] **Single click commits.** Open the picker, click a single new color, click out. The bar updates within ~50 ms (the new throttle's commit latency). Functionally identical; the user-perceived latency is sub-100 ms, well under the human threshold.
- [ ] **Cancel reverts.** Open picker, drag, click Cancel. The bar snaps back to the pre-drag color (commit path is independent of the throttle).

### F-016 — Chat punctuation consistency

- [ ] `/at profile delete <currentProfile>` (substitute the actual current profile's name). Chat prints `Cannot delete the current profile` — **no terminal period** (F-016 normalized this). Compare the period-bearing version that existed pre-M3 (`Cannot delete the current profile.`).
- [ ] `/at profile` (no subcommand) prints the help block. None of the lines end in a period.
- [ ] `/at` with no command prints the help block. None of the listed slash descriptions end in a period.

### F-017 — Undocumented profile aliases removed

- [ ] `/at profile use Default` — works (switches to Default profile).
- [ ] `/at profile set Default` — chat prints `Unknown profile subcommand 'set'`. Pre-M3, `set` was a hidden alias for `use`; M3.7 removed it.
- [ ] `/at profile new SmokeTest2` — works (creates and switches).
- [ ] `/at profile create SmokeTest3` — chat prints `Unknown profile subcommand 'create'`.
- [ ] `/at profile delete SmokeTest2` — works (deletes).
- [ ] `/at profile remove Default` — chat prints `Unknown profile subcommand 'remove'`.
- [ ] Clean up: `/at profile list` and verify no orphan **SmokeTest2** / **SmokeTest3** / **SmokeTest** profiles remain. Delete any that do.

---

## Triage matrix

| Symptom | Likely milestone | Bisect target |
|---|---|---|
| `/at help` prints `v?` | M1 | `SlashCommands.lua` `getVersion` (a0a0a34, F-001) |
| Saved-variable mutation corrupts subsequent profile defaults | M1 | `Events.lua` AceDB-missing fallback (a0a0a34, F-002) |
| Class-color toggle no longer greys/un-greys color picker | M1 | `OptionsPanel.lua` panel `set` (a0a0a34, F-003) |
| `/at test` flickers and reverts in <1 s | M1 | `Display.lua` testHoldUntil early-out (a0a0a34, F-004) |
| `/at test` while hidden silently no-ops | M1 | `SlashCommands.lua` runTest hidden check (a0a0a34, F-013) |
| Settings panel fails to load (Lua error at PLAYER_LOGIN) | M2 | One of the four `Panel/*.lua` (91db404, F-005) |
| LSM dropdowns empty / no swatch list | M2 | `Helpers.LSMValues` not wired (91db404, F-006) |
| Single sub-page broken; others fine | M2 | `Options/<that-page>.lua` schema row regression |
| About page missing logo / slash rows | M2 | `Panel/About.lua` `Helpers.BuildMainContent` (91db404, M2.4) |
| Scrollbar gone or asymmetric across pages | M2 | `Panel/ScrollPatch.lua` (91db404, M2.2) |
| Per-tick chat spam during combat | M3 | `Display.lua` DebugPrint guard inverted (db43379, F-007) |
| Color drag stutters or never commits | M3 | `Panel/Widgets.lua` throttle redesign (db43379, F-012) |
| `/at profile set X` succeeds | M3 | `SlashCommands.lua` runProfile (db43379, F-017 — alias still wired) |

---

## Out-of-scope (do NOT block on these)

- **F-014** (positional `entry[1]/[2]/[3]` access in `AddonTable.SlashCommands`): deferred per the plan; house-style match with KickCD.
- **F-015** (`Helpers.AttachTooltip` exposed but only used in-file): deferred; documented as part of the public Helpers contract.
- **Version bump**: explicitly excluded from this review per `CLAUDE.md`. Bump and tag at your discretion when ready to release.
- **Push to `origin/main`**: deferred per `CLAUDE.md` — no automated push.
