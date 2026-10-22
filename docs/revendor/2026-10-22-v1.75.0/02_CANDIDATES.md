# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` (56 commits) and the `CHANGELOG.md`
v1.72.0, v1.73.0, v1.74.0 and v1.75.0 blocks at the tag. OWNER_SCOPE A names AbsorbTracker as an
adopter of none of this release's surfaces, so every candidate below is **not adopted in this run**.

## A. Delivered on the copy

- The comment-only minors (Core 11, DebugLog 20, OptionsIdList 5, PerfPanel 7): no visible change.
- DebugLogDiagnostics 3: a diagnostics report names Glow and Sim whenever a client runs them.
- Kit revisions 39-41: the icon gate in `tests/test_vendor_sync.lua`, and the complexity suite's
  `crashed` bucket.

## B. New surfaces (host change required)

- `Perf.Note(key, ms, false)`, `parentKey = false` for "observed at top level" — not adopted in this
  run: not an OWNER_SCOPE adopter, and every `Perf.Note` here states nil or a real parent bucket.
- `Kit.assertLatchHoldOrder` (kit `latch.lua`) — not adopted in this run: not an OWNER_SCOPE adopter;
  this addon's stand-down latch has no hold-order case the helper would replace.
- `O.Drawer` (OptionsDrawer 1) — not adopted in this run: not an OWNER_SCOPE adopter; no settings page
  here is a list of conditions or filters.
- `W.SearchBox` (Widgets 13) — not adopted in this run: no filter bar.
- `W.TestStrip` (Widgets 13) — not adopted in this run: no explicit test mode (the unlocked bar is the
  preview, which the preview-mode marker rule carves out).
- `W.StepPanel` — not in the payload: LK-11 outcome B made the step panel Sim-private.
- `Item.BonusIDsFromLink` (Item 3) — not adopted in this run: this addon reads no items.

## C. Whole-module adoption

- `LibKa0s-Glow-1.0` — not adopted in this run: the addon draws no glow.
- `LibKa0s-Sim-1.0` — not adopted in this run: the addon has no simulator.
