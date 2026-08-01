# Pending ledger

Every pending item `/wow-addon:pending-audit` has ever put to a human, and what they decided.
The command maintains this file: it reads it at the start of a run to avoid re-asking settled
questions, and appends to it at the end. Hand-editing works, but keep the columns intact — the
`Evidence hash` is what matches a row to the thing it is about.

An item is matched by **ID *and* evidence hash**. If the underlying text changes, the hash changes,
the row stops matching, and the item is deliberately raised again — a marker whose wording was
rewritten is a new question, not a settled one.

## Decision vocabulary

| Marker | Value | Meaning | Re-surfaces? |
|---|---|---|---|
| 🟢 | `done` | Implemented this run | No — closed |
| 🔵 | `wont-do` | User decided it will never be done | No — closed |
| 🟡 | `deferred` | Decided: not now. Still on the books | Yes, as a collapsed count |
| ⚪ | `untriaged` | Found, never put to the user | Yes — interviewed in full next run |

Three of these are decisions; `untriaged` is the *absence* of one, which is why it is the only value
that gets fully re-interviewed rather than collapsed into a count. A `untriaged` row never means
anyone agreed to anything.

There is deliberately no red: nothing in this ledger is an error state.

## Ledger

| ID | Evidence hash | Source | Decision | Issue | Date | Rationale |
|---|---|---|---|---|---|---|
| PLAN-01 | `05984cf2` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` (AT-05) | 🟢 done | — | 2026-07-31 | Not published on Wago — CurseForge only. Recorded as an accepted deviation in `docs/ARCHITECTURE.md` rather than adding the key, closing the last open MUST from that audit. |
| ISS-10 | `f0c7ab96` | GitHub #10 | 🟡 deferred | #10 | 2026-07-31 | Cannot be worked without a repro: the issue is a title with an empty body, and the border path has been rewritten twice since it was filed. |
| PLAN-02 | `87b37e3f` | `docs/audits/2026-07-18/05_EXECUTION_PLAN.md` (AT-30) | 🟡 deferred | — | 2026-07-31 | Localization decision not made this run. "English only" stays under Known Limitations rather than being promoted to an accepted deviation. |
| PLAN-03 | `77a8ee64` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-008) | 🟡 deferred | #20 | 2026-07-31 | Second deferral, now tracked publicly. Previously deferred in commit `ef71076` to protect the M9 in-game pass. Design already specified (C-7 / M3.2). |
| DOC-01 | `d8f47c22` | `docs/reviews/2026-07-31/05_FINAL_SUMMARY.md` | 🔵 wont-do | — | 2026-07-31 | The review bundle is frozen history and stands as the pre-implementation document it announces itself to be. Left behind knowingly: the summary keeps claiming 18/18 addressed with nothing deferred, and keeps its `_fill in_` placeholders. The commit body of `ef71076` is the accurate record of what shipped. |
| ISS-17 | `7dae0445` | GitHub #17 | 🟢 done | #17 | 2026-07-31 | All three requested capabilities delivered (offline harness, in-game recipe + two captures, complexity report) and the question answered. Closed on GitHub with the evidence and pointers to its two continuations. |
| ISS-19 | `9a6ae035` | GitHub #19 | 🟢 done | #19 | 2026-07-31 | The reusable-harness half landed: the probe moved into LibKa0s and `core/Perf.lua` no longer exists here. Closed on GitHub; the remaining WowAddonStandards rollout is tracked by the three "Pending promotion" notes in `docs/ARCHITECTURE.md`. |
| ISS-18 | `56ca2052` | GitHub #18 | 🔵 wont-do | #18 | 2026-07-31 | Not this addon's problem — #17 cleared AbsorbTracker with three independent measurements. The remaining bisect is an in-game investigation of other authors' addons with nothing to change in this repo. Closed on GitHub at the user's explicit confirmation; the analysis survives in `docs/investigations/2026-07-29-combat-fps-drop/`. |
| PLAN-04 | `fc0521e5` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-013) | 🟢 done | — | 2026-07-31 | Implemented C-13 as designed: `NS.LIBKA0S_MISSING` in `core/CoreSetup.lua` is the single cause clause, and all five seams append their own "so <what> is unavailable". |
| PLAN-05 | `c19bec3e` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-011) | 🟢 done | — | 2026-07-31 | Went further than the review chose: deleted `NS.SlashCommands` and its stale comment outright rather than correcting the comment, since no in-repo reader was left. |
| PLAN-06 | `5feb8940` | `docs/reviews/2026-07-31/01_FINDINGS.md` (F-012) | 🟢 done | — | 2026-07-31 | Deleted the unreachable `stub.CliVersion` member from the degraded slash stub. |
| ISS-15 | `05728cee` | GitHub #15 | 🟡 deferred | #15 | 2026-07-31 | Real feature work — schema row, settings widget, repaint change. Deferred with a full design comment posted to the issue so it is ready to pick up. |
| ISS-8 | `80a0aab5` | GitHub #8 | 🟡 deferred | #8 | 2026-07-31 | Large feature: a second bar per unit with its own appearance settings. Not started this run. |
| ISS-6 | `1dff6c3a` | GitHub #6 | 🟡 deferred | #6 | 2026-07-31 | Large feature with real taint and combat-lockdown exposure. Not started this run. |
| ISS-5 | `37fe85c3` | GitHub #5 | 🟡 deferred | #5 | 2026-07-31 | Edit Mode integration overlaps the existing drag/lock positioning surface. Not started this run. |
| ISS-2 | `1deb4605` | GitHub #2 | 🟡 deferred | #2 | 2026-07-31 | Text-placement setting not started this run. |
| ISS-3 | `8b785aba` | GitHub #3 | 🟡 deferred | #3 | 2026-07-31 | Border offset not started this run; sensibly kept alongside #10 until the border symptom is pinned down. |
| ISS-4 | `49b4daca` | GitHub #4 | 🟡 deferred | #4 | 2026-07-31 | Fill direction not started this run. Small (one boolean row + `SetReverseFill`). |
| ISS-9 | `52f249b2` | GitHub #9 | 🟡 deferred | #9 | 2026-07-31 | Frame strata not started this run. Small (one select row + `SetFrameStrata`). |
| LIBKA0S-01 | `2026-08-01` | `../LibKa0s/docs/adoption/2026-08-01/04_RECOMMENDATIONS.md` §5 | 🟢 done | — | 2026-08-01 | Re-vendored `libs/LibKa0s/` and `tests/_kit/` whole-folder from LibKa0s v1.1.0. The only content change is the new `libs/LibKa0s/LICENSE` — the ship folder now carries the MIT notice, so every consumer gets it with no per-addon step. All eight minors unmoved (Core 2, DebugLog 3, Slash 4, Options 4, OptionsWidgets 4, OptionsScroll 2, Perf 5, PerfPanel 3). Both halves of the new two-diff gate are empty for both trees. `.pkgmeta` still ignores `tests/`, so the kit is never zipped; `libs/` is the ship payload and now carries the licence. |
| LIBKA0S-02 | `2026-08-01` | `../LibKa0s/docs/adoption/2026-08-01/04_RECOMMENDATIONS.md` §7 | 🟢 done | — | 2026-08-01 | §7 recon verdict **adopt-worthwhile**, and the thing worth adopting is not a loop. `settings/UnitPanel.lua`'s mirror header hand-rolled `RenderGrid`'s flow engine verbatim — SimpleGroup + Flow + SetFullWidth, two children at 0.5, AddChild + `AddSpacer(ROW_VSPACER)` — the third such copy in the collection. Now expressed as four `RenderGrid` items (the Unit dropdown folds in as the leading `wide` one). Layout is a fixed point: `RenderGrid`'s HALF is the same 0.5 and it emits the same trailing spacer. What is gained is per-item `pcall`ing, where before one raise in the header aborted the whole body and left the page half-drawn behind `RenderUnitPanel`'s outer `pcall`. `RenderGrid` added to `settings/OptionsSetup.lua`'s degraded no-op list. Three cases in `tests/test_helpers.lua`, two of which redden against the pre-adoption body. |
| LIBKA0S-03 | `2026-08-01` | `../LibKa0s/docs/adoption/2026-08-01/03_DEVIATIONS.md` §2 | 🟢 done | — | 2026-08-01 | The `L`-trap guard, which this repo had none of. Twelve cases: one **source** check over all five seam descriptors (the only guard that reddens on `L = NS.L` itself — mutation-verified against each of the five in turn), one non-vacuity case on `locales/enUS.lua`, three **library-regression** cases handing the vendored DebugLog/Slash/Perf a fallback-only locale table, and four **rendered** assertions in the modules' own suites. Recorded rather than faked: LibKa0s-Core-1.0 has no `STRINGS` and LibKa0s-Options-1.0's `L` is `lib.LAYOUT` (geometry, not locale), so neither takes an `L` override and neither gets a descriptor-mutation case it could not fail. |
| LIBKA0S-04 | `2026-08-01` | `../LibKa0s/docs/adoption/2026-08-01/04_RECOMMENDATIONS.md` §6 | 🟢 done | — | 2026-08-01 | `README.md` grew a **Credits and libraries** section naming LibKa0s v1.1.0 (MIT). Until now the only way to answer "which LibKa0s does this addon carry?" was to grep eight minor constants out of vendored source, which is exactly the question a re-vendor sweep needs answered fast. No `CHANGELOG.md` exists in this repo, so the README is the whole record; the line has to be moved by hand at each re-vendor. |
| LIBKA0S-05 | `2026-08-01` | `../LibKa0s/docs/adoption/2026-08-01/03_DEVIATIONS.md` §7 | 🔵 wont-do | — | 2026-08-01 | `settings/About.lua:93` — the addon's only true caller-driven widget-per-item render loop (one Label per `NS.Slash:LandingRows()` entry) — is **not** converted to `RenderGrid`, and this is a library gap rather than a decision about this addon. Every item would have to be `wide`, and `RenderGrid` emits `AddSpacer(scroll, L.ROW_VSPACER)` after *every* flushed row unconditionally (`OptionsWidgets.lua:548` and `:575`), with no per-item or per-call way to suppress it. The conversion is mechanically valid and a visible regression: 8px gutters through the whole Slash Commands block. **The finding, for upstream:** `RenderGrid` expresses a caller-driven list of two-column FORM widgets but not a caller-driven list of dense single-column TEXT lines — the shape every help/landing/log/summary list takes. Preferred remedy is an item-level `tight = true` that suppresses that row's trailing spacer, which composes and leaves the default unchanged. Revisit when that lands. |
