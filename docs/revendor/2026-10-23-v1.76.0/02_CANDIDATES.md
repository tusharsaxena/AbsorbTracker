# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.75.2..v1.76.0` (8 commits) and the `CHANGELOG.md`
v1.76.0 block at the tag. OWNER_SCOPE does not name AbsorbTracker as an adopter of anything in this
release, so every candidate below is **not adopted in this run**.

## A. Delivered on the copy

- Nothing visible here. SimTimeline 3 and SimPanel 5 (a started simulation plays on its own, Run all
  removed) change a major this addon does not consume. Widgets 14 leaves every existing call drawing
  what it drew at 13 (`docs/api/Widgets/version-14.1.4.3.2-docs.md`, *What changed at 14.1.4.3.2*).

## B. New surfaces (host change required)

- `W.TestStrip(parent, { kind = "sim" })` and `strip.kind` (Widgets 14,
  `docs/api/Widgets/version-14.1.4.3.2-docs.md` *What changed at 14.1.4.3.2*) — not adopted in this
  run: the addon has no test-mode strip and no simulator (the unlocked bar is the preview, which the
  preview-mode marker rule carves out). Additive.

## C. Whole-module adoption

- `LibKa0s-Sim-1.0` — not adopted in this run: the addon has no simulator (unchanged from v1.75.0's
  `02_CANDIDATES.md`). Additive.
