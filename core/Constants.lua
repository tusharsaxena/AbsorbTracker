local addonName, NS = ...
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- LibSharedMedia fallback paths — returned when LSM is absent or a media key doesn't resolve,
-- so the bar always has a valid texture/border/font.
C.FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
C.FALLBACK_BORDER  = "Interface\\Tooltips\\UI-Tooltip-Border"
C.FALLBACK_FONT    = "Fonts\\FRIZQT__.TTF"

-- Vendored monospace font (JetBrains Mono, OFL) used by the debug console (debug-logging-§2). The file
-- lives at media/fonts/ in the repo; this is the in-game addon-relative path.
C.FONT_MONO = "Interface\\AddOns\\AbsorbTracker\\media\\fonts\\JetBrainsMono-Regular.ttf"

-- About-page logo. Moved to media/logos/ per layout-§3 (typed media subfolders).
C.LOGO_PATH = "Interface\\AddOns\\AbsorbTracker\\media\\logos\\absorbracker.logo.v2.tga"
