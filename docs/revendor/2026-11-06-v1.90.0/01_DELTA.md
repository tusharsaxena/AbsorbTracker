Delta: LibKa0s v1.89.0 -> v1.90.0

Part of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (item `SF1-RV-AT`, from
`SF1_SMOKE_FEEDBACK.md`). The tag is **local**: `git -C ../LibKa0s ls-remote --tags origin v1.90.0`
prints nothing, which is expected; it is pushed only at the owner's go-ahead. This is not a refresh
(the provenance line names v1.89.0, not v1.90.0). `git -C ../LibKa0s rev-parse v1.90.0` is
`b2fce60` (the annotated tag object), which peels to commit `4485b8f`. The payload was extracted with
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C /tmp/claude-1000/rv-at-v190/x`.
This file was written before the copy.

## Step 0 pre-flight

The newest single-tag bundle is `2026-11-06-v1.89.0`, whose line 1 states base v1.85.0. The
provenance line at `7e9785c^` (the parent of the v1.89.0 re-vendor `7e9785c`) names v1.85.0:

    $ git show 7e9785c^:CLAUDE.md | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'
    Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0

`ok`. No base correction is owed.

## 3a. Claimed version, and the base

    $ grep -n '[Bb]undles' CLAUDE.md
    46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).

The last payload commit is `7e9785c` (`V89-AT: Re-vendor LibKa0s v1.89.0`), whose line names
v1.89.0, and no `CLAUDE.md` commit follows it. The two agree. **Base: v1.89.0**, the run's override.

    $ git -C ../LibKa0s log --oneline v1.89.0..v1.90.0
    4485b8f SF1-L3: Release v1.90.0 adds the release run's record and its notes
    4ac9f3c SF1-L3: Release v1.90.0 moves every version line to the tag and records the consumer sweep
    b9f7651 SF1-L2: RegisterOwner's keepScope, a Scope another addon's skin copy never writes
    7d42f4e SF1-L1: Every Widgets edge is one physical pixel at any UI scale, with no skin and under every skin
    e809ca3 Merge feat/2026-11-06-harvest-standards: ...
    72733ee SYNC-DOCS: Name the IconBrowser major everywhere the docs list majors, ...
    1ca12c6 LK-K3: Merge feat/2026-11-05-kit-unregister-guard (LibKa0s v1.89.0, kit revision 51)
    $ git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 | tail -1
    37 files changed, 35494 insertions(+), 94 deletions(-)

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` gives the
v1.89.0 minors (Core 15, Skin 16, SkinPaint 18, SkinPaintExtras 17, Widgets 23,
WidgetsAutocomplete 7, OptionsAppearance 6). Claim and bytes agree.

## 3c. Per-file minor delta

The loop over the tag's `LibKa0s/LibKa0s.xml`. Every file not listed is unchanged.

| File | v1.89.0 | v1.90.0 |
|---|---|---|
| `Core.lua` | `LibKa0s-Core-1.0` 15 | 16 |
| `Skin.lua` | `LibKa0s-Skin-1.0` 16 | 17 |
| `SkinPaint.lua` | `PAINT_MINOR` 18 | 19 |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` 17 | 18 |
| `Widgets.lua` | `LibKa0s-Widgets-1.0` 23 | 24 |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR` 7 | 8 |
| `OptionsAppearance.lua` | `APPEARANCE_MINOR` 6 | 7 |

No file is new, none is behind: no cross-major skew. No `NEEDS_*` floor rises.

## 3d. Diffs before the copy

    $ diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v 'Only in .*/media/icons'
    Files .../Core.lua and libs/LibKa0s/Core.lua differ
    Files .../OptionsAppearance.lua and libs/LibKa0s/OptionsAppearance.lua differ
    Files .../Skin.lua and libs/LibKa0s/Skin.lua differ
    Files .../SkinPaint.lua and libs/LibKa0s/SkinPaint.lua differ
    Files .../SkinPaintExtras.lua and libs/LibKa0s/SkinPaintExtras.lua differ
    Files .../Widgets.lua and libs/LibKa0s/Widgets.lua differ
    Files .../WidgetsAutocomplete.lua and libs/LibKa0s/WidgetsAutocomplete.lua differ
    $ diff -rq <scratch>/testkit tests/_kit
    (empty)

The byte and content readings agree (no line-ending drift). 213 `Only in <scratch>/LibKa0s/media/icons`
lines are the undeclared icons (the declaration working). No `Only in libs/LibKa0s` line: nothing
was removed upstream.

## 3e. Consumption map

    $ grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'

Unchanged since v1.89.0: eighteen host lookup sites over fifteen majors, among them Core
(`core/CoreSetup.lua:26`), Skin (`core/SkinSetup.lua:81`, `core/Database.lua:174`, `:285`), Widgets
(`core/WidgetsSetup.lua:24`) and Options (`settings/OptionsSetup.lua:76`). Not looked up: Toast,
IconBrowser, Compat, Pool, Item, Glow, Charts.

## 3f. Kit revision

    $ grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua
    <scratch>/testkit/framework.lua:20:Kit.VERSION = 51
    tests/_kit/framework.lua:20:Kit.VERSION = 51

Kit revision 51 on both sides; the kit payload is byte-identical. The pairing rule (from v1.9.0 both
payloads travel together) holds by construction, since both are copied whole.

## 3g. Contract delta

Moved and consumed: **Core** (15 -> 16), **Skin** (key 16.1.27.8.18.17.17.4.9 -> 17.1.27.8.19.18.17.4.9),
**Widgets** (23.5.12.6.7.5 -> 24.5.12.6.8.5) and **Options** (OptionsAppearance 6 -> 7).

- Core: `docs/api/Core/version-15-docs.md` against `version-16-docs.md`. "No public member is added,
  removed or renamed"; four internal `__` members (`__PixelSize`, `__WatchPixels`, `__OnPixelScale`,
  `__PixelBackdrop`), "A host calls none of them."
- Widgets: `version-23.5.12.6.7.5-docs.md` against `version-24.5.12.6.8.5-docs.md`. "No member,
  option or row field is added, removed or renamed", and "What a host owes: nothing."
- Skin: `version-16.1.27.8.18.17.17.4.9-docs.md` against `version-17.1.27.8.19.18.17.4.9-docs.md`.
  `RegisterOwner(owner, { keepScope = true })` is additive (an option with `Since 17`); the
  `RegisterOwner` row gains only that option. AbsorbTracker's `core/SkinSetup.lua:482` call is
  unaffected.
- Options: OptionsAppearance 7's `lib.__copySkinTo` treats a `keepScope` target differently; every
  other target "takes the Scope as before".
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`
  prints nothing: the addon hands the library no `__Attach*` members.

**Blockers: none.**

## 3h. Tags vendored and never recorded

The 3h listing (horizon `2026-08-25`, 64 vendored tags walked over both payloads and the `CLAUDE.md`
rolls) against the store's recorded tags prints nothing. **No span bundle.**

## 3i. The icon declaration

    $ grep -n 'LibKa0s icons:' CLAUDE.md
    47:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.

The next non-blank line under the provenance line; no split is needed. **Kept unchanged** (run
override). The range adds no library-drawn mark (`docs/releasing.md` *Library-drawn icons* is
unchanged in content by v1.90.0). Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`,
WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
    tests/test_mediasetup.lua:121   known[] from lib.ICONS (the catalog of names, not files)
    tests/test_mediasetup.lua:153   opens each DECLARED name's .tga
    tests/test_optionssetup.lua:562 opens info.tga (declared)

All three are narrowed to declared names already. **No blocker.**

## Dead stub mirrors

    $ grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit
    (none)

No `__` member was removed in the range.
