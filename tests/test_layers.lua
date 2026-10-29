local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- Frame layering (frame-layering-§1..§5): where every frame this addon creates sits, read back
-- through the kit's opt-in frame-layer recorder (tests/_kit/mock_layers.lua).
--
-- The shared bars were built at file load, before any recorder was installed, so their strata and
-- levels answer from the base mock's metatable and cannot be read. Each case therefore installs the
-- recorder and builds a FRESH probe bar through the very constructor the three shared bars came
-- from (NS.CreateBar), then restores the mock. The probe is never put in NS.bars, so no other suite
-- sees it. The layers table itself is core/Constants.lua's NS.Constants.LAYERS.

local LAYERS = NS.Constants.LAYERS

-- Install the recorder, plus a per-frame spy on EnableMouse and CreateFontString (neither is
-- recorded by the base or by mock_layers), run `body`, and put the mock back however it ends.
local function withLayers(body)
  local restore = dofile("tests/_kit/mock_layers.lua")(M)
  local layered = M.CreateFrame
  M.CreateFrame = function(...)
    local f = layered(...)
    if type(f) == "table" then
      rawset(f, "__mouseCalls", {})
      rawset(f, "__fontStrings", 0)
      local fontString = f.CreateFontString
      rawset(f, "EnableMouse", function(self, on)
        local calls = rawget(self, "__mouseCalls")
        calls[#calls + 1] = on and true or false
      end)
      rawset(f, "CreateFontString", function(self, ...)
        rawset(self, "__fontStrings", rawget(self, "__fontStrings") + 1)
        return fontString(self, ...)
      end)
    end
    return f
  end
  local ok, err = pcall(body)
  M.CreateFrame = layered
  restore()
  if not ok then error(err, 0) end
end

local probes = 0
local function probeBar(unit)
  probes = probes + 1
  return NS.CreateBar(unit or "player", "AbsorbTrackerLayersProbe" .. probes)
end

local function lastMouse(frame)
  local calls = rawget(frame, "__mouseCalls") or {}
  return calls[#calls]
end

-- ── the table ────────────────────────────────────────────────────────────────────────────────

test("LAYERS names the HUD strata and an ordered level ladder", function()
  assertEqual(type(LAYERS), "table", "NS.Constants.LAYERS is missing")
  assertEqual(LAYERS.STRATA.HUD, "MEDIUM")
  local L = LAYERS.LEVEL
  for _, k in ipairs({ "FILL", "BORDER", "OVERLAY", "HANDLE" }) do
    assertEqual(type(L[k]), "number", "LAYERS.LEVEL." .. k .. " is not a number")
  end
  -- frame-layering-§3: fill < border < overlay (text) < edit chrome at the top of the display.
  assertTrue(L.FILL < L.BORDER and L.BORDER < L.OVERLAY and L.OVERLAY < L.HANDLE,
    "the ladder must read FILL < BORDER < OVERLAY < HANDLE")
  assertTrue(L.FILL >= 1, "the fill sits above the bar's own backdrop background")
end)

-- ── the bar root ─────────────────────────────────────────────────────────────────────────────

test("a bar root states its HUD strata, is toplevel and is clamped", function()
  withLayers(function()
    for _, unit in ipairs(NS.Units.LIST) do
      local bar = probeBar(unit)
      local s = M.__layers(bar)
      assertEqual(rawget(bar, "__strata"), LAYERS.STRATA.HUD,
        unit .. ": the strata must be set on the root, not inherited from UIParent")
      assertTrue(s.toplevel, unit .. ": peers that overlap stack whole -- the bar is toplevel")
      assertTrue(s.clamped, unit .. ": the bar stays clamped to the screen")
    end
  end)
end)

-- ── the element ladder inside one bar ────────────────────────────────────────────────────────

test("inside a bar: fill, border, text overlay and drag strip sit at their LAYERS offsets", function()
  withLayers(function()
    local bar = probeBar("player")
    local base = bar:GetFrameLevel()
    assertEqual(bar.statusBar:GetFrameLevel(), base + LAYERS.LEVEL.FILL, "fill")
    assertTrue(bar.border ~= nil, "the bar has a border frame of its own")
    assertEqual(bar.border:GetFrameLevel(), base + LAYERS.LEVEL.BORDER, "border")
    assertTrue(bar.overlay ~= nil, "the bar has a text overlay frame")
    assertEqual(bar.overlay:GetFrameLevel(), base + LAYERS.LEVEL.OVERLAY, "text overlay")
    assertTrue(bar.handle ~= nil, "the drag strip is built")
    assertEqual(bar.handle:GetFrameLevel(), base + LAYERS.LEVEL.HANDLE, "drag strip")
    -- Nothing below restates a strata: every child rides the bar's.
    for _, f in ipairs({ bar.statusBar, bar.border, bar.overlay, bar.handle }) do
      assertEqual(f:GetFrameStrata(), LAYERS.STRATA.HUD)
      assertEqual(rawget(f, "__strata"), nil, "a child sets no strata of its own")
    end
  end)
end)

test("the strip's marks sit above the strip", function()
  withLayers(function()
    local handle = probeBar("target").handle
    for _, key in ipairs({ "help", "close" }) do
      local mark = handle[key]
      assertTrue(mark ~= nil, key .. " mark is built")
      assertTrue(mark:GetFrameLevel() > handle:GetFrameLevel(), key .. " mark is under the strip")
    end
  end)
end)

test("the value text is drawn on the overlay frame, not on the fill", function()
  withLayers(function()
    local bar = probeBar("player")
    assertEqual(rawget(bar.overlay, "__fontStrings"), 1, "the value text lives on bar.overlay")
    assertEqual(rawget(bar.statusBar, "__fontStrings"), 0, "the fill hosts no text")
  end)
end)

test("the border and text overlay frames take no mouse, so a drag still reaches the bar", function()
  withLayers(function()
    local bar = probeBar("focus")
    assertFalse(lastMouse(bar.border), "border frame must be EnableMouse(false)")
    assertFalse(lastMouse(bar.overlay), "overlay frame must be EnableMouse(false)")
  end)
end)

test("the drag strip ignores the bar's alpha", function()
  withLayers(function()
    local s = M.__layers(probeBar("player").handle)
    assertTrue(s.ignoreParentAlpha, "a faded bar must not fade its move affordance")
  end)
end)

-- ── re-asserting what moves (frame-layering-§3) ──────────────────────────────────────────────

test("NS.ApplyBarLayers re-bases every child over the bar's current level", function()
  withLayers(function()
    local bar = probeBar("player")
    -- What a toplevel raise does to the root: its level moves.
    bar:SetFrameLevel(bar:GetFrameLevel() + 7)
    NS.ApplyBarLayers(bar)
    local base = bar:GetFrameLevel()
    assertEqual(bar.statusBar:GetFrameLevel(), base + LAYERS.LEVEL.FILL)
    assertEqual(bar.border:GetFrameLevel(), base + LAYERS.LEVEL.BORDER)
    assertEqual(bar.overlay:GetFrameLevel(), base + LAYERS.LEVEL.OVERLAY)
    assertEqual(bar.handle:GetFrameLevel(), base + LAYERS.LEVEL.HANDLE)
    assertEqual(bar.handle.help:GetFrameLevel(), base + LAYERS.LEVEL.HANDLE + 1)
  end)
end)

test("the appearance pass re-asserts the bar's layers", function()
  local seen = {}
  local saved = NS.ApplyBarLayers
  NS.ApplyBarLayers = function(bar) seen[#seen + 1] = bar end
  local ok, err = pcall(NS.UpdateBarAppearance, "target")
  NS.ApplyBarLayers = saved
  if not ok then error(err, 0) end
  assertEqual(#seen, 1, "UpdateBarAppearance must call NS.ApplyBarLayers once")
  assertEqual(seen[1], NS.bars.target)
end)

test("ApplyBarLayers survives a level that is not a plain number", function()
  -- The base mock's GetFrameLevel answers the frame itself; a real client never does, but a guard
  -- that computed on it would raise inside the appearance pass. It reads 0 and writes offsets.
  assertTrue(pcall(NS.ApplyBarLayers, NS.bars.player), "ApplyBarLayers raised on a non-number level")
end)

-- ── the static half (frame-layering-§5) ──────────────────────────────────────────────────────

local function readFile(path)
  local fh = assert(io.open(path, "rb"))
  local body = fh:read("*a")
  fh:close()
  return body
end

test("no strata literal and no absolute level at any call site", function()
  for _, path in ipairs(T.loadedAddonFiles) do
    if path:match("^core/") or path:match("^modules/") or path:match("^settings/") then
      local body = readFile(path)
      assertFalse(body:find('SetFrameStrata%(%s*"') ~= nil,
        path .. " passes a strata literal; read NS.Constants.LAYERS.STRATA")
      assertFalse(body:find("SetFrameLevel%(%s*%d") ~= nil,
        path .. " sets an absolute frame level; use base:GetFrameLevel() + LAYERS.LEVEL.<NAME>")
    end
  end
end)

-- ── the border sits on its own frame (ABS-Z02) ───────────────────────────────────────────────

test("the appearance pass draws the edge on the border frame and the background on the bar", function()
  NS.UpdateBarAppearance("player")
  local bar = NS.bars.player
  assertEqual(bar.backdropInfo.edgeFile, nil, "the bar's own backdrop carries no edge")
  assertEqual(bar.backdropInfo.bgFile, NS.GetBgTexture())
  assertEqual(bar.borderInfo.edgeFile, NS.GetBorder())
  assertEqual(bar.borderInfo.edgeSize, NS.GetBorderSize("player"))
  assertEqual(bar.borderInfo.bgFile, nil, "the border frame draws no background over the fill")
end)
