local _, NS = ...

-- Bar data + media access layer: the settings read seam (GetSetting), the cached
-- LibSharedMedia fetchers (texture/border/font with fallbacks), and the class-color-aware color
-- resolvers.
--
-- Color getters re-read the useClassColor* toggles on every call so a class change / respec /
-- profile switch "just works" without explicit refresh wiring — do NOT cache the resolved color
-- on a frame.

local C = NS.Constants

-- AceDB instance, set by core/Database.lua at init.
NS.db = nil

-- Cached LibSharedMedia reference.
local LSM

function NS.GetLSM()
    if LSM then return LSM end
    if LibStub then
        LSM = LibStub("LibSharedMedia-3.0", true)
    end
    return LSM
end

-- Clear the LSM cache (called on enable to pick up late-loading libs).
function NS.ClearLSMCache()
    LSM = nil
end

-- ── the two rows whose value is not in the profile ─────────────────────────────────────────
--
-- Every other schema row is stored in the active profile at its own path, and LibKa0s-Schema-1.0
-- (settings/Schema.lua) reads and writes it there. Two rows keep their value somewhere else, and
-- each CARRIES ITS OWN get/set, which the library consults before it ever walks a path. They are
-- stamped onto the two composed rows by settings/General.lua, so the panel widget, `/at set` and
-- `/at get` reach them down the SAME seam every other row takes.
--
--   * `state.debugConsole`, the console WINDOW's visibility (options-ui-§15). Session state, not a
--     setting: reset by a /reload, and not something the next character inherits. Its get/set is
--     the `{ get, set }` pair LibKa0s-DebugLog's ConsoleCheckbox answers, which both arms of
--     core/DebugLogSetup.lua publish. The row is `sessionOnly`, so neither a profile reset nor the
--     reset count nor the validator's defaults check treats it as profile data.
--   * C.MINIMAP_PATH (`global.minimap.shown`), below: STORED, but in the global store, under
--     LibDBIcon's own key, and inverted.

-- ── the minimap button's one boolean (launcher-§3) ───────────────────────────────────────
--
-- C.MINIMAP_PATH, `global.minimap.shown`, is the ONE path in this addon whose stored value is not in
-- the profile and is not session state. The path reads in the row's sense (SHOWN); the value is
-- LibDBIcon's own `hide` key, in the GLOBAL store, and LibDBIcon writes it too (core/Constants.lua
-- says why it lives there and why the sense is inverted). So the row's own get/set below resolve
-- it before any path is ever walked: nothing is stored at `global.minimap.shown`, and a `shown` key
-- must never be (anti-pattern #81).
--
-- NOT `sessionOnly`, which is the shape it most resembles. That flag means "this value's home is
-- not the db and a /reload ends it", and both halves are wrong here: the value IS stored, and the
-- validator, the reset count and settings/OptionsSetup.lua's reset veto all read `row.sessionOnly`
-- to decide what a reset may touch. A stored row wearing that flag would be reset by
-- `/at resetall`, which is a profile reset and must not reach an installation-scoped button.
local function minimapTable()
    local g = NS.db and NS.db.global
    return type(g) == "table" and g.minimap or nil
end

--- The minimap row's `get`. The row's sense is SHOWN and the stored key says HIDDEN, so it inverts
--- here. An absent table reads as shown, which is the declared default (defaults/Profile.lua).
function NS.MinimapShown()
    local t = minimapTable()
    return not (t and t.hide)
end

--- The minimap row's `set`: the other half of the inversion, plus the button itself. launcher-§3
--- wants the minimap button to follow the checkbox immediately rather than at the next reload, and
--- every writer of that row reaches this -- the panel widget, `/at set`, `/at reset` -- through
--- NS.SetByPath.
---
--- The store is written HERE and again inside Lb:SetShown, with the same value, which is the
--- library's stated bargain (libs/LibKa0s/Launcher.lua): a writer that is not this seam gets the
--- store updated without having to remember the inversion a second time. Writing it here anyway is
--- what keeps a build with no launcher at all -- no LibKa0s, no LibDBIcon -- still storing what the
--- player chose.
function NS.SetMinimapShown(value)
    local g = NS.db and NS.db.global
    if type(g) == "table" then
        g.minimap = g.minimap or {}
        g.minimap.hide = not value
    end
    if NS.Launcher then NS.Launcher:SetShown(value and true or false) end
end

--- Generic setting getter: the schema runtime's read, with the shipped defaults behind it. Accepts
--- both a flat global key ("locked") and a dotted per-unit path ("units.target.barWidth").
---
--- The fallback is for the one moment the runtime has nowhere to read: before OnInitialize has
--- built the db, where the answer the addon wants is the shipped default rather than nil. There is
--- no setter beside this: every write goes through NS.SetByPath (architecture-§5).
function NS.GetSetting(path)
    local S = NS.SchemaRuntime
    if S then
        local v = S.Get(path)
        if v ~= nil then return v end
    end
    return NS.ResolvePath(NS.flatDefaults, path)
end

-- Media getters. `unit` defaults to "player" so existing single-bar call sites keep working;
-- every read routes through Units.Get, which applies the mirror.
local function unitSetting(unit, key)
    return NS.Units.Get(unit or "player", key)
end

function NS.GetBarTexture(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", unitSetting(unit, "barTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBgTexture(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", unitSetting(unit, "bgTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBorder(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local border = lsm:Fetch("border", unitSetting(unit, "border"))
        if border then return border end
    end
    return C.FALLBACK_BORDER
end

function NS.GetFont(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local font = lsm:Fetch("font", unitSetting(unit, "font"))
        if font then return font end
    end
    return C.FALLBACK_FONT
end

-- ── colors ─────────────────────────────────────────────────────────────────────────────────
--
-- THE SHARED RESOLVER OWNS THREE OF THE FOUR SURFACES. This file used to carry a private
-- `GetPlayerClassColor` reading `C_ClassColor.GetClassColor`; it is gone, and bar, border and text
-- go through NS.ResolveColor (core/CoreSetup.lua -> LibKa0s-Core-1.0) instead. The three rules it
-- enforces are the three this file already stated: the stored alpha survives the mode, an
-- unresolvable class falls through to the stored swatch rather than to a hue nobody chose, and the
-- swatch is read under BOTH modes -- which is why no color row carries `disabledIf`
-- (settings/Appearance.lua states that reversal in full).
--
-- WHICH CLASS, AND IT IS NOT THE PLAYER'S ANY MORE. options-ui-§17: the color resolves to the class
-- of the unit the surface DESCRIBES, and these four surfaces describe the bar's own unit — so a
-- target bar with Use class color on now paints in the TARGET's class where it used to paint in
-- the player's. That is a visible change for existing users and it is the intended one.
--
-- THE CLASS UNIT IS THE RENDERING UNIT, NEVER THE APPEARANCE SOURCE. `unitSetting` above resolves
-- the mirror (NS.Units.Get), so a mirrored focus bar reads the PLAYER's stored swatch — and still
-- takes the FOCUS's class. The mirror copies styling; "use the class color" is a rule about whose
-- class, not a color to copy. Every getter below therefore passes its own `unit`, not
-- NS.Units.SourceUnit(unit).

local backgroundMultiplier = 0.2

local bgClassColors = {
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },  -- #C41E3A
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },  -- #A330C9
    DRUID       = { r = 1.00, g = 0.49, b = 0.04 },  -- #FF7C0A
    EVOKER      = { r = 0.20, g = 0.58, b = 0.50 },  -- #33937F
    HUNTER      = { r = 0.67, g = 0.83, b = 0.45 },  -- #AAD372
    MAGE        = { r = 0.25, g = 0.78, b = 0.92 },  -- #3FC7EB
    MONK        = { r = 0.00, g = 1.00, b = 0.60 },  -- #00FF98
    PALADIN     = { r = 0.96, g = 0.55, b = 0.73 },  -- #F48CBA
    PRIEST      = { r = 1.00, g = 1.00, b = 1.00 },  -- #FFFFFF
    ROGUE       = { r = 1.00, g = 0.96, b = 0.41 },  -- #FFF468
    SHAMAN      = { r = 0.00, g = 0.44, b = 0.87 },  -- #0070DD
    WARLOCK     = { r = 0.53, g = 0.53, b = 0.93 },  -- #8788EE
    WARRIOR     = { r = 0.78, g = 0.61, b = 0.43 },  -- #C69B6D
}

-- THE BACKGROUND KEEPS ITS OWN PALETTE, and options-ui-§17 says so in as many words: a darkened
-- per-class background set is a different set of hues, not the class color times a constant, and
-- the two must not be substituted for each other. So this one surface does NOT go through
-- NS.ResolveColor -- it is the exemption the rule names, not an addon that missed the memo.
--
-- What it does share is the scope: the palette is read for the RENDERING unit, so a target bar's
-- backdrop takes the target's class. Same nil-on-unknown contract as the shared resolver's.
--
-- Only the PLAYER's answer is memoized, and only on success -- the library's own rule, and for its
-- reason: a target changes class every time the player retargets, so a per-unit cache would need
-- invalidating on two events to save one table index.
local playerBgClassColor
local function GetBgClassColor(unit)
    unit = unit or "player"
    if unit == "player" and playerBgClassColor then return playerBgClassColor end
    -- pcall'd like the library's: the token is the caller's, and one the client rejects raises.
    local ok, _, classFilename = pcall(UnitClass, unit)
    local base = ok and type(classFilename) == "string" and bgClassColors[classFilename] or nil
    if not base then return nil end
    local c = {
        r = base.r * backgroundMultiplier,
        g = base.g * backgroundMultiplier,
        b = base.b * backgroundMultiplier,
    }
    if unit == "player" then playerBgClassColor = c end
    return c
end

--- Forget the memoized player background color. Suite seam only, and the twin of the library's
--- own `__ResetClassColor` -- a live session cannot need either, because the player's class does
--- not change inside one.
function NS.__ResetBgClassColor() playerBgClassColor = nil end

--- The background's own resolve, over the palette above. The three rules are the shared
--- resolver's; only the source table differs.
local function resolveBgColor(c, on, unit)
    if type(c) ~= "table" then c = {} end
    local a = c.a or 1
    if on then
        local cc = GetBgClassColor(unit)
        if cc then return cc.r, cc.g, cc.b, a end
    end
    return c.r or 1, c.g or 1, c.b or 1, a
end

function NS.GetBarColor(unit)
    unit = unit or "player"
    return NS.ResolveColor(unitSetting(unit, "barColor"),
        unitSetting(unit, "useClassColorBar"), unit)
end

function NS.GetBgColor(unit)
    unit = unit or "player"
    return resolveBgColor(unitSetting(unit, "bgColor"),
        unitSetting(unit, "useClassColorBg"), unit)
end

function NS.GetBorderColor(unit)
    unit = unit or "player"
    return NS.ResolveColor(unitSetting(unit, "borderColor"),
        unitSetting(unit, "useClassColorBorder"), unit)
end

--- The absorb amount's color. Same resolver, same scope, as the two above it.
function NS.GetFontColor(unit)
    unit = unit or "player"
    return NS.ResolveColor(unitSetting(unit, "fontColor"),
        unitSetting(unit, "useClassColorText"), unit)
end

-- ── the master multipliers ─────────────────────────────────────────────────────────────────
--
-- Master scale and Master alpha are the ADDON-WIDE controls options-ui-§15 mandates on the Master
-- controls tab, and they are a different question from the per-unit `barAlpha` on the Appearance
-- page: one governs all three bars at once, the other one bar. §15 forbids conflating them, so
-- neither replaces the other -- the master alpha MULTIPLIES the per-unit value below.
--
-- Both clamp for the same reason the per-unit alpha does: the number comes out of SavedVariables,
-- which a player can hand-edit, and a bad one must read as the nearest legal setting rather than
-- as the addon having stopped working. A non-number reads as the default.

--- The addon-wide opacity multiplier, clamped to the row's own 0 .. 1.
function NS.GetMasterAlpha()
    local v = tonumber(NS.GetSetting("alpha"))
    if not v then return NS.flatDefaults.alpha end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

--- The addon-wide scale, clamped to the row's own 0.5 .. 2.
function NS.GetMasterScale()
    local v = tonumber(NS.GetSetting("scale"))
    if not v then return NS.flatDefaults.scale end
    if v < 0.5 then return 0.5 end
    if v > 2 then return 2 end
    return v
end

--- The whole frame's opacity: the unit's own value TIMES the addon-wide one.
---
--- The clamp is not belt and braces. This value comes out of SavedVariables, which a player can
--- hand-edit and an older profile can be holding anything in; `bar:SetAlpha(0)` is an invisible bar
--- with no error and no way to tell it from the addon having stopped working. Clamping to the same
--- 0 .. 1 the row advertises means the worst a bad value can do is look like the nearest legal
--- setting. A non-number reads as the default rather than raising inside a paint pass.
---
--- The floor moved from 0.1 to 0 with the composer (options-ui-§16 fixes the bar block's opacity
--- range), so a fully transparent bar is now reachable -- deliberately, and from two rows. It is a
--- choice the player made twice over rather than a value they can only land on by hand-editing.
function NS.GetBarAlpha(unit)
    local v = tonumber(unitSetting(unit, "barAlpha"))
    if not v then v = NS.unitDefaults.barAlpha end
    v = v * NS.GetMasterAlpha()
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

-- ── the coalescing window ────────────────────────────────────────────────────────────────────

--- The repaint throttle, clamped to the row's own 0.05 .. 1 (the `throttleWindow` row in
--- settings/General.lua declares that min and max).
---
--- Here for the same reason the three getters above clamp, and with a sharper edge. This value
--- does not reach a paint call, it reaches AceTimer: `new()` opens with `if delay < 0.01 then`
--- (libs/AceTimer-3.0/AceTimer-3.0.lua:33), which is a COMPARISON — so a hand-edited SavedVariables
--- string raises "attempt to compare string with number" inside `ScheduleTimer`. modules/Timer.lua
--- clears `pending` inside the callback, so a raise on the way IN leaves `pending` nil: the next
--- absorb event re-arms, raises again, and every repaint for the rest of the session is lost with
--- an error frame apiece.
---
--- The other end matters too. A stored 0 compares fine and AceTimer floors it at its own 0.01,
--- which is a repaint every frame — the storm the throttle exists to prevent, reached by editing
--- the file that configures it.
---
--- The bounds are the slider's own rather than AceTimer's, for the same reason the alpha getters
--- use the slider's: a bad value should read as the nearest setting the row would have let the
--- player pick. A non-number reads as the default.
function NS.GetThrottleWindow()
    local v = tonumber(NS.GetSetting("throttleWindow"))
    if not v then return NS.flatDefaults.throttleWindow end
    if v < 0.05 then return 0.05 end
    if v > 1 then return 1 end
    return v
end
