# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.58.0..v1.60.0` (17 commits), the `CHANGELOG.md` blocks
`## v1.60.0` (`:13`) and `## v1.59.0` (`:155`) with their "What a consumer owes" sections (`:121`,
`:190`), and the `Since` markers in `docs/api/DebugLog/version-14.1-docs.md`,
`docs/api/Slash/version-16-docs.md` and `docs/api/Widgets/version-10.3-docs.md`, all at tag v1.60.0.
The contract blocker in `01_DELTA.md` 3g (the stub's three members) is not a candidate; it landed in
the copy commit.

## A. Delivered on the re-vendor alone

- **The 3000-line console buffer** (`DebugLog.lua` 14, `lib.MAX_BUFFER` 1500 -> 3000,
  `lib.BUFFER_SLACK` 64 -> 128; `version-14.1-docs.md` "Compatibility", `:610-614`). No suite of this
  addon pins the buffer. Docs that state 1500 lines (`docs/module-map.md:808`) are DR-AT-05's.
- **`lib.TIME_COPY`**, the copy-timing switch (DebugLog 14). Off by default; nothing to wire.
- **`diagnostics` live while disabled** (Slash 16, `version-16-docs.md:39`). `settings/Slash.lua`'s
  `liveVerbs` is built from `SlashLib.LIVE_VERBS`, so it inherits the verb with no edit.
- **The kit's diagnostics contract suite** (kit revision 27, `testkit/test_diagnostics_contract.lua`),
  declared in `tests/run.lua`; one declared skip until `Kit.diagnostics` is wired.

## B. Host change required

| # | Candidate | Evidence | Touches | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | **The diagnostics report**: `brandName` and `diagnostics` descriptor fields, `D:RunDiagnostics`, `D:DebugVerb`, and both slash forms on Slash 16 | `version-14.1-docs.md:490-491`, `:524-526`; `version-16-docs.md:39`; CHANGELOG `:121` "Owed by `debug-logging-§14`" | `core/DebugLogSetup.lua`, a new sections file, `settings/Slash.lua`, `tests/run.lua` (`Kit.diagnostics`), tests | **Adopt**, in DR-AT-03 (the plan's decision; standard v2.68.0 makes it a MUST) | Additive |
| B2 | **The DragHandle close mark (X)**: `spec.onClose`, `closeIcon`, `closeTooltip` | `version-10.3-docs.md:25-31`, `:44`; CHANGELOG `:190` | `modules/Bar.lua` strips (player, target, focus), locale, `tests/test_draghandle.lua` Measure pins | **Adopt**, in DR-AT-06 (owner ruling Q1 / DR-OW-03: X sets `units.<unit>.enabled = false` on every bar) | Additive, but it widens every strip by 36px |

## C. Whole-module adoption

None. v1.60.0 adds no major (`DebugLogDiagnostics.lua` is a second file of DebugLog), and every
major this addon did not consume at v1.58.0 is unchanged in this range.
