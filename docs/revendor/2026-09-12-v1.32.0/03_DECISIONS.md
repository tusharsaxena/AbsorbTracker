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
