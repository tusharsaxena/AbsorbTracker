# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.70.0..v1.71.0` (20 commits) and the `CHANGELOG.md`
v1.71.0 block at the tag.

## A. Delivered on the copy

- Kit revision 38's `--list` Totals: `docs/test-cases.md` regenerated, Total 876 equals the badge.
- SlashParse 2: `/at set` refuses `nan` and the infinities on a number row.
- Env 2: the dead bare-global rung is gone; no visible change on a supported client.

## B. New surfaces (host change required)

- `Kit.secret`, `Kit.isSecret`, `Kit.reveal`, `Kit.installSecretValue` (kit `secrets.lua`) — not
  adopted in this run: no suite here simulates secret values (no `issecretvalue` stub in `tests/`), so
  there is nothing local to migrate; the release names only WhatGroup as owing it.
- `ChartMath.ClipSegment` — not adopted in this run: AbsorbTracker draws no line chart.
- `LineChart` render re-syncs the hover (no `ClearHover` needed) — not adopted in this run: no chart.
- `Autocomplete` re-installs hooks per call, `opts.maxRows` floored — not adopted in this run: no
  autocomplete box.
- `ParseValue` `nan` / `inf` refusal — not adopted in this run as a host change: it lands on the copy
  (class A) and no host code is needed; a pinning case was not added.

## C. Whole-module adoption

None. No major is added.

## Planned elsewhere, not a candidate

- `LibKa0s-Widgets-1.0` setup seam (`core/WidgetsSetup.lua`, `NS.Widgets`): plan item **AT-02** of
  this run, not decided here.
