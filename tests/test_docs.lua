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
--     `docs/perf-runs/` is only PARTLY frozen: its dated `.json` captures are records, but its
--     `README.md` is living prose and IS checked.
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
  -- Living docs that happen to sit in a subfolder. `docs/pending/LEDGER.md` is the open-items
  -- ledger and `docs/perf-runs/README.md` explains the capture format; both are rewritten as the
  -- addon changes, so both are ours to spell. The dated `.json` captures beside the latter are
  -- data, not prose, and are not globbed.
  add(glob("docs/pending/*.md"))
  add(glob("docs/perf-runs/*.md"))
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
