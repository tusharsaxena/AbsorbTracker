local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- THE SETTINGS-LAYOUT GUARD (item 020, AT-LY). The layout pass moves, regroups and relabels rows;
-- it never changes what is stored. This table is every schema row's stored path, its type, the
-- page whose Defaults resets it, its default and its range, captured from the schema at the
-- commit BEFORE the pass's first edit and written out literally. Nothing here is derived from the
-- live schema, so a pass that renames a key, moves a default, narrows a range, adds a setting or
-- drops one goes red on the line that names it.
--
-- `page` is pinned too, and that is deliberate. The three per-unit enables are drawn in the
-- Appearance band but stay stamped to `general` (options-ui-§14's cross-page stamp, disclosed in
-- both Defaults tooltips), so General's Defaults still resets them and `/at list` still prints
-- them under [general]. A re-stamp would be a visible change to two buttons' reach.
--
-- If a later change MEANS to add or alter a setting, it edits this table in the same commit, and
-- the diff of this file is then the review of exactly that.
-- red under: any key rename, default, type, range or page change, and any added or dropped row.
local PINNED = {
  ["alpha"] = { type = "number", page = "general", default = 1, min = 0, max = 1, step = 0.05 },
  ["enabled"] = { type = "bool", page = "general", default = true },
  ["global.minimap.shown"] = { type = "bool", page = "general", default = true },
  ["locked"] = { type = "bool", page = "general", default = false },
  ["scale"] = { type = "number", page = "general", default = 1, min = 0.5, max = 2, step = 0.05 },
  -- The Skin tab's seven rows (the skinning rollout's AT-01), added after the layout pass.
  ["skin.font"] = { type = "string", page = "general", default = "" },
  ["skin.ignoreFonts"] = { type = "bool", page = "general", default = false },
  ["skin.ignorePanel"] = { type = "bool", page = "general", default = true },
  ["skin.pickerSeen"] = { type = "bool", page = "general", default = false },
  ["skin.skin"] = { type = "string", page = "general", default = "ka0s" },
  ["skin.source"] = { type = "string", page = "general", default = "ka0s" },
  ["skin.texture"] = { type = "string", page = "general", default = "" },
  ["state.debugConsole"] = { type = "bool", page = "general", default = nil },
  ["throttleWindow"] = { type = "number", page = "general", default = 0.1, min = 0.05, max = 1, step = 0.05 },
  -- The three "Use the skin's ..." companions per unit (the skinning rollout's AT-03), default on.
  ["units.focus.barTextureFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.focus.borderFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.focus.fontFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.player.barTextureFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.player.borderFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.player.fontFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.target.barTextureFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.target.borderFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.target.fontFromSkin"] = { type = "bool", page = "appearance", default = true },
  ["units.focus.barAlpha"] = { type = "number", page = "appearance", default = 1, min = 0, max = 1, step = 0.05 },
  ["units.focus.barColor"] = { type = "color", page = "appearance", default = { a = 0.8, b = 1, g = 0.7, r = 0.4 } },
  ["units.focus.barHeight"] = { type = "number", page = "appearance", default = 20, min = 10, max = 100, step = 1 },
  ["units.focus.barTexture"] = { type = "string", page = "appearance", default = "Blizzard Raid Bar" },
  ["units.focus.barWidth"] = { type = "number", page = "appearance", default = 200, min = 50, max = 500, step = 1 },
  ["units.focus.bgColor"] = { type = "color", page = "appearance", default = { a = 0.8, b = 0.2, g = 0.2, r = 0.2 } },
  ["units.focus.bgTexture"] = { type = "string", page = "appearance", default = "Blizzard Raid Bar" },
  ["units.focus.border"] = { type = "string", page = "appearance", default = "Blizzard Tooltip" },
  ["units.focus.borderColor"] = { type = "color", page = "appearance", default = { a = 1, b = 0.5, g = 0.5, r = 0.5 } },
  ["units.focus.borderSize"] = { type = "number", page = "appearance", default = 12, min = 0, max = 16, step = 1 },
  ["units.focus.enabled"] = { type = "bool", page = "general", default = false },
  ["units.focus.font"] = { type = "string", page = "appearance", default = "Friz Quadrata TT" },
  ["units.focus.fontColor"] = { type = "color", page = "appearance", default = { a = 1, b = 1, g = 1, r = 1 } },
  ["units.focus.fontFlags"] = { type = "string", page = "appearance", default = "OUTLINE" },
  ["units.focus.fontShadow"] = { type = "bool", page = "appearance", default = false },
  ["units.focus.fontSize"] = { type = "number", page = "appearance", default = 12, min = 6, max = 32, step = 1 },
  ["units.focus.mirror"] = { type = "bool", page = "appearance", default = true },
  ["units.focus.useClassColorBar"] = { type = "bool", page = "appearance", default = false },
  ["units.focus.useClassColorBg"] = { type = "bool", page = "appearance", default = false },
  ["units.focus.useClassColorBorder"] = { type = "bool", page = "appearance", default = false },
  ["units.focus.useClassColorText"] = { type = "bool", page = "appearance", default = false },
  ["units.player.barAlpha"] = { type = "number", page = "appearance", default = 1, min = 0, max = 1, step = 0.05 },
  ["units.player.barColor"] = { type = "color", page = "appearance", default = { a = 0.8, b = 1, g = 0.7, r = 0.4 } },
  ["units.player.barHeight"] = { type = "number", page = "appearance", default = 20, min = 10, max = 100, step = 1 },
  ["units.player.barTexture"] = { type = "string", page = "appearance", default = "Blizzard Raid Bar" },
  ["units.player.barWidth"] = { type = "number", page = "appearance", default = 200, min = 50, max = 500, step = 1 },
  ["units.player.bgColor"] = { type = "color", page = "appearance", default = { a = 0.8, b = 0.2, g = 0.2, r = 0.2 } },
  ["units.player.bgTexture"] = { type = "string", page = "appearance", default = "Blizzard Raid Bar" },
  ["units.player.border"] = { type = "string", page = "appearance", default = "Blizzard Tooltip" },
  ["units.player.borderColor"] = { type = "color", page = "appearance", default = { a = 1, b = 0.5, g = 0.5, r = 0.5 } },
  ["units.player.borderSize"] = { type = "number", page = "appearance", default = 12, min = 0, max = 16, step = 1 },
  ["units.player.enabled"] = { type = "bool", page = "general", default = true },
  ["units.player.font"] = { type = "string", page = "appearance", default = "Friz Quadrata TT" },
  ["units.player.fontColor"] = { type = "color", page = "appearance", default = { a = 1, b = 1, g = 1, r = 1 } },
  ["units.player.fontFlags"] = { type = "string", page = "appearance", default = "OUTLINE" },
  ["units.player.fontShadow"] = { type = "bool", page = "appearance", default = false },
  ["units.player.fontSize"] = { type = "number", page = "appearance", default = 12, min = 6, max = 32, step = 1 },
  ["units.player.useClassColorBar"] = { type = "bool", page = "appearance", default = false },
  ["units.player.useClassColorBg"] = { type = "bool", page = "appearance", default = false },
  ["units.player.useClassColorBorder"] = { type = "bool", page = "appearance", default = false },
  ["units.player.useClassColorText"] = { type = "bool", page = "appearance", default = false },
  ["units.target.barAlpha"] = { type = "number", page = "appearance", default = 1, min = 0, max = 1, step = 0.05 },
  ["units.target.barColor"] = { type = "color", page = "appearance", default = { a = 0.8, b = 1, g = 0.7, r = 0.4 } },
  ["units.target.barHeight"] = { type = "number", page = "appearance", default = 20, min = 10, max = 100, step = 1 },
  ["units.target.barTexture"] = { type = "string", page = "appearance", default = "Blizzard Raid Bar" },
  ["units.target.barWidth"] = { type = "number", page = "appearance", default = 200, min = 50, max = 500, step = 1 },
  ["units.target.bgColor"] = { type = "color", page = "appearance", default = { a = 0.8, b = 0.2, g = 0.2, r = 0.2 } },
  ["units.target.bgTexture"] = { type = "string", page = "appearance", default = "Blizzard Raid Bar" },
  ["units.target.border"] = { type = "string", page = "appearance", default = "Blizzard Tooltip" },
  ["units.target.borderColor"] = { type = "color", page = "appearance", default = { a = 1, b = 0.5, g = 0.5, r = 0.5 } },
  ["units.target.borderSize"] = { type = "number", page = "appearance", default = 12, min = 0, max = 16, step = 1 },
  ["units.target.enabled"] = { type = "bool", page = "general", default = false },
  ["units.target.font"] = { type = "string", page = "appearance", default = "Friz Quadrata TT" },
  ["units.target.fontColor"] = { type = "color", page = "appearance", default = { a = 1, b = 1, g = 1, r = 1 } },
  ["units.target.fontFlags"] = { type = "string", page = "appearance", default = "OUTLINE" },
  ["units.target.fontShadow"] = { type = "bool", page = "appearance", default = false },
  ["units.target.fontSize"] = { type = "number", page = "appearance", default = 12, min = 6, max = 32, step = 1 },
  ["units.target.mirror"] = { type = "bool", page = "appearance", default = true },
  ["units.target.useClassColorBar"] = { type = "bool", page = "appearance", default = false },
  ["units.target.useClassColorBg"] = { type = "bool", page = "appearance", default = false },
  ["units.target.useClassColorBorder"] = { type = "bool", page = "appearance", default = false },
  ["units.target.useClassColorText"] = { type = "bool", page = "appearance", default = false },
  ["visibility"] = { type = "string", page = "general", default = "always" },
}

local function same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

local function show(v)
  if type(v) ~= "table" then return tostring(v) end
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = tostring(k) end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(v[k]) end
  return "{" .. table.concat(parts, ",") .. "}"
end

test("layout guard: every stored path keeps its type, page, default and range", function()
  local seen, n = {}, 0
  for _, row in ipairs(NS.Schema) do
    local want = PINNED[row.path]
    assertTrue(want ~= nil, "a schema row that was not there before the layout pass: " .. row.path)
    assertTrue(not seen[row.path], "a stored path declared twice: " .. row.path)
    seen[row.path] = true
    n = n + 1
    assertEqual(row.type, want.type, row.path .. " type")
    assertEqual(row.page, want.page, row.path .. " page")
    assertTrue(same(row.default, want.default),
      row.path .. " default is " .. show(row.default) .. ", was " .. show(want.default))
    assertEqual(row.min, want.min, row.path .. " min")
    assertEqual(row.max, want.max, row.path .. " max")
    assertEqual(row.step, want.step, row.path .. " step")
  end
  for path in pairs(PINNED) do
    assertTrue(seen[path], "a setting the layout pass lost: " .. path)
  end
  -- 70 from the layout pass, plus the Skin tab's seven (AT-01) and the nine skin companions (AT-03).
  assertEqual(n, 86, "the schema row count")
end)
