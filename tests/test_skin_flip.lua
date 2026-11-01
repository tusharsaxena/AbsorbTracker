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
  assertEqual(size.disabledIf(size), false, "a skin's None leaves the thickness live")
  assertEqual(size.skinValue(size), nil, "and shows the stored size")
end)

-- ── what the bars draw ───────────────────────────────────────────────────────────────────────

--- The shadow the player's value text draws, read off the appearance pass: `x, y, r, g, b, a`, or
--- false for none. The mock client has no CreateFont, so S.HudFont writes on the string.
local function drawnShadow()
  local fs = NS.bars.player.valueText
  local color, offset
  local savedColor, savedOffset = rawget(fs, "SetShadowColor"), rawget(fs, "SetShadowOffset")
  fs.SetShadowColor = function(_, ...) color = { ... } end
  fs.SetShadowOffset = function(_, ...) offset = { ... } end
  local ok, err = pcall(NS.UpdateBarAppearance, "player")
  fs.SetShadowColor, fs.SetShadowOffset = savedColor, savedOffset
  if not ok then error(err, 0) end
  if offset[1] == 0 and offset[2] == 0 and color[4] == 0 then return false end
  return offset[1], offset[2], color[1], color[2], color[3], color[4]
end

test("Ka0s Default keeps this addon's pixels: fill, background, border, text, no shadow", function()
  local d = NS.unitDefaults
  assertEqual(rgba(NS.GetBarColor("player")), rgba(d.barColor.r, d.barColor.g, d.barColor.b, d.barColor.a))
  assertEqual(rgba(NS.GetBgColor("player")), rgba(d.bgColor.r, d.bgColor.g, d.bgColor.b, d.bgColor.a))
  assertEqual(rgba(NS.GetBorderColor("player")),
    rgba(d.borderColor.r, d.borderColor.g, d.borderColor.b, d.borderColor.a))
  assertEqual(rgba(NS.GetFontColor("player")), rgba(1, 1, 1, 1))
  assertEqual(drawnShadow(), false, "Ka0s Default draws no HUD shadow")
end)

test("a skin switch changes every flipped surface", function()
  local before = { rgba(NS.GetBarColor("player")), rgba(NS.GetBgColor("player")),
    rgba(NS.GetBorderColor("player")), rgba(NS.GetFontColor("player")),
    NS.GetBarTexture("player"), NS.GetFont("player") }
  local bar = NS.bars.player
  local drawn = {}
  local function spy(frame, method)
    frame[method] = function(_, ...) drawn[method] = rgba(...) end
  end
  spy(bar.statusBar, "SetStatusBarColor")
  spy(bar, "SetBackdropColor")
  spy(bar.border, "SetBackdropBorderColor")
  local ok, err = pcall(onSkin("obsidian", function()
    assertEqual(rgba(NS.GetBarColor("player")), rgba(S.BarFillColor()), "fill: the skin's bar.fill")
    assertEqual(rgba(NS.GetBgColor("player")), rgba(S.Color("bar.bg")), "background: bar.bg")
    assertEqual(rgba(NS.GetBorderColor("player")), rgba(S.Color("bar.border")), "border: bar.border")
    assertEqual(rgba(NS.GetFontColor("player")), rgba(S.HudTextColor()), "text: hud.text")
    assertTrue(rgba(NS.GetBarColor("player")) ~= before[1], "the fill moved")
    assertTrue(rgba(NS.GetBgColor("player")) ~= before[2], "the background moved")
    assertTrue(rgba(NS.GetBorderColor("player")) ~= before[3], "the border moved")
    assertTrue(rgba(NS.GetFontColor("player")) ~= before[4], "the text moved")
    local x, y, r, g, b, a = S.HudShadow()
    assertEqual(rgba(drawnShadow()), rgba(x, y, r, g, b, a), "shadow: hud.shadow")
    -- The bar itself, not only its getters: red under a surface that keeps its old value.
    NS.UpdateBarAppearance("player")
    assertEqual(drawn.SetStatusBarColor, rgba(S.BarFillColor()), "the fill as drawn")
    assertEqual(drawn.SetBackdropColor, rgba(S.Color("bar.bg")), "the background as drawn")
    assertEqual(drawn.SetBackdropBorderColor, rgba(S.Color("bar.border")), "the border as drawn")
  end))
  bar.statusBar.SetStatusBarColor, bar.SetBackdropColor, bar.border.SetBackdropBorderColor = nil, nil, nil
  NS.UpdateBarAppearance("player")
  if not ok then error(err, 0) end
end)

test("a skin that says no shadow draws none, whatever the stored row says", function()
  -- red under: hud.shadow's `false` falling through to the stored fontShadow.
  withUnit("player", "fontShadowFromSkin", true, function()
    withUnit("player", "fontShadow", true, function()
      assertEqual(S.HudShadow(), false, "Ka0s Default's hud.shadow")
      assertEqual(drawnShadow(), false, "no shadow drawn")
    end)
  end)
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
      assertEqual(drawnShadow(), false, "stored off")
    end)
    withUnit("player", "fontShadow", true, function()
      assertEqual(rgba(drawnShadow()), rgba(1, -1, 0, 0, 0, 1), "stored on")
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
      assertEqual(rgba(drawnShadow()), rgba(1, -1, 0, 0, 0, 1))
    end)
    withUnit("player", "fontShadow", false, function()
      assertEqual(drawnShadow(), false)
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
  Skin.__hudFonts[fs] = nil
  if not ok then error(err, 0) end
end))

-- ── gloss (FS-AT-FIX, cause A3) ──────────────────────────────────────────────────────────────

--- `body(bar, gloss)` with the player's bar swapped for a fresh one on the kit's paint recorder: the
--- base mock's bars are no StatusBar, and the library leaves those alone. `gloss()` is the layer.
local function withGlossBar(body)
  local restorePaint = dofile("tests/_kit/mock_paint.lua")(mocks)
  local savedCreate = rawget(_G, "CreateFrame")
  rawset(_G, "CreateFrame", mocks.CreateFrame)
  local made, built = pcall(NS.CreateBar, "player", "AbsorbTrackerGlossProbe")
  rawset(_G, "CreateFrame", savedCreate)
  if not made then restorePaint() error(built, 0) end
  local real = NS.bars.player
  NS.bars.player = built
  local ok, err = pcall(body, built, function()
    local rec = Skin.painted[built.statusBar]
    return rec and rec.regions.gloss
  end)
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  NS.bars.player = real
  Skin:Untrack(built.statusBar)
  restorePaint()
  if not ok then error(err, 0) end
end

test("a glossy skin glosses the fill; Ka0s Default and the player's own texture do not", function()
  -- red under: a bar that never reads bar.gloss, or a gloss left on after the skin moved on.
  withGlossBar(function(_, gloss)
    NS.UpdateBarAppearance("player")
    assertEqual(gloss(), nil, "Ka0s Default has none")
    Skin:SetChoice(OWNER, "ka0s", "glass")
    NS.UpdateBarAppearance("player")
    assertTrue(gloss() ~= nil, "Glass has it")
    assertEqual(gloss():IsShown(), true, "the layer shows")
    withUnit("player", "barTextureFromSkin", false, function()
      NS.UpdateBarAppearance("player")
      assertEqual(gloss():IsShown(), false, "the player's own texture stays plain")
      -- red under: a call that omits the companion, which a replay would shine again.
      Skin:SetChoice(OWNER, "ka0s", "obsidian")
      Skin:SetChoice(OWNER, "ka0s", "glass")
      assertEqual(gloss():IsShown(), false, "and through a skin switch's replay")
    end)
    NS.UpdateBarAppearance("player")
    assertEqual(gloss():IsShown(), true, "the companion back on")
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    assertEqual(gloss():IsShown(), false, "a switch away takes it off")
  end)
end)

test("the gloss layer is built on the fill, in the one white look", function()
  -- red under: an anchor on the bar's corner, a shine past the fill's end (SKIN-40's fail case).
  withGlossBar(function(bar, gloss)
    Skin:SetChoice(OWNER, "ka0s", "glass")
    NS.UpdateBarAppearance("player")
    local layer, fill = gloss(), bar.statusBar:GetStatusBarTexture()
    assertEqual(layer:GetNumPoints(), 2, "two anchors")
    local topPoint, topRegion, topRelative = layer:GetPoint(1)
    local bottomPoint, bottomRegion, bottomRelative = layer:GetPoint(2)
    assertEqual(topPoint .. ">" .. topRelative, "TOPLEFT>TOPLEFT", "its top")
    assertEqual(bottomPoint .. ">" .. bottomRelative, "BOTTOMRIGHT>RIGHT", "its half-way line")
    assertTrue(topRegion == fill, "the top anchors to the fill")
    assertTrue(bottomRegion == fill, "the bottom anchors to the fill")
    local g = mocks.__paint(layer).gradient
    assertEqual(g.orientation, "VERTICAL")
    assertEqual(rgba(g.min.r, g.min.g, g.min.b, g.min.a), rgba(1, 1, 1, 0), "clear at the middle")
    assertEqual(rgba(g.max.r, g.max.g, g.max.b, g.max.a), rgba(1, 1, 1, 0.25), "the strength it had")
  end)
end)

test("with no library the facade draws no gloss, and HudFont still gives the text its face", function()
  -- red under: a no-op HudFont, which leaves the value text with no face, or one shadow arm dropped.
  local NS2 = dofile("tests/degraded_env.lua")()
  local S2 = NS2.Skin
  assertEqual(S2.BarGloss({}, true), nil, "nothing to draw, and nothing raised")
  local calls = {}
  local fs = {}
  for _, m in ipairs({ "SetFont", "SetShadowColor", "SetShadowOffset" }) do
    fs[m] = function(_, ...) calls[m] = rgba(...) end
  end
  S2.HudFont(fs, { face = "Fonts\\Host.ttf", size = 14, flags = "OUTLINE", shadow = true, shadowFromSkin = true })
  assertEqual(calls.SetFont, rgba("Fonts\\Host.ttf", 14, "OUTLINE"))
  assertEqual(calls.SetShadowColor, rgba(0, 0, 0, 1))
  assertEqual(calls.SetShadowOffset, rgba(1, -1))
  S2.HudFont(fs, { face = "Fonts\\Host.ttf", size = 14, flags = "OUTLINE", shadow = false })
  assertEqual(calls.SetShadowColor, rgba(0, 0, 0, 0), "the off arm writes")
  assertEqual(calls.SetShadowOffset, rgba(0, 0))
  S2.HudFont(fs, { face = "Fonts\\Host.ttf", size = 0, flags = "@skin" })
  assertEqual(calls.SetFont, rgba("Fonts\\Host.ttf", 12, "OUTLINE"), "the sentinel never reaches SetFont")
end)

test("with no library the stored border stands, and the shipped None draws no edge", function()
  -- red under: a no-op BarBorder, or a None that fetches the tooltip fallback.
  local NS2 = dofile("tests/degraded_env.lua")()
  local style, show, size = NS2.Skin.BarBorder("Blizzard Dialog", false, 7, true)
  assertEqual(style, "Blizzard Dialog")
  assertEqual(show, false)
  assertEqual(size, 7)
  assertEqual(NS2.Skin.HoverArt({}), nil, "nothing to tint, and nothing raised")
  assertEqual(NS2.Widgets.ContextMenu(), nil, "no menu, and nothing raised")
  assertEqual(NS2.GetBorder("player"), nil)
end)

-- ── the one step ─────────────────────────────────────────────────────────────────────────────

--- `body` with the store swapped for `profile`, the account stamp at `stamp`.
local function withStore(profile, stamp, body)
  local saved = NS.db
  NS.db = { profile = profile, global = { schemaVersion = stamp } }
  local ok, err = pcall(body)
  NS.db = saved
  if not ok then error(err, 0) end
end

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
  -- red under: FollowOnce called once per unit, which writes the record on the entry.
  assertEqual(p.units.player.skin, nil, "no stray skin table on an entry")
  assertEqual(p.units.target.skin, nil, "no stray skin table on an entry")
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

test("General's Defaults keeps the record, so the next migration leaves a turned-off companion off", function()
  -- red under: the record out of resetExempt (settings/Schema.lua). The press put it back to false,
  -- and the next RunMigrations or profile event forced every companion on and the flags to "@skin".
  local p = NS.db.profile
  local saved = deep(p)
  local ok, err = pcall(function()
    p.skin.fullSkinReset = true
    p.units.player.barColorFromSkin = false
    p.units.target.fontFlags = "OUTLINE"
    NS.Helpers.RestoreDefaults("general", {})
    assertEqual(p.skin.fullSkinReset, true, "the record survives the press")
    NS:RunMigrations()
    assertEqual(p.units.player.barColorFromSkin, false, "the migration")
    assertEqual(p.units.target.fontFlags, "OUTLINE", "the flag the player picked")
    NS.OnProfileChanged()
    assertEqual(p.units.player.barColorFromSkin, false, "a profile event")
  end)
  for key, value in pairs(saved) do p[key] = value end
  NS.OnProfileChanged()
  if not ok then error(err, 0) end
end)

test("past the stamp the runner still moves an active profile with no record", function()
  -- red under: a bare runLadder call at the end of RunMigrations.
  local p = partial()
  withStore(p, NS.SCHEMA_VERSION, function() NS:RunMigrations() end)
  assertEqual(p.skin.fullSkinReset, true, "recorded")
  assertEqual(p.units.player.barColorFromSkin, true, "a companion it had off")
  assertEqual(p.units.player.fontFlags, "@skin", "and the flags")
end)

test("a failed ladder step stops the run before the step onto the skin", function()
  -- red under: runLadder's failure answering `break` and so reporting success.
  local p = partial()
  local steps = NS.__migrationSteps
  steps[#steps + 1] = { to = NS.SCHEMA_VERSION + 1, apply = function() error("boom") end }
  local ok, err = pcall(withStore, p, NS.SCHEMA_VERSION, function() NS:RunMigrations() end)
  steps[#steps] = nil
  if not ok then error(err, 0) end
  assertEqual(p.skin.fullSkinReset, nil, "no record")
  assertEqual(p.units.player.fontShadowFromSkin, false, "a companion it did not touch")
  assertEqual(p.units.player.fontFlags, "THICKOUTLINE", "and the flags")
end)

test("the step creates the record's table on a raw profile with none", function()
  -- red under: ResetProfileToSkin no longer creating p.skin.
  local p = { units = { player = { barColorFromSkin = false } } }
  assertEqual(NS.ResetProfileToSkin(p), true, "it ran")
  assertEqual(p.skin.fullSkinReset, true, "recorded")
  assertEqual(p.units.player.barColorFromSkin, true)
  assertEqual(NS.ResetProfileToSkin(p), false, "and the record stops the next one")
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
  local step = steps[#steps - 1]
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

-- ── the bar border under a skin's None and a real style (FS-AT-GATE) ─────────────────────────

test("an untouched bar draws no edge and keeps its inset under Ka0s Default", function()
  -- red under: a shipped real style, which a skin's None hands back and draws on every profile.
  assertEqual(NS.defaults.profile.units.player.border, "None")
  NS.UpdateBarAppearance("player")
  assertEqual(NS.MediaKey("player", "border"), "None")
  assertEqual(NS.GetBorderSize("player"), S.Token("bar.borderSize"), "not the stored 12")
  assertEqual(NS.bars.player.backdropInfo.insets.left, 1, "the background's inset did not move")
end)

test("a skin's None defers to the player's stored style and size, companion on", function()
  -- red under: S.Resolve read as the skin's whatever it answered, or a report saying the skin's.
  withUnit("player", "border", "Blizzard Dialog", function()
    withUnit("player", "borderSize", 7, function()
      local style, fromSkin = NS.MediaKey("player", "border")
      assertEqual(style, "Blizzard Dialog")
      assertEqual(fromSkin, false, "the player's, and the report says so")
      assertEqual(NS.GetBorderSize("player"), 7)
    end)
  end)
end)

test("a real style in a skin wins over the player's, and the companion off gives it back", onSkin("azeroth", function()
  -- red under: a host that reads the stored style while the companion is on.
  assertTrue(S.Token("bar.borderStyle") ~= "None", "this skin states a real style")
  withUnit("player", "border", "Blizzard Dialog", function()
    local style, fromSkin = NS.MediaKey("player", "border")
    assertEqual(style, S.Token("bar.borderStyle"))
    assertEqual(fromSkin, true)
    assertEqual(NS.GetBorderSize("player"), S.Token("bar.borderSize"))
    withUnit("player", "borderFromSkin", false, function()
      assertEqual(NS.MediaKey("player", "border"), "Blizzard Dialog")
    end)
  end)
end))

test("v9 moves a stored old default to None, once, and leaves a pick and a companion off", function()
  -- red under: a step that sweeps every style, or one that runs past the account-wide stamp.
  local steps = NS.__migrationSteps
  local step = steps[#steps]
  assertEqual(step.to, 9)
  local a = { units = {
    player = { border = "Blizzard Tooltip" },
    target = { border = "Blizzard Dialog" },
    focus  = { border = "Blizzard Tooltip", borderFromSkin = false },
  } }
  local b = { units = { player = { border = "Blizzard Tooltip", borderSize = 6 } } }
  local saved = NS.db
  NS.db = { profile = a, global = {}, sv = { profiles = { Default = a, Raid = b } } }
  local ok, err = pcall(step.apply, a)
  NS.db = saved
  if not ok then error(err, 0) end
  assertEqual(a.units.player.border, "None", "the old default")
  assertEqual(b.units.player.border, "None", "on an inactive profile too")
  assertEqual(b.units.player.borderSize, 6, "a stored thickness stays")
  assertEqual(a.units.target.border, "Blizzard Dialog", "a real pick stays")
  assertEqual(a.units.focus.border, "Blizzard Tooltip", "a companion off keeps what it drew")
  assertEqual(b.units.target, nil, "no table on the way")
end)
