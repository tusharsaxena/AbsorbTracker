Delta: LibKa0s v1.58.0 -> v1.60.0 (span: v1.59.0 v1.60.0)

# 01 — Delta

Run: 2026-09-26, plan item DR-AT-01 of the 2026-09-25 diagnostics rollout
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/`, milestone M3). An orchestrated session
ran `/wow-addon:revendor-libka0s --tag v1.60.0` and answered its interview from the plan, which has
already decided every candidate (`03_DECISIONS.md`). Target: this repo, branch
`feat/2026-09-25-diagnostics-rollout`, cut from `master` @ `e5a7361`.

Source: the sibling checkout `../LibKa0s`, **tag `v1.60.0` (tag object `ac59511` -> commit
`bed0eb1`)**, extracted with `git -C ../LibKa0s archive v1.60.0 LibKa0s testkit | tar -x -C <scratch>/`,
never the working tree.

`git -C ../LibKa0s log --oneline v1.58.0..v1.60.0` lists 17 commits: v1.59.0's WidgetsDragHandle
minor 3 (`e8faa5d`, release `53c141a`, merge `c01db86`) and v1.60.0's DR-LK-01..DR-LK-06 (DebugLog
minor 14, DebugLogDiagnostics minor 1, Slash minor 16, kit revision 27, `MAX_BUFFER` 3000, release
`bed0eb1`). v1.59.0 was never vendored here on its own, so this bundle spans both tags.

## Base pre-flight

The newest single-tag bundle, `docs/revendor/2026-09-25-v1.58.0/`, names base v1.57.0 and new
v1.58.0 on line 1. `CLAUDE.md` named v1.58.0 before this run, and the vendored bytes are v1.58.0's
exactly: `diff -r --strip-trailing-cr <v1.58.0 archive>/LibKa0s libs/LibKa0s` and the same for
`testkit` against `tests/_kit` are both empty. The chain is unbroken.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.58.0 (MIT).` `README.md` has no provenance line. `docs/testing.md:170` restates the vendored tag
in prose and moves with it.

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives v1.58.0's
block (the left column of 3c). `grep -n 'Kit.VERSION' tests/_kit/framework.lua` gives kit revision
26. The claim and the bytes agree.

## 3c — Per-file minor delta

The tag's `LibKa0s/LibKa0s.xml` has 22 `<Script>` rows against the vendored 21: it adds
`DebugLogDiagnostics.lua` after `DebugLog.lua`.

| File | v1.58.0 | v1.60.0 |
|---|---|---|
| `Core.lua` | 8 | 8 |
| `Env.lua` | 1 | 1 |
| `Compat.lua` | 1 | 1 |
| `Lifecycle.lua` | 2 | 2 |
| `Bus.lua` | 2 | 2 |
| `Schema.lua` | 2 | 2 |
| `Pool.lua` | 3 | 3 |
| `Item.lua` | 2 | 2 |
| `Media.lua` | 4 | 4 |
| `Widgets.lua` | 10 | 10 |
| **`WidgetsDragHandle.lua`** (`DRAG_MINOR`) | 2 | **3** |
| **`DebugLog.lua`** | 13 | **14** |
| **`DebugLogDiagnostics.lua`** (`DIAG_MINOR`) | — | **1** (new file) |
| **`Slash.lua`** | 15 | **16** |
| `Launcher.lua` | 4 | 4 |
| `Options.lua` | 24 | 24 |
| `OptionsWidgets.lua` | 31 | 31 |
| `OptionsTabs.lua` | 4 | 4 |
| `OptionsCompose.lua` | 7 | 7 |
| `OptionsScroll.lua` | 4 | 4 |
| `Perf.lua` | 13 | 13 |
| `PerfPanel.lua` | 5 | 5 |

Three files move a minor and one is added. No major is added: the library is fifteen majors in
twenty-two files. The consumer was behind on no file before the copy (no cross-major skew).

## 3d — Both diffs

Content (`diff -rq --strip-trailing-cr`) and bytes (`diff -rq`) agree before the copy:

- `libs/LibKa0s`: `DebugLog.lua`, `LibKa0s.xml`, `Slash.lua`, `WidgetsDragHandle.lua` differ;
  `Only in <scratch>/LibKa0s: DebugLogDiagnostics.lua`.
- `tests/_kit`: `README.md`, `framework.lua` differ; `Only in <scratch>/testkit:
  test_diagnostics_contract.lua`.

No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing is deleted. The two diffs agree,
so nothing forked locally and the line endings have not drifted.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'` outside `libs/` and
`tests/`: the moved majors are consumed at

- `LibKa0s-DebugLog-1.0`: `core/DebugLogSetup.lua:14`;
- `LibKa0s-Slash-1.0`: `settings/Slash.lua:24` and `settings/Schema.lua:496`;
- `LibKa0s-Widgets-1.0` (the DragHandle): `modules/Bar.lua:15` and `modules/Display.lua:26`.

Every other lookup site is as recorded in `docs/revendor/2026-09-23-v1.56.0/01_DELTA.md` 3e.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **26 -> 27**. The
kit moves this time (new suite `test_diagnostics_contract.lua`), so both payloads move together in
one commit, and `tests/run.lua`'s suites list gains the kit's new suite in the same commit.

## 3g — Contract delta

`git -C ../LibKa0s diff --stat v1.58.0 v1.60.0 -- docs/api` adds `DebugLog/version-14.1-docs.md`,
`Slash/version-16-docs.md`, `Widgets/version-10.3-docs.md`, `testkit/version-27-docs.md` and their
member manifests, and flips the superseded documents' headers. No `grep -rn '__Attach' .` site
exists outside `libs/` and `tests/_kit/`, so no host-supplied callback moved its call site. Read
against the three consumed majors that moved:

- **Widgets 10.2 -> 10.3** (`version-10.3-docs.md`, "What changed at 10.3"): a strip whose spec
  has no `onClose` is exactly minor 2. This addon passes none today, so nothing moves on the copy.
- **Slash 15 -> 16** (`version-16-docs.md` header: "whose live set did not include
  `diagnostics`"): `lib.LIVE_VERBS` gains `diagnostics`. `settings/Slash.lua`'s `liveVerbs` is
  built from `SlashLib.LIVE_VERBS` plus `resetposition` and `profile`, so it inherits the verb. The
  addon ships no `diagnostics` verb yet (DR-AT-03), so nothing dispatches differently.
- **DebugLog 13 -> 14.1** (`version-14.1-docs.md` header): `MAX_BUFFER` 1500 -> 3000 and the slack
  64 -> 128. `grep -rn '1500\|MAX_BUFFER\|BUFFER_SLACK'` over this addon's own `.lua` finds no buffer
  pin (every `1500` hit is layout-§1's file cap). **The instance surface gains `RunDiagnostics`,
  `BuildDiagnostics` and `DebugVerb`.**

### Blockers

One, and it is an edit rather than a decision: **the degraded DebugLog stub in
`core/DebugLogSetup.lua` lacks the three new instance members**, so
`tests/test_surface_parity.lua`'s `parity: the DebugLog stub carries the whole live surface` goes red
on the copy. The v1.60.0 changelog ("What a consumer owes on re-vendoring v1.60.0") and
`02_SPEC.md` STD-14 of the rollout state the fix: `RunDiagnostics` prints the collection's
library-absent line, `"%s is unavailable: the LibKa0s library did not load."` naming
`/at diagnostics`, writes nothing and returns 0; `BuildDiagnostics` and `DebugVerb` are carried
beside it. It lands in the copy commit.

### Owed by the copy commit, not a blocker

- `tests/run.lua` declares `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }` (the kit's
  inventory fails the run until it does). With `Kit.diagnostics` unset it is one declared skip.
- The live-verb lists that spell the set out (`tests/test_disabled.lua` step 7,
  `tests/test_slashcmds.lua`'s `LIVE_WHILE_DISABLED`) and the builder's comment in
  `settings/Slash.lua` roll from twelve reserved verbs to thirteen.
