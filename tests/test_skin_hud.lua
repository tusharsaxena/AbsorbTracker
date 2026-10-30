-- tests/test_skin_hud.lua — the HUD bars follow the skin (AT-03, skinning-§6).
--
-- What this addon owes: each bar's texture (fill and background), border (style and thickness)
-- and font face are drawn from the owner's skin tokens while the unit's "Use the skin's ..."
-- companion is on, and from the stored pick while it is off; the companions default on, are
-- composed schema rows, mirror and copy like every appearance key; the colors never follow the
-- skin (X4); a skin switch repaints the bars; and the one-time v6 reset (O2) puts every stored
-- companion back on once, and never again over a later pick.
--
-- After test_skinsetup, which leaves the skin on Ka0s Default; every case here puts it back there.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "AbsorbTracker"
local S = NS.Skin

--- Run `body` with `unit`'s config key `key` at `value`, then restore it, whatever `body` raised.
local function withUnit(unit, key, value, body)
  local c = NS.db.profile.units[unit]
  local saved = c[key]
  c[key] = value
  local ok, err = pcall(body)
  c[key] = saved
  if not ok then error(err, 0) end
end

--- Back on Ka0s Default, whatever `fn` raised.
local function onDefault(fn)
  return function()
    local ok, err = pcall(fn)
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    if not ok then error(err, 0) end
  end
end

-- Run `body` with a LibSharedMedia-3.0 stub serving `media` ([mediaType][key] = path), as
-- tests/test_data.lua does.
local function withLSM(media, body)
  local savedLibStub = mocks.LibStub
  local lsm = {
    Fetch     = function(_, mtype, key) return (media[mtype] or {})[key] end,
    HashTable = function(_, mtype) return media[mtype] or {} end,
    Register  = function() return true end,
  }
  mocks.LibStub = setmetatable({}, {
    __call = function(_, name, silent)
      if name == "LibSharedMedia-3.0" then return lsm end
      return savedLibStub(name, silent)
    end,
  })
  NS.ClearLSMCache()
  local ok, err = pcall(body)
  mocks.LibStub = savedLibStub
  NS.ClearLSMCache()
  if not ok then error(err, 0) end
end

-- ── the companions ───────────────────────────────────────────────────────────────────────────

test("every unit's three skin companions default on (X3)", function()
  for _, unit in ipairs(NS.Units.LIST) do
    for _, key in ipairs(NS.Units.FROM_SKIN_KEYS) do
      assertEqual(NS.defaults.profile.units[unit][key], true, unit .. "." .. key)
    end
  end
end)

test("the companions are composed schema rows, bools defaulting on, on the tab of the pick", function()
  local tabs = { barTextureFromSkin = "Bar", borderFromSkin = "Bar", fontFromSkin = "Text" }
  for _, unit in ipairs(NS.Units.LIST) do
    for key, group in pairs(tabs) do
      local row = NS.FindSchemaRow("units." .. unit .. "." .. key)
      assertTrue(row ~= nil, "no row units." .. unit .. "." .. key)
      assertEqual(row.type, "bool", key)
      assertEqual(row.default, true, key .. " defaults on")
      assertEqual(row.group, group, key)
    end
  end
  -- The composer governs its own picker with it.
  assertEqual(NS.FindSchemaRow("units.player.barTexture").disabledIf, "units.player.barTextureFromSkin")
  assertEqual(NS.FindSchemaRow("units.player.border").disabledIf, "units.player.borderFromSkin")
  assertEqual(NS.FindSchemaRow("units.player.font").disabledIf, "units.player.fontFromSkin")
end)

test("the background texture and the border thickness follow the companions too (D3, D4)", function()
  local bg = NS.FindSchemaRow("units.target.bgTexture")
  local size = NS.FindSchemaRow("units.target.borderSize")
  assertEqual(bg.disabledIf, "units.target.barTextureFromSkin")
  assertEqual(size.disabledIf, "units.target.borderFromSkin")
  assertEqual(bg.skinValue(bg), S.Token("bar.texture"), "the background shows the skin's texture")
  assertEqual(size.skinValue(size), S.Token("bar.borderSize"), "the slider shows the skin's size")
  withUnit("target", "barTextureFromSkin", false, function()
    assertEqual(bg.skinValue(bg), nil, "off: the stored pick shows")
  end)
  withUnit("target", "borderFromSkin", false, function()
    assertEqual(size.skinValue(size), nil, "off: the stored size shows")
  end)
  -- The colors never follow the skin (X4): no color row is governed.
  for _, key in ipairs({ "barColor", "bgColor", "borderColor", "fontColor" }) do
    assertEqual(NS.FindSchemaRow("units.player." .. key).disabledIf, nil, key)
  end
end)

-- ── the getters ──────────────────────────────────────────────────────────────────────────────

test("a companion on draws the skin's token; off, the stored pick", function()
  local cases = {
    { "barTexture", "bar.texture", "barTextureFromSkin" },
    { "bgTexture", "bar.texture", "barTextureFromSkin" },
    { "border", "bar.borderStyle", "borderFromSkin" },
    { "borderSize", "bar.borderSize", "borderFromSkin" },
    { "font", "hud.font", "fontFromSkin" },
  }
  for _, c in ipairs(cases) do
    local key, token, companion = c[1], c[2], c[3]
    local name, fromSkin = NS.MediaKey("player", key)
    assertTrue(S.Token(token) ~= nil, token .. " is set in Ka0s Default")
    assertEqual(name, S.Token(token), key .. " follows " .. token)
    assertEqual(fromSkin, true, key)
    withUnit("player", companion, false, function()
      local own, skinned = NS.MediaKey("player", key)
      assertEqual(own, NS.db.profile.units.player[key], key .. " is the stored pick")
      assertEqual(skinned, false, key)
    end)
  end
  assertEqual(NS.GetBorderSize("player"), S.Token("bar.borderSize"))
  withUnit("player", "borderFromSkin", false, function()
    withUnit("player", "borderSize", 7, function()
      assertEqual(NS.GetBorderSize("player"), 7)
    end)
  end)
end)

test("Ignore fonts keeps the value text on the stored face, over the skin and a font override", function()
  -- The library enforces it (LibKa0s v1.81.0, Skin minor 8, R-1): while the owner ignores fonts,
  -- Resolve answers the stored `hud.font` and Token nil, and the addon keeps no check of its own
  -- (core/Data.lua). red under: a library that resolves `hud.font` through the skin while Ignore
  -- fonts is ticked (v1.80.0's payload), or a MediaKey that reports the stored face as the skin's
  -- (the companion alone, not the skin's Token answer).
  local panel, fonts = Skin:GetIgnore(OWNER)
  local savedFont, savedTexture = Skin:GetOverride(OWNER)
  local own = NS.db.profile.units.player.font
  local ok, err = pcall(function()
    assertEqual(NS.db.profile.units.player.fontFromSkin, true, "the companion is on")
    assertTrue(S.Token("hud.font") ~= own, "the skin's face differs from the stored one")
    Skin:SetIgnore(OWNER, nil, true)
    local name, fromSkin = NS.MediaKey("player", "font")
    assertEqual(name, own, "ignored fonts draw the stored face")
    assertEqual(fromSkin, false, "and the face is not the skin's")
    Skin:SetOverride(OWNER, "Override Face", nil)
    assertEqual((NS.MediaKey("player", "font")), own,
      "a font override is not drawn while fonts are ignored")
    withLSM({ font = { [own] = "path/own/font", ["Override Face"] = "path/override/font" } }, function()
      assertEqual(NS.GetFont("player"), "path/own/font")
    end)
    assertEqual((NS.MediaKey("player", "barTexture")), S.Token("bar.texture"),
      "Ignore fonts leaves the textures alone")
    Skin:SetOverride(OWNER, false, nil)
    Skin:SetIgnore(OWNER, nil, false)
    assertEqual((NS.MediaKey("player", "font")), S.Token("hud.font"), "unticked, the skin's face again")
  end)
  Skin:SetOverride(OWNER, savedFont or false, savedTexture or false)
  Skin:SetIgnore(OWNER, panel, fonts)
  if not ok then error(err, 0) end
end)

test("the getters fetch the skin's media through LibSharedMedia", function()
  withLSM({
    statusbar = { [S.Token("bar.texture")] = "path/skin/bar" },
    border    = { [S.Token("bar.borderStyle")] = "path/skin/border" },
    font      = { [S.Token("hud.font")] = "path/skin/font" },
  }, function()
    assertEqual(NS.GetBarTexture("player"), "path/skin/bar")
    assertEqual(NS.GetBgTexture("player"), "path/skin/bar")
    assertEqual(NS.GetBorder("player"), "path/skin/border")
    assertEqual(NS.GetFont("player"), "path/skin/font")
  end)
end)

test("a mirrored bar follows the player's companion, an unlinked one its own", function()
  withUnit("target", "mirror", true, function()
    withUnit("player", "fontFromSkin", false, function()
      withUnit("target", "fontFromSkin", true, function()
        assertEqual((NS.MediaKey("target", "font")), NS.db.profile.units.player.font,
          "linked: the player's stored pick")
      end)
    end)
  end)
  withUnit("target", "mirror", false, function()
    withUnit("player", "fontFromSkin", false, function()
      assertEqual((NS.MediaKey("target", "font")), S.Token("hud.font"), "unlinked: its own companion")
    end)
  end)
end)

test("Copy from Player copies the companions", function()
  local saved = {}
  for _, k in ipairs(NS.Units.FROM_SKIN_KEYS) do saved[k] = NS.db.profile.units.focus[k] end
  local mirror = NS.db.profile.units.focus.mirror
  local ok, err = pcall(function()
    withUnit("player", "borderFromSkin", false, function()
      NS.Units.CopyFromPlayer("focus")
      assertEqual(NS.db.profile.units.focus.borderFromSkin, false)
      assertEqual(NS.db.profile.units.focus.fontFromSkin, true)
    end)
  end)
  for k, v in pairs(saved) do NS.db.profile.units.focus[k] = v end
  NS.db.profile.units.focus.mirror = mirror
  if not ok then error(err, 0) end
end)

-- ── the bars ─────────────────────────────────────────────────────────────────────────────────

test("the appearance pass draws the skin's border thickness and inset", function()
  NS.UpdateBarAppearance("player")
  local bar = NS.bars.player
  local size = S.Token("bar.borderSize")
  assertEqual(bar.borderInfo.edgeSize, size)
  assertEqual(bar.backdropInfo.insets.left, math.max(1, math.floor(size / 4)))
  withUnit("player", "borderFromSkin", false, function()
    NS.UpdateBarAppearance("player")
    assertEqual(bar.borderInfo.edgeSize, NS.db.profile.units.player.borderSize)
  end)
  NS.UpdateBarAppearance("player")
end)

test("a skin switch repaints every bar, and leaves the player's colors alone", onDefault(function()
  local r, g, b, a = NS.GetBarColor("player")
  local painted, real = {}, NS.UpdateBarAppearance
  NS.UpdateBarAppearance = function(unit) painted[#painted + 1] = unit end
  local ok, err = pcall(Skin.SetChoice, Skin, OWNER, "ka0s", "obsidian")
  NS.UpdateBarAppearance = real
  assertTrue(ok, tostring(err))
  assertTrue(#painted >= #NS.Units.LIST, "every bar repainted: " .. #painted)
  assertEqual((NS.MediaKey("player", "font")), S.Token("hud.font"), "the new skin's face")
  local r2, g2, b2, a2 = NS.GetBarColor("player")
  assertTrue(r == r2 and g == g2 and b == b2 and a == a2, "the fill color is the player's (X4)")
end))

-- ── the one-time reset (O2) ──────────────────────────────────────────────────────────────────

--- Run the ladder over `profiles` (name -> table, `active` the loaded one) from stamp `from`.
local function migrate(profiles, active, from)
  local savedDB = NS.db
  NS.db = { profile = profiles[active], global = { schemaVersion = from }, sv = { profiles = profiles } }
  local ok, err = pcall(NS.RunMigrations, NS)
  local stamp = NS.db.global.schemaVersion
  NS.db = savedDB
  if not ok then error(err, 0) end
  return stamp
end

test("v6 puts every stored companion back on, keeps the picks and the colors", function()
  local color = { r = 0.9, g = 0.1, b = 0.1, a = 1 }
  local default = { schemaVersion = 3, units = {
    player = { font = "My Font", fontFromSkin = false, borderFromSkin = false, barColor = color },
  } }
  local raid = { schemaVersion = 3, units = {
    target = { barTexture = "My Texture", barTextureFromSkin = false },
    focus  = { border = "My Border" },
  } }
  local stamp = migrate({ Default = default, Raid = raid }, "Default", 5)
  assertEqual(stamp, 7)
  assertEqual(NS.SCHEMA_VERSION, 7)
  local p = default.units.player
  assertEqual(p.fontFromSkin, true, "the active profile's font follows the skin")
  assertEqual(p.borderFromSkin, true, "and its border")
  assertEqual(p.font, "My Font", "the stored pick is kept")
  assertEqual(p.barColor, color, "the color is untouched (X4)")
  assertEqual(p.barColor.r, 0.9)
  assertEqual(p.barColorFromSkin, nil, "no companion invented for a color")
  assertEqual(raid.units.target.barTextureFromSkin, true, "an inactive profile is reset too")
  assertEqual(raid.units.target.barTexture, "My Texture")
  assertEqual(raid.units.focus.borderFromSkin, nil, "an absent companion stays absent: it reads on")
  assertEqual(raid.units.focus.border, "My Border", "no sentinel written into a pick")
  assertEqual(raid.units.player, nil, "no unit table invented")
end)

test("v6 runs once: a pick made after it is kept", function()
  local p = { schemaVersion = 3, units = { player = { fontFromSkin = false } } }
  migrate({ Default = p }, "Default", 5)
  assertEqual(p.units.player.fontFromSkin, true, "the reset ran")
  p.units.player.fontFromSkin = false   -- the player unticks "Use the skin's font" afterwards
  local stamp = migrate({ Default = p }, "Default", 7)
  assertEqual(stamp, 7)
  assertEqual(p.units.player.fontFromSkin, false, "a later pick survives the next login")
end)

-- ── Font flags From skin and the HUD size scale (LibKa0s v1.82.0, rulings D-07 and D-09) ──────
--
-- Every bar's Font flags row offers "From skin" ("@skin") first and defaults to it; the value text
-- draws S.FontFlags(stored), which resolves From skin through the Skin tab's Font outline and
-- answers a picked flag as stored. The v7 step moves a stored flag equal to the old default
-- (OUTLINE) onto From skin, once, on every profile; a flag the player changed stays. While the bar
-- uses the skin's face (Use the skin's font) its size is S.HudFontSize(stored): the stored size
-- times the skin's HUD size over Ka0s Default's, the stored value never rewritten.

--- The value text's last SetFont arguments after one appearance pass of `unit`.
local function drawnFont(unit)
  local fs = NS.bars[unit].valueText
  local real, got = fs.SetFont, nil
  fs.SetFont = function(self, ...) got = { ... }; return real(self, ...) end
  local ok, err = pcall(NS.UpdateBarAppearance, unit)
  fs.SetFont = real
  if not ok then error(err, 0) end
  return got
end

--- Back on Ka0s Default with the Font outline on All text, whatever `fn` raised.
local function onDefaultOutline(fn)
  return onDefault(function()
    local ok, err = pcall(fn)
    Skin:SetOutline(OWNER, "all")
    Skin:SetIgnore(OWNER, true, false)
    if not ok then error(err, 0) end
  end)
end

test("every bar's Font flags default to From skin, offered first", function()
  for _, unit in ipairs(NS.Units.LIST) do
    assertEqual(NS.defaults.profile.units[unit].fontFlags, "@skin", unit .. ": the default")
    local row = NS.FindSchemaRow("units." .. unit .. ".fontFlags")
    assertEqual(row.default, "@skin", unit .. ": the row's default")
    assertEqual(row.sorting[1], "@skin", unit .. ": From skin leads the list")
    assertEqual(row.values["@skin"], "From skin")
    assertEqual(row.values[""], "None", "None is still offered")
  end
end)

test("From skin draws the Font outline's flags; a picked flag draws as picked", onDefaultOutline(function()
  -- red under: SetFont handed the stored "@skin" (the client draws no outline, or refuses it), or a
  -- picked flag rewritten by the skin.
  withUnit("player", "fontFlags", "@skin", function()
    assertEqual(drawnFont("player")[3], "OUTLINE", "All text: outlined")
    Skin:SetOutline(OWNER, "hud")
    assertEqual(drawnFont("player")[3], "OUTLINE", "HUD text only: the bar is HUD text")
    Skin:SetOutline(OWNER, "off")
    assertEqual(drawnFont("player")[3], "", "Off: no outline")
  end)
  withUnit("player", "fontFlags", "THICKOUTLINE", function()
    assertEqual(drawnFont("player")[3], "THICKOUTLINE", "a picked flag wins over Off")
  end)
  withUnit("player", "fontFlags", "", function()
    Skin:SetOutline(OWNER, "all")
    assertEqual(drawnFont("player")[3], "", "a picked None wins over All text")
  end)
end))

test("the Font outline's change repaints the bars' flags live", onDefaultOutline(function()
  withUnit("player", "fontFlags", "@skin", function()
    NS.UpdateBarAppearance("player")
    local fs = NS.bars.player.valueText
    local real, got = fs.SetFont, nil
    fs.SetFont = function(self, ...) got = { ... }; return real(self, ...) end
    local ok, err = pcall(function()
      Skin:SetOutline(OWNER, "off")
      mocks.__fireTimers()
    end)
    fs.SetFont = real
    if not ok then error(err, 0) end
    assertTrue(got ~= nil, "SetOutline's OnLooksChanged reached the appearance pass")
    assertEqual(got[3], "")
  end)
end))

test("v7 moves a stored OUTLINE onto From skin and keeps a flag the player changed", function()
  local default = { schemaVersion = 3, units = {
    player = { fontFlags = "OUTLINE" }, target = { fontFlags = "THICKOUTLINE" }, focus = { fontFlags = "" },
  } }
  local raid = { schemaVersion = 3, units = { player = { fontFlags = "OUTLINE" }, target = {} } }
  local stamp = migrate({ Default = default, Raid = raid }, "Default", 6)
  assertEqual(stamp, 7)
  assertEqual(NS.SCHEMA_VERSION, 7)
  assertEqual(default.units.player.fontFlags, "@skin", "the old default moves to From skin")
  assertEqual(default.units.target.fontFlags, "THICKOUTLINE", "a changed flag stays")
  assertEqual(default.units.focus.fontFlags, "", "a picked None stays")
  assertEqual(raid.units.player.fontFlags, "@skin", "an inactive profile moves too")
  assertEqual(raid.units.target.fontFlags, nil, "an absent flag stays absent: it reads From skin")
  assertEqual(raid.units.focus, nil, "no unit table invented")
end)

test("v7 runs once: an OUTLINE picked after it is kept", function()
  local p = { schemaVersion = 3, units = { player = { fontFlags = "OUTLINE" } } }
  migrate({ Default = p }, "Default", 6)
  assertEqual(p.units.player.fontFlags, "@skin", "the move ran")
  p.units.player.fontFlags = "OUTLINE"   -- the player picks Outline afterwards
  assertEqual(migrate({ Default = p }, "Default", 7), 7)
  assertEqual(p.units.player.fontFlags, "OUTLINE", "a later pick survives the next login")
end)

test("the skin's face draws at the skin's HUD size; the stored size never moves", onDefaultOutline(function()
  -- red under: SetFont handed the stored size under a skin whose HUD size is not Ka0s Default's
  -- (Obsidian's text would be narrower than Ka0s Default's), or the stored size rewritten.
  withUnit("player", "fontSize", 12, function()
    assertEqual(drawnFont("player")[2], 12, "Ka0s Default: as stored")
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    assertEqual(drawnFont("player")[2], 13, "Obsidian: 12 * 13 / 12")
    assertEqual(NS.db.profile.units.player.fontSize, 12, "the stored size is untouched")
    withUnit("player", "fontFromSkin", false, function()
      assertEqual(drawnFont("player")[2], 12, "its own face: as stored")
    end)
    Skin:SetIgnore(OWNER, true, true)
    assertEqual(drawnFont("player")[2], 12, "Ignore fonts: as stored")
  end)
  withUnit("player", "fontSize", 24, function()
    Skin:SetIgnore(OWNER, true, false)
    assertEqual(drawnFont("player")[2], 26, "Obsidian scales any stored size: 24 * 13 / 12")
  end)
end))

test("a mirrored bar follows the player's Use the skin's font for its size", onDefaultOutline(function()
  Skin:SetChoice(OWNER, "ka0s", "obsidian")
  withUnit("target", "mirror", true, function()
    withUnit("target", "fontFromSkin", false, function()
      withUnit("player", "fontSize", 12, function()
        assertTrue(NS.bars.target ~= nil, "the target bar exists")
        assertEqual(drawnFont("target")[2], 13, "the player's companion (on) governs the mirror")
      end)
    end)
  end)
end))
