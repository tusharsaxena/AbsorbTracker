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
