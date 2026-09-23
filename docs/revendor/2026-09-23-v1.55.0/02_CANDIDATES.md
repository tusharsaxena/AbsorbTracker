# 02 - Candidates: LibKa0s v1.54.2 -> v1.55.0

Written on 2026-09-23, after the copy (`27ccce6`), on branch `suite/2026-09-22-standards-sweep`.
Step 5 of `/wow-addon:revendor-libka0s`. The interview of Step 6 was replaced by the owner's
delegation (CP-6 of the suite sweep): the decisions in `03_DECISIONS.md` were taken by the agent
under the sweep's written decision rules, not by the owner in person.

Sources, in the playbook's order:

```sh
git -C ../LibKa0s log --oneline v1.54.2..v1.55.0
# 6f9c5e0 Record the v1.55.0 release run
# ae48f3f Make the v1.55.0 record true after the complexity split
# 244c752 Bring collectKitHoles and repoKind under the CCN 15 ceiling
# be91249 Split Schema's Set and Validate under the CCN 15 gate
# 18ca82a Release v1.55.0
# c051bef Re-vendor the standards reference, and make the v1.55.0 docs true
# 06b4051 Add three majors: Compat, Bus, and the Schema runtime's portable half
# 2a5e06f Test-kit revision 25: the four gates standard v2.63.0 already cites
```

- the `## v1.55.0` block of `../LibKa0s/CHANGELOG.md` at the tag;
- `../LibKa0s/docs/api/{Compat,Bus,Schema}/version-1-docs.md` (every surface is `Since 1`; no
  existing major's minor moved, so there is no old-versus-new API document pair to diff);
- the per-consumer adoption deltas of the sweep's three design specs, which name this repo with
  `file:line`: `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/3b-specs/`
  `compat.md` section 8.8, `bus.md` section 12 ("AbsorbTracker", under "Record half + Catalog") and
  `schema.md` section 11 ("AbsorbTracker - full adopter").

Prior declines searched first, as Step 5 asks:

```sh
gh issue list --search "LibKa0s" --state all --json number,title,state,labels
# #26 Widgets, #27 Item, #28 Pool: will-not-do. None names Compat, Bus or Schema.
grep -rn 'LibKa0s' docs --include='*.md' | grep -iE 'declin|not adopt|no combat|exempt'
# no line names Compat, Bus or Schema
```

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| Test kit revision 25 | The four gates standard v2.63.0 cites: the layout-section-1 cap census (`tests/_kit/test_layout_cap.lua`), the `.gitattributes` body case in `test_eol`, the (basename, directory) suite key, and the commit SHA in the automated-test record. Wired in `27ccce6` (01_DELTA, checklist). Nothing to adopt. |
| The three new majors registering | `libs/LibKa0s/{Compat,Bus,Schema}.lua` load from the XML and register in LibStub. Nothing in the addon looks them up yet, so the copy alone changes no behavior. |

## Class B: host change required

None. No existing file's minor moved (01_DELTA section 3c), so no existing major gained a surface.

## Class C: whole-module adoption

Ordered by the rule in Step 6 (fixes a live defect, then closes a recorded gap, then new
capability; ties by smallest blast radius).

### C1. `LibKa0s-Bus-1.0`: the stand-down record and the strict catalog

- **What:** replace `core/Bus.lua`'s hand-written subscription register (`NS.BusSubscribe`,
  `NS.BusUnsubscribeAll`, `NS.BusResubscribeAll`) with a `Bus:New` record, and declare `NS.MSG`
  through `Bus.Catalog`.
- **Evidence:** `docs/api/Bus/version-1-docs.md` "Library surface", "Instance surface", "Catalog",
  "Worked example" (the stub), "Known limitations" 3 (test probes on a tracked factory). The
  changelog block names AbsorbTracker among the four repos that wrote the record by hand. Spec
  `bus.md` section 8 row "AbsorbTracker's append-only triples": *strictly weaker: no events, no
  forget, so a subscription its owner dropped would be resurrected on stand-up.*
- **Files here:** `core/Bus.lua:43-47`, `:65-85`, `:88-94`; `core/Lifecycle.lua:104`, `:112`; the
  five subscription sites `core/AbsorbTracker.lua:362`, `modules/Timer.lua:81`,
  `modules/Display.lua:439`, `:442`, `:445`; `tests/test_bus.lua`, `tests/test_surface_parity.lua`,
  `tests/run.lua` (surface-source map), `tests/test_disabled.lua:113` (comment);
  `docs/ARCHITECTURE.md` Message Bus, "What stands down" and Known Limitations.
- **Blast radius:** replaces host code (a 20-line register) with a library record. The receivers'
  behavior on the live path is the same set of registrations taken down and put back; the live
  path gains event tracking and forget-on-unregister, neither exercised today. The **degraded**
  path loses one property: with LibKa0s absent the untracked-target stub records nothing, so a
  disable leaves the five bus subscriptions live (the spec's section 7 states it and asks for a
  Known Limitations line). No test pins the degraded bus stand-down
  (`grep -n "loadDegraded" tests/*.lua` reaches no bus or stand-down case).
- **Gap it closes:** a latent defect only (resurrecting a dropped subscription; no owner drops one
  today), plus the publisher half of `architecture-section-4`'s "fails at once" claim, which
  `Catalog`'s strict read makes true.
- **Recommendation:** adopt. The spec prescribes it for this repo with no MAY-defer clause.

### C2. `LibKa0s-Schema-1.0`: the settings schema runtime (full adopter)

- **What:** `settings/Schema.lua` becomes the major's setup file: `SchemaLib:New{...}` or a host
  degradation stub, the instance stashed as `NS.SchemaRuntime`, and the host's public names
  (`NS.SetByPath`, `NS.FindSchemaRow`, `NS.RegisterSchemaRows`, `NS.ApplyDefault`, `NS.Bulk`,
  `NS.ResolvePath`, `NS.SetPath`, the reset count trio, `NS.ValidateSchema`) bound to members.
- **Evidence:** `docs/api/Schema/version-1-docs.md` "Instance surface", "The Set pipeline", "The
  bulk bracket", "The profile reset's count", "Validate", "The degradation stub" (which names this
  addon's three degraded writers: `settings/Slash.lua:487`, `settings/OptionsSetup.lua:383`,
  `core/AbsorbTracker.lua:259`), "Adoption notes". Spec `schema.md` section 11 "AbsorbTracker - full
  adopter", every bullet with its `file:line`.
- **Files here:** `settings/Schema.lua` (most of it), `core/Data.lua:32-128` (the session and
  minimap branches, `NS.SetSetting` deleted), `settings/General.lua` (the console and minimap rows
  gain `get`/`set`), `settings/OptionsSetup.lua:59-92`, `:138-139`, `settings/Slash.lua:599-609`,
  and the suites that pin the old seam: `tests/test_schema.lua`, `tests/test_data.lua`,
  `tests/test_optionssetup.lua`, `tests/test_helpers.lua`, `tests/test_slashcmds.lua`,
  `tests/test_widgets.lua`, `tests/test_display.lua`, `tests/test_visibility.lua`,
  `tests/test_launcher.lua`. Measured with `git grep -n -e NS.Bulk -e SetSetting -e ResetProfileCounted
  -e ConsumeResetCount -e ProfileRowsOffDefault -e RegisterSessionSetting -e ValidateSchema -e
  NS.ApplyDefault -e NS.ResolvePath -e NS.SetPath -e RegisterSchemaRows -e FindSchemaRow -- core
  modules settings tests defaults`, comment lines dropped: 161 lines across 17 files.
- **Blast radius:** the largest of the three. It replaces the write seam every panel widget, every
  CLI verb and every reset goes through, and it carries behavior changes on purpose: an unknown
  path is refused rather than stored (JC-2), a table value is copied into the store (JC-6), a
  raising `onChange` propagates, `group` is required by `Validate`, and a degraded build's `[Set]`,
  bracket and reset-count lines disappear (the log-silent stub). It also adds a host copy of the
  write half (about 60 lines) as the degradation stub.
- **Gap it closes:** none recorded as a defect in this repo; it retires a second copy of the
  runtime nine hosts carried.
- **Recommendation:** adopt, after C1. The spec prescribes it for this repo as a full adopter with
  no MAY-defer clause; the rule for a decline is one honest attempt that cannot land green without
  changing pinned or player-visible behavior.

### C3. `LibKa0s-Compat-1.0`

- **What:** the secret seam (`IsSecret`, `CanAccess`, `IsSafeKey`) and six version-variant spell
  and specialization readers.
- **Evidence:** `docs/api/Compat/version-1-docs.md`; spec `compat.md` section 8.8: *"No member
  adopted: ... AbsorbTracker and PrettyChat have no `core/Compat.lua`. Re-vendor only (8.0)."*
- **Here:** `git grep -n -i -e issecret -e canaccess -e C_Spell -e GetSpecialization -e
  GetSpellInfo -- core modules settings` returns only comments. The addon reads no spell and no
  specialization, and its one secret-handling path is `NS.IsConcatSafe`, already wired to
  `LibKa0s-Core-1.0` (`core/CoreSetup.lua`). There is no caller for any member.
- **Blast radius:** none; there is nothing to replace.
- **Recommendation:** decline as **never** (a structural misfit the spec records), filed as a
  `state:will-not-do` issue so the next re-vendor reads it as settled.
