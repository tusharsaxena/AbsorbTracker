# Execution Plan — Ka0s Absorb Tracker

Companion to [`01_FINDINGS.md`](./01_FINDINGS.md) (the requirements) and [`02_PROPOSED_CHANGES.md`](./02_PROPOSED_CHANGES.md) (the design). This is the agent-team execution plan: ordered milestones, tasks per milestone, parallelization map, and human-coordinator checkpoints.

Tasks reference theme IDs (`T1…T7`) and finding IDs (`F-001…F-017`) from the companion docs.

---

## M1 — Correctness fixes (no refactor)

**Done when:** every High and Medium-correctness finding ships, manual smoke tests in `docs/smoke-tests.md` pass.

| Task | Owner-agent | Findings | Theme | Files touched |
|------|-------------|----------|-------|---------------|
| M1.1 | wow-api-migrator | F-001 | T1 | `SlashCommands.lua` |
| M1.2 | lua-refactorer  | F-002 | T3 | `Events.lua` |
| M1.3 | lua-refactorer  | F-003 | T2 | `OptionsPanel.lua` |
| M1.4 | ux-cleanup      | F-004, F-013 | T4 | `Display.lua`, `SlashCommands.lua`, `Core.lua` (or `Display.lua` for the `testHoldUntil` flag) |

**Concurrency map:**
- M1.1 ↔ M1.2 ↔ M1.3: disjoint files. **Parallelizable.**
- M1.4 touches `SlashCommands.lua` (so does M1.1) and `Display.lua`. **Serialize M1.4 after M1.1.**

**Suggested commit boundaries:**
- One commit per task. Messages:
  - `Slash: prefer C_AddOns.GetAddOnMetadata in /at help version line` (F-001)
  - `Events: deep-copy default tables in AceDB-missing fallback` (F-002)
  - `Panel: route widget writes through SetByPath` (F-003)
  - `/at test: hold the test value through next ticker tick` (F-004 + F-013)

**Checkpoint C-A (after M1):** human runs the manual QA recipe in `docs/smoke-tests.md`, focused on:
- `/at help` shows version (F-001 verification — easiest under a clean session).
- `/at config` opens (combat gate untouched, regression check).
- Color picker drag still smooth, color persists, paired class-color toggle still greys out the picker (F-003).
- `/at test 999999 5` paints for 5 s, then resumes live updates (F-004).
- `/at test` while bar is hidden prints the warning (F-013).

---

## M2 — `OptionsPanel.lua` split + `lsmValues` extraction

**Done when:** `OptionsPanel.lua` is ≤ 300 lines, the four `Panel/*.lua` files exist, the addon loads identically (no behavior change), and the sub-page rendering still passes the manual QA recipe.

**Pre-req:** M1 complete and merged. The split should land on a clean baseline so any regression is unambiguously the split.

| Task | Owner-agent | Findings | Theme | Files touched |
|------|-------------|----------|-------|---------------|
| M2.1 | lua-refactorer | F-005 (Helpers slice) | T5 | new `Panel/Helpers.lua`, `OptionsPanel.lua`, `AbsorbTracker.toc` |
| M2.2 | lua-refactorer | F-005 (ScrollPatch slice) | T5 | new `Panel/ScrollPatch.lua`, `OptionsPanel.lua`, `AbsorbTracker.toc` |
| M2.3 | lua-refactorer | F-005 (Widgets slice) | T5 | new `Panel/Widgets.lua`, `OptionsPanel.lua`, `AbsorbTracker.toc` |
| M2.4 | lua-refactorer | F-005 (About slice) | T5 | new `Panel/About.lua`, `OptionsPanel.lua`, `AbsorbTracker.toc` |
| M2.5 | lua-refactorer | F-006 | T5 | `Panel/Helpers.lua`, `Options/Bar.lua`, `Options/Border.lua`, `Options/Font.lua` |
| M2.6 | docs-writer    | F-005, F-006 | T5 | `docs/file-index.md`, `docs/module-map.md`, `docs/settings-panel.md` |

**Concurrency map:**
- M2.1 → M2.2 → M2.3 → M2.4: every step touches `OptionsPanel.lua` and `AbsorbTracker.toc`. **Strictly serialized.**
- M2.5 touches `Panel/Helpers.lua` (M2.1's output) plus three independent `Options/<page>.lua` files. **Run after M2.1.** Within M2.5, the three `Options/` edits are independently parallelizable from each other.
- M2.6 reads the new file layout. **Run after M2.4.**

**Suggested commit boundaries:**
- One commit per slice (M2.1, M2.2, M2.3, M2.4) so a regression bisect lands on the right file.
- One commit for M2.5.
- One commit for M2.6.

Commit messages:
- `Panel: extract Helpers (CreatePanel/Section/InlineButton/Tooltip/Defaults)`
- `Panel: extract ScrollPatch (PatchAlwaysShowScrollbar + ensureScroll)`
- `Panel: extract Widgets (CheckBox/Slider/Dropdown/ColorPicker + RenderSchema)`
- `Panel: extract About (top-level page builder)`
- `Options: dedupe lsmValues into Helpers.LSMValues`
- `docs: refresh file-index, module-map, settings-panel for Panel/ split`

**Checkpoint C-B (after M2):** human runs the full manual QA recipe — every page must render identically, every widget must behave identically. The split is mechanical; any visible delta is a bug.

---

## M3 — Polish sweep (Low-severity batch)

**Done when:** the dead-code / formatting / stylistic findings are addressed, with no behavior change.

**Pre-req:** M2 complete (so dead code in the new files is also covered) — but tasks here are independent of M2 except where noted.

| Task | Owner-agent | Findings | Theme | Files touched |
|------|-------------|----------|-------|---------------|
| M3.1 | lua-refactorer | F-007 | T6 | `Display.lua` (per-ticker call site only) |
| M3.2 | lua-refactorer | F-008 | T6 | `Timer.lua` |
| M3.3 | lua-refactorer | F-009 | T6 | `Core.lua` |
| M3.4 | lua-refactorer | F-010 | T6 | `Display.lua` |
| M3.5 | lua-refactorer | F-011 | T6 | `Panel/Widgets.lua` (or `OptionsPanel.lua` if M2 didn't ship) |
| M3.6 | ux-cleanup     | F-016 | T6 | `SlashCommands.lua` |
| M3.7 | ux-cleanup     | F-017 | T6 | `SlashCommands.lua` |
| M3.8 | lua-refactorer | F-012 | T7 | `Panel/Widgets.lua` (skip if M2 didn't ship) |

**Concurrency map:**
- M3.1 + M3.4 both touch `Display.lua`. **Serialize.**
- M3.6 + M3.7 both touch `SlashCommands.lua`. **Serialize.**
- M3.2, M3.3, M3.5, M3.8: disjoint. **All parallelizable** with each other and with the serialized pair above.

**Suggested commit boundaries:** one commit per task. Or batch as a single "polish sweep" commit if the team prefers fewer touches — none of the tasks individually warrants a stand-alone changelog line.

**Checkpoint C-C (after M3):** smoke-test recipe one more time. M3 is supposed to be invisible; if anything looks different, regression triage.

---

## Dependency graph (visual)

```
   M1.1  M1.2  M1.3
     \    |    /
      \   |   /
       \  |  /
        \ | /
         M1.4 (after M1.1)
          │
          ▼
       C-A (manual QA)
          │
          ▼
        M2.1
          │
        M2.2
          │
        M2.3
          │
        M2.4 ─▶ M2.6 (docs)
          │
        M2.5  (depends on M2.1)
          │
          ▼
       C-B (manual QA — full)
          │
          ▼
        M3 (mostly parallel; serialize within Display.lua and SlashCommands.lua)
          │
          ▼
       C-C (smoke test)
```

---

## File-level concurrency callouts

This table answers "if I dispatch multiple tasks at once, which collide?":

| File | Tasks that touch it |
|------|---------------------|
| `SlashCommands.lua` | M1.1, M1.4, M3.6, M3.7 |
| `Display.lua` | M1.4, M3.1, M3.4 |
| `Events.lua` | M1.2 |
| `OptionsPanel.lua` | M1.3 (then big rewrites in M2.1–M2.4) |
| `Core.lua` | M1.4 (testHoldUntil — optional placement), M3.3 |
| `Timer.lua` | M3.2 |
| `Panel/Helpers.lua` | M2.1 (creates), M2.5 (decorates) |
| `Panel/Widgets.lua` | M2.3 (creates), M3.5, M3.8 |
| `Options/Bar.lua` / `Border.lua` / `Font.lua` | M2.5 (independent of each other) |
| `AbsorbTracker.toc` | M2.1, M2.2, M2.3, M2.4 — strictly serialized |
| `docs/*` | M2.6 only |

When fan-out is allowed (e.g. parallelize M1.1 + M1.2 + M1.3, then run M1.4), make sure each agent rebases on the most recent merge before pushing.

---

## Out-of-scope for this plan

- `F-014` (positional `entry[1]/[2]/[3]` access): leave as house-style match with KickCD. Revisit if a third addon adopts a named-key version.
- `F-015` (`Helpers.AttachTooltip` exposed but only used in-file): docs say it's part of the public toolkit; intent is preserved.
- Any version bump to `AbsorbTracker.toc` or `README.md`: explicitly excluded per `CLAUDE.md` ("Never bump the version without an explicit instruction").
- Any `git add` / `git commit` / `git push`: human chooses when to commit, per `CLAUDE.md` ("Never auto-stage, auto-commit, or auto-push").

---

## Smoke-test surface (per checkpoint)

For each checkpoint, the manual recipe in `docs/smoke-tests.md` should be exercised. The findings touched in each milestone map to specific recipe sections:

- **C-A:** "settings panel — basic open and close", "color picker — drag and confirm", "/at test", "/at help".
- **C-B:** "settings panel — every sub-page renders", "schema row count matches `/at list`", "Defaults button per-page restores values", "scrollbar always visible across pages".
- **C-C:** light pass — "/at debug" toggles, profile switch refresh, every page still opens.

Triage any C-B regression to the most recent slice (M2.1 / M2.2 / M2.3 / M2.4) — bisecting is straightforward since each is its own commit.
