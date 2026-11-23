# AbsorbTracker feedback batch, 2026-11-23: design

Branch `feat/2026-11-23-absorbtracker-feedback`. Plan:
[`../plans/2026-11-23-absorbtracker-feedback.md`](../plans/2026-11-23-absorbtracker-feedback.md).

## The owner's words (verbatim, 2026-11-23)

1. "The unit selector disappears some times - this is immediately after setting up a new profiel
   for example. It fixes itself if i navigate to a different settings page and come back". The
   screenshot shows Appearance with the "Unit" label and an empty space where the dropdown should
   be, then the Bar and Text tabs below.
2. "Default setup for a new profile should be to enable all three bars, none of them linked.
   Position should be stack on on top of another for initial positioning"
3. "Add "psoition" settings in appearance > bar just below size sub section - allows faine control
   of every bar"

## ATF-01: the Unit picker after a profile event

### What was checked

The headless harness was driven through every sequence the report and the lead's notes name: the
Appearance page open, then hidden, then a profile created (`db:SetProfile`), copied
(`CopyProfile`), reset (`ResetProfile`) and deleted, and `/at profile new`, each with the page
shown and with it hidden and shown again, on Player and on an unlinked Target. To get closer to
the client than the kit's AceGUI fake (which never reuses a widget), the cases also ran under a
pooled AceGUI: a released widget goes back to a free list and the next `Create` of that type hands
it out again, as AceGUI-3.0 does.

Each of the three suspects was checked and none held in the harness:

- **A re-render while the panel is mid-release.** One render per event, never a nested one (a
  traced `RenderUnitPanel`), no widget released twice, and no chrome widget that is still drawn
  ever released, pooled or not. The stale set is released after the replacement is drawn, so the
  pool cannot hand a widget that is still on screen back to the same render.
- **A render without the unit context.** `ctx.unit` survives every event; the picker's value and
  list are right after each one.
- **A widget hidden and never shown again.** The picker's frame, the header frame, the chrome and
  its band height are shown and unchanged after each event.

The library's side was read as well: `PageHeader` and its pool of one, `releaseChrome` and
`releaseStaleBanner`, the refresh gate (`isShown`, `renderCtx`, the dirty flag), the AceGUI owner
proxy and `SkinAce`'s paint, restore and release chain, the first-run skin picker's rows,
`OptionsMedia`'s pickers and the Profiles page's AceConfigDialog double `Open`. None of them
releases, hides or re-parents a widget this page holds.

### Root cause

**Not established.** The symptom (the dropdown's own label drawn, its control not) is inside one
AceGUI widget, and the only code that acts on the control and not the label is the skin's fade of
the stock art and its box. The two candidates that fit, a widget whose stock art stays faded with
no box drawn over it, and the control covered by a frame drawn over the lower part of the band,
both depend on client draw state the harness does not model (texture alpha, frame levels and
strata, lazily loaded font faces). Neither could be reproduced headlessly, and no fix is shipped
without a failing case that a fix turns green.

### Design calls

- **D1. No speculative runtime change.** A next-frame redraw, a repaint after placement or a
  move to `PageBanner` would each be a guess, and the last would break the owner's ABS-L11 ruling
  (every control at the same x for every unit), because `PageBanner`'s cells follow the act count.
- **D2. Record the state when it happens.** The diagnostics report's `[UI]` section gains one line
  for the Appearance page's Unit picker: whether it is drawn, released, shown and visible, its size,
  its value, and the alpha of the control's stock art. When the owner sees the empty band again,
  `/at diagnostics` names which candidate it is.
- **D3. Pin the sequence.** `tests/test_profilepanel.lua` drives New, Copy, Reset and Delete,
  shown and hidden, under the pooled AceGUI, and asserts the picker exists, is live (not
  released), shown, and carries the units list and the picked unit. It passes before and after
  this batch: it guards the page, it is not the fix.
- **D4. A smoke check that captures evidence** (LOOK-21): reproduce, then `/at diagnostics` and
  `/fstack` over the empty cell, and record both.

## ATF-02: new-profile defaults

### Today

`defaults/Profile.lua` ships `player = unit(true, nil)`, `target = unit(false, true)`,
`focus = unit(false, true)`: target and focus off and linked (`mirror`). `NS.DefaultPosition`
(modules/Display.lua) already stacks the bars: player at the screen's center, target one step
above, focus two, the step being the player bar's height plus the drag strip's room plus an 8 px
gap.

### The trap

AceDB stores only what differs from a default and strips a value equal to it at logout, so an
existing profile that never touched target or focus stores nothing for `enabled` or `mirror`.
Changing the default would turn both bars on and unlink them on every such profile at the next
login. The owner asked for new profiles only.

### Design

- **D5. New defaults:** all three units `enabled = true`, target and focus `mirror = false`. The
  schema rows follow (`units.<unit>.mirror` reads its default from the defaults table instead of a
  literal `true`).
- **D6. Ladder step v11, `NS.SCHEMA_VERSION` 11:** every profile that existed before this load
  and stores no `enabled` for target or focus gets `false` written, and no `mirror` gets `true`,
  so it keeps its look. Stored values (a bar the player turned on, a unit they unlinked) are left
  alone.
- **D7. "Existed before this load" is a snapshot taken before AceDB touches the profiles.**
  AceDB's defaults merge fills the active profile in place the moment it is read (in the client
  lazily, in the kit's fake eagerly at `New`), after which a stored value and a merged default are
  indistinguishable. So `NS:InitDB` records, for every profile in the raw SavedVariables table
  before `AceDB:New`, which of the four flags it stores, and the v11 step reads that record. A
  profile absent from the record (none on a fresh install, or one created later) is never
  touched. The record is dropped after the ladder runs.
- **D8. A genuinely new profile later is never caught.** The ladder runs once per account (the
  account-wide stamp), at init only; a profile made afterwards through the Profiles page or
  `/at profile new` is not in any snapshot and gets the new defaults. A profile restored from an
  old backup after the stamp moved is the accepted gap: it reads the new defaults, as a reset
  profile does.
- **D9. The v3 lift seeds the legacy flags.** `MigrateProfileToV3` creates the per-unit rows of a
  pre-v3 profile. It seeded them from the defaults, which would now turn the bars on for a profile
  from before target and focus existed. It seeds target and focus off and linked explicitly.
- **D10. Reset and copy.** A reset profile is a fresh profile and gets the new defaults. A copy
  carries the source's stored values, so a migrated source copies its look.
- **D11. Positions.** No change: the default stays `position = nil`, and the stacked default
  already keeps the three bars one above another with no overlap at the default sizes (each bar 20
  px tall, each step at least 28 px). A test pins it.
- **D12. Look of an unlinked target or focus.** It starts from the factory appearance, which is
  identical for every unit, so it looks like an untouched player bar. Nothing is copied from the
  player.

## ATF-03: Position rows

### The stored shape

A drag stores `units.<unit>.position = { point, relPoint, x, y }` (modules/Bar.lua `savePosition`,
from `GetPoint`); nil means the stacked default. `NS.RestoreBarPosition` anchors to `UIParent`.

### Design

- **D13. The library's Position block.** `H.PositionBlock` (OptionsCompose minor 15) composes the
  rows: **X offset** and **Y offset**, sliders on a 1 px step with AceGUI's edit box, range
  -2000 to 2000, then a **Reset position** button. A hand-written copy would be anti-pattern #73.
  Subgroup **Position**, order 50, so it runs directly after Size (10-20) and before Fill (100+).
- **D14. The rows read and write the bar's real position.** Each row keeps its path
  (`units.<unit>.position.x` / `.y`, so `/at get` and `/at set` work) and carries its own `get` and
  `set`. `get` answers the stored offset, or the stacked default's while nothing is stored, so the
  sliders show where the bar is. `set` writes the whole table, keeping the stored anchor points and
  the other axis (`CENTER`/`CENTER` and the stacked offset when nothing was stored). The rows'
  `onChange` publishes `POSITION`, so a slider moves the bar live.
- **D15. No anchor point row.** The offsets are relative to the anchor the bar already has (the
  screen's center until it is dragged; a drag can store another). An anchor dropdown would move the
  bar on every pick; the tooltip names the anchor instead.
- **D16. A drag updates the sliders.** `savePosition` refreshes the open panel's values
  (`RefreshScalars`), and so does every reset of a position.
- **D17. Reset.** **Reset position** clears the selected unit's position (back to its stacked
  default). The Appearance page's **Defaults** clears every unit's position too, and its tooltip
  says so; `/at resetposition` and General's Reset Position are unchanged. Each row's `default` is
  its axis of the stacked default, read when asked (the step follows the player bar's height), and
  a write that lands the bar exactly on its stacked default at the screen's center clears the
  position instead of storing it, so a reset leaves the bar following the stack. (Amended during
  ATF-03: the first draft gave the rows no default, which the schema's own rule, every stored row
  declares one, refuses.)
- **D18. Linked units.** A linked unit's tabs are replaced by the hint, rows included, and the
  Position rows go with them, as the brief asks: the page's existing behavior. A linked bar is still
  placed by dragging it or by `/at set`; position was never part of the link.
- **D20. A drag and a reset go through the schema seam** (architecture-§5, "a row wins": a drag
  that writes a field a row addresses is a schema-row write). Once the rows address the offsets,
  the position is a preference, not named non-setting state. A drop sets the anchor in place
  (`Units.SetAnchor`, the one part no row addresses) and writes both offsets with `NS.SetByPath`
  inside one bracket; a reset sets the anchor to the center and applies both rows' defaults. Inside
  a bracket the rows do not publish `POSITION`; the act's owner does once. (Added during ATF-03.)
- **D19. Both clients.** Nothing here reads a client-specific API; the suite runs under both kit
  profiles.

## Out of scope

No version bump, no README Version History entry, no change under `libs/` or `tests/_kit/`.
