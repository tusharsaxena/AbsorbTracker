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
