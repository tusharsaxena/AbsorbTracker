-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§3).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the folder name with this addon's read and write seams; the seven `skin.*` keys
-- default to Ka0s Default and are skip-render schema rows on General's Skin tab; the tab lands last
-- on General; the profile's skin is applied right after AceDB exists and on every profile event;
-- one pick, from this addon's tab or another addon's copy, is ONE effective SetChoice (one
-- OnLooksChanged), however many store writes follow it; and the drag strips carry the owner.
--
-- Modeled on LootHistory's tests/test_skinsetup.lua, the reference adopter. After test_widgets,
-- which leaves the General page built and parked on its first tab; every case here parks it there
-- again and puts the skin back on Ka0s Default.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "AbsorbTracker"

-- ONE listener for the whole file: the library keeps a listener for the session, so each case
-- resets the counter instead of registering again.
local looks = 0
NS.Skin.OnLooksChanged(function() looks = looks + 1 end)

--- Back on Ka0s Default, stored and applied, with the Scope's defaults and no overrides, the
--- library's deferred page re-render run, and the counter cleared.
local function reset()
  NS.WriteSkinChoice("ka0s", "ka0s", { panel = true, fonts = false }, { font = false, texture = false })
  Skin:SetChoice(OWNER, "ka0s", "ka0s")
  Skin:SetIgnore(OWNER, true, false)
  if Skin.SetOverride then Skin:SetOverride(OWNER, false, false) end
  mocks.__fireTimers()
  looks = 0
end

--- Run `fn` with the skin reset before and after, whatever `fn` raised.
local function clean(fn)
  return function()
    reset()
    local ok, err = pcall(fn)
    reset()
    if not ok then error(err, 0) end
  end
end

--- `/at <line>` with chat swallowed.
local function quietly(line)
  local cf = mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function() end
  local ok, err = pcall(function() NS.Slash:OnSlash(line) end)
  cf.AddMessage = old
  if not ok then error(err, 0) end
end

local function generalCtx()
  for _, c in ipairs(NS.Helpers.__panels()) do
    if c.pageKey == "general" and c.scroll then return c end
  end
end

local function tabButtons(ctx)
  local out = {}
  for _, f in ipairs(ctx.__tabKids or {}) do
    if f.__frameType == "Button" then out[#out + 1] = f end
  end
  return out
end

--- Every widget under `w` whose label ends with `name`.
local function widgetNamed(w, name)
  for _, child in ipairs(w.children or {}) do
    local label = tostring(child.labelText or "")
    if child.type == "CheckBox" and label:sub(-#name) == name then return child end
    local found = widgetNamed(child, name)
    if found then return found end
  end
end

--- Open General's Skin tab (the third), run `fn(ctx)`, and park the page on its first tab again.
local function onSkinTab(fn)
  local panel = mocks.__subcategories["General"]
  panel:__fire("OnShow")
  local ctx = generalCtx()
  assertTrue(ctx ~= nil, "the General page rendered")
  tabButtons(ctx)[3]:__fire("OnClick")
  local ok, err = pcall(fn, ctx)
  tabButtons(ctx)[1]:__fire("OnClick")
  if not ok then error(err, 0) end
end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the owner is the folder name, and NS.Skin is its facade", function()
  -- red under: registering under the brand or a typo (the library keys every frame and every
  -- listener by owner), or publishing a facade of some other owner.
  assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner")
  assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"AbsorbTracker\")")
  assertEqual(NS.Skin.owner, OWNER)
  assertEqual(Skin:OwnerLabel(OWNER), NS.Constants.BRAND, "the copy confirmation names the brand")
end)

test("Skin seam: the read answers Ka0s Default before the profile store exists", function()
  -- RegisterOwner calls `get` at FILE LOAD, before NS:InitDB; a getter that raised there would be a
  -- visible Lua error on every login.
  local db = NS.db
  NS.db = nil
  local ok, source, skin = pcall(NS.SkinChoice)
  local ok2, font, texture = pcall(NS.SkinOverride)
  NS.db = db
  assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
  assertEqual(source, "ka0s")
  assertEqual(skin, "ka0s")
  assertTrue(ok2, "NS.SkinOverride raised without a store: " .. tostring(font))
  assertEqual(font, false)
  assertEqual(texture, false)
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

test("Skin seam: the seven skin keys default to Ka0s Default, as skip-render rows on General", function()
  -- red under: a default other than today's look, or a row that renders itself on top of the
  -- library's tab. pickerSeen false on every profile is the rollout's O3.
  local d = NS.defaults.profile.skin
  assertEqual(d.source, "ka0s")
  assertEqual(d.skin, "ka0s")
  assertEqual(d.ignorePanel, true, "the settings panel stays the client's on a new profile")
  assertEqual(d.ignoreFonts, false)
  assertEqual(d.font, "")
  assertEqual(d.texture, "")
  assertEqual(d.pickerSeen, false, "every profile sees the first-run picker once (O3)")
  for field in pairs(d) do
    local path = "skin." .. field
    local row = NS.FindSchemaRow(path)
    assertTrue(row ~= nil, path .. " is not a schema row")
    assertEqual(row.page, "general", path .. ": page")
    assertEqual(row.group, "Appearance", path .. ": group (the library tab's key)")
    assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
    assertTrue(type(row.onChange) == "function", path .. ": a declared onChange, never APPEARANCE")
  end
end)

test("Skin seam: the skin row's values are every registered skin, in the library's order", function()
  local values = NS.FindSchemaRow("skin.skin").values
  local skins = Skin:Skins()
  assertEqual(#values, #skins, "one value per registered skin")
  for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
  assertEqual(values[1].value, "ka0s", "Ka0s Default first")
end)

test("Skin seam: /at set refuses a skin that is not registered and applies one that is", clean(function()
  quietly("set skin.skin no-such-skin")
  assertEqual(NS.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
  assertEqual(looks, 0, "a refused set repainted")
  quietly("set skin.skin obsidian")
  assertEqual(NS.db.profile.skin.skin, "obsidian", "a registered skin was refused")
  local _, applied = Skin:GetChoice(OWNER)
  assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
  assertEqual(looks, 1, "one set, one repaint")
end))

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

test("Skin seam: the Skin tab is General's last, and opens", function()
  onSkinTab(function(ctx)
    assertEqual(#tabButtons(ctx), 3, "Master controls, Behavior, Skin")
    assertEqual(ctx.activeTab, "Appearance", "the third tab is the library's Skin tab")
  end)
end)

test("Skin seam: one tab pick is one effective SetChoice and one repaint", clean(function()
  -- The tab calls SetChoice first, then the write seam, which writes the rows through
  -- NS.SetByPath; each row's onChange applies only its own half and finds it applied already.
  -- red under: an onChange that re-applies the whole stored pair (two repaints), or a seam that
  -- writes the profile around NS.SetByPath.
  onSkinTab(function(ctx)
    local cb = widgetNamed(ctx.scroll, "Obsidian")
    assertTrue(cb ~= nil, "the Skin tab drew no Obsidian choice")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    assertEqual(looks, 1, "one pick must repaint exactly once")
    local source, skin = Skin:GetChoice(OWNER)
    assertEqual(source, "ka0s")
    assertEqual(skin, "obsidian", "the pick did not move the applied skin")
    assertEqual(NS.db.profile.skin.skin, "obsidian", "the pick did not reach the profile")
  end)
end))

test("Skin seam: the tab's Ignore fonts reaches the library and the profile, one repaint", clean(function()
  onSkinTab(function(ctx)
    local cb = widgetNamed(ctx.scroll, "Ignore fonts")
    assertTrue(cb ~= nil, "the Skin tab drew no Ignore fonts box")
    cb:SetValue(true); cb:__fire("OnValueChanged", true)
    local panel, fonts = Skin:GetIgnore(OWNER)
    assertEqual(fonts, true, "the library's exception moved")
    assertEqual(panel, true, "and the other kept")
    assertEqual(NS.db.profile.skin.ignoreFonts, true, "the profile holds it")
    assertEqual(NS.db.profile.skin.ignorePanel, true)
    assertEqual(looks, 1, "one toggle repaints once")
  end)
end))

test("Skin seam: another addon's copy to every Ka0s addon repaints AbsorbTracker once", clean(function()
  -- The library's copy calls SetChoice for each other owner, then WriteChoice, which reaches this
  -- addon's registered setter. Driven directly, as the copy drives it.
  Skin:SetChoice(OWNER, "ka0s", "ember")
  assertTrue(Skin:WriteChoice(OWNER, "ka0s", "ember"), "the copy's write did not reach the setter")
  assertEqual(looks, 1, "a copy must repaint this addon exactly once")
  assertEqual(NS.db.profile.skin.skin, "ember", "the copy did not land in the profile")
end))

-- ── the stored exceptions and overrides ──────────────────────────────────────────────────────

test("Skin seam: a whole apply carries the stored exceptions and overrides with the skin", clean(function()
  -- addon:OnInitialize and the profile events call NS.ApplySkinChoice() with no argument.
  -- red under: applying the stored pair and not the rest.
  T.rawSet("skin.ignorePanel", false)
  T.rawSet("skin.ignoreFonts", true)
  T.rawSet("skin.texture", "Solid")
  NS.ApplySkinChoice()
  local panel, fonts = Skin:GetIgnore(OWNER)
  assertEqual(panel, false, "the stored panel exception")
  assertEqual(fonts, true, "the stored fonts exception")
  local _, texture = Skin:GetOverride(OWNER)
  assertEqual(texture, "Solid", "the stored texture override")
end))

test("Skin seam: /at set reaches an exception and an override, each only its own half", clean(function()
  quietly("set skin.ignoreFonts true")
  local panel, fonts = Skin:GetIgnore(OWNER)
  assertEqual(fonts, true, "the set applied")
  assertEqual(panel, true, "the other half untouched")
  quietly("set skin.font Friz Quadrata TT")
  local font, texture = Skin:GetOverride(OWNER)
  assertEqual(font, "Friz Quadrata TT", "a free-text font key is taken and applied")
  assertEqual(texture, nil, "the texture override untouched (nil, the skin's own)")
  assertEqual(NS.db.profile.skin.font, "Friz Quadrata TT")
end))

-- ── the profile events ───────────────────────────────────────────────────────────────────────

test("Skin seam: a profile switch applies the new profile's skin, and back", clean(function()
  -- AceDB replaces the whole profile with no row's onChange firing; adoptProfile
  -- (core/AbsorbTracker.lua) must apply the new profile's skin. red under: not applying it.
  local db = NS.db
  local ok, err = pcall(function()
    db:SetProfile("SkinProbe")
    T.rawSet("skin.skin", "glass")
    db:SetProfile("Default")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "ka0s", "back on Default, Default's skin")
    looks = 0
    db:SetProfile("SkinProbe")
    assertEqual(select(2, Skin:GetChoice(OWNER)), "glass", "the switch did not move the applied skin")
    assertEqual(looks, 1, "one switch, one repaint")
  end)
  if db:GetCurrentProfile() ~= "Default" then db:SetProfile("Default") end
  if db.DeleteProfile then pcall(db.DeleteProfile, db, "SkinProbe", true) end
  if not ok then error(err, 0) end
end))

-- ── the factories ────────────────────────────────────────────────────────────────────────────

test("Skin seam: every bar's drag strip is built with this owner, so a switch repaints it", clean(function()
  -- modules/Bar.lua hands `owner = addonName` to LibKa0s-Widgets-1.0's DragHandle (minor 6). The
  -- strip's fill is `handle.bg`; a skin whose `handle.bg` differs from Ka0s Default's must reach it.
  -- red under: a strip built with no owner (it keeps the widget's own palette through every skin).
  for _, unit in ipairs({ "player", "target", "focus" }) do
    local handle = NS.bars[unit] and NS.bars[unit].handle
    assertTrue(handle ~= nil, unit .. ": no drag strip")
    assertTrue(handle.__pal ~= nil, unit .. ": the strip carries no palette")
  end
  local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for i = 1, 4 do
      if math.abs((a[i] or 1) - (b[i] or 1)) > 1e-6 then return false end
    end
    return true
  end
  assertTrue(same(NS.bars.player.handle.__pal.bg, Skin:Token(OWNER, "handle.bg")),
    "Ka0s Default's strip fill is the owner's token")
  Skin:SetChoice(OWNER, "ka0s", "ember")
  local ember = Skin:Token(OWNER, "handle.bg")
  assertTrue(same(NS.bars.player.handle.__pal.bg, ember),
    "a skin switch did not repaint the strip from the owner's skin")
end))
