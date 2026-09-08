# Testing

How to verify Ka0s Absorb Tracker. Both automated gates must be green **before every commit**
and before tagging a release; the in-game smoke tests run before a release or after bumping
`## Interface:` / refreshing vendored libs. Conforms to the Ka0s WoW Addon Standard `testing`
section.

## The green gate

| Check | Command | Expected |
|-------|---------|----------|
| Unit tests | `lua tests/run.lua` | all suites green (exits non-zero on any failure) |
| Lint | `luacheck .` | `0 warnings / 0 errors` |
| Syntax-check one file | `luac -p <path/to/file.lua>` | no output (clean parse) |
| In-game smoke tests | manual | see [smoke-tests.md](./smoke-tests.md) |

**Not part of the commit gate**, and deliberately so — but both gate the **tag**, which is a
different checkpoint (`automated-tests-§3`, *The release gate*):

| Check | Command | Why it does not gate a commit |
|-------|---------|---------------------|
| Offline perf | `lua tests/perf.lua` | Wall-clock numbers on a developer machine are not stable enough to fail a build on, and a perf suite that fails spuriously gets switched off within a week. It *does* hard-assert the deterministic half (repaint counts, API calls per pass, bytes per pass) and exits non-zero on a real regression, so it is CI-usable later. At the tag it must read `pass`. |
| Complexity | the `complexity` suite of `tests/_kit/run-automated-tests.sh` | Between commits it is a **report**, not a verdict — **recorded, never gating** — see [Automated test records](#automated-test-records--the-consolidated-run) below. At the tag it gates: `pass` with zero functions above CCN 15. Records: [automated-tests/](./automated-tests/). |

Both are documented in [performance.md](./performance.md).

### What the lint gate is a statement about (lint-§1)

`luacheck .` reading `0 warnings / 0 errors` is only worth something if the configuration is not the
reason it reads that way. `.luacheckrc` therefore sets **no top-level `ignore`**, and
`tests/test_lintconfig.lua` is the four-case gate that keeps it that way:

| Case | What it refuses |
|------|-----------------|
| no top-level `ignore` | any `ignore` at the top of `.luacheckrc` — it reaches all 54 files whatever it names, so naming the variable does not rescue it |
| no wholesale class switch | `unused_args = false` and eight relatives, which is the same blanket spelled as a switch |
| every `files[...]` ignore is narrow | a stanza keyed to a directory whose entries name no variable |
| no bare inline directive | `-- luacheck: ignore` with no code after it, which silences every code on the line rather than the one that was meant |

It loads `.luacheckrc` as Lua under a sandbox rather than scanning it as text, so what it inspects is
the table luacheck obeys and not a spelling a text scan would miss. It **fails rather than skips**
when it cannot look — no config, no `io.popen`, no git — on the same bargain
`tests/_kit/test_eol.lua` strikes.

What survives suppression, and where: three `files[...]` stanzas naming one file each
(`core/AbsorbTracker.lua`, `core/Database.lua`, `settings/Slash.lua`), every entry written
`212/self`, each covering a receiver a calling convention forces on a body that has no use for it;
plus one `-- luacheck: ignore 542` on the exempt-key branch in `tests/test_schema.lua`, the
repository's only empty branch. The reasoning for each sits in the comment above it in
`.luacheckrc`.

This replaced `ignore = { "212/self", "212/event", "211/addonName", "431" }`, removed by `M4c-06`.
Removing those four lines reported **32 findings**, and **19 were real defects**, not conventions:
nineteen files bound an `addonName` they never read, and all nineteen now open `local _, NS = ...`.
Two of the four entries were silencing nothing at all — this tree produces no `212/event`, and
`431` is shadowing an *upvalue*, which is not what its comment claimed it was for.

Toolchain: Lua 5.1 + luacheck + lizard. The full list — what each one is needed for, the evidence
for it, the WSL2/Ubuntu install command and a one-line verification per tool — lives in the root
**[DEPENDENCIES.md](../DEPENDENCIES.md)** (documentation-§7). That file answers *what to install*;
this one answers *how to verify*.

## Automated test records — the consolidated run

All four out-of-game suites go through one vendored runner, and every run is recorded
(`automated-tests`):

```sh
tests/_kit/run-automated-tests.sh                            # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity          # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
```

There are **two checkpoints**, and a suite's answer differs between them, so both are named:

| Suite | Command | Run + commit | Release tag |
|---|---|---|---|
| `lint` | `luacheck .` | **gates** | **gates** |
| `tests` | `lua tests/run.lua` | **gates** | **gates** |
| `perf` | `lua tests/perf.lua` | no — recorded | **gates** — `pass` required |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded | **gates** — `pass`, zero functions above CCN 15 |

**`perf` and `complexity` never fail a run and never block a commit** (`performance-§9`,
`performance-§10`). They are measured, recorded and diffed — a threshold that fails a run teaches
everyone to reach for `--no-verify`, after which the gate protects nothing and the habit remains.
They contribute `amber`, which is a signal rather than a stop. **A missing tool is a skip recorded
with its reason**, never a pass.

**At the tag, all four gate** (`automated-tests-§3`, *The release gate*). The release run's
`manifest.json` must show all four suites at `pass` and `suites.complexity.warnings` at `0`;
`/wow-addon:bump-version` evaluates that, not this script, whose exit code is unchanged. A `skip`
there is **NOT EVALUATED** rather than passed — install the tool and re-run.

The runner is **vendored** from `LibKa0s`'s `testkit/`; never edit `tests/_kit/`. A kit fix goes
upstream and is re-vendored.

**At release, not at commit.** A full bundle is produced as part of every version bump, before the
tag, with an `ANALYSIS.md` write-up. Commits are gated on lint + tests only; the tag is gated on
all four.

Results live in [`automated-tests/`](./automated-tests/): `RESULTS.md` is one row per run across all
four suites plus the current complexity watch list — **one file, overwritten in place**, so its git
history is the trend line — and each `<YYYYMMDD-HHMMSS>/` is a frozen bundle of that run's raw
output. Bundles are never edited and never pruned.

`docs/complexity.md` was this addon's standalone complexity report through standard v2.18.0; it is
**retired** — its raw output is each bundle's `complexity.txt` and its trend line is `RESULTS.md`.

## Verifying the vendored LibKa0s copies

Neither gate above can see this, and that is the whole problem: the library's suite passes against
the library, and this addon's passes against a stale vendored copy that still works. It has already
happened to **this** repo — `../LibKa0s/docs/releasing.md` records a fix landing upstream,
AbsorbTracker not being re-vendored, and both suites staying green the entire time. An after-the-fact
`diff -r` was the only thing that caught it.

Run after any re-vendor, and before any release:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s     # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                         # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit       # content — empty vs the CLAIMED tag
diff -r ../LibKa0s/testkit tests/_kit                           # bytes  — SHOULD be empty
```

### When these diffs are supposed to be non-empty

They compare against the sibling checkout's **working tree** — whatever `../LibKa0s` happens to have
checked out — which is a different question from *"is the vendored payload the release this addon
claims?"*. The two questions give the same answer only while the library has tagged nothing newer
than the tag this addon has taken.

Between a library release and the re-vendor that carries it they disagree, and that disagreement is
the normal state rather than a defect. It is the state as this is written: `../LibKa0s` sits on
**v1.27.0**, [`CLAUDE.md`](../CLAUDE.md) names **v1.26.0**, and the commands above report **306**
differing lines for the library and **947** for the test kit. Re-vendoring to quiet them would be
the actual mistake — it would pull an untested library release for the sake of a clean diff.

**The authoritative comparison is against the tag `CLAUDE.md` names**, and that one must be empty at
every commit:

```sh
tag=$(grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' CLAUDE.md \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
rm -rf "/tmp/libka0s-$tag" && mkdir -p "/tmp/libka0s-$tag"
git -C ../LibKa0s archive "$tag" | tar -x -C "/tmp/libka0s-$tag"
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/LibKa0s" libs/LibKa0s   # MUST be empty
diff -r --strip-trailing-cr "/tmp/libka0s-$tag/testkit" tests/_kit     # MUST be empty
```

`tests/test_vendor_sync.lua` asks exactly this question inside the suite — it greps the tag out of
`CLAUDE.md` and reads that blob out of git — so **a green suite has already answered it**, and the
block above is only the by-eye version for when you want to see the hunks. Which leaves the
working-tree diffs above answering a real but different question: *how far behind the library is
this addon?* That is release planning, not a gate.


Both halves, because the two answers are different findings.

**Content differs** → a real fork in `libs/`, which is the forbidden state. Name every hunk, and fix
it by re-vendoring from the library, never by editing here.

**Bytes differ but content matches** → a line-ending divergence, not a fork. Both repos pin
`* text=auto eol=crlf` over LF blobs, so a working tree holding *either* ending reads clean to
`git status`, and neither side's cleanliness proves anything. Establish which side drifted (`file -b
<path>`, and `git cat-file -p HEAD:<path> | file -b -` for what git stores) and renormalize that
side. **Re-vendoring will not converge it, and the fix is never an edit to `libs/`** — editing the
vendored copy to settle a line-ending disagreement creates a fork to fix one that was not there, and
the next re-vendor reverts it silently.

`CLAUDE.md` states the rule this checks ("never edit `libs/` here — change it upstream and
re-vendor"). The rule without the check is what both runs of the 2026-08-01 adoption report kept
landing on: the vendored copy is correct today, and nothing in this repo would say so if it stopped
being.

## Current status

The **authoritative** test-case list and pass count live in the generated inventory,
**[test-cases.md](./test-cases.md)** (testing-§5). It is the single source of truth for how many
cases exist and how they group by suite — this doc deliberately quotes **no** hard-coded number, so
there is nothing here to drift. Read `docs/test-cases.md` (or its `## Totals` table) for the count.

## The test-case inventory (`docs/test-cases.md`)

`docs/test-cases.md` is **generated, never hand-edited**. The runner's non-executing `--list` mode
enumerates every registered case grouped by its originating `test_*.lua` suite:

```sh
lua tests/run.lua --list > docs/test-cases.md
```

Verify it is in sync:

```sh
diff <(lua tests/run.lua --list) docs/test-cases.md   # no output == in sync
```

Note on line endings: this repo pins the whole tree CRLF with a single `* text=auto eol=crlf`
(`.gitattributes`), so the committed file is CRLF throughout — and the renderer in `tests/_kit/framework.lua` writes CRLF itself. There is no
`| sed 's/$/\r/'` in the command any more: a regeneration command with a pipeline in it is one
someone eventually runs without the pipeline, and the whitespace-only diff that produces is exactly
the kind of noise this file exists to prevent.

## Keeping the inventory & badge in sync

When the suite changes — a case added, removed, or renamed, or the pass count moves (i.e. **whenever
a failing test is resolved**) — do **both** of these **in the same change**, never as a follow-up:

1. Regenerate the inventory: `lua tests/run.lua --list > docs/test-cases.md`.
2. Update the README `Tests` badge count (`![Tests](…/badge/Tests-X%2FY_passing-green)`) to the new
   passed / total.

Both are local and hand-runnable — there is **no CI**, no GitHub Action, and no dynamic badge
(testing-§5). The green gate proves the suite passes on every commit; the inventory and badge keep
the coverage visible and honest.
