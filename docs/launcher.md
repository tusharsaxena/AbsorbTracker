# Launcher

The minimap button and broker row: the one LDB object, the two buttons, the options menu and its
disabled state, the status tooltip, the visibility row that survives every reset, and the icon. This page was the `## Launcher` section
of [ARCHITECTURE.md](./ARCHITECTURE.md) until the hub was brought back under documentation-§3's spill
rule; `core/LauncherSetup.lua`'s place among the setup seams is in [module-map.md](./module-map.md).

## One object

`core/LauncherSetup.lua` owns it, and there is **one object**: a single LibDataBroker-1.1 table of
`type = "launcher"`, named for the addon's **folder** (`AbsorbTracker`, from the file's first
vararg), handed to LibDBIcon-1.0 under that same name — LibDBIcon keys the button's saved position
by it, so the spelling is not cosmetic. LibDBIcon draws the minimap button from that table and any
broker display draws its own row from it, so there is one `OnClick`, one icon and one identity
(launcher-§1). Its **`label` is `Ka0s Absorb Tracker`** — the brand name in plain text, because a
broker row is printed beside the other ten Ka0s addons and that one string is what decides whether
they read as one collection. It is `NS.Constants.BRAND`, the **one** plain-text brand constant —
the same string `settings/Slash.lua` hands the dispatcher as `brandName`, because slash-commands-§7
makes the disabled refusal line carry exactly this spelling and two literals would be two brand
names. Deliberately **not** wired to the TOC's `## Title` (which may carry color escapes) and not
the folder name (which is `name`). Both libraries are
vendored under `libs/` and resolved with `LibStub(..., true)` at `Register()` time; a host missing
either gets an honest report rather than a raise.

## The two buttons

**Left-click opens the settings panel; right-click opens the options menu** (launcher-§2, standard
v2.67.0, `LibKa0s-Launcher-1.0` minor 4). That is the same on every Ka0s addon and it is the
library's, not this addon's: the descriptor passes `openSettings` and its accessor-and-toggle pairs,
and the library routes both buttons. The left click is not gated — the panel is setup rather than a
feature, and it is where a disabled addon is switched back on — and neither is the right. On a client
with no context-menu API (`MenuUtil`, 11.0+) the right click opens the settings panel too.

Until M6 (2026-09-24) the left click toggled the lock (the retired rung (b)) and was refused while
disabled; that toggle is the menu's *Locked* entry now.

## The options menu

The client's own context menu, titled `Ka0s Absorb Tracker`, with one checkbox per state this addon
has — the row the standard's `ADDONS.md` records:

```
Ka0s Absorb Tracker
[x] Enabled         isEnabled + setEnabled   -> the /at enable | /at disable handler
[x] Locked          isLocked  + toggleLock   -> the /at lock | /at unlock handler
```

**Each entry runs the slash verb's own handler**, looked up in `NS.COMMANDS` at click time
(`core/LauncherSetup.lua`'s `runVerb`), not a second implementation. So the write goes through
`NS.SetByPath` — the seam the Master-controls checkboxes use, whose `onChange` owns the stand-down
latch, the in-combat unlock refusal, the preview clear and the repaint — and the chat echo is the
verb's (`enabled = false`, `locked = true`, read back from the store). *Locked* picks `lock` or
`unlock` from the **stored** lock, so a click after a combat refusal toggles from what is actually
stored.

There is **no Test mode entry**: options-ui-§15 exempts an addon whose unlocked view already is its
preview, and this one took that exemption, so the lock is the preview switch. There is **no Show
window entry**: nothing here is a primary window.

**While the addon is disabled** (slash-commands-§7) the library grays *Locked* and labels it
`Locked (enable the addon first)`; a grayed entry runs no handler and writes nothing, which keeps
the audit finding fixed — an ungated launcher once wrote the stored tree of an addon the player had
switched off. *Enabled* stays live, so the way back is one click. The button itself stays on the
minimap either way, because `minimap.hide` is a per-installation display preference that says
nothing about whether the addon is running. `tests/test_launcher.lua` pins the entries, the routing
to each verb's handler and the per-open state reads; `tests/test_disabled.lua` step 8 pins the
disabled half.

## The status tooltip

**The button always shows a tooltip, including while the addon is disabled** (launcher-§1,
standard v2.66.0). `LibKa0s-Launcher-1.0` minor 3 draws all of it, in the one shape every Ka0s
addon shares; the descriptor in `core/LauncherSetup.lua` only feeds it, and every field is asked on
every hover:

```
Ka0s Absorb Tracker  v<version>       version: the TOC's `## Version` (NS.Meta); label alone if unreadable
Enabled: Yes|No                       isEnabled — the same accessor the menu's Enabled entry reads
Locked: Yes|No                        isLocked — the `locked` setting the menu's Locked entry toggles
Left-click: Open settings             the library's fixed hint (minor 4)
Right-click: Options menu             the library's fixed hint (minor 4)
```

The hints read the same while disabled, because neither button is gated. There is **no `Test mode:` line**: this addon has no Test mode (options-ui-§15's
exemption — the lock is the preview), so `isTestMode` is not passed. There is **no
`onTooltipShow`**: the addon has no lines of its own to append, and the title and click hints are
the library's. `tests/test_launcher.lua` pins the whole five-line tooltip, the lock read on every
show and the disabled state.

## Visibility: one row, one boolean

**Visibility is one row and one boolean.** `Minimap button` on Master controls stores LibDBIcon's
own `hide` key in the `db.global.minimap` table — **global**, so a profile switch does not move the
player's buttons. The row, and the path a player types (`global.minimap.shown`, launcher-§3), say
*shown*; the stored key says *hidden*, so the row's own `get` / `set`
(`NS.MinimapShown` / `NS.SetMinimapShown`, `core/Data.lua`) invert it, and no `shown` key is ever
stored (anti-pattern #81). The stored key never moved when the path was renamed from its old `hide`
spelling, so no SavedVariables migration exists and a button hidden before the rename stays hidden;
the old path now answers `Setting not found`;
the set also calls `NS.Launcher:SetShown`, so the button follows the checkbox immediately.

**The row survives every reset, as a property of the setting** (launcher-§3): a minimap button's
visibility is a per-installation display preference, like the angle LibDBIcon keeps beside it in the
same table. *Reset all settings* never reached it — it is a profile reset and the value is global —
but the **General page's Defaults button did**, because `LibKa0s-Options-1.0`'s `RestoreDefaults`
walks every row on the page and consults no veto. The exemption is the schema runtime's
`resetExempt` (`settings/Schema.lua`), which `ApplyDefault` honors while a bracket is open, and
both library resets open one around their walk. `/at reset global.minimap.shown` is deliberately
outside it: a single named reset opens no bracket, and naming the row is asking for it. Detail in [settings-panel.md](./settings-panel.md).

## The icon

The **icon** is `media/logos/absorbtracker.logo.128.tga`, the same file `## IconTexture` names
(launcher-§4) — 128×128, uncompressed 32-bit, regenerated from the `.png` beside it by layout-§4's
recipe. `tests/test_launcher.lua` reads its header bytes, because a wrong format there draws nothing
and raises nothing.
