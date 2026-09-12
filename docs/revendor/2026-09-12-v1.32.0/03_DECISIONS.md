# 03 — Decisions

This run was **non-interactive**. The orchestrator's rollout brief (the debug-logging-§10 bulk-logging
rollout, AbsorbTracker section) stood in for the interview, and a correction the orchestrator sent
after the v1.32.0 review is applied:

| Candidate | Decision | Why |
|---|---|---|
| B1 Options bracket | **adopted** (`aebd427`) | Every page Defaults and Reset All goes through it. |
| B2 Slash bracket | **not adopted** | `/at resetall` never reaches `CliResetAll` (02_CANDIDATES B2). |
| B3 profile handler per event | **adopted** (`aebd427`) | §10: a reset or copy is logged once, by the handler, worded by the event. |
| B4 `CopyFromPlayer` one line | **adopted** (`aebd427`) | §10: a bulk copy is one `[Set]` line. |

Calls made along the way:

- **N is the host's own tally, not `bulkEnd`'s `count`** (the orchestrator's correction). The seam
  counts the writes that changed a stored value. The library counts every row whose `applyDefault`
  returned, including rows already at their default and General's `state.debugConsole`, which has
  no default and writes nothing.
- **An all-default Defaults press logs `: 0 rows`**, not silence. The correction allows either
  choice; a line keeps the press visible in the log.
- **Nested brackets are one act.** The tallies are summed, one line is emitted at depth 0, and
  nothing is emitted if any level reset the profile.
- **The reset line's N is `NS.ProfileRowCount()`** (68): every row the profile stores, since
  AceDB replaces the whole profile. That count is cheap, so §10 has it included. How many rows
  actually changed would need a snapshot taken before the reset, which is not cheap, and the
  count-where-cheap clause lets it be left out.

No issue was filed, and none is owed.

## Addendum (2026-09-12): the reset line's N was wrong

The last call above is **withdrawn**. The rule's clarification after the rollout (the
"Profile-reset count" ruling) says the `(N rows)` on `[Set] reset profile '<name>' to defaults
(N rows)` must be the rows the reset actually changed, or be left out. It must never be every row
the profile stores. `NS.ProfileRowCount()` returned the schema size (68) on every reset, including
one on a clean profile, and an independent verifier flagged it HIGH.

It was also wrong about cost. Counting the changed rows needs no snapshot: a pass over the schema
just before `db:ResetProfile()`, comparing each stored value with its default, is the same walk
`ProfileRowCount` already made. That is WhatGroup's `Settings.ConsumeResetCount` pattern.

What replaced it, on `fix/2026-09-12-triage`:

- `NS.ProfileRowCount` is gone. `NS.ProfileRowsOffDefault()` counts the profile rows off their
  default. `NS.ResetProfileCounted(db)` stores that count as pending, calls `db:ResetProfile()`,
  and clears the count when the reset returns or raises. `NS.OnProfileReset` takes the count once
  through `NS.ConsumeResetCount()`.
- All four addon-driven resets are counted: the descriptor's `resetProfile`, the degraded stub,
  `/at profile reset` and `/at profile new`.
- A reset the addon did not drive (AceDBOptions' button, a `/run`) has no pending count, and its
  line omits `(N rows)`.

This file's body stays as written. The corrected lines are in 05_SUMMARY.md's addendum.
