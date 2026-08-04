# 02 — Deviations

**Audited against:** Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**.
**Provenance:** every section file fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/standards/` and
verified byte-identical to the canonical checkout at `WowAddonStandards@2141229` (clean tree). All
24 sections listed by `STANDARDS.md` were retrieved and read; none is unassessed. See
`01_CURRENT_STATE.md` for the commands.

**Verdict: minor deviations.** The addon is one of the closest things the collection has to a
reference implementation — the whole LibKa0s consumption surface (five majors, five seams, five
stubs) is correct, both vendor diffs are empty, both gate commands are green, and the combat-secret
and bus disciplines are exemplary. What remains is four MUSTs, none structural: two are stale README
data, one is a single AceGUI widget built one step too early, one is a call-site habit at the chat
printer.

**Counts:** MUST **4** · SHOULD **5** · MAY **3**.

**IDs.** Prefix `AT-`, continuing from `docs/audits/2026-07-18/` (highest prior `AT-31`). `AT-30`
and `AT-31` recur and keep their IDs. `AT-05`, `AT-26`, `AT-27`, `AT-28`, `AT-29` from that run are
**resolved** — see the closure list at the end.

---

## MUST

| ID | Section | Sev | Deviation | Fix direction |
|---|---|---|---|---|
| **AT-32** | `documentation-§1` (item 2 keep-in-sync) · `testing-§5` | MUST | The README `[tests]` badge reads **467/467** while the generated inventory `docs/test-cases.md` and a live run both report **469**. The badge is static text and has gone stale, which is the exact failure the keep-in-sync rule exists to prevent. | Update `README.md:7` to `Tests-469%2F469_passing-green`. Then make it hard to repeat: the count already lives in `docs/test-cases.md`'s `## Totals` row, so add a gate case that reads that row and asserts the README badge matches it — the badge is the one figure in the repo with no mechanical check behind it. |
| **AT-33** | `documentation-§1` (item 5 roll-forward) · anti-pattern #40 | MUST | `## What's new in 1.9.0` and the top `## Version History` row disagree about what 1.9.0 shipped. What's new lists eight bullets — target/focus bars, per-bar enable toggles, mirror/copy styling, the breaking fully-qualified slash paths — of which the Version History row mentions none; the row lists four items, all of which What's new also has. The standard requires the two to agree, the section being the top row surfaced above the fold. | Rewrite the 1.9.0 Version History row to carry the same highlights as `## What's new in 1.9.0`, leading with the two the row omits entirely and that a user would most want to see (the target/focus bars and the breaking slash-path change). Roll both forward in the same change on the next version bump. |
| **AT-34** | `options-ui-§5` (lazy body) · anti-pattern #42 | MUST | `settings/Profiles.lua` creates an AceGUI `SimpleGroup` and anchors it inside the page **builder**, which the library runs at category-registration time (`CreateOptionsPanel` at `OnEnable`), not in the panel's first `OnShow`. Two distinct rules bite: AceGUI lays children out against a container whose width is zero at registration, and a widget created inside the load window keeps Blizzard's stock art for the session while every later-created sibling comes out skinned — the same-code-different-look race #42 describes. Every other page in the addon is correctly lazy (the suite asserts it). | Move the `AceGUI:Create("SimpleGroup")` and its anchoring into the existing `OnShow` handler, behind a `built` flag, so the builder only registers the subcategory and parks the intent. `AceConfigDialog:Open` already runs on every show and is cheap to re-run, so the change is: create-once inside `OnShow`, then `Open`. Extend the existing "a page renders nothing until its first OnShow" case to cover the Profiles page, which it currently cannot reach. |
| **AT-35** | `events-frames-taint-§8` | MUST | Chat call sites build their line with `..` or `:format` **before** handing it to the shared secret-safe printer, which the standard forbids at call sites "even if it is never handed a secret today" — the single seam exists so no call site has to reason about that. 17 sites, concentrated in `settings/Slash.lua` (`runProfile`'s eight, `runToggle`'s two, `runTest`, `PrintCmd`, the degradation stub's four) plus `settings/Schema.lua:214`. None is fed a combat-protected value today — profile names, unit labels and user-typed numbers — so this is latent, not live. | The library already ships both remedies and the addon publishes neither. Add `NS.Format = printer.Format` beside `NS.Print` in `core/CoreSetup.lua` (with a guarded equivalent in the library-absent branch), then convert `print(("…%s…"):format(x))` to `NS.Format("…%s…", x)` and `print("a" .. b)` to `print("a", b)` — `printer.Print` is already varargs and stringifies each argument. Leave the two pure-indent concatenations (`"  " .. row`) if preferred, but note in the code why they are exempt. |

## SHOULD

| ID | Section | Sev | Deviation | Fix direction |
|---|---|---|---|---|
| **AT-30** *(recurs from 2026-07-18)* | `localization-§1` / `localization-§3` | SHOULD | The `NS.L` seam exists and `locales/enUS.lua` ships, so both MUSTs in those sections are met — but no user-facing string is routed through it. Labels, tooltips, slash output and the reset-confirm popup are hardcoded English, and `enUS.lua` carries the metatable and no keys. Already recorded under Known Limitations and deferred in `docs/pending/LEDGER.md` (PLAN-02). | Unchanged from the prior run: either keep as an accepted deviation, or wrap user-facing strings in `NS.L["…"]` with the English string as the key and populate `locales/enUS.lua`. Non-breaking either way — the seam is already in place and the fallback returns the key. User decides. |
| **AT-31** *(recurs from 2026-07-18)* | `events-frames-taint-§1` | SHOULD | `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` register on private `CreateFrame` frames — one per tracked unit — via `RegisterUnitEvent`, rather than through AceEvent-3.0. Justified and documented at length (AceEvent uses one shared frame with plain `RegisterEvent` and structurally cannot unit-filter; both events fire for every unit the client knows about, so an AceEvent registration pays a full C→Lua dispatch per unit to discard all but three). | Retain as accepted — this is the ">1000 events/min" case the rule's own parenthetical exempts, and the justification is recorded in `docs/ARCHITECTURE.md`. Kept in the ledger so it re-surfaces with its reason rather than being silently forgotten. If it is ever to stop recurring, the durable fix is upstream: `events-frames-taint-§1` could name unit-filtered event registration as a sanctioned exception. |
| **AT-36** | `documentation-§5` (docs in sync; the retired notation is retired by `STANDARDS.md`'s reading guide) | SHOULD | The repo still cites the standard using the **retired global `§N.M` numbering** in dozens of places — `core/Namespace.lua:5,9`, `core/AbsorbTracker.lua:9,163`, `core/Constants.lua:12,16`, `core/State.lua:3`, `core/Compat.lua:7`, `modules/Timer.lua:3`, `core/LSMPatch.lua:3`, `settings/Slash.lua:5,196`, `settings/Schema.lua:200,248`, `settings/OptionsSetup.lua:74,81`, `settings/About.lua:23`, and throughout `docs/ARCHITECTURE.md`'s "Standards Deviations". `filename-§N` is the only cross-reference form. A reader following `§4.2` or `§12.5` today lands nowhere. Several files already use the current form, so the repo is mixed. One reference is malformed outright: `settings/Slash.lua:199` reads `slash-commands-§:`. | Sweep the retired refs to their `filename-§N` equivalents — mechanical and greppable (`grep -rnE '§[0-9]+\.[0-9]+'`). The common ones map: `§3.x`→`library-stack`, `§4.1/§4.2/§4.5`→`architecture-§1/§2/§5`, `§5.1`→`savedvariables-§1`, `§7.x`→`slash-commands-§x`, `§8.x`→`localization-§x`, `§9.1`→`events-frames-taint-§1`, `§11`→`compat`, `§12.x`→`debug-logging-§x`, `§1.4`→`layout-§3`. Fix `slash-commands-§:` to `slash-commands-§3`. Frozen prior audit/review bundles are history and stay as they are. |
| **AT-37** | `documentation-§5` | SHOULD | `docs/ARCHITECTURE.md`'s "Standards Deviations" section lists three items as open deviations "pending promotion" that the standard **already sanctions outright** as of v2.17.1: the second SavedVariables global `AbsorbTrackerPerfDB` (now `savedvariables-§4` / `toc-file-§2`, the explicitly named carve-out), the gated `Perf.on and debugprofilestop()` bracket idiom (now the mandated shape in `performance-§2`), and `lizard`-generated `docs/complexity.md` (now `performance-§10`). A deviation register that lists compliant behavior as deviant trains its readers to skim it. | Delete the three entries, or move them to a short "was a deviation, now standard as of v2.17.1" note with the section that adopted each. Keep the remaining entries (Wago omission, per-profile `schemaVersion`, per-unit event frames, `__lastUnitCtx`, the fixed media) — those are still live decisions. |
| **AT-38** | `preview-mode` | SHOULD | Two SHOULDs in that section are unmet. There is no automatic preview while the display is **unlocked** — unlocking shows only a small unit label, so a user positioning a bar out of combat is dragging an empty frame — and `/at test` is a **timed fill** (`NS.testHoldUntil`) rather than a toggle, so there is no "preview verb toggled off" path, only expiry. The render path itself is correctly shared with live data, which is the third SHOULD and is met. | Feed the existing `/at test` placeholder through the same path whenever `locked` is false, clearing it on lock — `NS.ShouldShowBar` and `NS.UpdateAbsorbBar` already have the seam (`testHoldUntil`), so this is a condition change, not new render code. Optionally make `/at test off` clear `testHoldUntil` so the verb has an explicit off. |

## MAY / advisory

| ID | Section | Sev | Observation | Suggestion |
|---|---|---|---|---|
| **AT-39** | `lint` | MAY | `.luacheckrc`'s `exclude_files` excludes all of `docs/` where the template names `docs/audits/` and `docs/reviews/`. A superset, and harmless today (no `.lua` under `docs/`), but it would silently un-lint a future doc-adjacent script. | Narrow to the template's two entries, or leave it and note why in the existing comment. |
| **AT-40** | `documentation-§5` | MAY | `modules/Bar.lua:6` names `core/DebugLog.lua` as a caller of the player aliases; that file was replaced by `core/DebugLogSetup.lua` and the console moved into the library. A comment naming a file that no longer exists. | Update the comment to name the real readers. |
| **AT-41** | `documentation-§1` | MAY | The README carries a `## Credits and libraries` section between `## Troubleshooting` and `## Issues and feature requests`. `documentation-§1` enumerates twelve sections in an exact order and does not enumerate this one; the twelve that are required all appear, in the required relative order, so this is an addition rather than a reordering. Recorded so the next audit does not re-derive the judgment. | No change required. If a future standard revision tightens item 28 to forbid additions, fold the content into the Description or move it under `docs/`. |

---

## Closed since `docs/audits/2026-07-18/`

Recorded so the ledger stays honest about what moved.

- **AT-05** — missing `## X-Wago-ID`. **Closed by the standard**: `toc-file-§1` now makes Wago and
  WoWI IDs **MAY**, included only when the addon is actually listed there. The addon publishes on
  CurseForge only, so the omission is correct. The accepted-deviation entry in
  `docs/ARCHITECTURE.md` can be retired with AT-37.
- **AT-26** — no standalone `version` verb. **Fixed**: `settings/Slash.lua:96` registers it, reading
  `Compat.GetAddOnMetadata` with `NS.version` as fallback, and the README table lists it.
- **AT-27** — paired action buttons at a flush `0.5`. **Fixed by adoption**: the button-pair maker
  and `BUTTON_PAIR_REL` now live in `LibKa0s-Options-1.0`, which the addon consumes; the host copy
  of the constant was deliberately deleted from the stub.
- **AT-28** — TOC `#` section order. **Fixed**: `# Locales` sits directly after `# Libraries`.
- **AT-29** — no closed message bus. **Fixed**: `core/Bus.lua` publishes five
  `Ka0s_AbsorbTracker_*` messages with one sender each, every receiver on its own
  `NS.NewBusTarget()`, all documented in `docs/ARCHITECTURE.md`.
