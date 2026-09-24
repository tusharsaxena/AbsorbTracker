# Launcher

The minimap button and broker row: the one LDB object, the click rung, the disabled-state refusal,
the visibility row that survives every reset, and the icon. This page was the `## Launcher` section
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

## The click rung

**The rung is (b)** (launcher-§2, and the standard's `ADDONS.md` records it): left-click toggles the
addon's preview switch, which here is the **lock** — options-ui-§15 exempts an addon whose unlocked
view already is its preview, and this one took that exemption. The click writes through
`NS.SetByPath`, the same seam the Lock frame checkbox and `/at lock` / `/at unlock` write through,
so the in-combat unlock refusal, the preview clear and the repaint all come from the row's own
`onChange` rather than being reimplemented. **Right-click always opens the settings panel.**

## The disabled-state refusal

**While the addon is disabled the left click is refused** (launcher-§2, slash-commands-§7). Rung (b)
drives a preview switch, which is a feature, so the click prints `NS.Slash:DisabledLine()` — the
dispatcher's own line, not a second spelling — and does **nothing else**; in particular it reaches
no write seam, which is the audit finding it fixes: an ungated minimap button writes the stored tree
of an addon the player switched off, and a mouse click is a game event in every sense that matters.
**The gate is the library's, not this addon's:** the descriptor hands `LibKa0s-Launcher-1.0` minor 2
`isEnabled` (`NS.GetSetting("enabled") ~= false`) and `disabledLine` (`NS.Slash:DisabledLine()`),
both asked on every click, and the library refuses a left click before it ever calls `onClick` — so
the `locked` seam, whose `onChange` would land in SavedVariables whatever the click printed, is
never reached. `onClick` itself carries no gate. **Right-click is unchanged in either state** —
the panel is setup rather than a feature, so the right button opens it for the same reason `config` and the bare `/at` still do — and the button
itself stays on the minimap, because `minimap.hide` is a per-installation display preference that
says nothing about whether the addon is running. `tests/test_disabled.lua` step 8 pins all three;
`tests/test_launcher.lua` pins that the same registered object toggles again once re-enabled.

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
