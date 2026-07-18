# 02 — Deviations

**Addon:** Ka0s Absorb Tracker · **Prefix:** `AT-` · **Standard:** v2.7.0 (2026-07-17) · **Run:**
2026-07-18 (second audit).

IDs are stable across runs — a deviation that recurs keeps its ID. The first audit (2026-07-12) ran
against standard v1.0.0 with the retired global `§N.M` notation and used IDs `AT-01`..`AT-25`; all but
one of those were remediated (see that run's `06_EXECUTION_OUTCOME.md`). This run cites the current
`filename-§N` scheme, reuses `AT-05` for the one recurring gap, and assigns `AT-26`+ for gaps newly
introduced by the standard's evolution since v1.0.0. Severity: **MUST** = non-negotiable bug;
**SHOULD** = strongly preferred / partial. Evidence in `03_EVIDENCE.md`; remediation in
`04_TECHNICAL_DESIGN.md` / `05_EXECUTION_PLAN.md`.

## Summary

| Severity | Count |
|---|---|
| MUST | 4 |
| SHOULD | 3 |
| **Total** | **7** |

Of these, three (**AT-29**, **AT-30**, **AT-31**) are already recorded as **accepted, documented
deviations** in `docs/ARCHITECTURE.md` and are re-surfaced here per the audit playbook; the other four
(**AT-05**, **AT-26**, **AT-27**, **AT-28**) are open and mechanically fixable.

## Deviations

| ID | Section | Severity | Deviation | Fix direction |
|---|---|---|---|---|
| AT-26 | `slash-commands-§3` | MUST | No standalone `version` verb in `NS.COMMANDS` — `/at version` is unhandled; the standalone, greppable "what version am I running?" verb (required since standard v1.9.0) is missing (the version appears only in the help header). | Add a `version` entry to `NS.COMMANDS` printing `<NS.PREFIX> v<version>` on its own line, reading `Compat.GetAddOnMetadata(NS.name,"Version")` with `NS.version` fallback; add the row to the README `## Usage` slash table. |
| AT-27 | `options-ui-§6` / `options-ui-§8` (anti-pattern #31) | MUST | The 50/50 paired action buttons (`Reset Position` \| `Reset All Settings`) are left at `SetRelativeWidth(0.5)`; the standard requires cell-filling paired buttons to inset to `BUTTON_PAIR_REL` = **0.492** so the right button clears the `ScrollFrame` clip. No `BUTTON_PAIR_REL` constant exists. | Define `BUTTON_PAIR_REL = 0.492` in `settings/Helpers.lua`, expose on `Helpers`, and set each button in `Helpers.InlineButtonPair`'s `makeBtn` to it instead of `0.5`. |
| AT-28 | `toc-file-§5` (anti-pattern #28) | MUST | TOC file-listing `#` sections are ordered Libraries → Core → Defaults → Locales → Modules → Settings; the standard mandates **Libraries → Locales → Core → Defaults → Modules → Settings** (Locales directly after Libraries). | Move the `# Locales` block (with `locales\enUS.lua`) to sit immediately after `# Libraries`, ahead of `# Core`. Mechanical; verify load still green. |
| AT-05 | `toc-file-§1` | MUST | Addon is published (has `X-Curse-Project-ID: 1450165`) but the TOC omits `X-Wago-ID`; the standard requires both once published anywhere. (Recurs from the 2026-07-12 run.) | Add `## X-Wago-ID: <id>` after `X-Curse-Project-ID` once a Wago listing exists; if the addon is deliberately not on Wago, record that as an accepted deviation in `docs/ARCHITECTURE.md` rather than leaving it silent. |
| AT-29 | `architecture-§4` (anti-pattern #19) | MUST | No closed message bus — modules communicate via direct `NS.X` function calls (`NS.RequestRepaint`, `NS.UpdateBarAppearance`, …), not named `SendMessage`/`RegisterMessage`. **Already an accepted, documented deviation** (`docs/ARCHITECTURE.md` "Standards Deviations"/"Known Limitations"). | Keep as accepted (a 3-module addon with a shared-`NS` facade), or, if adopting the bus, route cross-module signals through `NS.bus:SendMessage("Ka0s_AbsorbTracker_*", …)` with per-receiver `NS.NewBusTarget()` targets and document each message in `docs/ARCHITECTURE.md`. User decides. |
| AT-30 | `localization-§1` / `localization-§3` | SHOULD | Output localization not wired: user-facing strings (labels, tooltips, slash output, the reset-confirm popup) are hardcoded English and never routed through `NS.L`; `locales/enUS.lua` ships only the metatable seam, no keys. **Already documented** ("English only"). | Keep as accepted, or wrap user-facing strings in `NS.L["…"]` (English-string keys) and populate `locales/enUS.lua`; the metatable seam already exists so this is non-breaking. User decides. |
| AT-31 | `events-frames-taint-§1` | SHOULD | `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` are registered on a private `CreateFrame` via `RegisterUnitEvent("player")` rather than through AceEvent-3.0. **Justified & documented** (AceEvent cannot unit-filter; routing these floods C→Lua per unit in combat) — a `SHOULD` deviation carrying its in-code/`docs` rationale. | Retain as accepted (the justification is exactly the ">1000 events/min" case the rule exempts). No change recommended; kept in the ledger so it re-surfaces with its reason. |

## Notable compliant areas (no deviation)
- `architecture-§2` printer reclaim after AceConsole embed; `architecture-§5` schema-as-single-source
  with boot path-validation (a standard-cited reference implementation).
- `events-frames-taint-§8` secret-safe stringifier (`table.concat` probe) — the standard's named
  reference implementation.
- `options-ui` landing+subcategory, eager register/lazy body, combat-refuse, always-show scrollbar,
  layout constants, AceGUI Defaults button, in-place `refreshers` refresh (options-ui-§11).
- `debug-logging` full console (format pair, session-only flag, ON/OFF ack, `[Init]` summary,
  coalescing, `[Set]` seam).
- `documentation` README structure + four-place standards reference; `testing` 73/73 + generated
  inventory; `packaging`/`lint` clean.
- Sanctioned media (debug font JetBrains Mono, logo) — **not** flagged (standard v2.6.0).
