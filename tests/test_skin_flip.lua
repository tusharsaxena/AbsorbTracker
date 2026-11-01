-- tests/test_skin_flip.lua — the bars' colors and shadow follow the skin (FS-AT-FLIP, causes D2, D3,
-- D4 and D6 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING).
--
-- What this addon owes (LibKa0s Options doc, "Moving to this version"): each color and the shadow
-- have a "Use the skin's ..." companion, default on, drawn after the class color and before the
-- stored swatch; Ka0s Default keeps this addon's pixels through its owner tokens; and the one
-- per-profile step moves existing profiles onto the skin, naming companions and the From skin
-- flags only, so every stored pick and color survives for a player who turns a companion off.
--
-- After test_skin_hud; every case leaves the skin on Ka0s Default.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "AbsorbTracker"
local S = NS.Skin

local COLOR_KEYS = { "barColorFromSkin", "bgColorFromSkin", "borderColorFromSkin",
  "fontColorFromSkin", "fontShadowFromSkin" }

local function withUnit(unit, key, value, body)
  local c = NS.db.profile.units[unit]
  local saved = c[key]
  c[key] = value
  local ok, err = pcall(body)
  c[key] = saved
  if not ok then error(err, 0) end
end

local function onSkin(key, fn)
  return function()
    Skin:SetChoice(OWNER, "ka0s", key)
    local ok, err = pcall(fn)
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    if not ok then error(err, 0) end
  end
end

local function rgba(...) return table.concat({ ... }, ",") end

--- A deep, order-free print of `v`, so "byte-identical" means every leaf.
local function dump(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys, out = {}, {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. dump(v[k]) end
  return "{" .. table.concat(out, ";") .. "}"
end

local function deep(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = deep(x) end
  return out
end

-- ── the rows and the defaults ────────────────────────────────────────────────────────────────

test("every unit's color and shadow companions are bool rows defaulting on, in both places", function()
  local groups = { barColorFromSkin = "Fill", bgColorFromSkin = "Background",
    borderColorFromSkin = "Border" }
  for _, unit in ipairs(NS.Units.LIST) do
    for _, key in ipairs(COLOR_KEYS) do
      local row = NS.FindSchemaRow("units." .. unit .. "." .. key)
      assertTrue(row ~= nil, "no row units." .. unit .. "." .. key)
      assertEqual(row.type, "bool", key)
      assertEqual(row.default, true, key .. " defaults on on the row")
      assertEqual(NS.defaults.profile.units[unit][key], true, key .. " defaults on in AceDB")
      assertTrue(type(row.desc) == "string" and row.desc:find("not read while this is on", 1, true) ~= nil,
        key .. "'s tooltip says the row it governs is not read")
      if groups[key] then assertEqual(row.subgroup, groups[key], key) end
    end
    assertTrue(NS.FindSchemaRow("units." .. unit .. ".fontColorFromSkin").label == "Use the skin's color")
    assertTrue(NS.FindSchemaRow("units." .. unit .. ".fontShadowFromSkin").label == "Use the skin's shadow")
  end
end)

test("no swatch carries disabledIf, and a class color has no companion", function()
  -- red under: a composed swatch grayed by its companion (options-ui-§17).
  for _, key in ipairs({ "barColor", "bgColor", "borderColor", "fontColor", "fontShadow" }) do
    assertEqual(NS.FindSchemaRow("units.player." .. key).disabledIf, nil, key)
  end
  for _, key in ipairs({ "useClassColorBar", "useClassColorBg", "useClassColorBorder", "useClassColorText" }) do
    assertEqual(NS.FindSchemaRow("units.player." .. key .. "FromSkin"), nil, key)
  end
end)

test("the picks' defaults moved to the Ka0s picks, in both places", function()
  local d = NS.unitDefaults
  assertEqual(d.barTexture, "Ka0s Default")
  assertEqual(d.bgTexture, "Ka0s Default")
  assertEqual(d.font, "Ka0s Prototype")
  assertEqual(NS.FindSchemaRow("units.player.barTexture").default, "Ka0s Default")
  assertEqual(NS.FindSchemaRow("units.player.bgTexture").default, "Ka0s Default")
  assertEqual(NS.FindSchemaRow("units.player.font").default, "Ka0s Prototype")
  assertEqual(NS.FindSchemaRow("units.player.fontFlags").default, "@skin")
  assertEqual(d.fontFlags, "@skin")
end)

test("the border family puts the thickness on the skin through the composer", function()
  local size = NS.FindSchemaRow("units.player.borderSize")
  assertEqual(size.disabledIf, "units.player.borderFromSkin")
  assertEqual(size.skinValue(size), S.Token("bar.borderSize"))
end)

-- ── what the bars draw ───────────────────────────────────────────────────────────────────────

test("Ka0s Default keeps this addon's pixels: fill, background, border, text, no shadow", function()
  local d = NS.unitDefaults
  assertEqual(rgba(NS.GetBarColor("player")), rgba(d.barColor.r, d.barColor.g, d.barColor.b, d.barColor.a))
  assertEqual(rgba(NS.GetBgColor("player")), rgba(d.bgColor.r, d.bgColor.g, d.bgColor.b, d.bgColor.a))
  assertEqual(rgba(NS.GetBorderColor("player")),
    rgba(d.borderColor.r, d.borderColor.g, d.borderColor.b, d.borderColor.a))
  assertEqual(rgba(NS.GetFontColor("player")), rgba(1, 1, 1, 1))
  assertEqual(NS.GetFontShadow("player"), false, "Ka0s Default draws no HUD shadow")
end)

test("a skin switch changes every flipped surface", function()
  local before = { rgba(NS.GetBarColor("player")), rgba(NS.GetBgColor("player")),
    rgba(NS.GetBorderColor("player")), rgba(NS.GetFontColor("player")),
    NS.GetBarTexture("player"), NS.GetFont("player") }
  onSkin("obsidian", function()
    assertEqual(rgba(NS.GetBarColor("player")), rgba(S.BarFillColor()), "fill: the skin's bar.fill")
    assertEqual(rgba(NS.GetBgColor("player")), rgba(S.Color("bar.bg")), "background: bar.bg")
    assertEqual(rgba(NS.GetBorderColor("player")), rgba(S.Color("bar.border")), "border: bar.border")
    assertEqual(rgba(NS.GetFontColor("player")), rgba(S.HudTextColor()), "text: hud.text")
    assertTrue(rgba(NS.GetBarColor("player")) ~= before[1], "the fill moved")
    assertTrue(rgba(NS.GetFontColor("player")) ~= before[4], "the text moved")
    local x, y, r, g, b, a = S.HudShadow()
    assertEqual(rgba(NS.GetFontShadow("player")), rgba(x, y, r, g, b, a), "shadow: hud.shadow")
  end)()
end)

test("a companion off draws the stored color and shadow", onSkin("obsidian", function()
  local c = { r = 0.11, g = 0.22, b = 0.33, a = 0.44 }
  for _, pair in ipairs({ { "barColor", NS.GetBarColor }, { "bgColor", NS.GetBgColor },
    { "borderColor", NS.GetBorderColor }, { "fontColor", NS.GetFontColor } }) do
    withUnit("player", pair[1] .. "FromSkin", false, function()
      withUnit("player", pair[1], c, function()
        assertEqual(rgba(pair[2]("player")), rgba(0.11, 0.22, 0.33, 0.44), pair[1])
      end)
    end)
  end
  withUnit("player", "fontShadowFromSkin", false, function()
    withUnit("player", "fontShadow", false, function()
      assertEqual(NS.GetFontShadow("player"), false, "stored off")
    end)
    withUnit("player", "fontShadow", true, function()
      assertEqual(rgba(NS.GetFontShadow("player")), rgba(1, -1, 0, 0, 0, 1), "stored on")
    end)
  end)
end))

test("a class color comes first, whatever the companion says", onSkin("obsidian", function()
  local real = NS.ResolveColor
  local handed = 0
  NS.ResolveColor = function(_, on) handed = handed + (on and 1 or 0); return 0.5, 0.25, 0.125, 1 end
  local ok, err = pcall(function()
    withUnit("player", "useClassColorBar", true, function()
      assertEqual(rgba(NS.GetBarColor("player")), rgba(0.5, 0.25, 0.125, 1), "the fill")
    end)
    withUnit("player", "useClassColorBorder", true, function()
      assertEqual(rgba(NS.GetBorderColor("player")), rgba(0.5, 0.25, 0.125, 1), "the border")
    end)
    withUnit("player", "useClassColorText", true, function()
      assertEqual(rgba(NS.GetFontColor("player")), rgba(0.5, 0.25, 0.125, 1), "the text")
    end)
  end)
  NS.ResolveColor = real
  if not ok then error(err, 0) end
  assertEqual(handed, 3, "the class branch ran")
  withUnit("player", "useClassColorBg", true, function()
    assertTrue(rgba(NS.GetBgColor("player")) ~= rgba(S.Color("bar.bg")), "the background palette stays")
  end)
end))

test("Ignore fonts: the stored fontShadow stands", function()
  Skin:SetChoice(OWNER, "ka0s", "obsidian")
  Skin:SetIgnore(OWNER, nil, true)
  local ok, err = pcall(function()
    assertEqual(S.HudShadow(), nil, "the library answers nil")
    withUnit("player", "fontShadow", true, function()
      assertEqual(rgba(NS.GetFontShadow("player")), rgba(1, -1, 0, 0, 0, 1))
    end)
    withUnit("player", "fontShadow", false, function()
      assertEqual(NS.GetFontShadow("player"), false)
    end)
  end)
  Skin:SetIgnore(OWNER, nil, false)
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  if not ok then error(err, 0) end
end)

test("the shadow lands on a font object where the client has CreateFont", onSkin("obsidian", function()
  -- A 12.0.7 client draws only a font object's shadow (LibKa0s Skin doc, FS-T1), so the bar's text
  -- wears a font object of its own. red under: the shadow set on the FontString alone.
  local handed = {}
  local function object(name)
    local o = { name = name, calls = {} }
    for _, m in ipairs({ "SetFont", "SetShadowColor", "SetShadowOffset" }) do
      o[m] = function(_, ...) o.calls[m] = { ... } end
    end
    return o
  end
  local saved, fs = rawget(_G, "CreateFont"), NS.bars.player.valueText
  local savedSet = fs.SetFontObject
  rawset(_G, "CreateFont", object)
  fs.SetFontObject = function(_, o) handed[#handed + 1] = o end
  local ok, err = pcall(function()
    NS.UpdateBarAppearance("player")
    local o = handed[#handed]
    assertTrue(o ~= nil, "the value text took a font object")
    local x, y, r, g, b, a = S.HudShadow()
    assertEqual(rgba(unpack(o.calls.SetShadowOffset)), rgba(x, y))
    assertEqual(rgba(unpack(o.calls.SetShadowColor)), rgba(r, g, b, a))
    assertEqual(o.calls.SetFont[1], NS.GetFont("player"))
  end)
  rawset(_G, "CreateFont", saved)
  fs.SetFontObject = savedSet
  NS.__ResetValueFonts()
  if not ok then error(err, 0) end
end))

-- ── the one step ─────────────────────────────────────────────────────────────────────────────

local function partial()
  return {
    schemaVersion = 3,
    skin = { source = "ka0s", skin = "obsidian", ignorePanel = false, ignoreFonts = true },
    units = {
      player = {
        font = "My Font", barTexture = "My Bar", bgTexture = "My Bg", border = "My Border",
        borderSize = 7, fontSize = 15, fontShadow = true, fontFlags = "THICKOUTLINE",
        barColor = { r = 0.9 }, bgColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 },
        borderColor = { g = 0.5 }, fontColor = { b = 0.6, a = 1 },
        useClassColorBar = true, useClassColorText = false,
        barTextureFromSkin = false, fontFromSkin = false, fontShadowFromSkin = false,
      },
      -- A companion absent, a color with one key.
      target = { barColor = { a = 0.5 }, mirror = false, enabled = true },
      -- focus: the whole sub-table is missing.
    },
  }
end

test("the step: every listed key follows, every stored pick and color is byte-identical", function()
  local p = partial()
  local keep = deep(p.units.player)
  assertEqual(NS.ResetProfileToSkin(p), true, "it ran")
  for _, unit in ipairs({ "player", "target" }) do
    for _, key in ipairs(NS.Units.SKIN_COMPANION_KEYS) do
      assertEqual(p.units[unit][key], true, unit .. "." .. key)
    end
    assertEqual(p.units[unit].fontFlags, "@skin", unit .. "'s flags, the one named pick")
  end
  assertEqual(p.units.focus, nil, "a path through a missing table is skipped")
  for key, value in pairs(keep) do
    if not key:match("FromSkin$") and key ~= "fontFlags" then
      assertEqual(dump(p.units.player[key]), dump(value), key .. " is untouched")
    end
  end
  for unit, c in pairs(p.units) do
    for key, value in pairs(c) do
      assertTrue(value ~= "@skin" or key == "fontFlags", unit .. "." .. key .. " holds the sentinel")
    end
  end
  assertEqual(p.units.player.useClassColorBar, true, "a class toggle stays")
  assertEqual(p.units.player.useClassColorText, false, "a class toggle stays")
  assertEqual(p.skin.ignorePanel, false, "skin.ignorePanel stays")
  assertEqual(p.skin.ignoreFonts, true, "skin.ignoreFonts stays")
  assertEqual(p.skin.fullSkinReset, true, "recorded per profile")
end)

test("the step names no size, class toggle, Scope key or color", function()
  local banned = { fontSize = 1, barWidth = 1, barHeight = 1, useClassColorBar = 1, useClassColorBg = 1,
    useClassColorBorder = 1, useClassColorText = 1, barColor = 1, bgColor = 1, borderColor = 1,
    fontColor = 1, fontShadow = 1, font = 1, barTexture = 1, bgTexture = 1, border = 1, borderSize = 1 }
  for _, key in ipairs(NS.Units.SKIN_RESET_KEYS) do
    assertEqual(banned[key], nil, key)
  end
  assertEqual(#NS.Units.SKIN_RESET_KEYS, #NS.Units.SKIN_COMPANION_KEYS + 1, "the flags are the one extra")
end)

test("a second run writes nothing, and a companion turned off afterwards stays off", function()
  local p = partial()
  NS.ResetProfileToSkin(p)
  local once = dump(p)
  assertEqual(NS.ResetProfileToSkin(p), false, "the record stops it")
  assertEqual(dump(p), once, "a second run writes nothing")
  p.units.player.barColorFromSkin = false
  p.units.player.fontFlags = "OUTLINE"
  assertEqual(NS.ResetProfileToSkin(p), false)
  assertEqual(p.units.player.barColorFromSkin, false, "the player's later choice stays")
  assertEqual(p.units.player.fontFlags, "OUTLINE", "and a flag picked later")
end)

test("the step is the same write with the library absent", function()
  local real = mocks.LibStub
  mocks.LibStub = setmetatable({}, { __call = function(_, name, silent)
    if name == "LibKa0s-Skin-1.0" then return nil end
    return real(name, silent)
  end })
  local p, q = partial(), partial()
  local ok, err = pcall(NS.ResetProfileToSkin, p)
  mocks.LibStub = real
  if not ok then error(err, 0) end
  NS.ResetProfileToSkin(q)
  assertEqual(dump(p), dump(q), "by hand and through ResetToSkin agree")
  assertEqual(p.units.focus, nil, "no table on the way")
end)

test("the ladder walks every stored profile, and a profile change runs the step", function()
  local steps = NS.__migrationSteps
  local step = steps[#steps]
  assertEqual(step.to, 8)
  local a, b = partial(), partial()
  local saved = NS.db
  NS.db = { profile = a, global = {}, sv = { profiles = { Default = a, Raid = b } } }
  local ok, err = pcall(step.apply, a)
  NS.db = saved
  if not ok then error(err, 0) end
  assertEqual(a.skin.fullSkinReset, true, "the active profile")
  assertEqual(b.skin.fullSkinReset, true, "an inactive profile")
  assertEqual(b.units.player.barColorFromSkin, true)

  local p = NS.db.profile
  local keptRecord, keptFlag = p.skin.fullSkinReset, p.units.player.fontColorFromSkin
  p.skin.fullSkinReset, p.units.player.fontColorFromSkin = false, false
  NS.OnProfileChanged()
  assertEqual(p.skin.fullSkinReset, true, "adoptProfile ran the step")
  assertEqual(p.units.player.fontColorFromSkin, true)
  p.skin.fullSkinReset, p.units.player.fontColorFromSkin = keptRecord, keptFlag
end)
