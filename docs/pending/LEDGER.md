# Pending ledger

Every pending item `/wow-addon:pending-audit` has ever put to a human, and what they decided.
The command maintains this file: it reads it at the start of a run to avoid re-asking settled
questions, and appends to it at the end. Hand-editing works, but keep the columns intact — the
`Evidence hash` is what matches a row to the thing it is about.

An item is matched by **ID *and* evidence hash**. If the underlying text changes, the hash changes,
the row stops matching, and the item is deliberately raised again — a marker whose wording was
rewritten is a new question, not a settled one.

## Decision vocabulary

| Marker | Value | Meaning | Re-surfaces? |
|---|---|---|---|
| 🟢 | `done` | Implemented this run | No — closed |
| 🔵 | `wont-do` | User decided it will never be done | No — closed |
| 🟡 | `deferred` | Decided: not now. Still on the books | Yes, as a collapsed count |
| ⚪ | `untriaged` | Found, never put to the user | Yes — interviewed in full next run |

Three of these are decisions; `untriaged` is the *absence* of one, which is why it is the only value
that gets fully re-interviewed rather than collapsed into a count. A `untriaged` row never means
anyone agreed to anything.

There is deliberately no red: nothing in this ledger is an error state.

## Ledger

| ID | Evidence hash | Source | Decision | Issue | Date | Rationale |
|---|---|---|---|---|---|---|
| PLAN-01 | `05984cf2` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` (AT-05) | 🟢 done | — | 2026-07-31 | Not published on Wago — CurseForge only. Recorded as an accepted deviation in `docs/ARCHITECTURE.md` rather than adding the key, closing the last open MUST from that audit. |
| ISS-10 | `f0c7ab96` | GitHub #10 | 🟡 deferred | #10 | 2026-07-31 | Cannot be worked without a repro: the issue is a title with an empty body, and the border path has been rewritten twice since it was filed. |
| PLAN-02 | `87b37e3f` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` (AT-30) | 🟡 deferred | — | 2026-07-31 | Localization decision not made this run. "English only" stays under Known Limitations rather than being promoted to an accepted deviation. |
| PLAN-03 | `77a8ee64` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-008) | 🟡 deferred | #20 | 2026-07-31 | Second deferral, now tracked publicly. Previously deferred in commit `ef71076` to protect the M9 in-game pass. Design already specified (C-7 / M3.2). |
| DOC-01 | `d8f47c22` | `docs/reviews/2026-07-31/05_FINAL_SUMMARY.md` | 🔵 wont-do | — | 2026-07-31 | The review bundle is frozen history and stands as the pre-implementation document it announces itself to be. Left behind knowingly: the summary keeps claiming 18/18 addressed with nothing deferred, and keeps its `_fill in_` placeholders. The commit body of `ef71076` is the accurate record of what shipped. |
| ISS-17 | `7dae0445` | GitHub #17 | 🟢 done | #17 | 2026-07-31 | All three requested capabilities delivered (offline harness, in-game recipe + two captures, complexity report) and the question answered. Closed on GitHub with the evidence and pointers to its two continuations. |
| ISS-19 | `9a6ae035` | GitHub #19 | 🟢 done | #19 | 2026-07-31 | The reusable-harness half landed: the probe moved into LibKa0s and `core/Perf.lua` no longer exists here. Closed on GitHub; the remaining WowAddonStandards rollout is tracked by the three "Pending promotion" notes in `docs/ARCHITECTURE.md`. |
| ISS-18 | `56ca2052` | GitHub #18 | 🔵 wont-do | #18 | 2026-07-31 | Not this addon's problem — #17 cleared AbsorbTracker with three independent measurements. The remaining bisect is an in-game investigation of other authors' addons with nothing to change in this repo. Closed on GitHub at the user's explicit confirmation; the analysis survives in `docs/investigations/2026-07-29-combat-fps-drop/`. |
| PLAN-04 | `fc0521e5` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-013) | 🟢 done | — | 2026-07-31 | Implemented C-13 as designed: `NS.LIBKA0S_MISSING` in `core/CoreSetup.lua` is the single cause clause, and all five seams append their own "so <what> is unavailable". |
| PLAN-05 | `c19bec3e` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-011) | 🟢 done | — | 2026-07-31 | Went further than the review chose: deleted `NS.SlashCommands` and its stale comment outright rather than correcting the comment, since no in-repo reader was left. |
| PLAN-06 | `5feb8940` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-012) | 🟢 done | — | 2026-07-31 | Deleted the unreachable `stub.CliVersion` member from the degraded slash stub. |
| ISS-15 | `05728cee` | GitHub #15 | 🟡 deferred | #15 | 2026-07-31 | Real feature work — schema row, settings widget, repaint change. Deferred with a full design comment posted to the issue so it is ready to pick up. |
| ISS-8 | `80a0aab5` | GitHub #8 | 🟡 deferred | #8 | 2026-07-31 | Large feature: a second bar per unit with its own appearance settings. Not started this run. |
| ISS-6 | `1dff6c3a` | GitHub #6 | 🟡 deferred | #6 | 2026-07-31 | Large feature with real taint and combat-lockdown exposure. Not started this run. |
| ISS-5 | `37fe85c3` | GitHub #5 | 🟡 deferred | #5 | 2026-07-31 | Edit Mode integration overlaps the existing drag/lock positioning surface. Not started this run. |
| ISS-2 | `1deb4605` | GitHub #2 | 🟡 deferred | #2 | 2026-07-31 | Text-placement setting not started this run. |
| ISS-3 | `8b785aba` | GitHub #3 | 🟡 deferred | #3 | 2026-07-31 | Border offset not started this run; sensibly kept alongside #10 until the border symptom is pinned down. |
| ISS-4 | `49b4daca` | GitHub #4 | 🟡 deferred | #4 | 2026-07-31 | Fill direction not started this run. Small (one boolean row + `SetReverseFill`). |
| ISS-9 | `52f249b2` | GitHub #9 | 🟡 deferred | #9 | 2026-07-31 | Frame strata not started this run. Small (one select row + `SetFrameStrata`). |
