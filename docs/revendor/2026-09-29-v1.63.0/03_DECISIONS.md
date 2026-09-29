# Decisions (AbsorbTracker)

- **C1, the Slash minor 17 profile surface:** adopted, by item `SP-AT-02` of the run, in its second
  commit (`SP-AT-02: /at profile via CliProfile`). Owner decisions D1 and D3 of the run settle it:
  the verb's logic lives in the library, and a name that is not a stored profile is refused rather
  than created. The existing `profile` sub-tree stays; bare `profile` lists and prints the sub-help,
  a first word that is not a sub-verb goes to `CliProfile`, and `use <name>` goes to `ProfileSwitch`.
- Nothing else in v1.63.0 is adopted, and nothing else is offered: it adds no other surface.
- No adoption interview and no GitHub issues: the run's plan fixes the decision.
- Plan: `Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`.
