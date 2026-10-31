-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; AT-02 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, Addendum 07, ruling D-19).
--
-- Ten skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only. So every string literal in a tracked .lua file outside libs/ and tests/ carries
-- only characters every shipped face draws (the kit's safe set, read from their cmaps). A string
-- drawn in the mono role carries a `glyph: mono` marker on its line. The guard's three hits were
-- all debug-console text (the → in the profile-changed and profile-copied lines, and the bulk
-- copy's scope), which the console draws in JetBrains Mono, so each is marked mono rather than
-- rewritten: no player-facing string needed a change.

local T = _G.AT_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
  -- red under: a ≈, →, ▼ or ▲ (or any other character outside the kit's safe set) in a string the
  -- addon paints in a skin face.
  T.assertDisplayGlyphs{ label = "AbsorbTracker" }
end)
