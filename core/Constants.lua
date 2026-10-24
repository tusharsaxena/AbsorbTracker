local _, NS = ...
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- LibSharedMedia fallback paths — returned when LSM is absent or a media key doesn't resolve,
-- so the bar always has a valid texture/border/font.
C.FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
C.FALLBACK_BORDER  = "Interface\\Tooltips\\UI-Tooltip-Border"
C.FALLBACK_FONT    = "Fonts\\FRIZQT__.TTF"

-- The monospace face used by the debug console (debug-logging-§2), from LibKa0s rather than from
-- this addon. A log is a column of timestamps and numbers, and a proportional face makes that column
-- shiver line to line; a fixed face pins it to a grid.
--
-- IT USED TO BE OURS, under media/fonts/JetBrainsMono-Regular.ttf. The bytes ship inside the LibKa0s
-- payload now (`LibKa0s-Media-1.0`, libs/LibKa0s/media/fonts/) so that every Ka0s addon prints in one
-- face rather than in one copy of it each — see core/MediaSetup.lua, which publishes this seam and
-- registers the face with LibSharedMedia. That file MUST load before this one; the TOC says so.
--
-- THE FALLBACK IS A REAL CLIENT FONT, NOT NIL AND NOT A GUESSED PATH. A degraded install has no
-- LibKa0s and therefore no face, and SetFont accepts a path to a file that is not there, fails to
-- load it, and simply does not draw the text. Landing on C.FALLBACK_FONT means a degraded install
-- loses the monospace grid and keeps every line on screen.
--
-- THE LAST RUNG IS THE `C.FALLBACK_FONT` LITERAL ABOVE, NOT `_G.STANDARD_TEXT_FONT`. The FrameXML global is
-- the same face, but it is a global whose value at the moment THIS file loads is somebody else's
-- business, and a nil last rung is exactly the failure the rung exists to prevent: nil reaches
-- `log:SetFont` on the one window whose job is to stay readable when everything else has failed.
-- C.FALLBACK_FONT is a literal in this file and cannot be nil. tests/test_mediasetup.lua pins it.
C.FONT_MONO = NS.MediaFont and NS.MediaFont("JetBrains Mono") or C.FALLBACK_FONT

-- The LibSharedMedia key the face is registered under — by the LIBRARY, whose catalog spells it this
-- way (`LibKa0s-Media-1.0`'s `FONTS`). Kept beside the path so anything that names the font by key
-- cannot drift from what was actually registered; tests/test_mediasetup.lua pins the pair.
C.FONT_MONO_NAME = "JetBrains Mono"

-- About-page logo. Moved to media/logos/ per layout-§3 (typed media subfolders).
C.LOGO_PATH = "Interface\\AddOns\\AbsorbTracker\\media\\logos\\absorbtracker.logo.tga"

-- The ICON-sized logo, and a DIFFERENT FILE from the one above rather than the same art at another
-- size (layout-§4). One is drawn by the settings panel's landing page at 300x300; this one is read
-- by the client as an icon, at icon size, in three places at once -- the AddOns list (the TOC's
-- `## IconTexture`), the minimap button and a broker display (launcher-§4) -- so a player who has
-- seen the addon once recognizes it in all three.
--
-- 128x128, uncompressed 32-bit (TGA image type 2, 32 bpp), regenerated from the 2000x2000 `.png`
-- beside it by layout-§4's recipe rather than hand-exported. The format is not a style preference:
-- an RLE-compressed or 24-bit TGA in this role draws NOTHING and raises nothing, so no gate reports
-- it and the button the player adopted the launcher for is simply invisible (anti-pattern #82).
--
-- THE TOC SPELLS THIS PATH AGAIN, and that duplication is the client's, not ours: `## IconTexture`
-- is read out of the TOC before a single line of Lua runs, so there is no constant it could read.
-- tests/test_docs.lua pins the two spellings together.
C.LOGO_ICON_PATH = "Interface\\AddOns\\AbsorbTracker\\media\\logos\\absorbtracker.logo.128.tga"

-- THE BRAND NAME, IN PLAIN TEXT, AND THERE IS EXACTLY ONE OF IT. launcher-§1 makes this the LDB
-- object's `label`, and slash-commands-§7 makes the same string the subject of the one line a
-- disabled addon prints — so LibKa0s-Slash-1.0 wants it as `brandName` and LibKa0s-Launcher-1.0
-- wants it as `label`. Two literals would be two brand spellings, which is the drift a shared
-- printer exists to end; one constant makes them the same string by construction.
--
-- NOT the TOC's `## Title` (a Title may carry color escapes, and one in the collection does) and
-- not the folder name (which LibDBIcon keys a saved position by and nobody reads as prose).
C.BRAND = "Ka0s Absorb Tracker"

-- The minimap button's visibility, as the path a player types and the row answers (launcher-§3).
-- VERBATIM and unprefixed: the table it names lives in the GLOBAL store, outside the
-- Master-controls block's profile prefix, because a minimap button belongs to the INSTALLATION
-- rather than to a profile -- switching profiles must not move the player's buttons, and
-- options-ui-§12's *Reset all settings*, a profile reset by definition, must not un-hide a button
-- they deliberately hid.
--
-- THE CLI NAME READS SHOWN, THE SAME SENSE AS THE CHECKBOX (launcher-§3, standard v2.65.0), and
-- the storage stays LibDBIcon's OWN `minimap.hide`. The row's get/set invert between the two, once,
-- at the read/write seam in core/Data.lua, so no `shown` key is ever stored: a second boolean
-- beside LibDBIcon's would be a copy of one state that the library also writes, free to disagree
-- the first time the player used LibDBIcon's own menu (anti-pattern #81). Because the stored key
-- never moved, a player who hid the button under the old `hide` spelling of this path keeps it
-- hidden with no SavedVariables migration.
C.MINIMAP_PATH = "global.minimap.shown"

-- ---------------------------------------------------------------------------
-- Frame layering (frame-layering-§1..§6, standard v2.88.0)
-- ---------------------------------------------------------------------------
--
-- THE ONE LAYERS TABLE (frame-layering-§5). Every SetFrameStrata and SetFrameLevel this addon
-- makes reads it, and every level is an OFFSET over the frame that owns the band, never an absolute
-- number: `base:GetFrameLevel() + LAYERS.LEVEL.<NAME>`. So no call site in core/, modules/ or
-- settings/ hands SetFrameStrata a string literal or SetFrameLevel a bare number, and
-- tests/test_layers.lua pins both.
--
-- THE ADDON'S WHOLE STACK, lowest first. Only the first two rows are this addon's own writes; the
-- rest are the library's, Blizzard's or a third party's, listed so a new frame is placed around
-- known neighbors rather than on top of whatever its parent happened to have.
--
--   HUD      MEDIUM, explicit on each bar root, toplevel, clamped. The three bars
--            (modules/Bar.lua) are peers that can overlap, so each is toplevel: the one grabbed
--            comes to the front whole (frame-layering-§3, peers stack whole). Inside one bar,
--            from its own level L (the element ladder, §3):
--              L + 0        the bar root: the backdrop BACKGROUND only (bgFile, insets)
--              L + FILL     the StatusBar fill
--              L + BORDER   `bar.border`, the backdrop EDGE, a mouse-off frame ABOVE the fill so
--                           the fill can never paint over the inner part of a thick border
--              L + OVERLAY  `bar.overlay`, the mouse-off frame that hosts the value text
--              L + HANDLE   the unlocked drag strip (LibKa0s-Widgets-1.0 DragHandle `level`),
--                           its `?` and X at handle + 1 (the widget's). Edit chrome sits at the
--                           top of its display (§2) and clears every content level of a
--                           neighboring bar at the same base; it ignores the bar's alpha.
--   Launcher MEDIUM, level 8, both fixed: the LibDBIcon minimap button (LibDBIcon's choice).
--   Settings HIGH, toplevel: Blizzard's Settings panel. Inside our pages the library's bands:
--            tab strip + 1, the combat cover computed over the deepest descendant (OptionsCombat).
--   MODAL    DIALOG, toplevel, clamped: the LibKa0s debug console and perf panel; Blizzard's
--            StaticPopups (the Reset-all confirmation) share it, and a library tool window
--            re-raises a shown StaticPopup when it shows.
--   CHILD    FULLSCREEN: the LibKa0s copy window, one strata above the console that opens it.
--   POPUP    FULLSCREEN_DIALOG: AceGUI dropdown pullouts and the color picker.
--   CURSOR   TOOLTIP: GameTooltip (strip and row tooltips); AceGUI-3.0-SharedMediaWidgets'
--            media pullouts also sit here (third party, not ours to move).
C.LAYERS = {
    STRATA = {
        HUD = "MEDIUM",
    },
    LEVEL = {
        FILL    = 1,
        BORDER  = 2,
        OVERLAY = 4,
        HANDLE  = 50,
    },
}
