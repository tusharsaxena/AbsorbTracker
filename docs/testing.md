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

**Not part of the gate**, and deliberately so:

| Check | Command | Why it is not gated |
|-------|---------|---------------------|
| Offline perf | `lua tests/perf.lua` | Wall-clock numbers on a developer machine are not stable enough to fail a build on, and a perf suite that fails spuriously gets switched off within a week. It *does* hard-assert the deterministic half (repaint counts, API calls per pass, bytes per pass) and exits non-zero on a real regression, so it is CI-usable later. |
| Complexity | `lizard -l lua core modules settings defaults locales` | Optional Python dev dependency; the Ka0s standard does not yet define a complexity rule. Report: [complexity.md](./complexity.md). |

Both are documented in [performance.md](./performance.md).

Toolchain: Lua 5.1 + luacheck (`sudo apt-get install -y lua5.1 luarocks && sudo luarocks install
luacheck`).

`tests/run.lua` mirrors the in-game lifecycle rather than only loading files: it calls `NS:InitDB()`
**and** `NS.CreateOptionsPanel()` at bootstrap, so every `settings/<page>.lua` builder runs for real
and a page that breaks fails the gate instead of waiting to be opened in-game.

The suite list (see [common-tasks.md](./common-tasks.md#run-the-test-gate) for the full table) now
includes `tests/test_units.lua` — `core/Units.lua`'s unit identity, mirror resolution
(`IsEnabled`/`IsMirrored`/`SourceUnit`/`Get`/`Set`), per-unit position, and `CopyFromPlayer` — and
`tests/test_perf.lua`, covering this addon's side of the `LibKa0s-Perf-1.0` harness (issue #17) —
`core/PerfSetup.lua`'s descriptor, the bracket call sites, and the suspend/resume state machine. The
probe itself (buckets, JSON, the record schema, report formatting, the capture ring) is tested in the
LibKa0s repo, not duplicated here.

`tests/test_debuglog.lua` is the same shape. The console itself — the two formatters, the buffer and
its cap, the enable seam's write path, the window, and the checkbox contract — is
`LibKa0s-DebugLog-1.0` and is tested in the LibKa0s repo; what stays here is this addon's wiring,
plus the degradation stub that answers when the vendored library is missing. `tests/test_util.lua`
went with it: its last two cases were the shared sink's, and a suite with nothing left in it is
worse than no suite at all, because the runner skips a listed file that does not exist.

`tests/test_slash.lua` and `tests/test_slashcmds.lua` are the same shape again. The slash
algorithm itself — the verb lookup, the help renderer, the row and key/value formatters, the
value renderer, the `/at list` builder, and the type-aware parser with its clamping, its enum
check and its color rescale — is `LibKa0s-Slash-1.0` and is tested in the LibKa0s repo. What
stays here is this addon's side: that `NS.COMMANDS` is a well-formed, unique, lower-case verb
table, the host verbs that reach into this addon's own state (lock/unlock/toggle/update/test/
profile/resetall/resetposition), the mirror note the annotator appends, the About page rendering
the same rows through the same formatter, and the schema verbs driven end to end through the
library so the seams this addon supplies — `get`/`set`/`findRow`/`applyDefault`/`allRows` — are
proven wired. The degradation stub in `settings/Slash.lua` has no case of its own yet;
`tests/test_coresetup.lua` covers that shape for Core, and this is the obvious gap to close next.

`tests/test_helpers.lua` and `tests/test_widgets.lua` are the shape again, and the least obviously
so. The panel shell, the widget makers, the two-column flow engine and the always-shown scrollbar
patch are `LibKa0s-Options-1.0` and are tested in the LibKa0s repo. What these two suites assert is
the seam: that `NS.Helpers` answers each member this addon calls, that a write through a widget
lands on `NS.SetByPath` and comes back through a refresher, that the Defaults button reverts a page
across all three units, that the panel carries the Blizzard canvas contract the library stamps in
`CreatePanel` (`OnCommit` / `OnRefresh` / `OnDefault`, the last forwarding to a `defaultsOnClick`
parked *after* the panel is built — which is what every page here does, and what makes Blizzard's
own footer Defaults control work), and that the per-unit page in `settings/UnitPanel.lua` — the
Unit dropdown, the mirror partition, and the two-tier header refresher — behaves. They exercise
library-backed members through `NS.Helpers` on purpose: that table **is** the library instance, so
a case that swaps a member out to spy on it swaps the one the library's own callers see.

The degradation stub in `settings/OptionsSetup.lua` is the one that could fail silently, and it has
its own guard. It is deliberately **load-completing** rather than member-answering — page files call
`NS.Helpers.LSMValues` inside schema-row literals at file load, so a nil there aborts the file and
takes its schema rows with it. `tests/test_perf.lua`'s `loadDegraded()` builds a second, complete
environment from the TOC with `libs/LibKa0s/` absent and asserts `#NS.Schema` against the
fully-loaded one, then names `units.player.barTexture` / `.border` / `.font` explicitly, because an
equal count could in principle be reached by a different set of rows. It is a comparison rather than
a fixed number, so it cannot rot as pages are added. Do not weaken either half.

`tests/test_ltrap.lua` is the odd one out: it is the only suite that reads this addon's **source**
rather than running it. Every LibKa0s module taking an `L` override resolves the descriptor's table
before its own `STRINGS`, and this addon's `NS.L` answers *every* key with a string (the standard's
mandated metatable fallback), so `L = NS.L` in a descriptor renders raw SCREAMING_SNAKE keys for
every key at once, in game only. Nothing observable after `lib:New` returns can see it, which is why
the guard is a source check across the five seam files. It matches on what the expression can
**evaluate to** rather than on one spelling — `L = NS.L` and `L = NS.L or {}` both trip it, while the
legitimate `L = NS.L and { … } or nil` does not — and a companion case drives that matcher against
all three forms, because a matcher nothing tests is one that can be narrowed back to a single
anchored form while still reporting green. The rest is non-vacuity (`locales/enUS.lua` really does
synthesize, so the source check guards something) plus library-regression cases that hand the
vendored DebugLog, Slash and Perf the exact fallback shape every Ka0s host has and require the
built-in English back. Core and Options take no `L` at all — Core has no `STRINGS`, and Options'
`L` is `lib.LAYOUT`, a geometry table — so neither can be handed a descriptor to break, and each
gets a **tripwire** over the vendored source instead: a case that goes red the day either grows an
override path, i.e. the day the real assertion becomes writable rather than the day someone
remembers to look. The two tripwires are not the same shape, on purpose — Options ships its own
`lib.STRINGS`, so asserting that table absent would fail against a module behaving as designed;
only the source half transfers. The **rendered** assertions live in each module's own suite;
smoke-test step 102 is the only check that looks at the screen.

`tests/test_optionssetup.lua` and `tests/test_docs.lua` round out the list. The first covers
`settings/OptionsSetup.lua` as a *file* — the descriptor's half of the reset contract, and the
degradation stub. The second checks the shipped prose, which is checkable and therefore checked:
two rules no code path enforces and no reviewer reliably catches.

**A note for anyone adding tests that touch suspend or the repaint timer.** `NS.Perf.Resume()`
republishes `REPAINT`, which arms a coalescing timer. Left armed, `pending` in `modules/Timer.lua`
stays set for the rest of the **process**, and every later suite's `RequestRepaint` quietly
coalesces into a pass that never fires — surfacing as unrelated failures three suites away.
`tests/test_perf.lua` drains it via a local `settle()` helper after every resume. Do the same.

## Verifying the vendored LibKa0s copies

Neither gate above can see this, and that is the whole problem: the library's suite passes against
the library, and this addon's passes against a stale vendored copy that still works. It has already
happened to **this** repo — `../LibKa0s/docs/releasing.md` records a fix landing upstream,
AbsorbTracker not being re-vendored, and both suites staying green the entire time. An after-the-fact
`diff -r` was the only thing that caught it.

Run after any re-vendor, and before any release:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s     # content — MUST be empty
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                         # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit       # content — MUST be empty
diff -r ../LibKa0s/testkit tests/_kit                           # bytes  — SHOULD be empty
```

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

Note on line endings: this repo pins `*.md text eol=crlf` (`.gitattributes`), so the committed file
is CRLF throughout — and the renderer in `tests/_kit/framework.lua` writes CRLF itself. There is no
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
