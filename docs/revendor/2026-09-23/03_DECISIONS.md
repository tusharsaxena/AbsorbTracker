# 03 - Decisions

**Delegated, not interviewed.** Step 6's interview was replaced by the owner's delegation (CP-6 of the
suite sweep, 2026-09-23): the agent decided each candidate under the sweep's written rules and
recorded it here as it landed. The rules, in short: adopt what the design spec prescribes for this
repo, one major per commit, characterization test first; decline as *not now* where the spec lets
the repo defer or where one honest attempt cannot land green without changing pinned or
player-visible behavior; decline as *never* only for a structural misfit the spec or this repo's
docs record. Every decline is a GitHub issue with one `state:` and one `severity:` label.

Order taken (Step 6's rule, then smallest blast radius): C1 Bus, C2 Schema. C3 Compat has no host
change to order, so its decision was taken first and filed at once.

## C3. `LibKa0s-Compat-1.0`: never

- **Decision:** decline, **never** (`state:will-not-do`, `severity:low`).
- **Why:** structural and recorded. Spec `compat.md` section 8.8 lists AbsorbTracker as a re-vendor
  only consumer, with no `core/Compat.lua`; `git grep -n -i -e issecret -e canaccess -e C_Spell -e
  GetSpecialization -e GetSpellInfo -- core modules settings` finds comments only. The addon's
  one secret guard is `NS.IsConcatSafe`, already on `LibKa0s-Core-1.0` (`core/CoreSetup.lua`).
- **Filed:** https://github.com/tusharsaxena/AbsorbTracker/issues/31 (`gh issue create`, labels
  `state:will-not-do` and `severity:low`). Left **open**: closing it (`gh issue close 31 --reason
  "not planned"`, the shape #26-#28 carry) was refused by the session's permission check, so that
  one click is the owner's.

## C1. `LibKa0s-Bus-1.0`: adopt

- **Decision:** adopt, record half and `Catalog`, exactly as spec `bus.md` section 12
  "AbsorbTracker" lists it.
- **Why:** the spec prescribes it for this repo with no MAY-defer clause, and it is the smaller of
  the two adoptions. The degraded path's loss (bus subscriptions stay live through a disable when
  LibKa0s is absent) is the one property the spec's section 7 stub gives up by design, and
  `options-ui-section-1` names that stub shape (the **untracked-target** stub) as a permitted one. It
  is not a deviation; it goes into `docs/ARCHITECTURE.md`'s Known Limitations, as the spec asks.
  Keeping this repo's own register as the degraded arm instead would be a host copy of the library
  running as a stub, which `options-ui-section-1` does not admit for Bus ("A host cannot admit a
  stub for another major to the runtime-completing class").
- **Landed:** `92c48d8`, green (683 passed, 0 failed, 0 skipped; the linter 0 / 0 in 60 files).

## C2. `LibKa0s-Schema-1.0`: adopt (full adopter)

- **Decision:** adopt, as spec `schema.md` section 11 "AbsorbTracker - full adopter" lists it.
- **Why:** the spec prescribes it for this repo with no MAY-defer clause (the MAY-defer in the API
  document's "A host that keeps its own seam" is for partial adopters, which this repo is not).
  The one honest attempt landed green with every player-visible pin kept: stored values, the
  panel's and CLI's reactions, the chat lines and the three degraded writers. What moved is what the
  API document's adoption notes list as intended, and each is pinned in the adoption commit.
- **Behavior changes taken on purpose, each pinned:** an unknown path is refused and stores nothing
  (JC-2; `tests/test_schema.lua` "SetByPath refuses a path with no schema row"); a table value is
  stored as a copy (JC-6); on a LibKa0s-less load the `[Set]` line, the bracket's `N rows` line and
  the reset's `(N rows)` count are gone, because the stub is log-silent (the two degraded Reset All
  cases in `tests/test_optionssetup.lua` re-pinned to "the write landed, the line is absent"). The
  degraded DebugLog stub already discarded those lines in the client, so no player saw them.
- **Where this differs from the spec's wording, and why** (none of these is a deviation from the
  standard; the spec is a design document, and each keeps behavior the suite pins):
  - The Options descriptor's `set` and `applyDefault` are one-line closures over `NS.SetByPath` /
    `NS.ApplyDefault`, not the member values the spec's common block names. Neither is a gate (the
    spec's reason for values); they keep the host's name the one seam a suite spies on
    (`tests/test_optionssetup.lua`'s Reset All veto case watches `NS.ApplyDefault`). `allRows`,
    `bulkBegin` and `bulkEnd` are the members.
  - The Slash descriptor's `set` and `applyDefault` keep their wrappers, because each also refreshes
    an open panel after the write (`NS.RefreshOptionsPanel`), which binding the bare member would
    drop. `findRow` is the member. `get` stays `NS.GetSetting` on both descriptors, the spec's own
    pre-db read.
  - The reset count's predicate excludes the profiles page as well as the minimap row (the spec's
    `notMinimap`), which is what the host's `ProfileRowsOffDefault` excluded; no shipped row is on
    that page, so the count is unchanged either way.
  - `NS.SetSetting` is deleted as the spec says. The suites used it as a raw fixture write (no row,
    no reaction); those sites now call the harness's `T.rawSet`, which `tests/run.lua` defines with a
    comment saying why the addon has no such writer (49 lines across seven suites, by
    `grep -c "T.rawSet(" tests/*.lua`). The four cases that pinned `SetSetting` itself re-pinned to
    `NS.SetByPath`.
  - The degraded stub carries the reference stub whole rather than trimmed, so the instance parity
    case (`tests/test_surface_parity.lua`) needs no ignore list.
- **Landed:** see `05_SUMMARY.md`.
