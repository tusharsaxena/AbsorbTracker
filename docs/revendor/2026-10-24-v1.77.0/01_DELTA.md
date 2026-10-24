Delta: LibKa0s v1.76.0 -> v1.77.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-24, plan item **AT-RV** of the keybindings, settings layout and frame strata run
(`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`), on branch
`feat/2026-10-24-keybinds-layout-strata`. The run follows the installed
`/dev-copilot:wow-revendor-libka0s` (dev-copilot 2.4.0) mechanically under the item spec: no
interview and no GitHub issue filing. The adoptions this run makes in AbsorbTracker belong to its
own items (AT-ZS; AbsorbTracker ships no key binding, so it has no KB item), and every other
candidate is recorded as **deferred (run 2026-10-24)**.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.77.0` (commit `78240f7`)**, not yet pushed
(`git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints nothing). The payloads were extracted with
`git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x -C <scratch>`, never a branch tip;
`tools/` only for `prune-icons.lua`, which is not copied into the addon.
`git -C ../LibKa0s log --oneline v1.76.0..v1.77.0` lists 15 commits (LK-00 to LK-90 and the v1.76.0
merge). `git -C ../LibKa0s diff --shortstat v1.76.0 v1.77.0 -- LibKa0s` reports 13 files changed
(1055 insertions, 32 deletions), and `-- testkit` 5 files changed (617 insertions, 2 deletions).

## Step 0 — Pre-flight

The newest single-tag bundle, `docs/revendor/2026-10-23-v1.76.0/`, states `v1.75.2 -> v1.76.0`. The
provenance line before its re-vendor commit `d002fdb` named v1.75.2, so the bundle agrees with the
history. No correction is owed.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` gave
`CLAUDE.md:43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).` The last
payload commit (`git log -1 --format=%H -- libs/LibKa0s tests/_kit`, `13c0a4b`, AT-RV2's re-copy of
the moved local v1.76.0) leaves the same line. Payload check against the claimed tag: `diff -rq` of
`<v1.76.0>/LibKa0s` against `libs/LibKa0s` printed only `Only in <v1.76.0>/LibKa0s/media/icons` lines
(the icons the addon does not declare), and `<v1.76.0>/testkit` against `tests/_kit` printed nothing
(`payload-matches`). **Base: v1.76.0.**

## 3b — Actual version, before this run

The vendored `LibStub` minors were v1.76.0's (the left column of 3c) and `Kit.VERSION` was **41**
(`grep -n 'Kit.VERSION' tests/_kit/framework.lua`). Claim and bytes agree.

## 3c — Per-file minor delta

Walked over the tag's `LibKa0s.xml` rows (41 files; `OptionsKeybinds.lua` is new). Twelve move:

| File | v1.76.0 | v1.77.0 |
|---|---|---|
| `Core.lua` (`MINOR`) | 11 | **12** |
| `Widgets.lua` (`MINOR`) | 14 | **15** |
| `WidgetsDragHandle.lua` (`DRAG_MINOR`) | 4 | **5** |
| `WidgetsAutocomplete.lua` (`AUTOCOMPLETE_MINOR`) | 2 | **3** |
| `DebugLog.lua` (`MINOR`) | 20 | **21** |
| `Options.lua` (`MINOR`) | 29 | **30** |
| `OptionsIds.lua` (`IDS_MINOR`) | 2 | **3** |
| `OptionsCombat.lua` (`COMBAT_MINOR`) | 1 | **2** |
| `OptionsCompose.lua` (`COMPOSE_MINOR`) | 7 | **8** |
| `OptionsKeybinds.lua` (`KEYBINDS_MINOR`) | (new) | **3** |
| `PerfPanel.lua` (`PANEL_MINOR`) | 8 | **9** |
| `SimPanel.lua` (`SIM_PANEL_MINOR`) | 5 | **6** |

Every other file is at its v1.76.0 minor. No file is behind: no cross-major skew.

## 3d — Both diffs

Before the prune, against the whole copy: `diff -r --strip-trailing-cr` and `diff -r` of
`<scratch>/LibKa0s` against `libs/LibKa0s` both printed nothing, and the same for `<scratch>/testkit`
against `tests/_kit`. After the prune, the library diff prints only
`Only in <scratch>/LibKa0s/media/icons…` lines for the undeclared icons; nothing is `Only in` the
addon and nothing differs. No file was removed upstream, so nothing was deleted on inference.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`
lists the same lookup sites as v1.76.0: `core/Bus.lua`, `core/EnvSetup.lua`, `core/DebugLogSetup.lua`,
`core/LauncherSetup.lua`, `core/MediaSetup.lua`, `core/CoreSetup.lua`, `core/Lifecycle.lua`,
`core/WidgetsSetup.lua`, `core/PerfSetup.lua`, plus `settings/Schema.lua` (Schema and Slash),
`settings/OptionsSetup.lua` and `settings/Slash.lua`. Of the moved majors, Core, Widgets (the drag
handle, the copy window), DebugLog (the console), Perf (the panel) and Options are consumed; Sim is
not.

## 3f — Kit revision

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua`: **42** at the tag,
**41** in the addon before the copy. Revision 42 adds `mock_bindings.lua`, `mock_layers.lua` (both
opt-in) and `bindings_xml.lua` (`Kit.assertBindingsXml`, `Kit.keybindThroughTab`). Both payloads
were copied whole in one commit, as the pairing rule requires.

## 3g — Contract delta

The majors to read are the consumed ones that moved: Core 11 -> 12, Widgets 14.1.4.3.2 ->
15.1.5.3.3, DebugLog 20 -> 21.3.1, Perf -> 15.1.1.9 and Options 29.2.34.2.5.9.1.7.4.2.1 ->
30.2.34.3.5.9.2.8.4.2.1.3.

- **Core 12, DebugLog 21, PerfPanel 9** (tag `CHANGELOG.md:71-98`): the debug console and the perf
  panel are now toplevel and re-raise a shown StaticPopup on show (`Core.RaiseStaticPopups`). No
  host-supplied member moves; "What a consumer owes: nothing" (`CHANGELOG.md:90`). The copy window
  is unchanged (FULLSCREEN, not toplevel).
- **WidgetsDragHandle 5** (`CHANGELOG.md:99-127`): `level`, `ignoreParentAlpha` and `ApplyLevel` are
  opt-in; "Neither field passed, the strip is minor 4's exactly" (`CHANGELOG.md:117`). The members
  this addon reaches (`DragHandle`, `DRAG_HANDLE`, `CopyWindow`) keep their shape.
- **Widgets 15, WidgetsAutocomplete 3** (`CHANGELOG.md:128-150`): dropdown menus and the
  autocomplete list clamp to the screen; a popup that fits sits where it did.
- **Options 30** (`CHANGELOG.md:151-350`): OptionsIds 3 and OptionsCombat 2 are `__`-only;
  OptionsKeybinds 1-3 and OptionsCompose 8 add four public instance members.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
host call site, so no host-supplied member's call site can have moved.

### Blockers

**One, fixed in the copy commit: the Options degradation stub owes four new members.** The tag's
`CHANGELOG.md:373-377` ("Every Options degradation stub gains four instance members:
`KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED` and `StrataTooltip`") and
`docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md:1994` and `:2787-2789` state it; the
v1.76.0 document (`docs/api/Options/version-29.2.34.2.5.9.1.7.4.2.1-docs.md`) has none of the four.
Measured: after the copy, `lua tests/run.lua` went 884 passed, 1 failed — `parity: the Options stub
carries every helper the degraded build can reach` (`tests/test_surface_parity.lua`), with
`KEYBINDS_UNCHANGED is missing (live: string); KeybindRows is missing (live: function);
KeybindingsTab is missing (live: function); StrataTooltip is missing (live: function)`.

The fix, in `settings/OptionsSetup.lua`'s library-absent arm: the four members answer inert
(`KeybindingsTab` and `KeybindRows` return nil, the library's own degraded answer for the rows;
`KEYBINDS_UNCHANGED` is `""`; `StrataTooltip` returns `""`). Nothing in this addon calls them, and an
empty string rather than the library's sentence keeps a host copy of library text out of the stub.
A new case in `tests/test_optionssetup.lua` pins the inert shape.

## 3h — Tags vendored and never recorded

The listing (vendored tags from both payload paths and the provenance-rolling `CLAUDE.md` commits,
minus the tags the bundles record) printed nothing. No span bundle is owed.

## 3i — The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> `CLAUDE.md:44:LibKa0s icons: clear, close, copy, help.`, the
next non-blank line after the provenance line. **Decided, kept unchanged**: the tag's
`CHANGELOG.md` *What a consumer owes* (`:373-381`) names no library-drawn icon, and the new surfaces
this addon would draw (the Keybindings tab, the strata tooltip) are not adopted here. Hand lists
have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`);
the owner's in-client smoke is the backstop.

## 3j — Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds only
the cases v1.75.0's re-vendor already narrowed to the declaration (`tests/test_mediasetup.lua`,
`tests/test_optionssetup.lua`). No blocker.
