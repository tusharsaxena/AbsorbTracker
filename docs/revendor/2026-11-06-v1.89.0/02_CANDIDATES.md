# Candidates, LibKa0s v1.85.0 -> v1.89.0

Sources: `git -C ../LibKa0s log --oneline v1.85.0..v1.89.0`, the tag's `CHANGELOG.md` blocks v1.86.0 to
v1.89.0, and the `docs/api/` documents of every major whose minor moved (Toast 3 -> 4, Widgets 22 ->
23, DebugLog 22.6.1.4 -> 22.7.1.4, IconBrowser new, testkit 50 -> 51). No contract blocker (01_DELTA
3g), so nothing here is a blocker in disguise.

## Class A: delivered on the copy

- **Kit revision 51** (CHANGELOG v1.89.0, "The kit's unregister guard (`LK-K1`)";
  `docs/api/testkit/version-51-docs.md`): `mock_ace.lua`'s CallbackHandler registry clears an entry
  only where one exists, so an `Unregister*` of a target with no registration during a dispatch no
  longer raises `invalid key to 'next'` or skips a registrant. "A consumer owes only the re-vendor."
- **DebugLogDiagnostics minor 7** (CHANGELOG v1.86.0, `docs/api/DebugLog/version-22.7.1.4-docs.md`,
  "No member change"): the `/at` diagnostics report's `LibKa0s running:` line names `IconBrowser`
  when the winning copy carries it.
- **Widgets minor 23, flat menus** (CHANGELOG v1.87.0, `docs/api/Widgets/version-23.5.12.6.7.5-docs.md`,
  "Every single-level menu, a dropdown's and a host's, is unchanged"): any flat menu the library
  draws draws what minor 22 drew. The addon opens no `W.ContextMenu` itself.

## Class B: host change required

- **Widgets 23 cascading `W.ContextMenu` rows** (`submenu`, `radio`, `selected`, `opts.check`;
  CHANGELOG v1.87.0, `docs/api/Widgets/version-23.5.12.6.7.5-docs.md`). AbsorbTracker has no
  `W.ContextMenu` use site: the only mention is the degradation stub `core/WidgetsSetup.lua:35`,
  which "nothing here calls". **Not applicable**, no host surface to change.
- **Toast 4 stack** (`stack`, `stackGrow`, `stackGap`, `SetStack`, `Visible`, `FrameFor`; CHANGELOG
  v1.88.0, `docs/api/Toast/version-4-docs.md`). AbsorbTracker does not look up `LibKa0s-Toast-1.0`
  (01_DELTA 3e) and carries no Toast stub, so no stub member is owed either. **Not applicable.**

## Class C: whole-module adoption

- **`LibKa0s-IconBrowser-1.0`** (new major, CHANGELOG v1.86.0, `docs/api/IconBrowser/version-1.1.1-docs.md`):
  a host-configured window for choosing an icon. AbsorbTracker's UI offers the player no icon
  choice: its art is fixed marks through `NS.Icon` (the `LibKa0s icons:` line), so there is nothing
  for a browser to serve. Blast radius would be additive, but there is no use. **Settled** by the
  owner's run ruling (no chooser, no adoption, no issue).
