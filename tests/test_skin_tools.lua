-- tests/test_skin_tools.lua — the AceGUI rows this addon acquires itself, and the tool surfaces,
-- on the skin (AT-04; core/SkinSetup.lua's owner, skinning-§3).
--
-- What this pins:
--
--   * the Appearance page's chrome block (the Unit dropdown, the enable box, Link to Player, Copy
--     from Player; settings/UnitPanel.lua) is painted for this owner through NS.SkinPaintAce,
--     whichever AceGUI handle the page was given, and the Scope's Ignore settings panel (on by
--     default) leaves it stock, so Ka0s Default's settings pages look as they did;
--   * the Profiles page's AceConfigDialog tree is painted through NS.SkinPaintAceTree after each
--     Open (the page cannot be built here, AceDBOptions is not mocked, so the call is read off the
--     source and the helper is driven on a hand-built tree);
--   * the debug console, its copy window and the perf panel, all the library's, are drawn for this
--     owner: their descriptors name the folder and pass no host skin hook.
--
-- No sim, no test strip, no copy window of its own and no tooltip lines of its own: the inventory
-- (S6-S7, S13-S14) found nothing else to own. Modeled on LootHistory's tests/test_skin_tools.lua.
-- After test_skin_picker; leaves the Scope on its defaults and the skin on Ka0s Default.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local RawAceGUI = mocks.LibStub("AceGUI-3.0")
local OWNER = "AbsorbTracker"

local function ownerOf(w)
  local st = Skin.__ace and Skin.__ace[w]
  return st and st.owner
end

local function readFile(path)
  local fh = assert(io.open(path, "rb"))
  local body = fh:read("*a")
  fh:close()
  return body
end

--- Run `fn` with the settings panel skinned (Ignore settings panel off), the Scope put back on its
--- defaults after, whatever `fn` raised.
local function panelSkinned(fn)
  return function()
    Skin:SetIgnore(OWNER, false, false)
    local ok, err = pcall(fn)
    Skin:SetIgnore(OWNER, true, false)
    mocks.__fireTimers()
    if not ok then error(err, 0) end
  end
end

--- The Appearance page rendered for `unit`, its chrome widgets answered; the page back on the
--- player after `fn`.
local function onChrome(unit, fn)
  local panel = mocks.__subcategories["Appearance"]
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  assertTrue(ctx ~= nil, "the Appearance page rendered")
  ctx.unit = unit
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  local ok, err = pcall(fn, ctx.__chromeWidgets or {})
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  if not ok then error(err, 0) end
end

-- ── the AceGUI rows ──────────────────────────────────────────────────────────────────────────

test("the chrome block's four widgets are painted for this owner, even off the raw AceGUI", panelSkinned(function()
  -- red under: a Create with no NS.SkinPaintAce after it (the raw handle paints nothing itself).
  local proxy = NS.AceGUI
  NS.AceGUI = RawAceGUI
  local ok, err = pcall(onChrome, "target", function(kids)
    assertEqual(#kids, 4, "target's block: Unit, enable, Link to Player, Copy from Player")
    for i, w in ipairs(kids) do
      assertEqual(ownerOf(w), OWNER, "chrome widget " .. i .. " (" .. tostring(w.type) .. ") is painted for " .. OWNER)
    end
  end)
  NS.AceGUI = proxy
  if not ok then error(err, 0) end
end))

test("under the default Scope (Ignore settings panel) the chrome block stays stock", function()
  -- Ka0s Default must look as it did: skin.ignorePanel defaults on, so nothing is painted.
  assertEqual(NS.GetSetting("skin.ignorePanel"), true)
  onChrome("target", function(kids)
    for i, w in ipairs(kids) do
      assertEqual(ownerOf(w), nil, "chrome widget " .. i .. " was painted under Ignore settings panel")
    end
  end)
end)

test("NS.SkinPaintAceTree paints every widget under a container", panelSkinned(function()
  local group = RawAceGUI:Create("SimpleGroup")
  local box = RawAceGUI:Create("CheckBox")
  group:AddChild(box)
  local n = NS.SkinPaintAceTree(group)
  assertTrue(n >= 1, "the tree paint reached the check box under the group (got " .. tostring(n) .. ")")
  assertEqual(ownerOf(box), OWNER)
  RawAceGUI:Release(box)
  assertEqual(ownerOf(box), nil, "the release puts the widget back stock")
  RawAceGUI:Release(group)
end))

test("the Profiles page paints AceConfigDialog's tree after each Open", function()
  -- red under: the Open with no tree paint after it (the profile manager's rows stay stock).
  local src = readFile("settings/Profiles.lua")
  local open = src:find("AceConfigDialog:Open%(APPNAME, container%)")
  local paint = src:find("NS%.SkinPaintAceTree%(container%)")
  assertTrue(open ~= nil and paint ~= nil and paint > open, "SkinPaintAceTree(container) follows the Open")
  assertTrue(src:find("NS%.AceGUI or LibStub%(\"AceGUI%-3%.0\"") ~= nil,
    "the container comes from the Options instance's handle when there is one")
end)

-- ── the tool surfaces ────────────────────────────────────────────────────────────────────────

test("the debug console and its copy window are painted for this owner", function()
  local src = readFile("core/DebugLogSetup.lua")
  assertTrue(src:find("addonName%s*=%s*addonName") ~= nil, "the console descriptor names the folder")
  assertTrue(src:find("applySkin%s*=") == nil and src:find("%f[%w]skin%s*=%s*{") == nil,
    "a host skin hook opts the console out of its owner")
  NS.DebugLog:Show()
  local f = NS.DebugLog._frameForTest
  assertTrue(f ~= nil, "the console frame")
  assertTrue(rawget(f, "__logLine") ~= nil, "the console was built unowned (no palette line)")
  local rec = Skin.painted[f]
  assertTrue(rec ~= nil and rec.owner == OWNER, "the console window is recorded for " .. OWNER)
  NS.DebugLog:ShowCopy()
  local cf = NS.DebugLog._copyFrameForTest
  assertTrue(cf ~= nil, "the console's copy window")
  assertTrue(rawget(cf, "__copyDesc") ~= nil, "the copy window was not painted for an owner")
  cf:Hide()
  NS.DebugLog:Hide()
  -- ShowCopy stamps two write-only test seams on the instance; cleared, so the DebugLog parity
  -- case (tests/test_surface_parity.lua) still compares the surface the addon reaches.
  NS.DebugLog._copyWindowForTest, NS.DebugLog._copyFrameForTest = nil, nil
end)

test("the perf panel is painted for this owner", function()
  local src = readFile("core/PerfSetup.lua")
  assertTrue(src:find("addonName%s*=%s*addonName") ~= nil, "the Perf descriptor's addonName")
  NS.Perf.ShowPanel()
  local f = NS.Perf.__panel and NS.Perf.__panel()
  assertTrue(f ~= nil, "the perf panel frame")
  local rec = Skin.painted[f]
  assertTrue(rec ~= nil and rec.owner == OWNER, "the perf panel is recorded for " .. OWNER)
  NS.Perf.HidePanel()
end)
