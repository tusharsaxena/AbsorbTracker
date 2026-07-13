# Final Summary — Ka0s Absorb Tracker (2026-05-02 review)

Outcome of the review captured on 2026-05-02 in [`01_FINDINGS.md`](./01_FINDINGS.md), designed in [`02_PROPOSED_CHANGES.md`](./02_PROPOSED_CHANGES.md), and executed via the milestones in [`04_EXECUTION_PLAN.md`](./04_EXECUTION_PLAN.md). Manual QA recipe lives in [`03_SMOKE_TESTS.md`](./03_SMOKE_TESTS.md).

> **Status:** All in-scope findings are shipped on `main`. Five commits ahead of `origin/main`, awaiting manual smoke-test sign-off and `git push`.

---

## TL;DR

- **15 of 17 findings resolved** across three milestones; **2 deferred** intentionally per the plan's "Out-of-scope" section.
- **`OptionsPanel.lua` shrank from 958 lines to 167** (the registration shell only); the panel toolkit moved into four `Panel/*.lua` slices (Helpers / ScrollPatch / Widgets / About), each decorating a single shared `AddonTable.Helpers` table.
- **Two latent correctness bugs hardened** (F-001 deprecated-API ordering, F-002 saved-variable aliasing) before they could fire in production.
- **One user-visible bug fixed** (F-004: `/at test` now actually paints for `[hold-secs]` instead of flickering for one ticker tick).
- **Convention drift closed**: panel writes now route through the documented `SetByPath` seam; LSM dropdown values factory deduplicated into a single `Helpers.LSMValues`; the dead `AddonTable.min` and the ghost `local UpdateAbsorbBar = …` are gone.
- **`/at` chat output is consistent** (no terminal periods); undocumented `/at profile` aliases (`set` / `create` / `remove`) are removed.
- **Color-picker drag** now allocates O(1) per drag session instead of ~60 closures + tables/sec at 60 Hz.
- **Docs synced** across `docs/file-index.md`, `docs/module-map.md`, `docs/settings-panel.md`, `docs/schema.md`, `docs/smoke-tests.md`, `ARCHITECTURE.md`, `CLAUDE.md`, and `README.md` (the `/at test` row).

---

## Findings status

| ID | Severity | Theme | Status | Resolution |
|---|---|---|---|---|
| F-001 | High | T1 — modern API surface | ✅ Fixed | M1.1 — `getVersion` prefers `C_AddOns.GetAddOnMetadata`. |
| F-002 | High | T3 — AceDB-missing fallback | ✅ Fixed | M1.2 — fallback seed loop deep-copies table defaults. |
| F-003 | Medium | T2 — `SetByPath` seam | ✅ Fixed | M1.3 — panel `set` and color-picker `commit` route via `AddonTable.SetByPath`. |
| F-004 | Medium | T4 — `/at test` actually tests | ✅ Fixed | M1.4 — `testHoldUntil` early-out in `UpdateAbsorbBar` + `runTest` accepts `[hold-secs]`. |
| F-005 | Medium | T5 — `OptionsPanel.lua` split | ✅ Fixed | M2.1–M2.4 — extracted `Panel/Helpers.lua`, `Panel/ScrollPatch.lua`, `Panel/Widgets.lua`, `Panel/About.lua`. |
| F-006 | Medium | T5 — `lsmValues` dedupe | ✅ Fixed | M2.5 — `Helpers.LSMValues(mediaType)` published; three duplicates dropped. |
| F-007 | Medium | T6 — DebugPrint hot-path guard | ✅ Fixed | M3.1 — per-tick `DebugPrint` wrapped in `if AddonTable.DEBUG then ... end`. |
| F-008 | Low | T6 — dead `local UpdateAbsorbBar` | ✅ Fixed | M3.2 — dropped from `Timer.lua:6`. |
| F-009 | Low | T6 — dead `AddonTable.min` | ✅ Fixed | M3.3 — dropped from `Core.lua:7`. |
| F-010 | Low | T6 — redundant intra-function locals | ✅ Fixed | M3.4 — dropped from `Display.UpdateAbsorbBar`. |
| F-011 | Low | T6 — `GetTime() and GetTime() or 0` | ✅ Fixed | Folded into M3.8 (the throttle redesign drops both call sites entirely). |
| F-012 | Low | T7 — color-picker throttle redesign | ✅ Fixed | M3.8 — single re-armed `C_Timer.NewTimer` + reused `pendingArgs` table. |
| F-013 | Low | T4 — `/at test` hidden warning | ✅ Fixed | Folded into M1.4 — `runTest` early-returns with chat hint when `hidden` is set. |
| F-014 | Low | (deferred) | ⏸ Deferred | Positional `entry[1]/[2]/[3]` access kept as house-style match with KickCD. |
| F-015 | Low | (deferred) | ⏸ Deferred | `Helpers.AttachTooltip` is part of the public Helpers contract per `docs/module-map.md`. |
| F-016 | Low | T6 — chat punctuation sweep | ✅ Fixed | M3.6 — uniform "no terminal period" rule across `SlashCommands.lua` `print()` sites. |
| F-017 | Low | T6 — undocumented `/at profile` aliases | ✅ Fixed | M3.7 — `set` / `create` / `remove` removed; only `use` / `new` / `delete` accepted. |

---

## What shipped, by milestone

### M1 — correctness fixes (commit `a0a0a34`)

Four fixes, four files, no refactor. Each hardens a specific dormant or active correctness issue.

| Task | Finding | File | Change |
|---|---|---|---|
| M1.1 | F-001 | `SlashCommands.lua` | `getVersion`: try `C_AddOns.GetAddOnMetadata` first, fall back to bare `GetAddOnMetadata`. Matches `OptionsPanel.lua`'s sibling `getMetadata` order. |
| M1.2 | F-002 | `Events.lua` | AceDB-missing seed loop deep-copies table-typed defaults (e.g. `barColor`) into `AbsorbTrackerDB` instead of aliasing the `flatDefaults` reference. |
| M1.3 | F-003 | `OptionsPanel.lua` | Panel `set(row, value)` calls `AddonTable.SetByPath(row.path, value)`; ColorPicker `commit(r,g,b,a)` does the same. The two-step `SetSetting + FireSchemaOnChange` open-coding is gone. |
| M1.4 | F-004 + F-013 | `Display.lua` + `SlashCommands.lua` | `Display.UpdateAbsorbBar` early-outs while `(AddonTable.testHoldUntil or 0) > GetTime()`. `runTest` parses `[value] [hold-secs]` (default 50000 / 5), prints a hidden-bar warning when `GetSetting("hidden")`, and sets `testHoldUntil = GetTime() + hold` after the paint. |

**Diff:** 4 files changed, +41 / −21.

### M2 — `OptionsPanel.lua` split + `lsmValues` extraction (commit `91db404`)

The 958-line `OptionsPanel.lua` was carrying six concerns. Each `Panel/*.lua` slice owns one. The file split is mechanical — every function body and signature was moved between files unchanged; only call-site name lookups (`attachTooltip` → `Helpers.AttachTooltip`, `ensureScroll` → `Helpers.EnsureScroll`, `addSpacer` → `Helpers.AddSpacer`) were rewritten.

| Task | Finding | New / touched | Notes |
|---|---|---|---|
| M2.1 | F-005 (Helpers slice) | new `Panel/Helpers.lua` | Layout constants, `attachTooltip`, `addSpacer`, `buildHeader`, `Helpers.CreatePanel`, `Helpers.EnsureScroll`, `Helpers.Section`, `Helpers.InlineButtonPair`, `Helpers.RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels`, plus the `renderedPanels` registry. Also publishes the cross-slice constants `Helpers.PADDING_X` / `HEADER_HEIGHT` / `ROW_VSPACER` / `SECTION_HEADING_H` so `Widgets.lua` and `About.lua` can read them without re-declaring. |
| M2.2 | F-005 (ScrollPatch slice) | new `Panel/ScrollPatch.lua` | `Helpers.PatchAlwaysShowScrollbar` — the always-visible-scrollbar override that rebinds `FixScroll` / `MoveScroll` / `OnRelease` on a single AceGUI ScrollFrame. Called once by `Helpers.EnsureScroll` per panel. |
| M2.3 | F-005 (Widgets slice) | new `Panel/Widgets.lua` | The four widget makers (`makeCheckbox` / `makeSlider` / `makeDropdown` / `makeColorPicker`), `applyWidth`, `snapToStep`, the `get` / `set` shims, `Helpers.RenderField` (dispatches by `row.type`), `Helpers.RenderSchema` (two-column flow + Section headings + `afterGroup` callbacks). |
| M2.4 | F-005 (About slice) | new `Panel/About.lua` | About-page block sizing, `LOGO_PATH`, `getMetadata`, `addBlock`, and `Helpers.BuildMainContent` (renamed from the file-local `buildMainContent`). `OptionsPanel.lua`'s `registerMain` now calls `Helpers.BuildMainContent(mainCtx)` on first OnShow. |
| M2.5 | F-006 | `Panel/Helpers.lua` + `Options/Bar.lua` / `Border.lua` / `Font.lua` | `Helpers.LSMValues(mediaType)` returns the deferred LSM-hash closure; the three duplicates in `Options/*.lua` are gone. |
| M2.6 | (docs) | `docs/file-index.md`, `docs/module-map.md`, `docs/settings-panel.md`, `docs/schema.md`, `ARCHITECTURE.md`, `CLAUDE.md` | File index lists the four Panel/ slices; module map shows the surface across slices and the load-order entry; settings-panel doc adds a source-layout section and updates the LSM-values factory description; schema / architecture / CLAUDE doc references retargeted to `Panel/Widgets.lua` and the multi-file split. |

**Net file shape:**

| File | Lines (before → after) | Role |
|---|---|---|
| `OptionsPanel.lua` | 958 → 167 | Registration shell only — publishes empty `AddonTable.Helpers` and `AddonTable.PARENT_TITLE`; owns `pendingPages`, `RegisterOptionsPage`, `CreateOptionsPanel`, `OpenOptionsPanel`, `RefreshOptionsPanel`, `expandMainCategory`, `registerMain`. |
| `Panel/Helpers.lua` | new — 354 | Toolkit core + layout constants + panel registry + `LSMValues` factory. |
| `Panel/ScrollPatch.lua` | new — 127 | `PatchAlwaysShowScrollbar`. |
| `Panel/Widgets.lua` | new — 296 | Widget makers + `RenderField` + `RenderSchema`. |
| `Panel/About.lua` | new — 108 | `BuildMainContent`. |

**Diff:** 15 files changed, +992 / −866 (net +126 lines, but only because the new files include their own banner comments).

### M3 — polish sweep (commit `db43379`)

Eight low-severity items batched into a single commit. Each is invisible to the user; together they remove drift, dead code, and one allocation hotspot.

| Task | Finding | File | Change |
|---|---|---|---|
| M3.1 | F-007 | `Display.lua:98` | Per-tick `DebugPrint` wrapped in `if AddonTable.DEBUG then ... end` so `AbbreviateNumbers` + `AddonTable.format` don't allocate when debug is off. |
| M3.2 | F-008 | `Timer.lua:6` | Dropped `local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar` (unused; the call site references the table directly). |
| M3.3 | F-009 | `Core.lua:7` | Dropped `AddonTable.min = math.min` (no readers anywhere). |
| M3.4 | F-010 | `Display.lua:80-81` | Dropped the redundant `local GetSetting = AddonTable.GetSetting` / `local DebugPrint = AddonTable.DebugPrint` re-declarations inside `UpdateAbsorbBar` body; the file-scope locals already cover them. |
| M3.5 + M3.8 | F-011 + F-012 | `Panel/Widgets.lua` | ColorPicker throttle replaced. The new design uses a single re-armed `C_Timer.NewTimer(0.05, ...)` and a reused `pendingArgs` table. A 60 Hz drag now produces O(1) garbage per session instead of ~60 closures + 60 tables/sec. The `GetTime() and GetTime() or 0` double-call (F-011) is dropped along the way (the new design doesn't need `lastCommit`). |
| M3.6 | F-016 | `SlashCommands.lua` | Uniform "no terminal period" rule across every `print()` site. Lines normalized: "Bar is hidden; run /at toggle to show it before testing", "Profile system requires AceDB-3.0", "Cannot delete the current profile", "No settings registered yet". |
| M3.7 | F-017 | `SlashCommands.lua` `runProfile` | Dropped the undocumented `set` / `create` / `remove` aliases. Only `use` / `new` / `delete` are accepted; anything else hits the "Unknown profile subcommand" branch. |
| (docs) | — | `docs/file-index.md`, `docs/module-map.md` | Refreshed `Core` / `Display` / `Timer` / `Panel/Widgets` line counts (35 / 112 / 39 / 292) and updated Display's hot-path note + the Widgets throttle note. Removed the `AddonTable.min = math.min` entry from the module-map's cached-globals block. |

**Diff:** 7 files changed, +29 / −34.

### Doc commits

Two single-purpose doc commits landed after M3 to address the proposal's flagged docs-debt:

- **`c145ccd`** — `docs/smoke-tests.md`: bar-paint section now exercises `/at test 999999 2` (custom hold) and the `/at toggle` → `/at test` hidden-bar warning. M1.4's behavior is now in the manual recipe.
- **`dabad81`** — `README.md`: command table's `/at test [value]` row updated to `/at test [value] [hold-secs] | Paint the bar with a fake value (default 50000) for the given duration (default 5 s) for visual tweaking`. The `/at help` description string had already been updated in M1.4; this closes the README half of the docs-debt the proposal called out.

---

## File-level changes (summary)

| File | Change | Touched in |
|---|---|---|
| `AbsorbTracker.toc` | +4 lines (Panel/* load order) | M2 |
| `ARCHITECTURE.md` | Settings panel paragraph rewritten for the multi-file split | M2.6 |
| `CLAUDE.md` | Doc-index pointer expanded to mention `Panel/<slice>.lua` | M2.6 |
| `Core.lua` | −1 line (`AddonTable.min`) | M3 |
| `Display.lua` | testHoldUntil early-out (M1.4); intra-function local cleanup (M3.4); DebugPrint guard (M3.1) | M1, M3 |
| `Events.lua` | Deep-copy in AceDB-missing fallback (F-002) | M1 |
| `Options/Bar.lua` | `lsmValues` factory removed; calls `Helpers.LSMValues("statusbar")` | M2.5 |
| `Options/Border.lua` | Same as Bar (`Helpers.LSMValues("border")`) | M2.5 |
| `Options/Font.lua` | Same as Bar (`Helpers.LSMValues("font")`) | M2.5 |
| `OptionsPanel.lua` | Shrunk 958 → 167 lines (registration shell only); panel `set` / color-picker `commit` route via `SetByPath` (F-003) | M1, M2 |
| `Panel/About.lua` | NEW (108 lines) — `Helpers.BuildMainContent` | M2.4 |
| `Panel/Helpers.lua` | NEW (354 lines) — toolkit core + `Helpers.LSMValues` | M2.1, M2.5 |
| `Panel/ScrollPatch.lua` | NEW (127 lines) — `Helpers.PatchAlwaysShowScrollbar` | M2.2 |
| `Panel/Widgets.lua` | NEW (292 lines) — widget makers + `Helpers.RenderField` + `Helpers.RenderSchema` + redesigned ColorPicker throttle | M2.3, M3 |
| `README.md` | `/at test` row updated to `[value] [hold-secs]` | docs-debt |
| `SlashCommands.lua` | `getVersion` API order (F-001); `/at test` description string and `runTest` body (M1.4); chat punctuation sweep (F-016); profile alias removal (F-017) | M1, M3 |
| `Timer.lua` | −1 line (dead `local UpdateAbsorbBar`) | M3 |
| `docs/file-index.md` | Three-section refresh: top-level Lua line counts, new Panel/ section, Options/ row notes | M2.6, M3 |
| `docs/module-map.md` | OptionsPanel API block split into shell + decoration; load-order step 13 added; cached-globals block updated | M2.6, M3 |
| `docs/schema.md` | Color-picker maker reference retargeted from OptionsPanel to Panel/Widgets | M2.6 |
| `docs/settings-panel.md` | Source-layout table added at the top; `buildMainContent` renamed to `Helpers.BuildMainContent`; `LSMValues` factory documented | M2.6 |
| `docs/smoke-tests.md` | `/at test` section covers `[hold-secs]` and hidden-bar warning | docs-debt |

---

## Deferred — kept open intentionally

### F-014 — positional `entry[1]/[2]/[3]` access in `AddonTable.SlashCommands`

Each command-list row is `{name, desc, handler}`; readers index by slot. Keeping it as-is per the plan's house-style match with KickCD. Revisit if a third addon adopts a named-key shape.

### F-015 — `Helpers.AttachTooltip` exposed but only used in-file

`docs/module-map.md` lists it as part of the public Helpers contract; the export is intentional even though only `Panel/Helpers.lua` itself currently calls it. No action needed.

---

## Out-of-scope by policy

- **Version bump.** `## Version: 1.7.0` in `AbsorbTracker.toc` and the README badge / Version History entry are unchanged. `CLAUDE.md` is unambiguous: "Never bump the version without an explicit instruction." Bump and tag at your discretion when ready to release.
- **Push to `origin/main`.** Five commits ahead, awaiting your `git push`. `CLAUDE.md`: "Pushing still requires a separate explicit ask."
- **`reviews/2026-05-02/REVIEW_*.md`.** These review docs (FINDINGS, PROPOSED_CHANGES, EXECUTION_PLAN, plus this SMOKE_TESTS / FINAL_SUMMARY pair) live in the repo as a frozen artifact of the review session. They were committed in `3415c29` (the original three) and the new pair lands as part of the review wrap-up.

---

## What's next (for you)

1. **Run the smoke-test recipe** in [`03_SMOKE_TESTS.md`](./03_SMOKE_TESTS.md) — C-A (~5 min), C-B (~15 min), C-C (~3 min). Total ~25 min if everything passes.
2. **If anything fails**, the triage matrix at the end of `03_SMOKE_TESTS.md` maps symptoms back to the milestone commit so you can `git revert` cleanly without unwinding unrelated work.
3. **`git push origin main`** when smoke tests pass.
4. **Bump version + tag** when you're ready to release. `1.7.0 → 1.7.1` is the conservative bump (the patch surface is bug fixes + internal refactor, no user-facing API change beyond the `/at test [hold-secs]` argument that's strictly additive).

---

## Appendix — commit list

```
dabad81  README: document /at test [hold-secs] argument
c145ccd  Smoke-test recipe: cover /at test [hold-secs] and hidden-bar warning
db43379  M3 review polish sweep: dead code, hot-path guards, throttle, chat punctuation
91db404  M2 review refactor: split OptionsPanel.lua into Panel/ toolkit slices
a0a0a34  M1 review fixes: API order, fallback deep-copy, SetByPath seam, /at test hold
3415c29  Capture 2026-05-02 wow-addon:review findings, proposals, execution plan  (pre-existing)
```
