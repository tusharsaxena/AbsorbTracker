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
--   * `docs/audits/`, `docs/reviews/`, `docs/superpowers/`, `docs/investigations/` -- frozen dated
--     bundles. Rewriting them destroys the record of what was true on the day they were written.
--     `docs/perf-analysis/` is only PARTLY frozen: its dated `<YYYYMMDD-HHMMSS>/` capture bundles
--     are records, but the `README.md` beside them is living prose and IS checked.
--   * `docs/test-cases.md` -- generated from the suite; it inherits whatever the test names say.
--   * this file -- it has to name the words it forbids.
--
-- "cancelled" is absent from the list on purpose: it never had a live site of its own here --
-- every occurrence quoted the library's output string, which was upstream's to change. LibKa0s
-- v1.27.0 changed it, so the quotes now read CANCELED and the word is gone from this repo.

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

-- ── The Tier 2 documentation map says what docs/ actually holds ─────────────────

-- `documentation-§3` files a conditional doc as Present or as Not applicable, and Not applicable is
-- a valid state that MUST be stated rather than left to an empty directory listing. What it must not
-- be is wrong: a row reading Not applicable beside a trigger that has fired is indistinguishable, to
-- everything except a human re-deriving the trigger, from a doc nobody has written yet. That is
-- exactly what this repo carried -- seventeen verbs and a `PROFILE_VERBS` tree filed as "no
-- subcommand tree" -- and it survived three audits because nothing checked it.
--
-- So the two halves are checked against the disk. Present must name a file; Not applicable must not.
-- The trigger itself is prose and stays a human's to read; the status is not, and this is the half a
-- machine can hold.

test("every Tier 2 documentation-map row agrees with docs/", function()
  local body = readFile("docs/ARCHITECTURE.md")
  local section = body:match("### Conditional[^\n]*\n(.-)\n###")
  assertTrue(section ~= nil,
    "docs/ARCHITECTURE.md has no `### Conditional ... Tier 2` section to read")

  local rows, offenders = 0, {}
  for doc, status in section:gmatch("|%s*`([^`]+)`%s*|%s*([^|]-)%s*|") do
    if status == "Present" or status == "Not applicable" then
      rows = rows + 1
      local path = "docs/" .. doc
      local f = io.open(path, "r")
      local exists = f ~= nil
      if f then f:close() end
      if status == "Present" and not exists then
        offenders[#offenders + 1] = doc .. " is filed Present and does not exist"
      elseif status == "Not applicable" and exists then
        offenders[#offenders + 1] = doc .. " exists and is filed Not applicable"
      end
    end
  end

  assertTrue(rows >= 5, "read only " .. rows .. " Tier 2 rows -- the table shape changed")
  assertEqual(#offenders, 0, "the map and the directory disagree: "
    .. table.concat(offenders, "; "))
end)


-- ── The deviation register's own citations resolve ─────────────────────────────

-- `audit-review-history`'s third MUST: an id a register row cites in **Why** has to resolve -- a
-- deviation id into `docs/audits/`, a finding id into `docs/reviews/`, an issue number onto this
-- repo. An id that resolves to nothing is worse than no citation at all, because it reads as
-- evidence and leads to none, and it survives every re-read by a maintainer who knows the shape of
-- an id and never goes looking for what it names.
--
-- The check is deliberately NOT "the string appears somewhere under `docs/audits/`". A bundle that
-- REPORTS a dead citation quotes the dead id while doing so, so a substring search goes green on
-- the very defect it was written for -- `testing-§12`'s failure mode, sitting inside the gate for
-- it. What counts is the id being ASSIGNED: standing at the head of a markdown table cell, a
-- heading or a bullet, which is where every bundle in this repo puts a row's own id, and where
-- prose that merely mentions one never puts it.
--
-- Scope is the **deviation** id -- this repo's own audit-bundle prefix, which is what
-- `documentation-§3` puts in a row's Why cell and what a bundle under `docs/audits/` assigns.

local DEVIATION_ID = { "%f[%w]AT%-[%u%-]*%d+", "%f[%w]ABSORBTRACKER%-[%u%-]*%d+" }

--- Every `.md` under a dated bundle directory.
local function bundleFiles()
  return glob("docs/audits/*/*.md")
end

--- Does `id` head a table cell, a heading or a bullet anywhere in `files`?
local function isAssigned(id, files)
  local function heads(s)
    return s:sub(1, #id) == id and not s:sub(#id + 1, #id + 1):match("[%w%-]")
  end
  for _, path in ipairs(files) do
    for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
      local trimmed = line:gsub("^%s+", "")
      local lead = trimmed:match("^#+%s*(.*)$") or trimmed:match("^[%-%*]%s+(.*)$")
      if lead and heads((lead:gsub("^[%s%*`%[]+", ""))) then return true end
      if trimmed:sub(1, 1) == "|" then
        for field in (trimmed .. "|"):gmatch("([^|]*)|") do
          if heads((field:gsub("^[%s%*`%[]+", ""))) then return true end
        end
      end
    end
  end
  return false
end

test("every deviation id the register cites is assigned by a bundle in docs/audits/", function()
  -- The sentinel is what lets the register be the file's LAST `##` section without the slice
  -- silently coming back nil and the case passing on an empty string.
  local body = readFile("docs/ARCHITECTURE.md") .. "\n## \n"
  local section = body:match("\n## Documented deviations\r?\n(.-)\r?\n## ")
  assertTrue(section ~= nil,
    "docs/ARCHITECTURE.md has no `## Documented deviations` section to read")

  local files = bundleFiles()
  assertTrue(#files > 0, "no bundle files under docs/audits/ -- nothing to resolve against")

  local seen, cited, offenders = {}, 0, {}
  for _, pattern in ipairs(DEVIATION_ID) do
    for pos, id in section:gmatch("()(" .. pattern .. ")") do
      -- A hyphen in front means this is the tail of a longer id (a work-item `M1-LK-11`), not a
      -- citation of a bundle row.
      if section:sub(pos - 1, pos - 1) ~= "-" and not id:find("%-R%-") and not seen[id] then
        seen[id] = true
        cited = cited + 1
        if not isAssigned(id, files) then offenders[#offenders + 1] = id end
      end
    end
  end

  assertTrue(cited > 0,
    "the register cites no deviation id at all -- either the rows changed or DEVIATION_ID did")
  assertEqual(#offenders, 0,
    "cited by a register row and assigned by no bundle under docs/audits/: "
      .. table.concat(offenders, ", "))
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
  recentre = "recenter", recentres = "recenters", recentred = "recentered",
  defence = "defense", licence = "license",
  grey = "gray", greys = "grays", greyed = "grayed", greying = "graying",
  artefact = "artifact", artefacts = "artifacts",
  labelled = "labeled", modelling = "modeling", whilst = "while",
  memoised = "memoized", memoise = "memoize",
  neighbour = "neighbor", neighbours = "neighbors", neighbouring = "neighboring",
  synthesise = "synthesize", synthesises = "synthesizes",
  synthesised = "synthesized", synthesising = "synthesizing",
  unrecognised = "unrecognized", unrecognise = "unrecognize",
  renormalise = "renormalize", renormalised = "renormalized",
  serialises = "serializes", serialised = "serialized", serialising = "serializing",
  summarises = "summarizes", summarised = "summarized", summarising = "summarizing",
  utilises = "utilizes", utilised = "utilized", utilising = "utilizing",
  alphabetise = "alphabetize", alphabetising = "alphabetizing",
  acknowledgement = "acknowledgment", acknowledgements = "acknowledgments",
  judgement = "judgment",
  signalling = "signaling", signalled = "signaled",
  travelled = "traveled", travelling = "traveling",
  cancelling = "canceling",
  dialogue = "dialog", dialogues = "dialogs",
  practise = "practice", programme = "program", fulfil = "fulfill",
  amongst = "among", learnt = "learned", ageing = "aging",
  paralyse = "paralyze", paralysed = "paralyzed",
  offence = "offense", pretence = "pretense",
  sceptic = "skeptic", sceptical = "skeptical",
  metre = "meter", metres = "meters", fibre = "fiber", calibre = "caliber",
  mould = "mold", moulded = "molded", sulphur = "sulfur",

  -- The rest of the inflections, and the -ise stems the list above never named. A table built
  -- from base forms only is a table that greenlights the inflection: `serialise` was listed and
  -- `serialises` was not, which is how "serialises" reached ARCHITECTURE.md under a green suite.
  -- Every -ise stem this collection plausibly writes gets its full -e/-es/-ed/-ing/-ation set.
  --
  -- `analyses` is deliberately ABSENT: it is also the correct US plural of "analysis", and a
  -- guard that reddens on a correct word gets deleted rather than obeyed.
  initialises = "initializes",
  normalises = "normalizes", normalisation = "normalization",
  renormalises = "renormalizes", renormalising = "renormalizing",
  recognises = "recognizes", recognising = "recognizing", recognisable = "recognizable",
  unrecognisable = "unrecognizable",
  generalising = "generalizing", generalisation = "generalization",
  specialises = "specializes", specialising = "specializing",
  optimises = "optimizes", optimising = "optimizing", optimisations = "optimizations",
  customises = "customizes", customising = "customizing", customisation = "customization",
  serialisation = "serialization",
  deserialise = "deserialize", deserialises = "deserializes",
  deserialised = "deserialized", deserialising = "deserializing",
  summarisation = "summarization",
  organises = "organizes", organising = "organizing", organisational = "organizational",
  authorises = "authorizes", authorising = "authorizing", authorisation = "authorization",
  prioritises = "prioritizes", prioritising = "prioritizing", prioritisation = "prioritization",
  alphabetises = "alphabetizes", alphabetised = "alphabetized",
  categorise = "categorize", categorises = "categorizes", categorised = "categorized",
  categorising = "categorizing", categorisation = "categorization",
  sanitise = "sanitize", sanitises = "sanitizes", sanitised = "sanitized",
  sanitising = "sanitizing", sanitisation = "sanitization",
  visualise = "visualize", visualises = "visualizes", visualised = "visualized",
  visualising = "visualizing", visualisation = "visualization",
  minimise = "minimize", minimises = "minimizes", minimised = "minimized",
  minimising = "minimizing", minimisation = "minimization",
  maximise = "maximize", maximises = "maximizes", maximised = "maximized",
  maximising = "maximizing", maximisation = "maximization",
  itemise = "itemize", itemises = "itemizes", itemised = "itemized", itemising = "itemizing",
  randomise = "randomize", randomises = "randomizes", randomised = "randomized",
  randomising = "randomizing", randomisation = "randomization",
  tokenise = "tokenize", tokenises = "tokenizes", tokenised = "tokenized",
  tokenising = "tokenizing", tokenisation = "tokenization",
  capitalise = "capitalize", capitalises = "capitalizes", capitalised = "capitalized",
  capitalising = "capitalizing", capitalisation = "capitalization",
  localise = "localize", localises = "localizes", localised = "localized",
  localising = "localizing", localisation = "localization",
  modularise = "modularize", modularised = "modularized", modularising = "modularizing",
  standardise = "standardize", standardises = "standardizes", standardised = "standardized",
  standardising = "standardizing", standardisation = "standardization",
  colourise = "colorize", colourised = "colorized", colourising = "colorizing",
  greyscale = "grayscale", greyish = "grayish",
  behaviourally = "behaviorally",
  centring = "centering", recentring = "recentering",
  favours = "favors", favouring = "favoring", favourites = "favorites",
  honouring = "honoring",
  licences = "licenses", defences = "defenses",
  labelling = "labeling", modelled = "modeled",
  practises = "practices", practised = "practiced", practising = "practicing",
  programmes = "programs",
  paralyses = "paralyzes", paralysing = "paralyzing",
  fulfils = "fulfills",
  neighbourhood = "neighborhood", neighbourly = "neighborly",
  memoises = "memoizes", memoising = "memoizing",
  artefactual = "artifactual",
  judgements = "judgments",
  offences = "offenses", sceptically = "skeptically",
  fibres = "fibers", moulds = "molds", moulding = "molding",
}

--- Every file this repo authors itself, as paths relative to the repo root.
local function ownFiles()
  local files = {}
  local function add(list)
    for _, p in ipairs(list) do files[#files + 1] = p end
  end
  add(glob("*.md"))
  add(glob("*.toc"))
  add(glob("docs/*.md"))
  -- Living docs that happen to sit in a subfolder. `docs/perf-analysis/README.md` explains the
  -- capture format and the store's index, and is rewritten as the addon changes, so it is ours to
  -- spell. The dated capture bundles beside it are frozen, sit one level deeper, and are not
  -- globbed.
  -- (`docs/pending/` is gone: the open-items ledger was retired and its contents moved to GitHub
  -- issues, so there is no longer a pending doc to scan. See standards `audit-review-history`.)
  add(glob("docs/perf-analysis/*.md"))
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
