local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("ParseSchemaValue bool accepts truthy/falsey words, rejects junk", function()
  local row = { type = "bool" }
  assertEqual(NS.ParseSchemaValue(row, "on"), true)
  assertEqual(NS.ParseSchemaValue(row, "true"), true)
  assertEqual(NS.ParseSchemaValue(row, "0"), false)
  assertEqual(NS.ParseSchemaValue(row, "off"), false)
  local v, err = NS.ParseSchemaValue(row, "maybe")
  assertEqual(v, nil)
  assertTrue(err ~= nil)
end)

test("ParseSchemaValue number clamps to the row's min/max", function()
  local row = NS.FindSchemaRow("barWidth")  -- min 50, max 500
  assertTrue(row ~= nil, "barWidth row must exist")
  assertEqual(NS.ParseSchemaValue(row, "9999"), 500)
  assertEqual(NS.ParseSchemaValue(row, "10"), 50)
  assertEqual(NS.ParseSchemaValue(row, "200"), 200)
  local v, err = NS.ParseSchemaValue(row, "abc")
  assertEqual(v, nil)
  assertTrue(err ~= nil)
end)

test("ParseSchemaValue color accepts 0-1 and 0-255 and clamps to 0..1", function()
  local row = { type = "color" }
  local c = NS.ParseSchemaValue(row, "255 0 0 128")
  assertTrue(math.abs(c.r - 1) < 1e-6)
  assertEqual(c.g, 0)
  assertEqual(c.b, 0)
  assertTrue(math.abs(c.a - 128 / 255) < 1e-6)
  local c2 = NS.ParseSchemaValue(row, "0.5 0.5 0.5")
  assertTrue(math.abs(c2.a - 1) < 1e-6, "alpha defaults to 1")
end)

test("ParseSchemaValue string validates against allowed values", function()
  local row = { type = "string", values = { A = "a", B = "b" } }
  assertEqual(NS.ParseSchemaValue(row, "A"), "A")
  local v = NS.ParseSchemaValue(row, "Z")
  assertEqual(v, nil)
end)

test("FormatSchemaValue formats by type", function()
  assertEqual(NS.FormatSchemaValue({ type = "bool" }, true), "true")
  assertEqual(NS.FormatSchemaValue({ type = "bool" }, false), "false")
  assertEqual(NS.FormatSchemaValue({ type = "number", fmt = "%d px" }, 200), "200 px")
  assertEqual(NS.FormatSchemaValue({ type = "number" }, 3), "3")
  assertEqual(NS.FormatSchemaValue({ type = "color" }, { r = 1, g = 0, b = 0, a = 1 }),
    "{1.00, 0.00, 0.00, 1.00}")
end)

test("SchemaForPage keeps groups in registration order (Size, Bar, Background)", function()
  local rows = NS.SchemaForPage("bar")
  assertTrue(#rows >= 6, "bar page should have >= 6 rows")
  local order, seen = {}, {}
  for _, r in ipairs(rows) do
    if r.group and not seen[r.group] then
      seen[r.group] = true
      order[#order + 1] = r.group
    end
  end
  assertEqual(order[1], "Size")
  assertEqual(order[2], "Bar")
  assertEqual(order[3], "Background")
end)

test("ValidateSchema resolves every real path against defaults (0 errors, 0 missing)", function()
  local errors, resolved, missing = NS.ValidateSchema()
  assertEqual(errors, 0)
  assertEqual(missing, 0)
  assertTrue(resolved > 0, "at least one path should resolve")
end)

test("ValidateSchema reports a planted path that does not resolve against defaults", function()
  local bogus = { path = "doesNotExist", page = "bar", type = "number", label = "x" }
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
  for i, row in ipairs(NS.Schema) do
    local where = "row #" .. i .. " (" .. tostring(row.path) .. ")"
    assertTrue(type(row.label) == "string" and row.label ~= "", where .. " needs a label")
    assertTrue(type(row.desc) == "string" and row.desc ~= "", where .. " needs a desc")
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
  for _, row in ipairs(NS.Schema) do
    assertTrue(row.default ~= nil, tostring(row.path) .. " has no default to reset to")
  end
end)

test("every row's default matches the value in defaults.profile", function()
  -- Two sources for one value: the schema row drives /at reset, defaults.profile drives a fresh
  -- profile and the RunMigrations backfill. If they disagree, resetting a setting lands somewhere
  -- other than where a brand-new profile starts.
  local defaults = NS.defaults.profile
  for _, row in ipairs(NS.Schema) do
    local want = defaults[row.path]
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
  local paths = {}
  for _, row in ipairs(NS.Schema) do paths[row.path] = true end
  for key in pairs(NS.defaults.profile) do
    assertTrue(paths[key], "profile default '" .. key .. "' has no schema row")
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

test("`inverse` is only used on bool rows", function()
  -- The widget layer applies `inverse` by negating the value; on any other type that is nonsense.
  for _, row in ipairs(NS.Schema) do
    if row.inverse then
      assertEqual(row.type, "bool", row.path .. " uses inverse on a non-bool row")
    end
  end
end)

test("`disabledIf` names a real sibling setting", function()
  -- A typo'd disabledIf reads nil, which is falsey, so the widget would simply never grey out —
  -- a silent failure with no error to notice.
  for _, row in ipairs(NS.Schema) do
    if row.disabledIf then
      assertTrue(NS.defaults.profile[row.disabledIf] ~= nil,
        row.path .. " disabledIf='" .. row.disabledIf .. "' does not resolve")
    end
  end
end)

test("every schema row lands on a page the panel actually builds", function()
  local pages = { general = true, bar = true, border = true, font = true, profiles = true }
  for _, row in ipairs(NS.Schema) do
    assertTrue(pages[row.page], tostring(row.path) .. " is on unknown page " .. tostring(row.page))
  end
end)

-- ── SetByPath / ApplyDefault dispatch ──────────────────────────────────────────────

test("FindSchemaRow returns the row for a known path and nil for an unknown one", function()
  local row = NS.FindSchemaRow("barWidth")
  assertTrue(row ~= nil and row.path == "barWidth")
  assertEqual(NS.FindSchemaRow("nothingLikeThis"), nil)
end)

test("SetByPath writes the value and fires the row's own onChange with it", function()
  local row = NS.FindSchemaRow("barWidth")
  local saved = row.onChange
  local got
  row.onChange = function(v) got = v end
  local ok, err = pcall(NS.SetByPath, "barWidth", 240)
  row.onChange = saved
  if not ok then error(err) end
  assertEqual(NS.GetSetting("barWidth"), 240)
  assertEqual(got, 240, "the onChange receives the written value")
  NS.SetByPath("barWidth", NS.flatDefaults.barWidth)
end)

test("SetByPath falls back to broadcasting APPEARANCE for a row with no onChange", function()
  local row = NS.FindSchemaRow("barWidth")
  local saved = row.onChange
  row.onChange = nil
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.APPEARANCE, function() seen = seen + 1 end)
  local ok, err = pcall(NS.SetByPath, "barWidth", 210)
  target:UnregisterMessage(NS.MSG.APPEARANCE)
  row.onChange = saved
  if not ok then error(err) end
  assertEqual(seen, 1, "the default onChange repaints the bar's appearance")
  NS.SetByPath("barWidth", NS.flatDefaults.barWidth)
end)

test("SetByPath still writes a value that has no schema row at all", function()
  -- The write happens before the row lookup, so an internal (non-schema) key round-trips.
  NS.SetByPath("someInternalKey", 7)
  assertEqual(NS.GetSetting("someInternalKey"), 7)
  NS.db.profile.someInternalKey = nil
end)

test("ApplyDefault deep-copies a colour table so profiles never share one", function()
  -- Handing out the row's own table would let a ColorPicker drag in one profile mutate the schema
  -- default itself, and through it every other profile that was reset from it.
  local row = NS.FindSchemaRow("barColor")
  assertTrue(row ~= nil, "barColor is a colour row")
  NS.ApplyDefault(row)
  local stored = NS.GetSetting("barColor")
  assertTrue(stored ~= row.default, "the stored table must be a copy, not the row's own")
  stored.r = 0.123
  assertTrue(row.default.r ~= 0.123, "mutating the stored colour must not reach the default")
  NS.ApplyDefault(row)
end)

test("ApplyDefault is a no-op for a row with no default", function()
  NS.SetSetting("barWidth", 250)
  NS.ApplyDefault({ path = "barWidth", type = "number" })   -- no `default` key
  assertEqual(NS.GetSetting("barWidth"), 250, "nothing should have been written")
  NS.SetSetting("barWidth", NS.flatDefaults.barWidth)
end)
