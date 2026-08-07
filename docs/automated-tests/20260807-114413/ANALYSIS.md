# Analysis — 20260807-114413

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** 3efc3d6e210233c3b6dd400d85f724c07a783ae5 (master), clean
- **Previous run:** [`20260807-110443`](../20260807-110443/)

## Headline

All four suites pass and nothing moved: lint 0/0 over 28 files, 489 tests passed with zero skipped
and zero failed, six perf scenarios, and zero functions above CCN 15. The complexity output is
**byte-identical** to the previous run's — same 7766 NLOC, 1088 functions, avg CCN 1.7, max CCN 15 —
which is expected, because the only commits between the two runs were the LibKa0s v1.8.2 re-vendor
and the `.gitattributes` re-sync, neither of which touches this addon's own source. Nothing to act
on. The one fact this run establishes that the previous one could not is a **toolchain** fact rather
than an addon one: this is the first bundle written by test-kit revision 10's `normalize_eol` pass in
a repo that has never seen it, and every artifact landed CRLF as `.gitattributes` pins (see *What
moved*).

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260807-110443` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 28 files | [`lint.txt`](lint.txt) | No — 0/0 over 28 files on both runs |
| tests | pass | 489 passed, 0 skipped, 0 failed, 489 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No — identical on both runs |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | Scenario count, api/iter and bytes/iter all identical; ms/iter differs in the fourth decimal (timing jitter) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | No — `complexity.txt` is byte-identical to the previous run's |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below comes from [`manifest.json`](manifest.json)'s `suites.complexity`, which
records all eight of `lizard`'s footer fields, and is corroborated by the footer in
[`complexity.txt`](complexity.txt).

| Metric | Value |
|---|---|
| Total NLOC | 7766 |
| Functions | 1088 |
| Avg NLOC / function | 6.5 |
| Avg CCN | 1.7 |
| Max CCN | 15 |
| Avg tokens / function | 45.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

The averages are the point. Total NLOC and average NLOC/function are both flat here, so the addon
neither grew nor got denser between the two runs — a matched pair, which is the only combination that
lets "unchanged" be read as a real result rather than as two offsetting movements.

Every suite is a clean pass, so there is no per-suite exception paragraph to write. No suite was
skipped: `lua 5.1.5`, `luacheck 1.2.0` and `lizard 1.23.0` were all present and all ran
([`manifest.json`](manifest.json), `host`).

## What moved

- **lint** — nothing. 0 warnings / 0 errors over 28 files on both runs. The file count is unchanged
  because nothing entered or left the linted scope; `.luacheckrc` excludes `tests/`, so the harness
  cannot move this number however much it grows.
- **tests** — nothing. 489 passed / 0 skipped / 0 failed / 489 total, identical to the previous run.
  The `0 skipped` is worth stating rather than assuming: the vendored-payload cases that a missing
  sibling checkout would skip (`testing-§11`) both ran and both passed — "libs/LibKa0s is the LibKa0s
  release CLAUDE.md says this addon bundles" and "tests/_kit is the test kit that shipped with that
  release" ([`tests.txt`](tests.txt)). That is the pair most likely to skip after a re-vendor, and it
  did not.
- **perf** — 6 scenarios on both runs, with `api/iter` and `bytes/iter` **identical** across every
  scenario (`paintPass` 12.0 / 312.0, `appearancePass` 45.0 / 893.7, `probeOverheadOn` 12.0 / 312.3,
  and so on). Those two columns are the ones worth reading across runs and they did not move. Only
  `ms/iter` differs, in the fourth decimal place in both directions — `probeOverheadOn` 0.00609 →
  0.00559, `paintPass` 0.00513 → 0.00529 — which is machine jitter, not a signal. The zero-overhead
  pair still shows what `performance-§2` wants: `probeOverheadOff` and `probeOverheadOn` sit within
  noise of each other on ms/iter and are identical on api/iter, with 0.3 bytes/iter between them.
- **complexity** — nothing, and this one is exact rather than approximate:
  [`complexity.txt`](complexity.txt) is byte-identical to
  [`20260807-110443/complexity.txt`](../20260807-110443/complexity.txt) once line endings are set
  aside. Every function, span and CCN is the same.
- **Provenance** — the one real difference between the two runs is in
  [`manifest.json`](manifest.json)'s `git` block. The previous run was taken at `788fb06` with
  `"dirty": true`, mid-re-vendor; this one is at `3efc3d6` with `"dirty": false`. The previous
  bundle therefore recorded an uncommitted tree, and this is the first clean-tree confirmation that
  the LibKa0s v1.8.2 payload leaves all four suites where they were.
- **Toolchain (not an addon figure)** — every artifact in this bundle was written CRLF, matching the
  `* text=auto eol=crlf` pin in `.gitattributes`. Test-kit revision 10 added a `normalize_eol` pass
  to the runner for exactly this; before it, the runner always wrote LF and the working tree
  disagreed with the pin until the next checkout laundered it. This bundle is untracked at the time
  of writing, so its CRLF came from the runner and from nothing else — the previous bundle's CRLF
  cannot prove the same thing, because it has since been committed and could have been normalized on
  the way back out. This is recorded here as a fact about the kit, not as a suite result; no suite
  figure depends on it.

## Complexity watch list

`lizard` warned on nothing this run — `Warning cnt` is 0 in
[`complexity.txt`](complexity.txt)'s footer, and `No thresholds exceeded` is printed above it. The
table below is therefore the **watch** list rather than the warned list: every function at or above
CCN 12, highest first. An empty table would carry the same verdict and none of the signal.

### Functions on the CCN watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Helpers.BuildMainContent` | 15 | `settings/About.lua` | **At the line, not over it.** Unchanged. The one to watch: the About page is a straight-line builder, so one more content block puts it over — and over is a blocked tag, not just a warning. Peel the block sequence into a data table the day it grows. |
| `NS.ValidateSchema` | 14 | `settings/Schema.lua` | **Accepted.** Unchanged. Dense guarding, not tangled control flow: the integrity checks are a flat list of independent row assertions, each `if` is one rule, and merging any two would hide which rule fired. |
| `addon:OnAbsorbChanged` | 14 | `core/AbsorbTracker.lua` | **Accepted.** Unchanged; `lizard` reports it as `addon` at `164-185`. Dense guarding rather than tangle — the branching is the per-unit relevance ladder the handler exists to be, and splitting it would move the ladder, not shorten it. |
| `build` | 12 | `settings/Profiles.lua` | **Accepted.** Unchanged at CCN 12, span `16-71`. Well under the line; the lazy-`OnShow` work is the direction of travel here, not a peel. |

Nothing **newly** crossed. All four CCN values, and all four spans, are identical to the previous
run. No function is above CCN 15, so the `automated-tests-§3` release gate's complexity condition is
satisfied by this run's manifest.

On shelf life (`automated-tests-§4`): the three-consecutive-**release**-runs clock has still not
started. Every manifest in `docs/automated-tests/` carries `"release": null`, this one included, so
none of the three `Accepted` entries above has spent a single release cycle in that state. The first
`--release` bundle starts the count. `Helpers.BuildMainContent` is not on that clock at all — its
disposition is *watch*, not *accepted*.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1282 | **Accepted.** Not newly crossed and unchanged since [`20260807-022551`](../20260807-022551/). A flat list of independent test cases at avg CCN 1.2 — length here is case count, not tangle. Peel by verb group if it crosses 1400. |

No file is over the 1500 cap (`overCapFiles` 0 in [`manifest.json`](manifest.json)). One file sits in
the on-notice band (`bandFiles` 1), and it is the same file as the previous run.

## Actions

None. All four suites pass, nothing crossed a threshold, nothing regressed, and no disposition is
due for conversion.
