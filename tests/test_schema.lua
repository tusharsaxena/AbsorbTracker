local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The type-aware parser is LibKa0s-Slash-1.0's now (`lib.ParseValue`), and its cases live in that
-- repo's tests/test_slash.lua — the bool vocabulary, the clamp, the case-sensitive enum, the
-- 0-255 color rescale and the unknown-type message. Keeping copies here would be two places to
-- fix one bug, which is what testing-§8 forbids.

test("FormatSchemaValue formats by type", function()
  assertEqual(NS.FormatSchemaValue({ type = "bool" }, true), "true")
  assertEqual(NS.FormatSchemaValue({ type = "bool" }, false), "false")
  assertEqual(NS.FormatSchemaValue({ type = "number", fmt = "%d px" }, 200), "200 px")
  assertEqual(NS.FormatSchemaValue({ type = "number" }, 3), "3")
  assertEqual(NS.FormatSchemaValue({ type = "color" }, { r = 1, g = 0, b = 0, a = 1 }),
    "{1.00, 0.00, 0.00, 1.00}")
end)

test("SchemaForPage keeps groups in registration order, which IS the Appearance tab strip",
  function()
  -- Filtered to one unit so the three units' rows don't interleave when checking group order.
  -- This is the strip a player sees, left to right: RenderTabbedSchema (and this addon's own
  -- Helpers.__partitionTabs, which draws the strip because the page has a bespoke header above it)
  -- both take one tab per distinct `group` in declaration order. The whole list, in order, not just
  -- the first three -- a run that ends where the assertions stop is a run that can grow a fourth
  -- tab nobody named.
  local rows = NS.SchemaForPage("appearance", "player")
  local order, seen = {}, {}
  for _, r in ipairs(rows) do
    if r.group and not seen[r.group] then
      seen[r.group] = true
      order[#order + 1] = r.group
    end
  end
  local want = { "Size", "Bar", "Background", "Border", "Text" }
  assertEqual(#order, #want, "unexpected tab count on the Appearance page")
  for i, name in ipairs(want) do
    assertEqual(order[i], name, "Appearance tab " .. i)
  end
end)

-- The page -> tab -> row-count partition, as designed. This is the case that catches a row drifting
-- into the wrong tab: a moved row leaves one count short and lands another one over, and neither
-- shows up in a test that only asserts the tab NAMES.
--
-- Counts are per unit for the Appearance page (it renders one unit at a time behind the banner) and
-- unfiltered for General (it renders with ctx.unit nil, so every unit's enable toggle is on screen
-- at once). The mirror row is excluded from every count on purpose: it carries no `group`, belongs
-- to no tab, and is drawn bespoke in the header.
test("the page -> tab -> row-count partition is the designed one", function()
  local want = {
    -- Master controls is FIRST and holds exactly the six schema rows options-ui-§15 entitles this
    -- addon to: enable, general visibility, master scale, master alpha, lock frame, debug console.
    -- The two resets are the tab's closing BUTTON PAIR rather than rows, so they are not counted
    -- here -- tests/test_widgets.lua is what pins them onto this tab.
    { page = "general", unit = nil, tabs = { { "Master controls", 6 }, { "Bars", 4 } } },
    { page = "appearance", unit = "player", tabs = {
      { "Size", 2 }, { "Bar", 4 }, { "Background", 3 }, { "Border", 4 }, { "Text", 6 },
    } },
  }
  for _, page in ipairs(want) do
    local counts, order, seen = {}, {}, {}
    for _, r in ipairs(NS.SchemaForPage(page.page, page.unit)) do
      if r.group then
        if not seen[r.group] then
          seen[r.group] = true
          order[#order + 1] = r.group
        end
        counts[r.group] = (counts[r.group] or 0) + 1
      end
    end
    assertEqual(#order, #page.tabs, page.page .. ": unexpected tab count")
    for i, spec in ipairs(page.tabs) do
      assertEqual(order[i], spec[1], page.page .. " tab " .. i)
      assertEqual(counts[spec[1]], spec[2], page.page .. " / " .. spec[1] .. " row count")
    end
  end
end)

-- The two-visible-control rule (options-ui-§13, PROMPT Step 1): a tab holding fewer than two
-- visible controls is not a subject, it is a click that reveals one checkbox. Merge it into the tab
-- whose subject contains it.
--
-- Nothing on either page is exempt today, and the exemption is stated here rather than left to be
-- invented later. The one thing this addon draws that HAS no path and so cannot be counted is the
-- Appearance page's bespoke chrome -- the Unit banner, and the mirror checkbox + "Copy styling from
-- Player" button in the header. Neither sits inside a tab: the banner is chrome above the strip and
-- the mirror pair is drawn above it by Helpers.RenderUnitPanel, so neither can prop up a one-row
-- tab. If a future tab ever earns the exemption, name it in EXEMPT with the bespoke controls it
-- sits beside -- never by dropping the assertion or lowering the 2.
--
-- Counted the way the strip is DRAWN, one page-and-unit at a time: NS.Schema as a whole would show
-- every Appearance tab at three times its size (once per unit) and a genuinely one-row tab would
-- read as three and pass.
-- red under: a tab losing rows until one is left, or a new one-row group.
test("no tab holds fewer than two visible controls", function()
  local EXEMPT = {}   -- { ["<tab>"] = "<the bespoke controls it sits beside>" }
  local views = { { "general", nil } }
  for _, unit in ipairs(NS.Units.LIST) do
    views[#views + 1] = { "appearance", unit }
  end

  local sawTab = false
  for _, view in ipairs(views) do
    local page, unit = view[1], view[2]
    local counts, order, seen = {}, {}, {}
    for _, r in ipairs(NS.SchemaForPage(page, unit)) do
      if r.group and not r.skipRender then
        if not seen[r.group] then
          seen[r.group] = true
          order[#order + 1] = r.group
        end
        counts[r.group] = (counts[r.group] or 0) + 1
      end
    end
    for _, group in ipairs(order) do
      sawTab = true
      local where = page .. (unit and ("/" .. unit) or "") .. " / " .. group
      if not EXEMPT[group] then
        assertTrue(counts[group] >= 2,
          where .. " holds only " .. counts[group] .. " visible control(s)")
      end
    end
  end
  assertTrue(sawTab, "no tabs were counted at all -- the walk found nothing")
end)

test("ValidateSchema resolves every real path against defaults (0 errors, 0 missing)", function()
  local errors, resolved, missing = NS.ValidateSchema()
  assertEqual(errors, 0)
  assertEqual(missing, 0)
  assertTrue(resolved > 0, "at least one path should resolve")
end)

test("ValidateSchema reports a planted path that does not resolve against defaults", function()
  local bogus = { path = "doesNotExist", page = "appearance", type = "number", label = "x" }
  NS.Schema[#NS.Schema + 1] = bogus
  local _, _, missing = NS.ValidateSchema()
  assertEqual(missing, 1)
  NS.Schema[#NS.Schema] = nil  -- remove the planted row
end)

test("ValidateSchema flags an invalid page/type as a shape error", function()
  local bad = { path = "barWidth", page = "nope", type = "weird", label = "x" }
  NS.Schema[#NS.Schema + 1] = bad
  local errors = NS.ValidateSchema()
  assertTrue(errors >= 2, "invalid page + invalid type should be two errors")
  NS.Schema[#NS.Schema] = nil
end)

-- ── Schema integrity ───────────────────────────────────────────────────────────────
--
-- ValidateSchema above is the runtime guard the addon ships with (it only PRINTS, and only checks
-- page/type/path). These are the stricter build-time invariants: they hold for the schema as it
-- stands today, so a new row that forgets a tooltip, a slider range, or a default fails here
-- rather than shipping a half-wired option.

test("every schema row carries a label and a tooltip description", function()
  -- `tooltip` OR `desc`, because the flow engine reads exactly that: `row.tooltip or row.desc`
  -- (libs/LibKa0s/OptionsWidgets.lua's tooltipBody). `desc` is this addon's older spelling and the
  -- one its hand-written rows still use; `tooltip` is what the composers emit and what the rest of
  -- the collection declares. Asserting only `desc` would fail every composed row while the tooltip
  -- it names renders perfectly, which is a test measuring a spelling rather than a behavior.
  -- red under: dropping the tooltip from any composed block, or the desc from a hand-written row.
  for i, row in ipairs(NS.Schema) do
    local where = "row #" .. i .. " (" .. tostring(row.path) .. ")"
    local body = row.tooltip or row.desc
    assertTrue(type(row.label) == "string" and row.label ~= "", where .. " needs a label")
    assertTrue(type(body) == "string" and body ~= "", where .. " needs a tooltip or desc")
  end
end)

test("every schema path is unique", function()
  -- FindSchemaRow returns the FIRST match, so a duplicate path silently shadows the later row:
  -- its widget writes the setting but /at get/set and the Defaults button read the other one.
  local seen = {}
  for _, row in ipairs(NS.Schema) do
    assertEqual(seen[row.path], nil, "duplicate schema path: " .. tostring(row.path))
    seen[row.path] = true
  end
end)

test("every schema row declares a default", function()
  -- ApplyDefault bails out on a nil default, so a row without one is silently skipped by
  -- /at reset, /at resetall and the per-panel Defaults button.
  --
  -- A `sessionOnly` row is exempt, and is the only thing that is: its value is not in the profile
  -- at all (core/Data.lua's session-settings registry answers it), so there is nothing for a reset
  -- to restore it TO. Giving the debug-console toggle a default would make "reset all settings"
  -- close a console window the player opened, which is not a setting.
  -- red under: adding a default to the console row, or dropping one from any stored row.
  for _, row in ipairs(NS.Schema) do
    if not row.sessionOnly then
      assertTrue(row.default ~= nil, tostring(row.path) .. " has no default to reset to")
    end
  end
end)

test("every row's default matches the value in defaults.profile", function()
  -- Two sources for one value: the schema row drives /at reset, defaults.profile drives a fresh
  -- profile and the RunMigrations backfill. If they disagree, resetting a setting lands somewhere
  -- other than where a brand-new profile starts.
  local defaults = NS.defaults.profile
  for _, row in ipairs(NS.Schema) do
    local want = NS.ResolvePath(defaults, row.path)
    if type(row.default) == "table" then
      assertEqual(type(want), "table", row.path .. " default should be a table in both places")
      for k, v in pairs(row.default) do
        assertEqual(want[k], v, row.path .. "." .. tostring(k) .. " disagrees")
      end
    else
      assertEqual(row.default, want, row.path .. " default disagrees with defaults.profile")
    end
  end
end)

test("every persisted profile default is reachable from a schema row", function()
  -- The other direction: a default with no row is a setting the user can neither see in the panel
  -- nor reach via /at set. (`position` is exempt by construction — it defaults to nil, so it is
  -- not a key here; it is written by dragging and cleared explicitly by RestoreAllDefaults.)
  -- Appearance defaults now live two levels deep, at profile.units.<unit>.<key>, so walk that one
  -- extra level explicitly rather than a generic recursive walk (the shape is exactly two levels:
  -- flat globals at the root, and per-unit tables under `units`).
  -- `schemaVersion` is also exempt: it is the per-profile migration stamp (defaults/Profile.lua),
  -- bookkeeping the migration seam owns, not a user-facing setting. A schema row for it would put
  -- a "schema version" slider on a settings page and let `/at set schemaVersion 1` re-trigger the
  -- v3 lift on a live profile.
  local EXEMPT = { schemaVersion = true }
  local paths = {}
  for _, row in ipairs(NS.Schema) do paths[row.path] = true end
  for key, val in pairs(NS.defaults.profile) do
    if EXEMPT[key] then -- luacheck: ignore
      -- bookkeeping, not a setting
    elseif key == "units" then
      for unitName, unitDefaults in pairs(val) do
        for field in pairs(unitDefaults) do
          local path = "units." .. unitName .. "." .. field
          assertTrue(paths[path], "profile default '" .. path .. "' has no schema row")
        end
      end
    else
      assertTrue(paths[key], "profile default '" .. key .. "' has no schema row")
    end
  end
end)

test("every number row declares a usable min/max range", function()
  for _, row in ipairs(NS.Schema) do
    if row.type == "number" then
      assertEqual(type(row.min), "number", row.path .. " needs a min for its slider and clamp")
      assertEqual(type(row.max), "number", row.path .. " needs a max")
      assertTrue(row.min < row.max, row.path .. " has an inverted range")
      assertTrue(row.default >= row.min and row.default <= row.max,
        row.path .. " default sits outside its own range")
    end
  end
end)

test("every string row supplies a values source", function()
  -- parseString validates against allowedValues(row); with no `values` the allowed list is empty
  -- and /at set can never satisfy it, making the setting CLI-unreachable.
  for _, row in ipairs(NS.Schema) do
    if row.type == "string" then
      local t = type(row.values)
      assertTrue(t == "function" or t == "table", row.path .. " needs values for its dropdown")
    end
  end
end)

-- ── the options-ui v2 adoption invariants ──────────────────────────────────────────
--
-- Three loops over the whole schema, each pinning one rule the library now depends on. They are
-- deliberately whole-schema rather than per-page: a rule that holds on the pages someone remembered
-- to list is a rule that stops holding the day a page is added.

test("every row on every page carries a `group`", function()
  -- options-ui-§13: a page whose rows declare no group cannot draw a strip. The library reports it
  -- and renders the page untabbed, which is a silent downgrade -- the page simply looks unlike
  -- every other page in the collection and nothing in a suite notices.
  --
  -- `skipRender` rows are exempt and are the only exemption: their widget is bespoke chrome, not a
  -- tab's content (the mirror flag, drawn in the Appearance page's header). They still carry a
  -- group naming their subject -- settings/UnitPanel.lua's partition is what keeps them out of the
  -- strip -- so this is an exemption from being COUNTED, not from being attributable.
  -- red under: deleting `group` from any row, on any page.
  for i, row in ipairs(NS.Schema) do
    local where = "row #" .. i .. " (" .. tostring(row.path) .. ")"
    assertTrue(type(row.group) == "string" and row.group ~= "",
      where .. " carries no group, so it belongs to no tab")
  end
end)

test("every color row is immediately followed by its class-color companion", function()
  -- options-ui-§17: the companion is placed immediately to the swatch's RIGHT, and in a
  -- two-column flow that means immediately after it in DECLARATION order. The composers guarantee
  -- it; this is what would notice a hand-written pair that got separated by a third row.
  --
  -- Walked over NS.Schema in registration order, which is the order the composers appended in and
  -- the order RenderRows fills the columns in.
  -- red under: inserting any row between a swatch and its companion, or dropping a companion.
  local seen = 0
  for i, row in ipairs(NS.Schema) do
    if row.type == "color" then
      seen = seen + 1
      local next_ = NS.Schema[i + 1]
      local where = row.path .. " (row #" .. i .. ")"
      assertTrue(next_ ~= nil and next_.type == "bool",
        where .. " has no companion bool beside it")
      assertTrue(next_.label == "Use class color",
        where .. "'s companion is labeled " .. tostring(next_ and next_.label))
      assertEqual(next_.group, row.group, where .. "'s companion sits on another tab")
      -- The pair may not be split across two lines by an odd number of widgets above it, and
      -- `startsLine` is what makes that a property of the declaration rather than of the count.
      assertEqual(row.startsLine, true, where .. " must start its own line")
    end
  end
  assertTrue(seen > 0, "the walk found no color rows at all")
end)

test("no color row carries `disabledIf`, and every pair declares whose class it means", function()
  -- Two halves of options-ui-§17, in one walk because they are the same rule from two sides.
  --
  -- `disabledIf` on a color row is anti-pattern #74: the swatch is still read for its ALPHA under
  -- class color, so graying it tells the player something untrue. The tooltip says it in words
  -- instead (H.CLASS_COLOR_NOTE).
  --
  -- `classColorSource` is DECLARED because the path cannot be trusted to say it: a row stored
  -- under `units.<unit>.` that drew the player's own spells would be player-scoped. On this addon
  -- every one of the four surfaces paints the tracked unit's own bar, so every pair is "unit" --
  -- and that declaration is what an audit reads.
  -- red under: a `disabledIf` coming back, or a pair silently reverting to the player's class.
  for _, row in ipairs(NS.Schema) do
    if row.type == "color" then
      assertEqual(row.disabledIf, nil, row.path .. " must never gray itself out")
      assertEqual(row.classColorSource, "unit", row.path .. " does not declare whose class it means")
      assertEqual(row.classColorUnit, row.unit, row.path .. " names a unit other than its own")
    end
  end
  -- The companion carries the same declaration, so an audit reading either row gets one answer.
  for i, row in ipairs(NS.Schema) do
    if row.type == "color" then
      local companion = NS.Schema[i + 1]
      assertEqual(companion.classColorSource, row.classColorSource,
        row.path .. " and its companion disagree about whose class")
      assertEqual(companion.classColorUnit, row.classColorUnit)
      assertEqual(companion.disabledIf, nil)
    end
  end
end)

test("every media-backed row answers a populated option list", function()
  -- The composers declare `values` as a closure returning O.LSMValues(kind) -- a closure returning
  -- a CLOSURE, where the flow engine's enumList calls it once and expects a table. It gets a
  -- function, answers an empty list, and its own "no options" report is gated on `row.values ==
  -- nil`, so the dropdown renders empty and nothing says why. settings/Appearance.lua corrects
  -- that on its own rows (never in libs/, which the next re-vendor would overwrite); this is what
  -- proves the correction is still applied, and what will fail loudly the day upstream fixes it
  -- and the workaround is left behind doing nothing.
  -- red under: deleting fixMediaValues, or an upstream `values` shape that answers a non-table.
  local seen = 0
  for _, row in ipairs(NS.Schema) do
    if row.dialogControl then
      seen = seen + 1
      local v = type(row.values) == "function" and row.values() or row.values
      assertEqual(type(v), "table",
        row.path .. " (" .. row.dialogControl .. ") answers " .. type(v) .. ", not a list")
      assertTrue(next(v) ~= nil, row.path .. " answers an EMPTY list, which cannot be opened")
    end
  end
  assertTrue(seen > 0, "the walk found no media-backed rows at all")
end)

test("`disabledIf` names a real sibling setting", function()
  -- A typo'd disabledIf reads nil, which is falsey, so the widget would simply never gray out —
  -- a silent failure with no error to notice.
  for _, row in ipairs(NS.Schema) do
    if row.disabledIf then
      assertTrue(NS.ResolvePath(NS.defaults.profile, row.disabledIf) ~= nil,
        row.path .. " disabledIf='" .. row.disabledIf .. "' does not resolve")
    end
  end
end)

test("every schema row lands on a page the panel actually builds", function()
  local pages = { general = true, appearance = true, profiles = true }
  for _, row in ipairs(NS.Schema) do
    assertTrue(pages[row.page], tostring(row.path) .. " is on unknown page " .. tostring(row.page))
  end
end)

-- ── SetByPath / ApplyDefault dispatch ──────────────────────────────────────────────

test("FindSchemaRow returns the row for a known path and nil for an unknown one", function()
  local row = NS.FindSchemaRow("units.player.barWidth")
  assertTrue(row ~= nil and row.path == "units.player.barWidth")
  assertEqual(NS.FindSchemaRow("nothingLikeThis"), nil)
end)

test("SetByPath writes the value and fires the row's own onChange with it", function()
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved = row.onChange
  local got
  row.onChange = function(v) got = v end
  local ok, err = pcall(NS.SetByPath, "units.player.barWidth", 240)
  row.onChange = saved
  if not ok then error(err) end
  assertEqual(NS.GetSetting("units.player.barWidth"), 240)
  assertEqual(got, 240, "the onChange receives the written value")
  NS.SetByPath("units.player.barWidth", NS.unitDefaults.barWidth)
end)

test("SetByPath falls back to broadcasting APPEARANCE for a row with no onChange", function()
  local row = NS.FindSchemaRow("units.player.barWidth")
  local saved = row.onChange
  row.onChange = nil
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.APPEARANCE, function() seen = seen + 1 end)
  local ok, err = pcall(NS.SetByPath, "units.player.barWidth", 210)
  target:UnregisterMessage(NS.MSG.APPEARANCE)
  row.onChange = saved
  if not ok then error(err) end
  assertEqual(seen, 1, "the default onChange repaints the bar's appearance")
  NS.SetByPath("units.player.barWidth", NS.unitDefaults.barWidth)
end)

test("SetByPath still writes a value that has no schema row at all", function()
  -- The write happens before the row lookup, so an internal (non-schema) key round-trips.
  NS.SetByPath("someInternalKey", 7)
  assertEqual(NS.GetSetting("someInternalKey"), 7)
  NS.db.profile.someInternalKey = nil
end)

test("ApplyDefault deep-copies a color table so profiles never share one", function()
  -- Handing out the row's own table would let a ColorPicker drag in one profile mutate the schema
  -- default itself, and through it every other profile that was reset from it.
  local row = NS.FindSchemaRow("units.player.barColor")
  assertTrue(row ~= nil, "units.player.barColor is a color row")
  NS.ApplyDefault(row)
  local stored = NS.GetSetting("units.player.barColor")
  assertTrue(stored ~= row.default, "the stored table must be a copy, not the row's own")
  stored.r = 0.123
  assertTrue(row.default.r ~= 0.123, "mutating the stored color must not reach the default")
  NS.ApplyDefault(row)
end)

test("ApplyDefault is a no-op for a row with no default", function()
  NS.SetSetting("barWidth", 250)
  NS.ApplyDefault({ path = "barWidth", type = "number" })   -- no `default` key
  assertEqual(NS.GetSetting("barWidth"), 250, "nothing should have been written")
  NS.SetSetting("barWidth", NS.flatDefaults.barWidth)
end)

test("ResolvePath walks a dotted path", function()
  local t = { units = { target = { barWidth = 275 } } }
  assertEqual(NS.ResolvePath(t, "units.target.barWidth"), 275)
end)

test("ResolvePath returns nil for a missing branch instead of raising", function()
  local t = { units = {} }
  assertEqual(NS.ResolvePath(t, "units.focus.barWidth"), nil)
  assertEqual(NS.ResolvePath(t, "nope.at.all"), nil)
end)

test("ResolvePath still handles a flat key", function()
  assertEqual(NS.ResolvePath({ hidden = true }, "hidden"), true)
end)

test("SetPath writes through a dotted path and creates intermediate tables", function()
  local t = {}
  NS.SetPath(t, "units.focus.barWidth", 321)
  assertEqual(t.units.focus.barWidth, 321)
end)

test("GetSetting and SetSetting round-trip a dotted path", function()
  local saved = NS.GetSetting("units.target.barWidth")
  NS.SetSetting("units.target.barWidth", 313)
  assertEqual(NS.GetSetting("units.target.barWidth"), 313)
  NS.SetSetting("units.target.barWidth", saved)
end)

test("ValidateSchema resolves nested paths against defaults.profile", function()
  local errors, resolved, missing = NS.ValidateSchema()
  assertEqual(errors, 0, "no malformed schema rows")
  assertEqual(missing, 0, "every schema path must resolve against the defaults profile")
  assertTrue(resolved > 0)
end)

test("SchemaForPage with no unit returns every unit's rows", function()
  local rows = NS.SchemaForPage("appearance")
  local seen = {}
  for _, r in ipairs(rows) do if r.unit then seen[r.unit] = true end end
  assertTrue(seen.player and seen.target and seen.focus,
    "resets and /at list need every unit's rows")
end)

test("SchemaForPage filtered to a unit excludes the other units' rows", function()
  local all = NS.SchemaForPage("appearance")
  local focusRows = NS.SchemaForPage("appearance", "focus")

  -- Prove the unfiltered set actually contains other units' rows to exclude — otherwise this
  -- test would pass vacuously even if the `unit` argument were ignored entirely.
  local haveOther = false
  for _, r in ipairs(all) do
    if r.unit and r.unit ~= "focus" then haveOther = true end
  end
  assertTrue(haveOther,
    "the unfiltered Appearance page must contain player/target rows to prove against")

  for _, r in ipairs(focusRows) do
    assertTrue(r.unit == nil or r.unit == "focus",
      "a unit-filtered page must not leak another unit's widgets")
  end

  -- Prove the filter actually filters: a no-op SchemaForPage(page, unit) that ignored `unit`
  -- would return the same row count as the unfiltered call, and the assertion above would still
  -- pass (every unit-tagged row on this page happens to be "focus" only if nothing else were
  -- excluded — which is false here, so this also catches that no-op).
  assertTrue(#focusRows < #all,
    "the focus-filtered set must be strictly smaller than the unfiltered set")
end)

test("PartitionUnitRows splits alwaysPerUnit rows from the mirrored appearance rows", function()
  local rows = {
    { path = "units.focus.enabled",  alwaysPerUnit = true },
    { path = "units.focus.barWidth" },
    { path = "units.focus.barColor" },
  }
  local perUnit, styled = NS.PartitionUnitRows(rows)
  assertEqual(#perUnit, 1)
  assertEqual(perUnit[1].path, "units.focus.enabled")
  assertEqual(#styled, 2)
end)

test("the appearance page carries a full row set for all three units", function()
  for _, page in ipairs({ "appearance" }) do
    for _, unit in ipairs(NS.Units.LIST) do
      local rows = NS.SchemaForPage(page, unit)
      assertTrue(#rows > 0, page .. " page has no rows for " .. unit)
      for _, r in ipairs(rows) do
        assertTrue(r.path:match("^units%." .. unit .. "%."),
          "row " .. r.path .. " on " .. page .. "/" .. unit .. " is not unit-scoped")
      end
    end
  end
end)

test("each unit's row set for a page is the same size", function()
  for _, page in ipairs({ "appearance" }) do
    local n = #NS.SchemaForPage(page, "target")
    assertEqual(#NS.SchemaForPage(page, "focus"), n,
      page .. ": target and focus must expose identical settings")
  end
end)

test("the enable row is per-unit, lives on General, and survives mirroring", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local row = NS.FindSchemaRow("units." .. unit .. ".enabled")
    assertTrue(row ~= nil, unit .. " has no enable row")
    -- alwaysPerUnit is what keeps `/at get units.<unit>.enabled` free of the "(mirrored)" note:
    -- the flag is honored per-unit whatever the mirror says.
    assertEqual(row.alwaysPerUnit, true)
    assertEqual(row.page, "general", "the enable toggles are master controls, not appearance")
    assertEqual(row.group, "Bars")
    assertEqual(row.label, "Enable " .. NS.Units.LABEL[unit] .. " Bar")
  end
end)

-- The Master controls tab, and it is the one options-ui-§15 mandates rather than one this addon
-- chose: the canonical set in the canonical order, composed by H.MasterControls and spliced at the
-- HEAD of the general page so it is the first tab in the strip.
--
-- The set is asserted WHOLE and in order. An addon may omit only the four frame-only rows and only
-- when it is frameless, and this one is not -- modules/Bar.lua calls SetMovable(true) on every bar
-- -- so all six schema rows are here. The two resets are the tab's closing BUTTON PAIR rather than
-- rows; tests/test_widgets.lua pins those onto this group's afterGroup hook.
-- red under: a reordered composer, a `frameless = true` this addon is not entitled to, or a row
-- moved back to the tab it came from.
test("the Master controls tab is the canonical set, in order, and leads the General page", function()
  local want = { "enabled", "visibility", "scale", "alpha", "locked", "state.debugConsole" }
  local got, firstGroup = {}, nil
  for _, r in ipairs(NS.SchemaForPage("general")) do
    firstGroup = firstGroup or r.group
    if r.group == "Master controls" then got[#got + 1] = r.path end
  end
  assertEqual(firstGroup, "Master controls", "Master controls must be the FIRST tab")
  assertEqual(#got, #want, "unexpected Master controls row count")
  for i, path in ipairs(want) do
    assertEqual(got[i], path, "Master controls row " .. i)
  end
  -- The console toggle is session state and must never reach the profile (options-ui-§15). Pinned
  -- through the ACCESSORS, because routing is the whole job of the session registry: GetSetting and
  -- SetSetting take this one path to the console WINDOW's own show/hide state, and db.profile never
  -- grows a `state` key on the way.
  -- red under: dropping the sessionSettings lookup from either accessor in core/Data.lua.
  assertEqual(NS.FindSchemaRow("state.debugConsole").sessionOnly, true)
  local wasShown = NS.GetSetting("state.debugConsole")
  NS.SetSetting("state.debugConsole", not wasShown)
  assertEqual(NS.GetSetting("state.debugConsole"), not wasShown,
    "the console path must round-trip through its live get/set pair")
  assertEqual(NS.db.profile.state, nil, "and must never reach db.profile")
  NS.SetSetting("state.debugConsole", wasShown)
end)

test("the Bars tab is the three enable toggles then the throttle, under their own headings",
  function()
  -- RenderRows fills left-then-right in schema order, so the rendered layout IS the row order:
  -- [Enable Player Bar | Enable Target Bar], [Enable Focus Bar], then the throttle under its own
  -- heading. The globals the enables used to be interleaved with are on Master controls now --
  -- pairing an enable toggle with "Lock Position" put two answers to two different questions on
  -- one line.
  --
  -- The throttle is here rather than on a `Behavior` tab of its own because lock and the combat
  -- gate both moved to Master controls and left it alone: a tab holding one control is a click
  -- that reveals one widget. A merged tab that mixes kinds carries a subsection heading per kind
  -- (options-ui-§7), and neither heading may repeat the tab's name.
  -- red under: dropping either subgroup, or naming one of them "Bars".
  local want = {
    { "units.player.enabled", "Tracked units" },
    { "units.target.enabled", "Tracked units" },
    { "units.focus.enabled",  "Tracked units" },
    { "throttleWindow",       "Updates"       },
  }
  local got = {}
  for _, r in ipairs(NS.SchemaForPage("general")) do
    if r.group == "Bars" then got[#got + 1] = r end
  end
  assertEqual(#got, #want, "unexpected Bars row count")
  for i, spec in ipairs(want) do
    assertEqual(got[i].path, spec[1], "Bars row " .. i)
    assertEqual(got[i].subgroup, spec[2], "Bars row " .. i .. " subgroup")
    assertTrue(got[i].subgroup ~= got[i].group, "a subgroup may not repeat its tab's name")
  end
end)

test("the mirror row exists for target and focus but not the player", function()
  assertTrue(NS.FindSchemaRow("units.target.mirror") ~= nil)
  assertTrue(NS.FindSchemaRow("units.focus.mirror") ~= nil)
  assertEqual(NS.FindSchemaRow("units.player.mirror"), nil,
    "the player is the mirror source; a player mirror row would be circular")
end)

test("the mirror row is kept out of the auto-rendered body", function()
  -- The panel draws it bespoke in the header; it stays in the schema so /at set can reach it.
  assertEqual(NS.FindSchemaRow("units.focus.mirror").skipRender, true)
end)

-- General carries the three flat globals plus exactly one enable toggle per unit. Nothing else
-- unit-scoped belongs here: appearance is what the Appearance page's Unit banner is for, and a
-- second unit-scoped row would silently render all three units' copies at once (the General page
-- renders with ctx.unit nil, so SchemaForPage does no unit filtering).
test("General's rows are the flat globals plus one enable toggle per unit", function()
  local enables = {}
  for _, r in ipairs(NS.SchemaForPage("general")) do
    if r.unit then
      assertEqual(r.path, "units." .. r.unit .. ".enabled",
        r.path .. " is unit-scoped but is not an enable toggle")
      assertTrue(not enables[r.unit], "duplicate enable row for " .. r.unit)
      enables[r.unit] = true
    else
      assertTrue(not r.path:match("^units%."),
        r.path .. " writes a per-unit path but carries no unit tag")
    end
  end
  for _, unit in ipairs(NS.Units.LIST) do
    assertTrue(enables[unit], unit .. " has no enable toggle on General")
  end
end)

-- ── FormatSchemaValue's library seam ───────────────────────────────────────────────
--
-- The formatter itself is LibKa0s-Slash-1.0's and is covered in that repo. What this addon owns is
-- the seam: the major is resolved once at file load (library-stack-§4 — settings/Schema.lua loads
-- long after libs\LibKa0s\LibKa0s.xml, so the answer can never change later), and the branch taken
-- when that resolution came back empty.

test("FormatSchemaValue resolves the Slash major at load, never per call", function()
  local savedLibStub = T.mocks.LibStub
  local calls = 0
  T.mocks.LibStub = setmetatable({}, {
    __call = function(_, name, silent)
      calls = calls + 1
      return savedLibStub(name, silent)
    end,
  })
  local ok, err = pcall(function()
    NS.FormatSchemaValue({ type = "bool" }, true)
    NS.FormatSchemaValue({ type = "color" }, { r = 1, g = 0, b = 0, a = 1 })
  end)
  T.mocks.LibStub = savedLibStub
  if not ok then error(err) end
  assertEqual(calls, 0)
end)

test("a build without LibKa0s-Slash-1.0 falls back to a minimal FormatSchemaValue", function()
  -- Re-load settings/Schema.lua into a scratch namespace with the Slash major absent, which is the
  -- only way to reach the fallback now that the lookup happens once at load. The fallback is
  -- deliberately minimal: its sole caller is the debug-gated [Set] line, inert in that build.
  local Loader = dofile("tests/_kit/loader.lua")
  Loader.addonName = "AbsorbTracker"
  local savedLibStub = T.mocks.LibStub
  local mocks = setmetatable({
    LibStub = setmetatable({}, {
      __call = function(_, name, silent)
        if name == "LibKa0s-Slash-1.0" then return nil end
        return savedLibStub(name, silent)
      end,
    }),
  }, { __index = T.mocks })
  local NS2 = {}
  Loader.load("settings/Schema.lua", NS2, mocks)
  assertEqual(NS2.FormatSchemaValue({ type = "bool" }, nil), "nil")
  assertEqual(NS2.FormatSchemaValue({ type = "bool" }, true), "true")
  assertEqual(NS2.FormatSchemaValue({ type = "number", fmt = "%d px" }, 200), "200")
end)
