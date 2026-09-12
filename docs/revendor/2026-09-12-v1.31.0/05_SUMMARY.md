# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

## The move

| | |
|---|---|
| From | v1.30.0 |
| To | **v1.31.0** (tag commit `30db4ed`) |
| Files that moved in `libs/LibKa0s/` | `OptionsWidgets.lua` (`WIDGETS_MINOR` 14 → 15), `OptionsCompose.lua` (`COMPOSE_MINOR` 3 → 4) |
| Kit revision | **16 → 17** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none |

## What reached this addon for free

- **The flow engine's pathless-row arm** (OptionsWidgets 15) and **the composers' bind arm**
  (OptionsCompose 4). Every row here is path-keyed, so rendering and writes are unchanged. Upstream
  pins path-keyed composer output byte for byte against a golden fixture.
- **Kit 17's Ace surfaces.** This harness reaches the named `NewAddon` path directly, so the addon
  object is now built from its real mixin list with the client's lifecycle, and AceTimer, AceEvent
  and AceConsole are the fuller fakes. The suite stays at 565, all green.

## What was adopted

Nothing. Kit 17 retires no local mock layer here: `tests/wow_mock.lua` replaces none of the kit's
Ace fakes (02_CANDIDATES B2). `spec.bind` has no fit, because there are no registry records
(02_CANDIDATES B1).

## Other live references moved with the tag

`CLAUDE.md:69` (the provenance line), `docs/testing.md:140`, `docs/module-map.md` row 31 (the kit
revision and line counts), and `docs/smoke-tests.md:242-243` (the geometry flip is now revision 18
at the earliest).

## Wave B2 follow-ups on the same branch

- **§9, the named-state sweep** (`8099786`). Every write to persistent state outside
  `NS.SetByPath` was checked. Two were already accounted for:
  - `units.<unit>.position`, which was already named;
  - the savedvariables-§1 load pass: the two schema stamps, the v3 lift, the backfills, and the
    v4/v5 steps.

  One piece was **unnamed**: the perf capture ring `AbsorbTrackerPerfDB`, recorded data written
  only by the vendored library. It is now named in `docs/ARCHITECTURE.md` → Settings Schema. The
  owner is `core/PerfSetup.lua`, and the one writer is `LibKa0s-Perf-1.0`'s `P.Save`, reached by
  `/at perf finish`. No register row was added, and none was retired: the ring's old row had
  already retired on 2026-08-05.
- **§8, the purge-trace check.** The addon has **no forget, purge or delete verb over learned or
  recorded data**. Its only persisted store of that class is the perf ring, and only the library
  writes it:
  - The schema-mismatch discard **is** traced (`P.Log`, `libs/LibKa0s/Perf.lua:744`).
  - The retention trim past the ring's size (default 10, `Perf.lua:752`) is **not** traced. `finish`
    announces "saved" and never says the oldest record was dropped.

  This is an **`[upstream]` finding** against LibKa0s-Perf (debug-logging-§8, "retention/prune").
  It is not patched here, because `libs/` is read-only. Other things that might look relevant are
  not persistent learned data:
  - `NS.ClearLSMCache` clears an in-memory lookup cache;
  - `NS.__ResetBgClassColor` is a suite seam;
  - the `dropKeyEverywhere` migration is the load pass, and it already logs `[Migrate]`;
  - AceDBOptions' profile delete is a settings act.

## What was declined

Nothing. No issue was filed (filing was out of scope for this run), and none is owed.

## Skipped or unreached

Nothing.

## Gates

| When | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, branch head `26bac46` | 565 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| Re-vendor, provenance and live references rolled | 565 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |
| §9 naming | 565 passed, 0 failed, 0 skipped | 0 / 0 in 54 files |

`tests/test_vendor_sync.lua` ran all three cases against the sibling, so none was skipped.
`docs/test-cases.md` still matches `lua tests/run.lua --list`, and the README `Tests` badge (565/565)
is unchanged. No Lua outside `libs/` and `tests/_kit/` changed, so the lizard figures cannot have
moved. Nothing was pushed.

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`). Before anything
was pushed, a review of that release found defects in the kit-17 fakes, and LibKa0s re-cut the tag on the
fixed tree: **`v1.31.0` now points at `e7e1962`**. The re-vendor commit that follows this bundle copied
both payloads whole from the re-cut tag, and the vendor-sync cases pass against it.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `LibKa0s/` move in this release, not two. This bundle's own `[upstream]` finding, the
§8 purge-trace check in `05_SUMMARY.md` ("the retention trim past the ring's size ... is **not** traced",
`Perf.lua:752`), is **resolved upstream by Perf minor 11**: `P.Save` now logs one summary line when it
drops the oldest records past its cap (`libs/LibKa0s/Perf.lua:757`), next to the schema-discard line it
already logged (`:744`). Upstream, the re-cut adds `bab743c` (Perf minor 11), `1f1790c` (the review
fixes) and `e7e1962` (the release record, re-taken) on top of `30db4ed`.

The gate was re-run on the re-cut payload in this repo's re-vendor commit, **`4af0d74`** ("Re-vendor the
reviewed LibKa0s v1.31.0 (tag moved to e7e1962)"): `lua tests/run.lua` 565 passed, 0 failed, 0 skipped,
565 total; `luacheck .` 0 / 0 in 54 files. `tests/test_vendor_sync.lua` compared both payloads against
the sibling at `e7e1962` and skipped none. The case count did not move, so `docs/test-cases.md` and the
README `Tests` badge (565/565) stand.
