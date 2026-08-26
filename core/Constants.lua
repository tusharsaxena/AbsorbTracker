local addonName, NS = ...
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
