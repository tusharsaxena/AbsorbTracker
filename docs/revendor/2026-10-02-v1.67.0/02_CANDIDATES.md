# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.66.0..v1.67.0`, the `CHANGELOG.md` v1.67.0 block, and
`docs/api/Core/version-10-docs.md` ("The resize grip") and
`docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md` at the tag. No interview was held: the
2026-10-02 census-adoption plan (`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`)
already assigns every new surface to an item.

## A. Delivered on the copy

- The loaded-addon guard on the IdList help art (OptionsIdList 3): latent here, because this addon
  draws no `O.IdList`. It protects the first helped list anyone adds.
- The Options 28 docblock correction: no behavior change.

## B. New surfaces, and the census-adoption item that takes each

| # | Surface | Evidence | Item | Note |
|---|---|---|---|---|
| B1 | Options descriptor `addonName` (the host folder name, checked against the loaded addons) | CHANGELOG v1.67.0 "OptionsIdList minor 3 and Options minor 28"; Options 28 doc | **CA-AT-NM** | `settings/OptionsSetup.lua`: keep vararg 1 as `addonName` and pass `addonName = addonName,`. Latent: no IdList here |
| B2 | `MakeResizable` opts `canResize`, `onResizeStop`, `gripParent` (Core 10) | CHANGELOG v1.67.0 "Core minor 10"; Core 10 doc "The resize grip" | **none** | This addon builds no resize grip of its own; the census adopts it in BankLedger, LootHistory and MultiMeters |

This host's other census item, **CA-AT-01** (AbsorbTracker#33: `Slash.SplitVerb`,
`Slash.ProfileNames` and `Core.SECRET`), adopts surfaces that were already in v1.66.0, so it is not a
v1.67.0 candidate. It follows CA-AT-NM in the same branch.

## C. Whole-module adoption

None. No major is added, and every major this addon did not consume at v1.66.0 is unchanged.
