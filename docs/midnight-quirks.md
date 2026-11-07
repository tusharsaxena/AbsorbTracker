# Midnight quirks — WoW retail API gotchas

This file has two parts: the collection's client-quirks catalog, vendored whole from the Ka0s WoW Addon Standard between the markers below and never edited here, and then this addon's own quirks under `## AbsorbTracker-specific quirks`.

<!-- BEGIN VENDORED: quirks catalog v2.103.1 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into every addon's `docs/midnight-quirks.md` (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Client quirks

The client behaviors the collection paid for more than once. Each entry here was discovered
**independently in two or more Ka0s repositories**, written up in each, and promoted by a harvest so the
next addon reads it instead of rediscovering it. A behavior one repo found stays in that repo's
`docs/midnight-quirks.md` until a second repo meets it.

*Why this section exists.* By 2026-11-06 eleven addons kept a private `docs/midnight-quirks.md`, 2,073
lines and about 133 entries between them, and about 81 of those entries were 21 behaviors written up
independently two to eight times. Nine of the eleven opened with their own restatement of the 12.0 secret
rules. Three write-ups contradicted this standard, and one contradiction was this standard's own error
(events-frames-taint-§2, *The combat-start edge*). A catalog was proposed and deferred twice, on
2026-08-25 and 2026-09-22, because an inventory rots; the build stamp per entry (§1) is the answer to that
objection (WowAddonStandards `harvests/2026-11-06/02_FINDINGS.md`, F3-01; every write-up quoted in
`harvests/2026-11-06/03_EVIDENCE.md`, Part A).

### 1. How an entry is written, and how it expires (MUST)

Every entry **MUST** carry:

- **The behavior**, stated as what the client does, not as advice.
- **Measured:** the client build or date it was observed on, where any write-up recorded one. An entry with
  no measurement says *not measured*; that is a weaker entry, not a missing field.
- **Cost:** what happened to an addon that did not know it.
- **Client:** the client it was measured on, `Retail` or `Forever` (clients-§1). An entry that names none is a Retail entry, which is every entry written before v2.103.0; a Forever behavior is written with `Forever` and its build, and it is not assumed to hold on Retail.
- **Do:** the workaround, as a rule an addon can follow.
- **Source:** the deepest write-up — the repo and document that probed furthest — and the harvest that
  promoted it. Every version is quoted in that harvest's `03_EVIDENCE.md`.

**Expiry.** An entry describes a client, and clients move. When the retail interface number moves past the
newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a standard
release — not worked around in the addon. An entry nobody can reproduce moves to §6 as an open probe rather
than being deleted, because the behavior may only have moved.

**What an addon does with this section (MUST): carry it as a vendored block.** This section is the one
part of the standard an addon carries a **copy** of, because it is reference data about the game client
that a working addon needs offline, next to the code that works around it — not a rule, which is only ever
pointed at. Every addon's `docs/midnight-quirks.md` (documentation-§3) is two parts: the vendored block,
opened by a `BEGIN VENDORED` HTML comment naming the catalog's version and source and closed by an
`END VENDORED` HTML comment, each spelled exactly as `/dev-copilot:wow-revendor-standards` writes it; then
the addon's own section. The markers are described here rather than shown, because this text travels
inside them: a literal marker in the vendored copy would give the file a second end marker for the next
re-vendor to cut at.

```markdown
[the BEGIN VENDORED comment, stamped quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own quirks: one no second repo has met, its per-event costs, its own probe tables …
```

- The block is **copied whole and replaced wholesale** by `/dev-copilot:wow-revendor-standards`, stamped with
  the standard version it came from, under the same discipline as `libs/LibKa0s/` (anti-pattern #45): never
  a subset, **never edited inside the markers**. A local edit inside them is reverted by the next revendor,
  and the behavior it fixed comes back with no cause in the addon's history; a correction belongs in the
  addon's own section, where the next harvest finds it.
- The addon's own section **MUST NOT** restate a behavior the block carries. When a harvest promotes an
  entry, the revendor prunes the addon's copy: the upstream entry is the deeper write-up, and two live
  copies of one finding is the shape that drifted three times into contradiction.
- An addon with no quirks of its own still carries the block, with an empty own section.

**Contested behaviors are not rules.** Where two repos recorded opposite behavior and nobody has probed
the difference, the entry goes in §6 with both sides and the probe that would settle it.

Behaviors this standard already states elsewhere are not repeated here: the unknown-event raise
(events-frames-taint-§1), `Settings.OpenToCategory`'s numeric ID and collapsed parent (options-ui-§2),
the protected category switch in combat (options-ui-§2, anti-pattern #88), a secret through `tostring` and
`..` (events-frames-taint-§8), lockdown at `PLAYER_REGEN_DISABLED` (events-frames-taint-§2), the spec
readers' move to `C_SpecializationInfo` (compat, `LibKa0s-Compat-1.0`) and `SendChatMessage`'s move to
`C_ChatInfo` (compat).

### 2. Secret values

**A secret boolean cannot be tested at all.** `if`, `not`, `==` and `and`/`or` on a secret boolean raise
("attempt to compare … (a secret boolean value)"); the value is unusable in Lua, not merely unprintable.
`DurationObject`'s `HasExpired`, `HasStarted`, `IsActive` and `IsZero` come back secret in combat, and an
engine button's `IsShown` has answered a secret boolean out of combat. *Measured:* 12.0.7 (probe table);
12.1 (`IsShown`). *Cost:* a raise on every refresh tick of the path that tests it. *Do:* check
`issecretvalue` before any test; route a secret boolean to a C-side consumer
(`C_CurveUtil.EvaluateColorValueFromBoolean`, `SetAlphaFromBoolean`), or treat it as the cautious answer
(a secret lockdown reads as locked, a secret restriction as active, a secret claim as no claim). Two repos
disagree on whether to gate before the C-side call; that disagreement is recorded in `LibKa0s`
`docs/api/Compat` and is not ruled here. *Source:* KickCD `docs/midnight-quirks.md`, "Secret booleans are
unusable"; seven repos (harvest 2026-11-06, Q6).

**A secret cannot be a table key.** Indexing or assigning with a secret key raises "attempted to perform
indexed assignment on a table that cannot be indexed with secret keys". `UnitGUID` on a follower-dungeon
pet (`party3pet`) answers a secret string. *Cost:* a raise on every refresh tick for a roster keyed by
GUID. *Do:* guard a key with `IsSafeKey` (`LibKa0s-Compat-1.0`) or `issecretvalue` before keying; a
secret GUID is never a handle. *Source:* MultiMeters `docs/midnight-quirks.md`, the follower-dungeon pet
GUID; seven repos (Q7).

**A secret never reaches SavedVariables, and one that does is written as `nil`.** A value captured as
secret stays secret after combat ends, and the client writes a secret to SavedVariables as `nil` — or,
where it was a key, loses the entry. *Measured:* a reload probe, 2026-10-25. *Cost:* silent data loss on
the next reload. *Do:* store a plain value or nothing; never store a captured secret to read later.
*Source:* DpsRace `docs/known-limitations.md`, the reload probe; three repos (Q21).

**A frame handed a secret has secret geometry, and so does everything anchored to it.** After
`StatusBar:SetValue(secret)` (or `SetAlphaFromBoolean`, or anchoring to an aura engine container) the
frame `HasSecretValues`: its width, points and frame level read secret, out of combat too, and the
taint runs down the anchor chain to every frame anchored to it; a tooltip showing hidden information has
secret geometry. A secret size's `type` is `"number"`, so a type check lets it through, and
`BackdropTemplate`'s own arithmetic on a secret size raises. *Cost:* a raise inside Blizzard code, or a
layout computed from a secret. *Do:* compute layout from configuration and never read geometry back from a
frame that was handed a value; keep a record of the alpha you set rather than calling `GetAlpha()`; read a
frame level under a restricted anchor through a secret-safe guard (frame-layering). *Source:* AuraMaster
`docs/midnight-quirks.md`, the aura engine container entries (measured and dated); six repos and
`LibKa0s` `docs/api/Widgets` (Q8).

**A restricted spell's cooldown: branch on `isActive`, paint with the duration object.** In a restricted
state `C_Spell.GetSpellCooldown`'s timings are secret while `isEnabled` and `isActive` stay plain
(documented NeverSecret). `GetSpellCooldownDuration` answers a **zeroed** object, not `nil`, when there is
no cooldown, and a fresh object per call. *Cost:* raw `SetCooldown` with a secret start or duration raises;
a nil check passes the zeroed object. *Do:* decide from `isActive`; paint with
`Cooldown:SetCooldownFromDurationObject`, which accepts the object from tainted code. *Source:* KickCD
`docs/midnight-quirks.md`, the cooldown probe table; four repos (Q9).

**`notInterruptible` is secret, and the interruptibility events make it plain.** The cast info's
`notInterruptible` is secret; `UNIT_SPELLCAST_INTERRUPTIBLE` / `_NOT_INTERRUPTIBLE` deliver it plain.
`CastingBarFrameTemplate`'s built-in `OnUpdate` compares `GetTime()` with a secret `maxValue` and raises
when the bar shows another unit. *Do:* split the gate — the color path takes the secret C-side, the logic
path takes the event's plain value; do not inherit `CastingBarFrameTemplate` for a unit other than the
player. *Source:* KickCD `docs/midnight-quirks.md`, "split the gate in two"; two repos (Q13).

**`InChatMessagingLockdown` can answer a secret.** *Do:* read it through a guard and treat a secret as
locked. *Source:* DropWatcher and QuickComms `core/Compat.lua` (byte-identical), DpsRace; three repos (Q27).

### 3. Events

**A valid event can register without complaint and never fire.** `GUILDBANKFRAME_OPENED` registers and
never fires (*Measured:* 12.0.7); `UNIT_SPELLCAST_SUCCEEDED` is suppressed for protected interrupts;
`UNIT_HEALTH` and `UNIT_NAME_UPDATE` never fire for compound tokens such as `party1target`;
`GET_ITEM_INFO_RECEIVED` does not fire for an item already cached. This is the inverse of the
unknown-event raise (events-frames-taint-§1) and it is silent: nothing errors. *Cost:* a feature that
never runs, with nothing in the log. *Do:* confirm a new event fires in game before building on it, and
prefer an edge with a second source (a frame's `OnShow`, a gated timer) where the event is known to be
silent. *Source:* BankLedger `docs/midnight-quirks.md`, `GUILDBANKFRAME_OPENED`; four repos (Q20).

**Client state can lag its own event, or change with no event at all.** `IsMounted()` has flipped by the
time `PLAYER_MOUNT_DISPLAY_CHANGED` arrives while `C_PlayerInfo.GetGlidingInfo`'s `canGlide` sometimes has
not; after `INSPECT_READY` some slots still answer an item id with no link; switching bank tabs fires no
event, and the live warband tab has taken over a second to catch up; chat lockdown clears with no event.
*Cost:* a read at the edge answers the old state, and the display stays wrong until the next unrelated
event. *Do:* answer at the edge **and once more after a short settle** (a fraction of a second, a bounded
retry), never a poll. *Source:* MultiMeters `docs/midnight-quirks.md`, "some client state lags its own
event"; six repos (Q19).

**An empowered cast fires `UNIT_SPELLCAST_EMPOWER_*`, not the channel events.** `UnitChannelInfo`
reports it, but `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` do not fire for it, and its release fires
`UNIT_SPELLCAST_SUCCEEDED` with the same cast GUID. *Do:* register the `EMPOWER_*` events wherever channels
are tracked. *Source:* KickCD `docs/midnight-quirks.md`, empowered casts; three repos (Q12).

**`ADDON_RESTRICTION_STATE_CHANGED` fires *before* enforcement.** The `Activating` state arrives before the
restriction begins, and access is still permitted during that dispatch; a dungeon restriction type has
gone active on entry and not cleared. Read the restriction type by its `Enum.AddOnRestrictionType` member
name — a member can be missing on some builds. *Measured:* 12.1.0, 2026-09-18. *Do:* treat `Activating`
as the last moment to read, not as the start of the restriction. The payload's second argument is
contested (§6). *Source:* AuraMaster `docs/midnight-quirks.md`, the restriction types; six repos (Q10).

### 4. Combat and secure frames

**Blizzard's aura buttons are forbidden to addon code, and `IsForbidden()` can say otherwise.** In
combat every call on a Blizzard aura button's objects raises "Attempt to access forbidden object from code
tainted by an AddOn"; in an instance (seen in Mythic+) the same buttons answer `IsForbidden()` `false` and
still refuse every read, `GetChildren` included. *Do:* never read Blizzard aura buttons; where a frame
must be inspected, `pcall` the read and treat a failure as forbidden. *Source:* PartyFrameEnhanced
`docs/midnight-quirks.md`, forbidden aura buttons; three repos (Q14).

**Escape runs a protected `Hide()` in combat.** A secure or protected frame listed in `UISpecialFrames` is
hidden by `CloseSpecialWindows`, which is a protected action in combat. *Do:* list a non-secure proxy in
`UISpecialFrames` and hide the protected frame from it out of combat, or keep protected frames out of the
list. *Source:* WhatGroup `docs/midnight-quirks.md`, the escape proxy; two repos (Q24).

### 5. Item, tooltip, enum and realm data

**Item data is nil until cached, and the load event has holes.** `GetItemInfo` answers nothing for an
uncached item; `GET_ITEM_INFO_RECEIVED` does not fire on an addon's first scan for an item the client
already holds; an uncached item's tooltip is not empty but a legible `RETRIEVING_ITEM_INFO` line; a failed
load drops its wait and nothing asks again. *Cost:* a blank or wrong row that never repairs. *Do:* load
through `LibKa0s-Item-1.0`'s cache-then-callback path (library-stack-§7), treat `RETRIEVING_ITEM_INFO` as
not-yet-loaded, and re-ask after a failed load. *Source:* ConsumableMaster `docs/midnight-quirks.md`, the
first-scan hole; seven repos (Q15).

**`C_TooltipInfo` returns raw templates.** Tooltip lines can carry the unexpanded plural grammar
`|4singular:plural;` (*Measured:* 12.1.5, "for the next 3 |4hour:hrs; 49 min") and a no-break space that
Lua's `%s` does not match. *Cost:* a parser that knew only the expanded words read no duration and called a
tradeable drop expired. *Do:* expand `|4…;` before matching, and match the no-break space explicitly.
*Source:* DropWatcher `docs/midnight-quirks.md`, the trade window; two repos (Q16).

**Tooltip line text can be secret** under an addon restriction, including through `TooltipDataProcessor`.
*Do:* guard each line before matching. *Source:* DropWatcher `docs/midnight-quirks.md`; two repos (Q17).

**Blizzard renumbers enums; resolve a member by name, never by number.** One build's
`Enum.TooltipDataLineType` and bank-tab values are not the next build's, and a member can be absent on a
build. *Cost:* a numeric guess for a member the build does not expose landed on an unrelated bank
container. *Do:* read `Enum.X.Member`, and handle its absence; localization-§4 already forbids the string
spelling. *Source:* DropWatcher `docs/midnight-quirks.md`, the research's enum values; five repos (Q18).

**`GetNormalizedRealmName` is nil early in login.** *Cost:* a stored `Name-` key with no realm. *Do:* never
build a `Name-Realm` key before the realm is known; defer, or fall back to `GetRealmName` with its spaces
and hyphens removed. *Source:* DropWatcher `docs/midnight-quirks.md`, realm names; four repos (Q25).

**A template-less `FontString` with no font raises on `SetText`.** "Font not set" from a `FontString`
created without a template or `SetFontObject` takes the addon down at load; a mock that does not enforce it
passes every test. *Do:* give every bare `FontString` a font object before its first `SetText`; the kit's
mock enforces it. *Source:* MultiMeters `tests/mock_frame.lua`, the font-not-set guard; three repos and
`LibKa0s` (Q22).

### 6. Open probes — contested behaviors (not rules)

Each needs an in-game probe, recorded with the build, before any section of this standard changes.

- **WoW Forever behaviors (none recorded yet).** The catalog was written on Retail. The Forever client (build 70790) has a missing-API surface, `SetDesaturation` among it, that LibKa0s tracks in LibKa0s#44, and no quirk entry yet meets this section's two-repo bar for it. Record a Forever behavior in the repo that meets it, with the build, and promote it by a harvest like any other.

- **`string.format` on a secret.** events-frames-taint-§8 says it raises, with three repos; two say it
  works, one with a mid-combat observation. The likely difference is the specifier (`%s` against `%d` and
  `%.1f`) or that the result is itself a secret string. Probe each specifier, in combat, on a damage-meter
  value and a `UnitHealth` value. Until then §8's rule stands.
- **`ADDON_RESTRICTION_STATE_CHANGED`'s second argument.** One repo documents an
  `Enum.AddOnRestrictionState` value; three (one measured) record a boolean as well. Handle both shapes.
  The 2026-09-22 harvest called this settled, and it is not.
- **`SetAllPoints(parent)` on a secure button at load.** One repo records "Cannot anchor protected frames
  to regions" and uses the implicit-parent form; another anchors its secure rows with `SetAllPoints(row)`
  at birth and treats it as working, with its in-game smoke check still owed.
<!-- END VENDORED -->

## AbsorbTracker-specific quirks

Catalog of WoW Midnight (Interface 12.x) behaviors and Blizzard-API conventions that bite the addon. When something breaks at patch time, this is where to look first.

## Secret values from `UnitGetTotalAbsorbs`

`UnitGetTotalAbsorbs("player")` may return WoW's opaque-token "secret" value in combat (and for very large absorb amounts). Lua cannot compare a secret value with a number (`tonumber()` returns nil; `>` / `<` against a number errors).

- **Use `AbbreviateNumbers()` for display.** It accepts secret values directly and returns a formatted string (`"123K"`, `"1.2M"`). Never run the result of `UnitGetTotalAbsorbs` through `tonumber` before display — you'll lose the value.
- **Pass the raw value into `statusBar:SetValue` and `statusBar:SetMinMaxValues`.** Engine-side widget APIs accept secret values directly. This is what `NS.UpdateAbsorbBar` (`modules/Display.lua`) does: it reads the absorb amount, formats the text via `AbbreviateNumbers`, and pushes the raw value into the StatusBar without any Lua-side comparison.

### A secret survives `tostring()` **and `..`**, but **explodes in `table.concat`**

The subtle trap: `AbbreviateNumbers(secretValue)` returns a *secret string*, not a plain one. A secret string passes through `tostring()` unchanged, **and the `..` operator does not raise on it either** — `secret .. ""` silently returns another secret string. What *does* raise is `table.concat`:

```
invalid value (secret) at index N in table for 'concat'
```

This asymmetry is the whole gotcha, and it shapes the debug-logging design (`debug-logging-§8` / `debug-logging-§9`). The single debug sink, `NS.Debug(tag, fmt, ...)` (`LibKa0s-DebugLog-1.0`, `libs/LibKa0s/DebugLog.lua`, vendored — `core/DebugLogSetup.lua` hands it `NS.SafeToString` as the descriptor's `safeToString` hook and publishes the result under the name the call sites already use), routes every vararg through `NS.SafeToString` then `fmt:format(...)`, so no call site can be killed by a secret — but the *hot path* is also **coalesced** (`debug-logging-§9`): `OnAbsorbChanged` (`core/AbsorbTracker.lua`) and `UpdateAbsorbBar` (`modules/Display.lua`) no longer log a line per absorb event / per repaint. They bump debug-gated counters (`dbgAbsorbEvents`, and `NS.NoteRepaint()`'s `dbgRepaints`), and `OnLeaveCombat` flushes one `[Combat] left: N events, M repaints` rollup at combat end.

Value transitions are still logged live, but only when safe: `[Absorb]` (shield up/gone) fires in `OnAbsorbChanged` only when `NS.IsConcatSafe(value)` is true — i.e. out of combat, where the value is a plain number, not a secret. **In combat the absorb value IS secret**, so `[Absorb]` transitions don't fire, and the `[Combat]` rollup's `final=<value>` field is likewise appended only when the post-combat read is concat-safe; otherwise the rollup degrades to counts only (`[Combat] left: N events, M repaints`, no `final=`). This is the accepted WoW 12.0 constraint, not a bug — a secret value simply cannot be rendered.

The guard lives at the concat boundary, not the call sites: `NS.SafeToString` substitutes the sentinel `"<secret>"` (Core's `lib.SECRET`, published as `NS.SECRET` for the addon's own secret-safe readouts) for any value that a real `table.concat` would reject. **The algorithm is not this addon's any more** — it is `LibKa0s-Core-1.0` (`libs/LibKa0s/Core.lua`, vendored), because it was identical in every Ka0s addon and wrong in slightly different ways in several of them; `core/CoreSetup.lua` takes `NS.SafeToString` / `NS.IsConcatSafe` straight off the library (with the pre-library implementations kept as the fallback for a missing vendored lib), and the library's own suite is where the detector is proved. The reasoning below is unchanged, and is why the library does it this way. Detection **must probe `table.concat`, not `..`** — `NS.IsConcatSafe(v)` runs `pcall(function() return table.concat({ v }) end)`, because a probe built on `..` reports a secret as *safe* (the operator propagates instead of raising) and lets it slip straight through to the real concat. Both `NS.Print` (chat) and `NS.Debug` (console) route every arg through `SafeToString`, so no addon line can be killed by a secret even outside the coalesced hot path. `nil`/`boolean` are handled up front (they are never secret but `table.concat` rejects them too). All debug work remains gated behind `NS.State.debug` so the probe cost is zero when debug is off.

**Rule of thumb:** never feed a value read from a combat-protected API into `..`, `table.concat`, or `string.format`. Hand it straight to an engine-side widget/`AbbreviateNumbers` for display, or run it through `NS.SafeToString` before it touches a string operation.

## `SetBackdrop` is a no-op when the table identity is unchanged

WoW's `Frame:SetBackdrop(info)` ignores the call when `info` is the same table identity as the previously-set backdrop, *even if its fields changed*. AbsorbTracker reuses one `backdropInfo` table per bar (`NS.bars[unit].backdropInfo`, built at file load in `modules/Bar.lua`) to avoid GC, mutates its fields in `NS.UpdateBarAppearance` (`modules/Display.lua`), and then calls:

```lua
bar:SetBackdrop(nil)            -- force-clear
bar:SetBackdrop(backdropInfo)   -- re-apply with current fields
```

Don't try to "optimize" by skipping the `SetBackdrop(nil)`. The backdrop will look stale until the next `/reload`.

## `InCombatLockdown()` lags `PLAYER_REGEN_DISABLED` — use `UnitAffectingCombat` for the visibility gate

The `visibility` bar-visibility gate (`NS.ShouldShowBar`, `modules/Display.lua`) must key off `UnitAffectingCombat("player")`, **not** `InCombatLockdown()`. It was the `showOnlyInCombat` boolean when this was found; schema v5 replaced that with the four-value dropdown, and its `inCombat` / `outOfCombat` arms inherit the same rule.

`InCombatLockdown()` reports the *secure-frame lockdown* state, which is a distinct thing from "the player is in combat" — and in this client the two are not simultaneous at the entering-combat edge. When `PLAYER_REGEN_DISABLED` fires (`addon:OnEnterCombat`), `InCombatLockdown()` still returns **false**; secure lockdown engages a fraction of a second later. Debug capture of the transition:

```
[OnEnterCombat] fired | InCombatLockdown: false
[ApplyVisibility] decision: HIDE | InCombatLockdown: false | visibility: inCombat
[UpdateAbsorbBar] Absorb: <secret> | MaxHP: 734K   ← same second, now NOT skipped → lockdown flipped true
```

Gating on `InCombatLockdown()` therefore hid the bar at the exact moment it should appear: `OnEnterCombat`'s `NS.ApplyVisibility()` read the stale `false` and called `bar:Hide()`. The bar never recovered for the rest of the fight, because the repaint path (`NS.UpdateAbsorbBar`) only updates the bar's *value* — it never re-runs the show/hide decision — so nothing re-showed the frame once lockdown flipped true. Absorb values kept painting underneath a hidden frame.

`UnitAffectingCombat("player")` is true from the instant combat starts (already true at `PLAYER_REGEN_DISABLED`) and false at `PLAYER_REGEN_ENABLED`, which is exactly the predicate a *display* gate wants. The bar is a plain, non-secure frame, so this query carries no taint concern.

**Rule of thumb:** `InCombatLockdown()` answers "are secure actions locked?" (use it to gate protected API calls like `Settings.OpenToCategory` — here, to *refuse* the panel open, below). `UnitAffectingCombat("player")` answers "is the player in combat?" (use it for display/visibility logic). They are not interchangeable at the combat-entry edge.

## Combat lockdown taints `Settings.OpenToCategory`

`Settings.OpenToCategory(categoryID)` is part of the protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI behavior.

`NS.OpenOptionsPanel` (`settings/OptionsSetup.lua`) is a one-line delegate to `LibKa0s-Options-1.0`'s `O.OpenOptionsPanel` (`libs/LibKa0s/Options.lua`), which therefore **refuses** the open when `InCombatLockdown()` is true, per Ka0s standard options-ui-§2 (refuse-with-notice, *not* defer-and-replay). It emits a `Cfg` debug line, prints a single gray, `[AT]`-tagged notice, and returns — it never calls the protected `Settings.OpenToCategory` under lockdown, and never queues the open. Out of combat it guards `Settings.OpenToCategory` and the captured `mainCategoryID` before opening, then expands the tree.

The refusal string is `lib.STRINGS.COMBAT_REFUSED`, byte-fixed by options-ui-§2:

```
|cffaaaaaacannot open settings during combat \226\128\148 Blizzard's category-switch is protected|r
```

(The em dash is a byte escape, so no editor between the library and a client can break it. The line reaches chat through the descriptor's `print` hook — `settings/OptionsSetup.lua` points it at `NS.Print` — so it still carries the cyan `[AT]` prefix; the message body is gray, hex `aaaaaa`. This catalog deliberately quotes the string and not the function body: a quirks file quoting a code body it does not own is exactly how the next drift starts.)

The gate lives **inside** `OpenOptionsPanel` (not just the `/at config` slash dispatcher), so every caller — the slash verb, `/run` scripts, any future internal caller — is refused. The house behavior is an explicit, greppable refusal rather than a panel that auto-opens the instant combat ends and steals focus during post-pull recovery; the user re-runs `/at config` when they choose. `addon:OnLeaveCombat` (`core/AbsorbTracker.lua`) now only re-applies visibility and repaints — there is no combat-deferred open to replay. (This reverses the earlier defer-and-replay behavior, which conformed to the pre-v1.10.0 options-ui-§2. A deferred **secure frame write** may legitimately still queue on `PLAYER_REGEN_ENABLED` (per the standard's events-frames-taint-§2), but a taint-prone *protected* path like the category-switch must not be touched at all under lockdown.)

## `Settings.OpenToCategory` wants a numeric ID, not a category object

`Settings.RegisterCanvasLayoutCategory(panel, name)` returns a category *object* with a `:GetID()` method; `Settings.RegisterCanvasLayoutSubcategory(parent, panel, name)` returns the same shape. `Settings.OpenToCategory` accepts the numeric ID directly — passing the object produces a range error.

`libs/LibKa0s/Options.lua` captures `mainCategory:GetID()` at parent registration into `mainCategoryID`; `OpenOptionsPanel` calls `Settings.OpenToCategory(mainCategoryID)` so `/at config` always lands on the parent (about page) and then calls `expandMainCategory()` to expand the sub-page tree so every sub-page is visible at once. `expandMainCategory` reaches into `SettingsPanel:GetCategoryList()` private API; the whole call is wrapped in `pcall` so a future Blizzard refactor that renames or removes those internals degrades gracefully (the panel still opens, the tree just doesn't auto-expand).

## Interface line — track both clients' builds

`AbsorbTracker.toc` declares two build numbers, Retail's first and WoW Forever's second (toc-file-§3):

```
## Interface: 120105, 16001
```

Each value is `(major * 10000) + (minor * 100) + patch` for that client's Live patch: Retail Midnight 12.1.5 and Forever 1.60.1. Each client picks the number that matches it. **When either client ships a patch, replace that client's number** (`/dev-copilot:wow-bump-interface` bumps them per client) so the addon reads as up to date in that client's AddOn list, and move the README `[wow]` badge in the same change.

If a patch breaks the addon, note the regression in the README's troubleshooting section.

## `BackdropTemplate` is mandatory for backdrop frames

WoW retail (10.0+) split backdrop functionality off the base Frame and into the `BackdropTemplate` mixin. Frames that need `SetBackdrop` / `SetBackdropColor` / `SetBackdropBorderColor` must declare the template at creation:

```lua
CreateFrame("Frame", "AbsorbTrackerFrame", UIParent, "BackdropTemplate")
```

`modules/Bar.lua` does this for the bar. The vendored `LibKa0s` windows carry it too — `libs/LibKa0s/DebugLog.lua` (the console and its Copy window) and `libs/LibKa0s/PerfPanel.lua` (the step panel) all pass `"BackdropTemplate"` at `CreateFrame`, because `LibKa0s-Core-1.0`'s `ApplySkin` calls `SetBackdrop` on them. (`libs/LibKa0s/Options.lua`'s settings canvases do **not** — they never set a backdrop; Blizzard draws that panel.) If a future custom widget needs a backdrop and forgets the template, the addon will error on `SetBackdrop`.

## Class color sources

Two different paths for the same concept:

- **Bar / border** use `C_ClassColor.GetClassColor(classFile)` directly — Blizzard's official class-color API, returns a `ColorMixin` with `:GetRGBA()`.
- **Background** uses a hard-coded per-class table multiplied by `0.2` to produce a darkened variant. The per-class table mirrors WoW's official class colors (DEATHKNIGHT through WARRIOR); the result is cached in `playerBgClassColor` since the player class doesn't change at runtime.

Why the asymmetry: a bar fill at full class brightness atop a background also at full class brightness washes out the value text. The 0.2 multiplier on the background keeps the absorb fill readable. Picking a fixed darken factor was preferred over computing a perceptually-uniform delta because the result is independent of which class the player is — every class gets the same readability profile.

Both paths resolve at *call* time inside `NS.GetBarColor` / `NS.GetBgColor` / `NS.GetBorderColor` (`core/Data.lua`). Class change / respec / profile switch all "just work" without explicit refresh wiring — the next paint reads the current toggle and produces the right color. See [scope.md](./scope.md#resolved-decisions).

## `UNIT_ABSORB_AMOUNT_CHANGED` fires often during heavy combat

The event can fire many times per second during raid encounters with stacking absorbs (Power Word: Shield + trinket procs + Discipline absorbs + …). The `OnAbsorbChanged` handler in `core/AbsorbTracker.lua` bumps a counter rather than logging a line per event, and logs only on the up/gone transitions — and those go through `NS.IsConcatSafe` first, because a raw combat value can be a secret and an unrenderable one is dropped rather than printed. It then publishes the `REPAINT` message on the bus — it does not repaint directly. `modules/Timer.lua` owns the sole `REPAINT` subscriber and funnels it through `NS.RequestRepaint()` (below), so a burst of events can't over-render the StatusBar and the string-format calls.

`NS.RequestRepaint()` (`modules/Timer.lua`) is the coalescing repaint scheduler and the source of truth for visual updates. It runs on **AceTimer** — a trailing-edge one-shot: if a repaint is already queued, further calls are a no-op; otherwise it schedules `NS.addon:ScheduleTimer(NS.UpdateAbsorbBar, throttleWindow)` (Ka0s standard library-stack-§1 — a one-shot AceTimer, not a raw `C_Timer`), which self-clears once it fires. `throttleWindow` is user-configurable (0.05 – 1 s; default 0.1 s). There is no repeating ticker and no polling — idle = zero repaints. See [data-flow.md](./data-flow.md#absorb-update-path).

## When an event you depend on gets removed in retail

If Blizzard removes an event the addon listens for (it has happened in past retail patches — `LEARNED_SPELL_IN_TAB` was replaced by `LEARNED_SPELL_IN_SKILL_LINE`), the name becomes one the client does not know, and **registering an unknown name raises** — `Attempt to register unknown event "<NAME>"` (events-frames-taint-§1). A block of bare `RegisterEvent` calls then loses every line after the one that raised, so one retired event would take the whole enable path down with it.

That is why every registration here goes through LibKa0s-Core's `SafeRegisterEvent` / `SafeRegisterUnitEvent` (published as `NS.SafeRegisterEvent` / `NS.SafeRegisterUnitEvent` by `core/CoreSetup.lua`). The helper front-gates the name with `C_EventUtils.IsEventValid` where the client has it (falling back to a private probe frame), then `pcall`s the registration, so a refused name costs only itself. The refused name is appended once to the session list `NS.State.rejectedEvents`, logged on the `Events` debug tag, counted in the `[Init]` summary, and printed by `/at debug events`. The degraded stub (library absent) keeps the `pcall` and the list, without the front gate.

AbsorbTracker listens for `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` (on one private `RegisterUnitEvent(event, unit)` frame per unit — player, target and focus each get their own — the events-frames-taint-§1 unit-filter carve-out, see ([ARCHITECTURE.md → Event Subscriptions](./ARCHITECTURE.md#the-per-unit-frames-are-the-unit-filter-carve-out))) and `PLAYER_ENTERING_WORLD` / `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` / `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` (AceEvent, through the helper), all from `addon:OnEnable` via `RegisterLifecycleEvents` and `SyncUnitEventFrames` (`core/AbsorbTracker.lua`), plus the AceAddon lifecycle events `ADDON_LOADED` → `OnInitialize` and `PLAYER_LOGIN` → `OnEnable` — all stable retail events. If a future patch deprecates one, the replacement should be wired by patching the registration in `core/AbsorbTracker.lua`; nothing else needs to change.
