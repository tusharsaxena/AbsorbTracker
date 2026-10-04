Delta: LibKa0s v1.68.0 -> v1.68.1

# 01 — Delta (AbsorbTracker)

Run: 2026-10-04, an orchestrated session running `/dev-copilot:wow-revendor-libka0s AbsorbTracker
--tag v1.68.1` non-interactively. The owner pre-authorized the run and was not available for an
interview; the run was told to stop on any genuine decision (an adoption candidate, a contract
change, red unrelated to the re-vendor). None arose. Target: this repo, branch
`feat/2026-10-04-revendor-libka0s-v1.68.1`, cut from `master` @ `47f7ad3`, which equalled
`origin/master` after `git fetch` with a clean tree.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.68.1` (tag object `9fb7956` -> commit
`9000cbd`)**, which is also `git -C ../LibKa0s tag --sort=-v:refname | head -1`. The payloads were
extracted with `git -C ../LibKa0s archive v1.68.1 LibKa0s testkit | tar -x -C <scratch>/new`, never a
branch tip. `git -C ../LibKa0s log --oneline v1.68.0..v1.68.1` lists 7 commits: DC-REN-01 (kit
revision 36, the rename), DC-REN-02 to DC-REN-05 (release record and doc follow-ups), SD-FIN-01 (a
library test comment) and the `feat/2026-10-02-drag-attach` merge. `git -C ../LibKa0s diff --stat
v1.68.0 v1.68.1 -- LibKa0s testkit` names three files, all under `testkit/`: `framework.lua` (1 line),
`run-automated-tests.sh` (4 lines) and `test_eol.lua` (1 line).

This is the library's rename-only release: the kit names `/dev-copilot:*` commands where it named
`/wow-addon:*` (CHANGELOG v1.68.1, lines 13-53 at the tag).

## Step 0 — Base pre-flight (roster-wide, report only)

All eleven roster addons report `ok`: each newest single-tag bundle is `2026-10-02-v1.68.0` with base
v1.67.0, which matches the provenance line before its re-vendor commit (AbsorbTracker's is `63b0795`).
No misstated base, so no correction paragraph.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.68.0 (MIT).` The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit` ->
`63b0795`, left the line at v1.68.0, so the two agree. `git log --format='%h %s' 63b0795..HEAD --
CLAUDE.md` lists two commits (`3215549` DC-REN-01, `05f1f8c` SD-FIN-01), neither of which moves the
line. Payload check against the claimed tag: `diff -rq <v1.68.0>/LibKa0s libs/LibKa0s && diff -rq
<v1.68.0>/testkit tests/_kit` printed `payload-matches`. `docs/testing.md:170` restates the tag in prose
and moves with it. `README.md` has no provenance line.

**Base: v1.68.0.**

## 3b — Actual version, before this run

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` returns 32
constants, v1.68.0's (both columns of 3c), and `Kit.VERSION` is 35. Claim and bytes agree.

## 3c — Per-file minor delta

`git -C ../LibKa0s diff --quiet v1.68.0 v1.68.1 -- LibKa0s` exits 0: **the library payload is
byte-identical between the two tags**, the XML included. Walking the tag's `LibKa0s.xml` rows with the
playbook's loop (old from `libs/LibKa0s/<f>`, new from `git show v1.68.1:LibKa0s/<f>`), all 32 files
report the same constant on both sides: Core 10, Env 1, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 12 (WidgetsReorder 1, WidgetsDragHandle 4), DebugLog 19 (DebugLogDiagnostics 2,
DebugLogGates 1), Slash 19 (SlashParse 1), Launcher 5, Options 28 (OptionsRegistry 2, OptionsWidgets 34,
OptionsIds 2, OptionsIdList 3, OptionsTabs 8, OptionsCombat 1, OptionsCompose 7, OptionsScroll 4,
OptionsNav 2), Perf 14 (PerfSampler 1, PerfCommands 1, PerfPanel 6).

No file moves a minor, no file or major is added, and no `NEEDS_*` floor rises. The consumer is behind
on no file (no cross-major skew).

## 3d — Both diffs

Before the copy:

- `libs/LibKa0s`: `diff -r --strip-trailing-cr` and `diff -rq` against `<scratch>/new/LibKa0s` are both
  empty (exit 0). No `Only in` line.
- `tests/_kit`: three files differ, `framework.lua`, `run-automated-tests.sh` and `test_eol.lua`
  (12 changed lines in content, 6 per side). No `Only in` line on either side.

Nothing is deleted.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'`, outside `libs/` and
`tests/`: Env (`core/EnvSetup.lua:62`), Core (`core/CoreSetup.lua:26`), Bus (`core/Bus.lua:36`),
Lifecycle (`core/Lifecycle.lua:61`), Launcher (`core/LauncherSetup.lua:70`), Media
(`core/MediaSetup.lua:82`), DebugLog (`core/DebugLogSetup.lua:14`), Perf (`core/PerfSetup.lua:16`),
Widgets (`modules/Display.lua:26`, `modules/Bar.lua:15`), Options (`settings/OptionsSetup.lua:71`),
Slash (`settings/Slash.lua:24`, `settings/Schema.lua:498`) and Schema (`settings/Schema.lua:328`).
Unchanged from the v1.68.0 bundle apart from `settings/Schema.lua`'s Slash lookup sitting two lines
lower (496 -> 498), which is the addon's own edit since then. No major moved, so nothing here feeds
3g or Step 5.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION =' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua` -> **35 -> 36**.
The pairing rule (a consumer on v1.9.0 or newer takes kit revision 11 or newer in the same commit) is
satisfied by construction: both payloads are copied whole, and they move together for that reason.
The kit's revision-36 document (`docs/api/testkit/version-36-docs.md:19-23` at the tag) states that no
file is added, no public member, kit case or mock changes, and the runner's manifest is unchanged. Its
one visible effect is one runner-printed line in `RESULTS.md` on the next run (`:40-43`). Adoption is
the whole-folder copy plus the runner's `100755` mode (`:53-56`), and "a consumer's own prose that
names the revision it holds (`kit revision 35`) moves to 36 in the same commit" (`:59-60`).

## 3g — Contract delta

No major moved a minor (3c), so the set of majors to read (moved, intersected with consumed) is
empty. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs
--exclude-dir=_kit` finds no site. The kit change is comment- and string-only (3f), and no case or
member contract moves.

**No blockers.**

## 3h — Tags vendored and never recorded

Running the playbook's listing from horizon `2026-08-25` gives 48 vendored tags and 49 recorded, and
`grep -vxF -f recorded.txt vendored.txt` is empty. Every tag this addon vendored has a bundle, so there
is no span bundle.
