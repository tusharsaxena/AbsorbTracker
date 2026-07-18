# 05 — Execution Plan

Ordered, checkable remediation steps for the separate follow-up engagement (this audit is read-only).
Each step is tied to a deviation ID from `02_DEVIATIONS.md` and its design in `04_TECHNICAL_DESIGN.md`.
Work test-first; keep `lua tests/run.lua` (73/73 today) and `luacheck .` (0/0) green before each
commit. Do **not** auto-stage/commit/push and do **not** bump the version unless the user asks.

## Sprint 1 — Mechanical MUST fixes (fast, low-risk, independent)

- [ ] **AT-26 — `version` verb.**
  1. Add a failing test in `tests/test_slash.lua`: `findCommand("version")` is non-nil and its `fn`
     emits a line containing the version.
  2. Add the `{"version", "Print the addon version", fn}` row to `NS.COMMANDS`
     (`settings/Slash.lua`), using the existing `getVersion()`.
  3. Add the `/at version` row to the README `## Usage` slash table.
  4. Regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) and update the
     README `[tests]` badge to the new X/Y in the same change.
  5. Green gate.

- [ ] **AT-27 — `BUTTON_PAIR_REL` 0.492.**
  1. Add `local BUTTON_PAIR_REL = 0.492` to the layout constants in `settings/Helpers.lua` and expose
     it on `Helpers`.
  2. Change `makeBtn`'s `SetRelativeWidth(0.5)` → `SetRelativeWidth(BUTTON_PAIR_REL)`.
  3. Green gate; in-game smoke: confirm the right button's border is no longer clipped
     (`docs/smoke-tests.md`).

- [ ] **AT-28 — TOC section order.**
  1. Move the `# Locales` block above `# Core` in `AbsorbTracker.toc` (Libraries → Locales → Core →
     Defaults → Modules → Settings).
  2. Green gate (harness loads in TOC order — confirms the earlier locale load is safe).

- [ ] **AT-05 — `X-Wago-ID` (decision-gated).**
  1. Ask the user: is Absorb Tracker published on Wago?
  2. If yes → add `## X-Wago-ID: <id>` after `X-Curse-Project-ID` in the TOC.
  3. If no → add an accepted-deviation bullet to `docs/ARCHITECTURE.md` "Standards Deviations"
     ("CurseForge only; no Wago listing").

*Sprint 1 closes all four open MUST items. AT-26/27/28 are independent and can land in one green pass;
AT-05 waits on the user's Wago answer.*

## Sprint 2 — Accepted-deviation confirmations (documentation, no code)

- [ ] **AT-29 — message bus:** confirm with the user that the no-bus facade stays an accepted
  deviation; ensure the `docs/ARCHITECTURE.md` "Standards Deviations" entry cites the current
  `architecture-§4` reference (it currently reads as a Known Limitation — promote/cross-reference it
  so a future audit sees it as explicitly accepted). Only if the user chooses full conformance does
  this become a code sprint (see `04_TECHNICAL_DESIGN.md` AT-29 — bus + per-target receivers +
  documented messages + upgraded bus mock; do it in isolation with new tests).

- [ ] **AT-30 — localization:** confirm "English only" stays accepted, or schedule an incremental
  `NS.L` wrapping pass (page by page, English-string keys). Non-breaking either way.

- [ ] **AT-31 — private unit-event frame:** no action; keep the documented justification. Verify the
  `docs/ARCHITECTURE.md` entry references `events-frames-taint-§1`.

## Definition of done
- All four open MUSTs (AT-26, AT-27, AT-28, AT-05) resolved or explicitly recorded as accepted.
- The three carried deviations (AT-29, AT-30, AT-31) reconfirmed as accepted in
  `docs/ARCHITECTURE.md` with current `filename-§N` references.
- `lua tests/run.lua` and `luacheck .` green; `docs/test-cases.md` + README `[tests]` badge in
  lockstep; README slash table matches `NS.COMMANDS`.
- No version bump and no commit unless the user explicitly instructs.
