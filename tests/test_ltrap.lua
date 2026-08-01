-- tests/test_ltrap.lua — the `L` trap, pinned in the one place that sees every seam at once.
--
-- THE FAILURE. Every LibKa0s module that takes an `L` override resolves the descriptor's table
-- first and its own STRINGS second. This addon's locale table answers EVERY key with a string,
-- because the Ka0s standard mandates the metatable fallback (locales/enUS.lua:6):
--
--     NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })
--
-- So a descriptor holding `L = NS.L` makes the library's own strings unreachable and the addon
-- renders raw SCREAMING_SNAKE keys — PANEL_TITLE_SUFFIX, STEP_START, LIST_HEADER — in place of
-- English. It fails for every key at once and only in game. KickCD shipped exactly that panel.
--
-- THREE GUARDS, and they are honest about which half of the failure each one can see.
--
--   1. The SOURCE check below. It is the one that reddens on the mistake itself — adding
--      `L = NS.L` to any of the five seam descriptors — and it is the only guard that can, because
--      of (3). It reads the seam files rather than the loaded namespace: a descriptor field is not
--      observable after `lib:New` returns.
--   2. The RENDERED checks, in each module's own suite (tests/test_debuglog.lua,
--      tests/test_slash.lua, tests/test_perf.lua, tests/test_helpers.lua). Those assert on the
--      string the library actually produced, reached through a real accessor on the live instance,
--      so they redden if a resolver ever lets a synthesised key through.
--   3. The LIBRARY-REGRESSION checks below. The vendored copy resolves an override with `rawget`
--      (DebugLog 3 / Slash 4 / Perf 5), so a fallback-only locale table now correctly falls
--      THROUGH and `L = NS.L` renders prose anyway. That hardening is what these pin — hand the
--      vendored library the exact table shape every Ka0s host has and require the built-in string
--      back. If a future re-vendor regresses the resolver to a plain index, this is what says so
--      before the panel does.
--
-- Only DebugLog, Slash and Perf take an `L` at all. LibKa0s-Core-1.0 has no STRINGS table and no
-- `L` descriptor field, and LibKa0s-Options-1.0's `L` is `lib.LAYOUT` — a geometry table, not a
-- locale one; its user-visible strings come from `lib.STRINGS` with no override path. Writing a
-- descriptor-mutation case for either would be a case that cannot fail, so neither has one. The
-- source check still covers both files, because the mistake to catch is someone ADDING an `L`.

local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertNil

-- The five seams, in TOC load order. Kept as a literal list rather than a glob so a new seam has
-- to be added deliberately — see CLAUDE.md, "LibKa0s is vendored".
local SEAMS = {
  "core/CoreSetup.lua",
  "core/DebugLogSetup.lua",
  "core/PerfSetup.lua",
  "settings/Slash.lua",
  "settings/OptionsSetup.lua",
}

-- The exact shape locales/enUS.lua produces, rebuilt rather than reused so a test cannot leave a
-- key rawset on the real NS.L.
local function fallbackLocale()
  return setmetatable({}, { __index = function(_, k) return k end })
end

-- ── 1. the source check ────────────────────────────────────────────────────────────
--
-- red under: adding `L = NS.L,` to any seam descriptor.

test("no LibKa0s descriptor in this addon is handed the key-returning locale table", function()
  -- The general form, so the next seam file cannot reintroduce it. A table whose __index
  -- synthesises a value for an unknown key can never be a valid `L` override: it answers every
  -- key. Pass nothing (this addon translates nothing, so that is the whole answer), or pass a
  -- plain table holding only the keys actually translated.
  local offenders = {}
  for _, rel in ipairs(SEAMS) do
    local fh = assert(io.open(rel, "r"), "cannot open " .. rel .. " (tests run from the repo root)")
    local n = 0
    for line in fh:lines() do
      n = n + 1
      -- `L = NS.L` in any spacing, and the aliased form a refactor might leave behind.
      if line:match("^%s*L%s*=%s*NS%.L%s*[,}]?%s*$") or line:match("[{,]%s*L%s*=%s*NS%.L%s*[,}]") then
        offenders[#offenders + 1] = rel .. ":" .. n .. "  " .. line:match("^%s*(.-)%s*$")
      end
    end
    fh:close()
  end
  assertEqual(#offenders, 0,
    "a seam descriptor was handed NS.L — the library renders raw keys against any vendored copy\n"
    .. "older than DebugLog 3 / Slash 4 / Perf 5:\n  " .. table.concat(offenders, "\n  "))
end)

test("locales/enUS.lua really does answer every key, so the check above guards something", function()
  -- Non-vacuity. If NS.L ever stopped synthesising, the trap would not exist and the source check
  -- would be dead weight rather than a guard — this case is what would notice.
  assertEqual(NS.L["NO_SUCH_KEY_ANYWHERE"], "NO_SUCH_KEY_ANYWHERE",
    "the standard's metatable fallback is what makes NS.L unusable as an `L` override")
  assertNil(rawget(NS.L, "NO_SUCH_KEY_ANYWHERE"),
    "and rawget is what lets the current library see through it")
end)

-- ── 3. the library-regression checks ───────────────────────────────────────────────
--
-- red under: a re-vendor that regresses any resolver from rawget back to a plain index.

test("vendored DebugLog resolves a fallback-only override to its own strings", function()
  local lib = T.mocks.LibStub("LibKa0s-DebugLog-1.0", true)
  assertTrue(lib ~= nil, "the vendored DebugLog major must be registered")
  local D = lib:New({
    name = "LTrapProbe", title = "L Trap Probe",
    -- The fields DebugLog:New validates up front.
    font = NS.Constants.FONT_MONO,
    isEnabled = function() return false end,
    setEnabled = function() end,
    L = fallbackLocale(),
  })
  local label = D:ConsoleCheckbox().label
  assertNil(label:match("^[A-Z][A-Z0-9_]+$"),
    "the vendored library let a synthesised key through as '" .. label .. "'")
  assertEqual(label, lib.STRINGS.CHECKBOX_LABEL,
    "it must fall through to the library's own string")
end)

test("vendored Slash resolves a fallback-only override to its own strings", function()
  local lib = T.mocks.LibStub("LibKa0s-Slash-1.0", true)
  assertTrue(lib ~= nil, "the vendored Slash major must be registered")
  local Sl = lib:New({
    slash = "/ltrapprobe", commands = {}, print = function() end,
    allRows = function() return {} end,
    L = fallbackLocale(),
  })
  local line = Sl:BuildListLines()[1]
  assertNil(line:match("^[A-Z][A-Z0-9_]+$"),
    "the vendored library let a synthesised key through as '" .. line .. "'")
  assertEqual(line, lib.STRINGS.LIST_EMPTY,
    "it must fall through to the library's own string")
end)

test("vendored Perf resolves a fallback-only override to its own strings", function()
  local lib = T.mocks.LibStub("LibKa0s-Perf-1.0", true)
  assertTrue(lib ~= nil, "the vendored Perf major must be registered")
  local P = lib:New({
    name = "LTrapProbe", sv = "LTrapProbeDB",
    suspend = function() end, resume = function() end,
    L = fallbackLocale(),
  })
  assertTrue(#(P.STEPS or {}) > 0, "the probe instance must have built its step list")
  for _, step in ipairs(P.STEPS) do
    assertNil(step.label:match("^[A-Z][A-Z0-9_]+$"),
      "the vendored library let a synthesised key through as '" .. step.label .. "'")
    assertEqual(step.label, lib.STRINGS[step.string],
      "it must fall through to the library's own string")
  end
end)
