local T = _G.AT_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- FB2-AT-01 (Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH, decision D1, LibKa0s#104): every
-- named sample person an addon draws (test mode, the sim, a preview, an unlock stand-in, a sample
-- chat line or toast) comes from LibKa0s-Sim-1.0, its five protagonists (Sim.Sample) or its seeded
-- crowd (Sim.SampleCrowd), never from a list or literal the addon keeps. Absorb Tracker draws no
-- named person today (its bars show shield values and its strips the unit's label), so this guard
-- holds it there: no "Sample..." or "Mock..." name literal lives outside tests/, libs/ and the frozen
-- bundles.

local FROZEN = { "docs/audits/", "docs/reviews/", "docs/automated-tests/", "docs/perf-analysis/",
                 "docs/revendor/", "docs/superpowers/" }
local SKIP = { "libs/", "tests/", "media/" }
local TEXT = { lua = true, toc = true, xml = true, md = true, txt = true }
-- English words the two prefixes start, which are not names.
local WORDS = { Sampled = true, Sampler = true, Samplers = true, Sampling = true, Mockup = true,
                Mockups = true, Mocked = true, Mocking = true }

--- The repo's tracked files (git), else every file under the root.
local function files()
  local out = {}
  local function collect(cmd)
    local p = io.popen and io.popen(cmd)
    if not p then return end
    for line in p:lines() do
      local path = line:gsub("[\r\n]+$", ""):gsub("^%./", "")
      if path ~= "" then out[#out + 1] = path end
    end
    p:close()
  end
  collect("git ls-files 2>/dev/null")
  if #out == 0 then collect("find . -type f -not -path './.git/*' 2>/dev/null") end
  return out
end

local function startsWithAny(path, list)
  for _, prefix in ipairs(list) do
    if path:sub(1, #prefix) == prefix then return true end
  end
  return false
end

--- The paths this guard reads.
local function scanned()
  local out = {}
  for _, path in ipairs(files()) do
    local ext = path:match("%.(%w+)$")
    if ext and TEXT[ext:lower()] and not startsWithAny(path, SKIP) and not startsWithAny(path, FROZEN) then
      out[#out + 1] = path
    end
  end
  return out
end

--- Each sample-name literal in `body`, as "line: word".
local function hits(body)
  local out, n = {}, 0
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    n = n + 1
    for _, prefix in ipairs({ "Sample", "Mock" }) do
      for word in line:gmatch("%f[%w]" .. prefix .. "%l%l+%f[%W]") do
        if not WORDS[word] then out[#out + 1] = n .. ": " .. word end
      end
    end
  end
  return out
end

test("sample names: the guard reads the addon's own source and docs", function()
  local seen = {}
  for _, path in ipairs(scanned()) do seen[path] = true end
  assertTrue(seen["modules/Sim.lua"], "the sim's source is read")
  assertTrue(seen["core/Data.lua"], "the preview stand-in's source is read")
  assertTrue(seen["docs/smoke-tests.md"], "the living docs are read")
  assertTrue(not seen["libs/LibKa0s/Sim.lua"], "the library's own data is not")
end)

test("sample names: the guard flags a planted name and passes words and the prefixes alone", function()
  assertEqual(#hits('local who = "Samplehunter-Samplerealm"'), 2)
  assertEqual(#hits("pet = 'Mockfang'"), 1)
  assertEqual(#hits("Sampled once, a Mockup, Samples and Mock data"), 0)
end)

test("sample names: no sample-name literal outside tests/, libs/ and the frozen bundles", function()
  local bad = {}
  for _, path in ipairs(scanned()) do
    local f = io.open(path, "r")
    if f then
      local body = f:read("*a")
      f:close()
      for _, h in ipairs(hits(body)) do bad[#bad + 1] = path .. ":" .. h end
    end
  end
  assertEqual(#bad, 0, "take named sample people from LibKa0s-Sim-1.0 (Sample, SampleCrowd): "
    .. table.concat(bad, ", "))
end)
