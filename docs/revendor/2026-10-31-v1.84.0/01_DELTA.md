Delta: LibKa0s v1.83.0 -> v1.84.0

# 01 — Delta (AbsorbTracker)

Run 2026-10-31, item AT-RV, on branch `feat/2026-10-31-findings-remediation`. The tag is local
(`git -C ../LibKa0s ls-remote --tags origin v1.84.0` prints nothing); the payload comes from it, commit
`e917ccd`, not from the working tree.

## 3a Base

`grep -n '[Bb]undles' CLAUDE.md` gives `CLAUDE.md:46`, v1.83.0. The last payload commit's own line
(`git log -1 --format=%H -- libs/LibKa0s tests/_kit`, then `git show`) names v1.83.0 too. The two agree.
Step 0 for this addon: the newest single-tag bundle, `2026-10-24-v1.77.0`, states base v1.76.0, and the
provenance before `19858da` was v1.76.0. No correction is owed.

## 3b, 3c Minors

`diff -rq --strip-trailing-cr` against an extract of v1.83.0 differs only in the icons this addon does
not declare, so the line and the bytes agree. 3c's loop over the tag's `LibKa0s.xml`, moved files only.
No skew. Nine files are new.

| File | Old | New |
|---|---|---|
| `Schema.lua` | 2 | 3 |
| `Charts.lua` | new | 1 |
| `ChartsRender.lua` | new | 1 |
| `Skin.lua` | 10 | 11 |
| `SkinOwnerTokens.lua` | new | 1 |
| `SkinDefs.lua` | 18 | 19 |
| `SkinDefsOthers.lua` | new | 1 |
| `WidgetsDragHandle.lua` | 8 | 10 |
| `DebugLogDiagnostics.lua` | 5 | 6 |
| `Slash.lua` | 20 | 21 |
| `Options.lua` | 34 | 35 |
| `OptionsWidgets.lua` | 38 | 40 |
| `OptionsFlow.lua` | new | 2 |
| `OptionsIds.lua` | 5 | 6 |
| `OptionsIdSuggest.lua` | new | 1 |
| `OptionsTabs.lua` | 11 | 13 |
| `OptionsTabbed.lua` | new | 2 |
| `OptionsCompose.lua` | 14 | 15 |
| `OptionsSkinPicker.lua` | 4 | 5 |
| `OptionsSkinPickerRows.lua` | new | 1 |
| `SimPanel.lua` | 8 | 9 |
| `SimPanelRender.lua` | new | 1 |

## 3d Diffs

Before the copy, the only difference from v1.83.0 is `Only in .../media/icons` for undeclared icons,
which is the declaration working.

## 3e Consumption

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'` outside `libs/` and `tests/`:
Env, Skin, Bus, Launcher, DebugLog, Core, Lifecycle, Widgets, Perf, Media, Schema, Slash, Options. The
new `LibKa0s-Charts-1.0` has no lookup here, nor do Sim, Glow, Item, Pool and Toast.

## 3f Kit

Revision 46 to 47 (`grep -n 'Kit.VERSION'`). Both payloads move in one commit, as the pairing rule
requires.

## 3g Contract delta

Docs read: `docs/api/{Options,Schema,Slash,Skin,Widgets,DebugLog}` at the two keys, and the tag's
`CHANGELOG.md` v1.84.0 block. `grep -rn '__Attach'` outside the payloads finds no call site in this
addon, so no host-supplied member can have moved. No surface this addon uses tightened: the changes
are additive or are pure moves.

### Blockers

- `O.PositionBlock` is a new public member, owed by the Options degradation stub (tag `CHANGELOG.md`,
  "Consumers' degradation stubs owe the new `O.PositionBlock`"). Fixed in the copy commit.
- The kit's `mock_ace.lua` split and the new payload files reach this addon's test loaders only through
  `LibKa0s.xml` and the kit, so any hand-typed list is fixed in the copy commit if the gate shows one.

## 3h Span

The listing printed nothing. No span bundle is owed.

## 3i Icons

`LibKa0s icons: clear, close, copy, help, settings.` is kept, directly under the provenance line.
Decided by the run's brief. Hand lists have drifted before, so the owner's in-client smoke stays the
backstop: a pruned icon resolves to a path and draws blank.

## 3j Tests over the icon folder

`tests/test_mediasetup.lua:149` reads declared names only. `tests/test_optionssetup.lua:613` asserts an
undeclared `info` stays absent. Neither loops the catalog, so neither is a blocker.
