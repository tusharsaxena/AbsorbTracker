Delta: LibKa0s v1.62.0 -> v1.63.0

# The delta (AbsorbTracker)

Copied from the tag `v1.63.0` (`dd7a774`) with `git -C ../LibKa0s archive v1.63.0 LibKa0s testkit`,
never from a working tree. Item `SP-AT-02` of the 2026-09-29 smoke-rework and profile-verb run
(`Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`, spec S3).

## Base (3a, 3b)

`grep -n '[Bb]undles' CLAUDE.md` named **v1.62.0**. The last payload commit, `5042c6b`
(`git log -1 --format=%h -- libs/LibKa0s tests/_kit`), carries the same line, and the minors on disk
were v1.62.0's (Slash 16). No disagreement. Step 0: the newest single-tag bundle,
`2026-09-26-v1.62.0`, states base v1.61.0, which is what `5042c6b^` carried.

## Per-file minors (3c), from the tag's `LibKa0s.xml`

| File | Old | New |
|---|---|---|
| `Slash.lua` | 16 | 17 |

Every other file is unchanged. No cross-major skew. `git -C ../LibKa0s diff --stat v1.62.0 v1.63.0
-- LibKa0s testkit` lists `LibKa0s/Slash.lua` alone (130 insertions, 1 deletion).

## Both diffs (3d), before the copy

`diff -rq --strip-trailing-cr` and plain `diff -rq`, tag against the vendored folders, gave the same
list: `LibKa0s/Slash.lua` differs, nothing else. The kit folders are identical. Nothing is only in
the addon, so nothing is deleted. After the copy both diffs, content and bytes, are empty.

## Consumption (3e)

Unchanged. `settings/Slash.lua:24` is the Slash lookup, `settings/Schema.lua:496` the second one.
No major is new.

## Kit revision (3f)

`Kit.VERSION` 31 on both sides: the kit did not move in this range. Both payloads are still copied
whole, in one commit.

## Contract delta (3g)

No runtime behavior moves: the additions are a descriptor field (`profiles`), two instance members
(`CliProfile`, `ProfileSwitch`), one lib-level function (`ProfileNames`) and nine `PROFILE_*`
strings (`version-17-docs.md`, "Compatibility"). One parity gate moves, as that section predicts:
`tests/test_surface_parity.lua`'s Slash case compares the degraded stub against the live instance
by name, and went red on the copy alone with

```text
LibKa0s-Slash-1.0: the degraded stub diverges from the live surface in 2 place(s) —
CliProfile is missing (live: function); ProfileSwitch is missing (live: function)
```

## Blockers

The stub gap above, fixed in the copy commit: the library-absent stub in `settings/Slash.lua` gains
`CliProfile` and `ProfileSwitch`, both on route (b) (the library-absent line for `/at profile`,
nothing switched), per `version-17-docs.md` "The degradation stub".

## Span (3h)

The audit's listing printed nothing: every tag this addon vendored has a bundle.
