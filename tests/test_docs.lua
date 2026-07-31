-- tests/test_docs.lua — the shipped prose is checkable, so it is checked.
--
-- Two rules about text that no code path can enforce and no reviewer reliably catches:
--
--   1. Angle-bracket argument placeholders must not appear in README.md. CurseForge's markdown
--      renderer treats `<path>` as an unknown HTML tag and strips it -- INSIDE backticks too --
--      so a command row that reads perfectly on GitHub ships to players with its argument
--      silently deleted. Real HTML (`<br>` in the Version History cells) is deliberate and stays.
--
--   2. US English is this collection's source dialect for every authored string and comment. A
--      repo where half the call sites say "colour" is a repo that one `grep -r color` no longer
--      sweeps. The check runs over the addon's OWN files only.
--
-- Deliberately out of scope, and why:
--   * `libs/` -- vendored. A spelling there is an upstream fix in the LibKa0s repo; a local patch
--     is silently reverted by the next whole-folder re-vendor.
--   * `tests/_kit/` -- likewise vendored, from LibKa0s/testkit.
--   * `docs/audits/`, `docs/reviews/`, `docs/superpowers/`, `docs/investigations/`,
--     `docs/perf-runs/` -- frozen dated bundles. Rewriting them destroys the record of what was
--     true on the day they were written.
--   * `docs/test-cases.md` -- generated from the suite; it inherits whatever the test names say.
--   * this file -- it has to name the words it forbids.
--
-- "cancelled" is absent from the list on purpose: every occurrence in this repo quotes the
-- library's own `perf run CANCELLED` output string, which is upstream's to change.

local T = _G.AT_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function readFile(path)
  local f = io.open(path, "r")
  assertTrue(f ~= nil, "cannot open " .. path .. " (tests run from the repo root)")
  local body = f:read("*a")
  f:close()
  return body
end

--- Shell glob -> sorted list of paths. `ls` is enough: the suite already runs from a POSIX shell.
local function glob(pattern)
  local out, p = {}, io.popen("ls -1 " .. pattern .. " 2>/dev/null")
  if not p then return out end
  for line in p:lines() do
    if line ~= "" then out[#out + 1] = line end
  end
  p:close()
  return out
end

-- ── README: no angle-bracket placeholders ──────────────────────────────────────────────────

-- The tags markdown genuinely wants in this README. Anything else between angle brackets is a
-- placeholder that CurseForge will eat.
local ALLOWED_TAGS = { br = true }

test("README.md carries no angle-bracket argument placeholders", function()
  local body = readFile("README.md")
  local lineNo, offenders = 0, {}
  for line in (body .. "\n"):gmatch("([^\n]*)\n") do
    lineNo = lineNo + 1
    for tag in line:gmatch("<([^<>]*)>") do
      if not ALLOWED_TAGS[tag:lower():match("^/?%s*(%a*)") or ""] then
        offenders[#offenders + 1] = "README.md:" .. lineNo .. " <" .. tag .. ">"
      end
    end
  end
  assertEqual(#offenders, 0,
    "CurseForge strips these even inside backticks; write the argument bare -- "
      .. table.concat(offenders, "; "))
end)

-- ── US English across the addon's own files ────────────────────────────────────────────────

local BRITISH = {
  behaviour = "behavior", behaviours = "behaviors", behavioural = "behavioral",
  colour = "color", colours = "colors", coloured = "colored", colouring = "coloring",
  initialise = "initialize", initialised = "initialized", initialising = "initializing",
  initialisation = "initialization",
  normalise = "normalize", normalised = "normalized", normalising = "normalizing",
  recognise = "recognize", recognised = "recognized",
  generalise = "generalize", generalises = "generalizes", generalised = "generalized",
  specialise = "specialize", specialised = "specialized",
  optimise = "optimize", optimised = "optimized", optimisation = "optimization",
  customise = "customize", customised = "customized",
  serialise = "serialize", summarise = "summarize", utilise = "utilize",
  organise = "organize", organised = "organized", organisation = "organization",
  authorise = "authorize", authorised = "authorized",
  prioritise = "prioritize", prioritised = "prioritized",
  analyse = "analyze", analysed = "analyzed", analysing = "analyzing",
  honour = "honor", honours = "honors", honoured = "honored",
  favour = "favor", favoured = "favored", favourite = "favorite",
  catalogue = "catalog", catalogues = "catalogs",
  centre = "center", centred = "centered", centres = "centers",
  defence = "defense", licence = "license",
  grey = "gray", greys = "grays", greyed = "grayed", greying = "graying",
  artefact = "artifact", artefacts = "artifacts",
  labelled = "labeled", modelling = "modeling", whilst = "while",
  memoised = "memoized", memoise = "memoize",
}

--- Every file this repo authors itself, as paths relative to the repo root.
local function ownFiles()
  local files = {}
  local function add(list)
    for _, p in ipairs(list) do files[#files + 1] = p end
  end
  add(glob("*.md"))
  add(glob("docs/*.md"))
  add(glob("core/*.lua"))
  add(glob("settings/*.lua"))
  add(glob("modules/*.lua"))
  add(glob("defaults/*.lua"))
  add(glob("locales/*.lua"))
  add(glob("tests/*.lua"))

  local skip = { ["docs/test-cases.md"] = true, ["tests/test_docs.lua"] = true }
  local kept = {}
  for _, p in ipairs(files) do
    if not skip[p] and not p:match("^tests/_kit/") then kept[#kept + 1] = p end
  end
  return kept
end

test("the addon's own files use US spellings", function()
  local paths = ownFiles()
  assertTrue(#paths > 20, "the glob found almost nothing (" .. #paths .. ") -- run from the root")

  local offenders = 0
  local report = {}
  for _, path in ipairs(paths) do
    local lineNo = 0
    for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
      lineNo = lineNo + 1
      for word in line:gmatch("%a+") do
        local us = BRITISH[word:lower()]
        if us then
          offenders = offenders + 1
          if #report < 12 then
            report[#report + 1] = path .. ":" .. lineNo .. " " .. word .. " -> " .. us
          end
        end
      end
    end
  end
  assertEqual(offenders, 0,
    "en-US is this collection's source dialect: " .. table.concat(report, "; "))
end)
