# Forever quirks — Ka0s Absorb Tracker

This file has two parts: the collection's Forever quirks catalog, vendored whole from the Ka0s WoW Addon Standard between the markers below and never edited here, and then this addon's own WoW Forever quirks under `## AbsorbTracker-specific quirks`. Ka0s Absorb Tracker ships on Retail and WoW Forever (clients-§2), so it carries this file beside `docs/midnight-quirks.md`, which holds the Retail catalog and this addon's Retail and both-client quirks.

<!-- BEGIN VENDORED: forever quirks catalog v2.117.0 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into the `docs/forever-quirks.md` of every addon that ships on WoW Forever (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Forever quirks

The WoW Forever catalog: the client behaviors the collection has measured **on WoW Forever** (clients-§1),
each written up so the next addon reads it instead of rediscovering it. It is the Forever counterpart of
client-quirks, which is the **Retail** catalog. The two are kept apart because an addon that ships on one
client needs only that client's catalog, and because a behavior measured on one client is not assumed to
hold on the other.

*Why this section exists.* Through v2.116.0 the collection had one catalog, client-quirks, written on
Retail, and one Forever entry inside it (the two-word names, now §4). Ka0s Skill Master, Forever-only
since v2.105.0 (clients-§9), carried that Retail catalog whole in its `docs/midnight-quirks.md` and had
nowhere upstream to put what it measured on Forever: on 2026-11-10 (build 70862) the client answered a
secret number and refused an aura read, the Retail secret-value rules measured again on the other client.
The owner's ruling of 2026-11-10 split the catalog per client, one file per client an addon ships on
(SkillMaster `docs/superpowers/plans/2026-11-10-feedback-1.md`, *Owner decisions*).

### 1. How an entry is written, promoted and vendored (MUST)

**The entry shape is client-quirks-§1's**, unchanged: the behavior, *Measured*, *Cost*, *Client*, *Do*
and *Source*. Every entry here is *Client:* Forever, stamped with the client version and build it was
measured on (`1.60.1, build 70862`). A Forever entry is not assumed to hold on Retail, and a Retail entry
is not assumed to hold on Forever until §2 says it was measured here.

**Promotion (MUST).** An entry enters this catalog by a harvest, under one of two bars:

- **An engine behavior the Retail catalog already carries** enters on **one** repo's measurement on
  Forever. The two-repo bar was met when the behavior was first promoted; what the Forever measurement adds
  is the fact that the same engine does it here. The entry names the Retail entry it repeats
  (the client-quirks subsection, cited by its number) and adds the Forever build, call and error text, never a second copy of the Retail
  write-up.
- **A behavior new to Forever** needs **two** repos that met it independently, as client-quirks-§1
  requires. A behavior one repo found stays in that repo's own section of `docs/forever-quirks.md` and is
  listed in §5 as one repo, awaiting a second.

The two-word names entry (§4) predates both bars and stands on the owner's ruling of 2026-11-08.

**Expiry.** client-quirks-§1's rule, read per client: when the Forever client version or build moves past
the newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a
standard release, not worked around in the addon. An entry nobody can reproduce moves to §5 as an open
probe rather than being deleted.

**What an addon does with this section (MUST): carry it as a vendored block in `docs/forever-quirks.md`.**
Every addon whose roster **Clients** value includes Forever (`Retail · Forever` or `Forever`, clients-§2)
carries `docs/forever-quirks.md` (documentation-§3), shaped as client-quirks-§1 describes for
`docs/midnight-quirks.md`: the vendored block, opened by a `BEGIN VENDORED` HTML comment naming the
**Forever** quirks catalog's version and source and closed by an `END VENDORED` HTML comment, each spelled
exactly as `/dev-copilot:wow-revendor-standards` writes it; then the addon's own section. The markers are
described here rather than shown, for client-quirks-§1's reason: this text travels inside them.

```markdown
[the BEGIN VENDORED comment, stamped forever quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own Forever quirks: one no second repo has met, its probe tables, its measured API shapes …
```

- The block is copied whole, replaced wholesale and never edited inside the markers, under client-quirks-§1's
  discipline. A correction belongs in the addon's own section, where the next harvest finds it.
- The own section **MUST NOT** restate a behavior the block carries, and a harvest that promotes an entry
  prunes the addon's copy.
- **One file per client.** A `Retail · Forever` addon carries both files, `docs/midnight-quirks.md` with the
  Retail catalog and `docs/forever-quirks.md` with this one, and files each own finding under the client it
  was measured on. A `Forever` addon carries `docs/forever-quirks.md` only; a `docs/midnight-quirks.md` in a
  Forever-only addon is a retired name (documentation-§3), and its own findings move into
  `docs/forever-quirks.md`. A `Retail` or `Retail (port pending)` addon carries no `docs/forever-quirks.md`.
- An addon with no Forever quirks of its own still carries the block, with an empty own section.

### 2. Which Retail entries hold on Forever

WoW Forever runs on the modern engine: it carries modern client APIs (clients-§3) alongside its
vanilla-era game data, and §3 measured its secret-value system and its taint attribution at work.
That is a reason to expect the Retail catalog's engine behaviors here, and it is **not** a measurement. Each
Retail section's status on Forever, as of build 70862:

| Retail entry | Status on Forever | Evidence |
|---|---|---|
| client-quirks-§2, secret values | **measured**: the secret-value system is live on Forever (§3) | §3, build 70862 |
| client-quirks-§2, a secret cannot be a table key; a secret written to SavedVariables as `nil`; secret geometry | **assumed**: follows from §3, not probed on Forever | none |
| client-quirks-§2, restricted spell cooldowns, `notInterruptible`, `InChatMessagingLockdown` | **assumed**, not probed on Forever | none |
| client-quirks-§3, events (silent valid events, state lagging its event, empowered casts, `ADDON_RESTRICTION_STATE_CHANGED`) | **assumed**, not probed on Forever. The instances that name a Retail-only feature (the warband bank tab, a Mythic+ observation) do not arise there, because the feature is absent (clients) | none |
| client-quirks-§4, Blizzard's aura buttons, escape and protected `Hide()` | **assumed**, not probed on Forever | none |
| client-quirks-§5, item cache, `C_TooltipInfo` templates, secret tooltip text, enum renumbering | **assumed**, not probed on Forever | none |
| client-quirks-§5, `GetNormalizedRealmName` nil early in login | **assumed**; on Forever the realm a character is keyed by is the ruleset, not this name (§4) | §4 |
| client-quirks-§5, a template-less `FontString` raises on `SetText` | **assumed**; the kit's mock enforces it under both profiles, which is not a client measurement | none |
| client-quirks-§6, the open probes | open on Forever as on Retail | none |

An *assumed* row is a working assumption: write the Retail workaround on Forever too, and record what you
see, with the build, in your own section. A measurement promotes the row to *measured* under §1's
one-repo bar.

### 3. Secret values on Forever (measured)

**`UnitStat` can answer a secret number.** *Client:* Forever (1.60.1, build 70862). *Measured:* the owner's
in-game error, 2026-11-10: inside an AceTimer callback, a comparison on the value `UnitStat("player", i)`
answered raised "attempt to compare field 'value' (a secret number value)" (the error as SkillMaster's
`tests/test_statdata.lua` records it). Whether the player was in combat is not recorded. *Cost:* a raise on every rescan of the
path that compares the stat; the stat line stops updating. *Do:* client-quirks-§2's rule: test
`issecretvalue` before any comparison or arithmetic on a stat reader's return, keep the last plain value
(marked stale) rather than the secret, and rescan on `PLAYER_REGEN_ENABLED`. The combat edge is assumed:
if the secret persists out of combat, the stale value stands until a later scan reads it plain. *Retail entry:*
client-quirks-§2, the secret-value family. *Source:* SkillMaster `docs/forever-quirks.md`, its own
section's measured findings; promoted under §1's one-repo bar for an engine behavior.

**`C_UnitAuras.GetBuffDataByIndex` can raise instead of answering a secret.** *Client:* Forever (1.60.1,
build 70862). *Measured:* the owner's in-game error, 2026-11-10: the read raised "Auras cannot be accessed
when secret while tainted by 'SkillMaster'". The call fails outright; it does not hand back a secret table
to test. *Cost:* a raise that takes down the whole scan, not one missing value, so an `issecretvalue` guard
on the return never runs. *Do:* call the aura reader through `pcall` and treat a failure as "auras are
secret now": keep the last plain list and read again after combat (the combat edge is assumed; if the
raise persists out of combat, the last list stands until a later read succeeds). *Retail entry:* client-quirks-§2, the
secret-value family. *Source:* SkillMaster `docs/forever-quirks.md`, its own section's measured findings;
promoted under §1's one-repo bar for an engine behavior.

### 4. Names and realms

**On Forever a character's name is two words, unique per region, and its realm is a long label.** *Client:*
Forever (1.60.1, build 70790). *Measured:* the owner's in-game probe of 2026-11-08 (Ka0sAddonsCommonTasks
`docs/2026-11-07-WOW_FOREVER_PORT_STEP5/W1_FOREVER_NAME_PROBE.md`). Every character has a first name and a
surname, and only the pair is unique; `RegionalUniqueNamesEnabled()` answers true. The name APIs answer:

| Call | Forever answers | Retail answers |
|---|---|---|
| `UnitName(unit)`, `UnitFullName(unit)` | `"Traxex"`, `"Silentshot"`: the **surname** second | the name, then the realm (nil on your own realm) |
| `GetUnitName(unit, true)`, `Ambiguate(…, "short")` | `"Traxex Silentshot"` | `"Name"`, or `"Name-Realm"` across realms |
| a chat event's sender (arg 2) | `"Doom Dock"`, no realm suffix | `"Name-Realm"` |
| `GetRealmName()` / `GetNormalizedRealmName()` | `"CAMWOW AU1 Realm 2 PvP"` / `"CAMWOWAU1Realm2PvP"` | the realm, with and without its spaces |
| AceDB-3.0 40's `db.keys` | `char` `"Traxex Silentshot"`, `realm` `"PvP"`, `factionrealm` `"Alliance - PvP"` | `"Name - Realm"`, the realm |

Players know a realm by its ruleset (Normal, PvP, RP-PvP), not by its label, and there is no cross-realm play to
put a realm on another player. *Cost:* `local name, realm = UnitName(unit)` reads the surname as a realm and
builds `"Traxex-Silentshot"`; a one-value `UnitName(unit)` keeps only the first name, so two characters that
share one ("Traxex Silentshot", "Traxex Ironhide") collide in a key, a filter or a roster; a surface sized for
one Retail word truncates the pair; a `Name-Realm` key built from `GetNormalizedRealmName` is unique but is
not the identity the player or AceDB uses. *Do:* read a character through `LibKa0s-Compat-1.0`'s identity readers (from `LibKa0s v1.94.0`):
`UnitCharacterName(unit)` for any unit, `CharacterKey()` and `RealmKey()` for the player, and `RegionalNames()`
for the question itself. They implement this rule. When `RegionalUniqueNamesEnabled` exists and answers true,
a character's identity is its **whole name**: `GetUnitName(unit, true)` for any unit, or
`UnitNameUnmodified("player")`'s two returns joined by a space for the player, and its realm is the
**ruleset** AceDB 40 derives from `C_GameRules` (`Hardcore`, `RP-PvP`, `RP`, `PvP`, `PvE`). The ruleset is the realm key for stored realm data too, by the owner's
ruling of 2026-11-08, so two PvP realms share one realm key. An addon whose
profile store is AceDB reads those as `db.keys.char` and `db.keys.realm` and never derives them again. That
test is feature detection inside the compat family (clients-§3, compat), never a client check in feature
code. Never read `UnitName`'s second return as a realm, never split a name on whitespace or key on its first
word, and size every surface that shows a name, a realm or a profile key for the long form, or truncate it
with the whole value in a tooltip. *Source:* the owner's ruling and probe of 2026-11-08 during the WoW
Forever port's step 5, recorded ahead of the two-repo bar by that ruling; AceDB-3.0 minor 40's key block.
Carried in client-quirks-§5 from v2.103.0 to v2.116.0, and moved here in v2.117.0.

### 5. Open probes and one-repo findings (not rules)

Each needs an in-game probe, recorded with the build, or a second repo, before it becomes an entry.

- **The missing-API surface.** The Forever client (build 70790) lacks some Retail APIs, `SetDesaturation`
  among them, which LibKa0s tracks in LibKa0s#44. Feature-detect at the call site or in the compat family
  (clients-§3) until the library's list is complete.
- **Secret values in combat on Forever.** §3's two measurements are out of a timer callback and a buff
  scan, with combat state not recorded. Whether meter values, cast spell IDs, castGUIDs and a pet's GUID are
  secret in combat on Forever is not measured; CombatTrail treats each as possibly secret, and an in-combat
  probe would settle it.
- **One repo, awaiting a second.** Each is recorded in that repo's own section of its quirks doc and
  promotes under §1 when a second repo meets it:
  - `C_SkillInfo.GetSkillLineInfo(i)` answers one table with `isCollapsed`, `rank`, `maxRank`, `modifier`,
    `skillID` and `parentSkillLineID`, not the Retail-style `skillRank` / `skillMaxRank`; none of the 1.12
    skill globals exist. *Measured:* build 70862. *Source:* SkillMaster.
  - `C_Item.GetWeaponEnchantInfo(weaponSlot)` takes an `Enum.WeaponSlot` (`MainHand` 0, `OffHand` 1,
    `Ranged` 2), raises on 16 and without one, and answers an array of records. *Measured:* build 70862.
    *Source:* SkillMaster.
  - Each profession and secondary skill is listed twice in the skill list, the vanilla line and a child line
    whose `parentSkillLineID` is the vanilla one, in either order. *Measured:* build 70862. *Source:*
    SkillMaster.
  - Registering `COMBAT_LOG_EVENT_UNFILTERED` raises `ADDON_ACTION_FORBIDDEN`, which `pcall` does not
    catch. *Measured:* build 70862. *Source:* CombatTrail.
  - `C_DamageMeter` ships whole, its two enums match Retail, and the player source's `amountPerSecond` is
    nil out of combat. *Measured:* build 70862, out of combat. *Source:* CombatTrail.
  - `Enum.ItemConsumableSubclass` keeps Retail's numbers and adds Draught 13, Device 14 and
    ItemenhancementTemporary 15, while the stones and oils report subclass 8. *Measured:* the enum is read
    from BlizzardInterfaceResources' `forever` 1.60.1 (70532) dump, not probed in game; the stones' and oils'
    subclass 8 is from the owner's item dump on build 70862. *Source:* ConsumableMaster.
<!-- END VENDORED -->

## AbsorbTracker-specific quirks

None yet. The addon's own quirks, all measured on Retail or holding on both clients, stay in `docs/midnight-quirks.md`; a behavior measured on WoW Forever that the catalog above does not carry is written here (forever-quirks-§1).
