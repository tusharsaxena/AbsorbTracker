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
check and its colour rescale — is `LibKa0s-Slash-1.0` and is tested in the LibKa0s repo. What
stays here is this addon's side: that `NS.COMMANDS` is a well-formed, unique, lower-case verb
table, the host verbs that reach into this addon's own state (lock/unlock/toggle/update/test/
profile/resetall/resetposition), the mirror note the annotator appends, the About page rendering
the same rows through the same formatter, and the schema verbs driven end to end through the
library so the seams this addon supplies — `get`/`set`/`findRow`/`applyDefault`/`allRows` — are
proven wired. The degradation stub in `settings/Slash.lua` has no case of its own yet;
`tests/test_coresetup.lua` covers that shape for Core, and this is the obvious gap to close next.

**A note for anyone adding tests that touch suspend or the repaint timer.** `NS.Perf.Resume()`
republishes `REPAINT`, which arms a coalescing timer. Left armed, `pending` in `modules/Timer.lua`
stays set for the rest of the **process**, and every later suite's `RequestRepaint` quietly
coalesces into a pass that never fires — surfacing as unrelated failures three suites away.
`tests/test_perf.lua` drains it via a local `settle()` helper after every resume. Do the same.

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
