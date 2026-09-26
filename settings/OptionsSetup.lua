local _, NS = ...

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0.
--
-- The settings-canvas shell, the schema-row to AceGUI translation and the two-column flow engine
-- live in libs/LibKa0s/{Options,OptionsWidgets,OptionsScroll}.lua and are shared across every Ka0s
-- addon. This file is only the part that is ours: where a value lives, which rows belong to which
-- page, what a color looks like on disk, and what "reset everything" has to clear that no schema
-- row owns.
--
-- It replaces four files that used to be this addon's own toolkit — settings/Panel.lua,
-- settings/Helpers.lua, settings/ScrollPatch.lua and settings/Widgets.lua. `NS.Helpers` keeps its
-- name and keeps answering every member it answered before: forty-odd call sites across the page
-- files and the suites index it directly, and renaming it would have been churn with no reader on
-- the other side. What changed is where the implementations come from.
--
-- Loads immediately after settings/Slash.lua and BEFORE every settings/<page>.lua, because those
-- files call NS.Helpers.LSMValues at file load. See the stub below for what that costs.

local print = NS.Print

-- Brand string, read by the library's header builder and by the top-level canvas registration. A
-- file-scope local, not an NS export: it reaches the library as descriptor.parentTitle, and the two
-- files that used to read it off the namespace (settings/Panel.lua, settings/Helpers.lua) are inside
-- the library now.
local PARENT_TITLE = NS.Constants.BRAND

-- The one rule about what a global reset must not touch. Profiles rows are AceDBOptions-supplied and
-- resetting them deletes user data, which is not what "restore defaults" means to anyone. Named once
-- because it is enforced TWICE: by the library, through descriptor.skipRestoreAll below, and by the
-- degradation stub's own reset loop, which has to keep working with no library at all. Two literal
-- copies of the rule — which is what this file used to carry, in opposite polarity — is one added
-- page away from a degraded `/at resetall` that deletes profiles.
--
-- EVERY PROFILE-BACKED ROW IS VETOED TOO (options-ui-§12). The global reset IS a profile reset now —
-- see resetProfile below — so walking the schema first and writing each row's default into the
-- profile would fire the panel refresh once per row for values about to be discarded whole. What the
-- walk is left with is exactly what a profile reset cannot reach: the sessionOnly rows, whose
-- storage is their own `set()` rather than the db.
-- ONE ROW SURVIVES EVERY RESET, and launcher-§3 states that as a PROPERTY of the setting rather
-- than deriving it from where the value happens to live. Whether the minimap button is shown is a
-- per-installation display preference, in the same class as the ANGLE the player dragged it to --
-- which LibDBIcon keeps in the very same table, and which no reset in the collection touches.
-- Nobody has ever wanted *reset my settings* to mean *and put the button back on my minimap*.
--
-- THE DERIVATION THAT USED TO STAND IN FOR THIS WAS TRUE AND INSUFFICIENT. Reset all settings is a
-- profile reset (options-ui-§12) and this row is in the GLOBAL store, so that reset genuinely
-- cannot reach it -- twice over here, because `vetoedFromResetAll` below already vetoes every
-- non-sessionOnly row. But the argument was only ever about that ONE act, and this addon ships a
-- second: the General page's Defaults button, which walks `rowsForPage("general")` and resets each
-- row it finds. The minimap row is on that page, carrying `default = true`, and the library's
-- RestoreDefaults consults no veto at all -- so one press put a deliberately hidden button back.
--
-- ENFORCED BY THE SCHEMA RUNTIME'S `resetExempt` (settings/Schema.lua, LibKa0s-Schema-1.0), which
-- ApplyDefault honors while a bracket is open. RestoreDefaults and RestoreAllDefaults each open one
-- around their walk, so both are covered, and so is any reset the library grows later that
-- brackets its sweep. It is not a wrapper on this descriptor's `applyDefault` any more: the
-- runtime's own ApplyDefault calls its own Set, so a wrapper here would be bypassed by a reset
-- driven through the instance. `/at reset global.minimap.shown` is deliberately NOT covered: a
-- single named reset opens no bracket, and a player who names this row is asking for exactly it.
local function survivesEveryReset(row)
    return row.path == NS.Constants.MINIMAP_PATH
end

local function vetoedFromResetAll(row)
    if survivesEveryReset(row) then return true end
    if row.page == "profiles" then return true end
    return not row.sessionOnly
end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

-- ---------------------------------------------------------------------
-- The descriptor
-- ---------------------------------------------------------------------

local descriptor = {
    parentTitle   = PARENT_TITLE,
    mainPanelName = "AbsorbTrackerMainPanel",

    print = function(line) print(line) end,
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

    -- The schema seams, all LibKa0s-Schema-1.0's (settings/Schema.lua). SetByPath rather than a
    -- bare write, so a panel change takes exactly the path a `/at set` takes: the [Set] debug line,
    -- the row's onChange, and the panel refresh. `get` is the host's read, which adds the shipped
    -- defaults behind the runtime's. `set` and `applyDefault` look the host's names up at call time
    -- rather than capturing the members, which keeps them the one seam a suite can spy on; neither
    -- carries a gate (a refusal would belong in the row's `validate`, which a reset also reaches).
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) return NS.SetByPath(path, value) end,
    -- The minimap exemption above is the runtime's `resetExempt`, honored inside every sweep this
    -- library drives (RestoreDefaults and RestoreAllDefaults both open a bracket around their walk).
    applyDefault = function(row) return NS.ApplyDefault(row) end,
    allRows      = NS.SchemaRuntime.AllRows,

    -- `filter` is ctx.unit, which the library passes through without interpreting. That is what
    -- makes a per-unit page render only the selected unit's rows while a page with ctx.unit nil
    -- (General) gets every unit's.
    rowsForPage  = function(pageKey, filter) return NS.SchemaForPage(pageKey, filter) end,

    -- The veto, named once above and shared with the stub's own reset loop.
    skipRestoreAll = vetoedFromResetAll,

    -- RESET ALL SETTINGS IS A PROFILE RESET (options-ui-§12), and `resetProfile` is the library
    -- field that says so (LibKa0s-Options-1.0 minor 9). It was a hand-written `afterRestoreAll`
    -- here, and in eight sibling addons -- one policy the standard forbids varying, restated once
    -- per repo.
    --
    -- With the field supplied the library narrows its own row walk to the sessionOnly rows before
    -- calling this, so the veto above is belt to that braces on the live path; it is the WHOLE
    -- policy on the degraded one, where there is no library to do the narrowing.
    --
    -- One call, and the same act as the Profiles page's Reset Profile. AceDB empties the ACTIVE
    -- profile -- and only that one; the profile LIST is untouched, which is the line the veto
    -- exists for -- the defaults merge back, and `OnProfileReset` reaches NS.OnProfileReset
    -- (core/Database.lua), which repaints the bar and refreshes an open panel exactly as a profile
    -- switch does. Counted (NS.ResetProfileCounted), so that handler's one line carries the rows the
    -- reset changed (debug-logging-§10).
    --
    -- `position` comes back with it. It is written by dragging rather than by a schema row, so
    -- ApplyDefault never touched it and this hook used to call ResetAllPositions to clear it -- but
    -- a position lives IN THE PROFILE. The helper is untouched and still backs `/at resetposition`
    -- and the General page's button; it simply has no business here any more.
    resetProfile = function()
        local db = NS.db
        if db and db.ResetProfile then NS.ResetProfileCounted(db) end
    end,

    -- This addon ships the AceDBOptions Profiles page (settings/Profiles.lua), so the General
    -- page's Reset all settings tooltip names the equivalence options-ui-§12 asks for: "the same
    -- thing Profiles → Reset Profile does". The library cannot see which pages a host registers,
    -- so the host says so (LibKa0s-Options-1.0 minor 18). It changes that tooltip and nothing else.
    profilesPage = true,

    -- The bulk bracket (LibKa0s-Options-1.0 minor 16, debug-logging-§10). RestoreDefaults and
    -- RestoreAllDefaults call these around their walks, so a Defaults press is one
    -- `[Set] reset <page>: N rows` line rather than one `[Set]` per row. A Reset All carries
    -- info.profileReset and logs nothing here: OnProfileReset logs it once. Both fields, always as
    -- a pair, because a mute with no end would silence every later write.
    bulkBegin = NS.SchemaRuntime.BulkBegin,
    bulkEnd   = NS.SchemaRuntime.BulkEnd,

    -- AceTimer through the addon object (Ka0s standard library-stack-§1) rather than a raw C_Timer. Backs the
    -- color picker's 50 ms drag throttle; the library takes it as a descriptor field because
    -- embedding AceTimer would be its second dependency-budget breach.
    scheduleTimer = function(fn, delay) return NS.addon:ScheduleTimer(fn, delay) end,

    getLSM   = function() return NS.GetLSM() end,
    validate = function() NS.ValidateSchema() end,

    -- Ka0s standard library-stack-§4: resolve AceGUI once and read the upvalue. settings/About.lua and the
    -- page builders read NS.AceGUI, so the library hands it over rather than keeping it private.
    onAceGUI = function(AceGUI) NS.AceGUI = AceGUI end,

    -- The About page's body, built on the main panel's first OnShow (settings/About.lua decorates
    -- NS.Helpers.BuildMainContent, which does not exist yet at this point in the load).
    buildMain = function(ctx)
        if NS.Helpers and NS.Helpers.BuildMainContent then NS.Helpers.BuildMainContent(ctx) end
    end,

    -- Colors are stored as {r=, g=, b=, a=} named keys (core/Data.lua's GetBarColor / GetBgColor /
    -- GetBorderColor read that shape). That is also the library's default, so these two are written
    -- out rather than omitted only because the shape is a real contract with the rest of the addon
    -- and a silent default is a poor place for it to live.
    colorDecode = function(c)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
}

-- ---------------------------------------------------------------------
-- The degradation stub — LOAD-COMPLETING, not member-answering
-- ---------------------------------------------------------------------
--
-- Every other setup file in this addon degrades to a table that answers each member with an honest
-- "not installed" line. That calculus does not survive contact with this one, and the reason is not
-- importance — it is WHEN the missing code is reached.
--
-- settings/Appearance.lua evaluates `NS.Helpers.LSMValues("statusbar")` inside a schema-row
-- literal, at FILE LOAD. With LSMValues nil that is `attempt to call field 'LSMValues' (a nil
-- value)`, so settings/Appearance.lua never finishes loading, so NS.RegisterSchemaRows never runs
-- for the appearance page, so most of NS.Schema is missing — and `/at list`,
-- `/at set units.player.barWidth`, `/at reset` and the profile defaults all break with it. The
-- addon would not degrade; it would half-load, and nothing would say so.
--
-- So this stub publishes every member a page file touches AT LOAD TIME. Measured, one member at a
-- time, by deleting it and re-running the library-absent load (tests/degraded_env.lua) to see
-- whether the page files still finish. That set is still SIX: LSMValues, which
-- settings/Appearance.lua calls inside a schema-row literal, and the five schema COMPOSERS, which
-- settings/General.lua and settings/Appearance.lua call inside NS.RegisterSchemaRows. Dropping any
-- one of them raises out of a page file and takes that page's rows with it; dropping anything else
-- changed nothing. The five composers are HOLLOW -- each answers {} (options-ui-§1, v2.65.0;
-- anti-pattern #73) -- so the degraded schema is the hand-written rows alone, and the composed
-- rows are the one named gap between it and the full schema (tests/test_perf.lua pins all three
-- figures).
--
-- RestoreAllDefaults is kept even though it measured as call-time, because the call it answers is
-- `/at resetall` and the StaticPopup's OnAccept closure in settings/General.lua — a recovery path,
-- and a user whose panel will not open is exactly the user who needs it.
--
-- What used to sit here and no longer does: SECTION_HEADING_H, ROW_VSPACER and BUTTON_PAIR_REL.
-- They are copies of lib.LAYOUT's values, and their only readers (settings/About.lua's
-- BuildMainContent, settings/UnitPanel.lua's render body) both sit behind an AceGUI a degraded build
-- never gets, so nothing in that build ever read them. A host copy of a library constant is the copy
-- that goes stale.
--
-- tests/test_optionssetup.lua pins that member set and the composers' empty answer, and
-- tests/test_perf.lua pins the full count, the degraded count and the gap between them, attributed
-- per composed tab, over a whole library-absent load. Those cases are the only thing standing
-- between this stub and a silent half-load, so do not weaken either.
--
-- Note what is NOT here: no copy of a widget maker, no copy of the flow engine, no copy of the
-- header, no copy of lib.LAYOUT. Hand-copying the code whose drift the extraction exists to end is
-- the one duplicate testing-§8 most specifically forbids.
if not lib then
    local MISSING = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."

    local Helpers = {}
    NS.Helpers = Helpers

    -- Reached at load, so it must be real enough for the page files to finish.
    Helpers.LSMValues = function() return function() return {} end end

    -- ── the composers: hollow ───────────────────────────────────────────────────────────────
    --
    -- The other five load-time members, and each answers the EMPTY block (options-ui-§1): the page
    -- files finish loading and register what they wrote by hand, and no composed row exists. The
    -- rows a composer would have emitted are the library's, labels, paths and defaults alike, and
    -- a host copy of them is anti-pattern #73 however little of the row it reproduces.
    --
    -- What that costs a library-less session is only what it has lost anyway: the panel, and the
    -- schema CLI, whose verbs all answer "unavailable" here (settings/Slash.lua's own stub). The
    -- composed paths a HOST verb still writes -- `enabled` and `locked` -- are declared in
    -- settings/Schema.lua's WRITE_THROUGH list, so /at enable, /at disable, /at lock, /at unlock
    -- and the combat re-lock store and react without a row. Reads never needed one: NS.GetSetting
    -- walks the store and falls back to the shipped defaults.
    --
    -- MasterControls keeps its two-value shape, the rows and the afterGroup tail, so
    -- settings/General.lua's destructuring call still gets a callable tail. MASTER_GROUP is not
    -- published: its one reader is General's build(), which a library-less load never reaches.
    for _, name in ipairs({ "ColorPair", "FontGroup", "BorderGroup", "BarGroup" }) do
        Helpers[name] = function() return {} end
    end
    Helpers.MasterControls = function() return {}, function() end end

    Helpers.RestoreAllDefaults = function()
        -- Bracketed exactly as the library brackets the live walk (debug-logging-§10): the session
        -- rows are written under the mute, and a profile reset is logged once, by OnProfileReset.
        -- With no AceDB there is no profile reset and the bracket's own `[Set] reset all` line is
        -- the record.
        NS.Bulk.Run("reset", "all", function(info)
            -- The rows are the schema's and the schema loaded fine, so a reset still works without
            -- any panel at all. Losing the panel is survivable; losing the reset would not be.
            for _, row in ipairs(NS.Schema or {}) do
                if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end
            end
            -- Then the profile itself, which IS the reset (options-ui-§12). On the live path the
            -- library makes this call through the descriptor's `resetProfile`; here there is no
            -- library, so the stub makes it. The saved positions come back with the profile, which
            -- is why the ResetAllPositions call that used to close this function is gone from it.
            -- Counted, as on the live path, so the handler's line carries the rows it changed.
            local db = NS.db
            if db and db.ResetProfile then
                NS.ResetProfileCounted(db)
                info.profileReset = true
            end
        end)
    end

    -- Reached only from a builder or a user action, so a no-op is the honest answer.
    for _, name in ipairs({
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section",
        "AddSpacer", "AttachTooltip", "InlineButtonPair", "RenderField", "RenderGrid", "RenderRows",
        "RenderSchema", "SessionCheckbox", "RefreshAllPanels", "RestoreDefaults",
        "PatchAlwaysShowScrollbar",
        -- SetRenderer is here because the three page builders now declare their bodies THROUGH it
        -- rather than parking a raw OnShow of their own, and that is what buys them the library's
        -- Blizzard-sidebar combat lock (options-ui-§2/§11). It is a builder call exactly like the
        -- CreatePanel above it, so a no-op is the same honest answer.
        --
        -- It was absent while this addon had no caller for it -- the rule the RenderPanel note in
        -- tests/test_surface_parity.lua states, that a stub member with no caller is a copy waiting
        -- to go stale -- and that exemption is what let the pages hand-wire OnShow with nothing
        -- going red. The exemption leaves that file in the same commit as this line arrives.
        "SetRenderer",
        -- The chrome band (options-ui-§13 / §14), new to the surface at LibKa0s v1.23.0. Every one of
        -- these is reached from a page builder or a tab click: settings/General.lua calls
        -- RenderTabbedSchema, settings/UnitPanel.lua calls PageHeader and TabStrip, and both reach
        -- SetChromeHeight through them. A no-op is the honest answer for the same reason
        -- RenderSchema's is -- there is no panel to draw into.
        --
        -- PageHeader rather than PageBanner: the Appearance page's one chrome block carries the Unit
        -- picker AND the two page-wide mirror controls, and options-ui-§14 allows a page exactly one
        -- block, so the picker is built inside PageHeader's frame and PageBanner has no call site in
        -- this addon at all. A stub member with no caller is a copy waiting to go stale.
        "SetChromeHeight", "TabStrip", "PageHeader", "RenderTabbedSchema",
        -- RenderUnitPanel is deliberately absent: settings/UnitPanel.lua loads after this file and
        -- publishes the real one either way, and it already bails on a nil NS.AceGUI. A no-op here
        -- would read as though the degraded build had its own, which it does not.
    }) do
        Helpers[name] = function() end
    end
    -- LibKa0s v1.35.0's render-time members, carried inert because the owner asked for them on every consumer.
    -- Since LibKa0s v1.62.0 the id members live in OptionsIds.lua / OptionsIdList.lua (minor 1 each), peeled
    -- unchanged out of OptionsWidgets.lua; same members on the same instance, so the stub is unchanged.
    Helpers.ChoiceGrid, Helpers.IdInput, Helpers.IdList = function() end, function() end, function() end
    Helpers.ResolveId         = function() return nil end
    Helpers.UnnamedCandidates = function() return nil end
    Helpers.ID_NAME_HINT      = {}
    -- SelectTab, new at LibKa0s v1.36.0: reached only from a tab click on an already-rendered
    -- page, so a no-op is the same honest answer as the builder/user-action list above. This
    -- addon does not adopt tab-scoped refresh; the stub exists so the degraded build's surface
    -- keeps matching the live one.
    Helpers.SelectTab = function() end
    -- NavRail, new at LibKa0s v1.61.0 (OptionsNav minor 1): drawn only by a page render, and no
    -- page here draws a rail, so the same inert no-op answers.
    Helpers.NavRail = function() end
    Helpers.__panels   = function() return {} end
    Helpers.__panelFor = function() return nil end

    NS.RegisterOptionsPage = function() end
    NS.RefreshOptionsPanel = function() end
    -- One honest line, exactly as this already did when AceGUI was the thing missing.
    NS.CreateOptionsPanel  = function() print(MISSING) end
    NS.OpenOptionsPanel    = function() print(MISSING) end
    return
end

-- ---------------------------------------------------------------------
-- The live wiring
-- ---------------------------------------------------------------------

-- ── the LSM30_Border widget fixup ──────────────────────────────────────────────────────────────
--
-- A LIBRARY ACT, NOT AN INSTANCE ONE, and that is the whole reason it moved here. AceGUI's
-- WidgetRegistry is process-global: one slot named "LSM30_Border" shared by every addon in the
-- client, Ka0s or not. This addon and four siblings each carried a private copy of the same wrapper
-- in core/LSMPatch.lua, each registering at whatever version it found plus one — so a client
-- running all five stacked five wrappers, and the outermost belonged to whichever addon the loader
-- happened to reach last. Nothing could see that: each addon's own suite loads one copy, registers
-- once and passes.
--
-- `lib.__PatchLSM30Border` (LibKa0s-Options-1.0 minor 15) is the same wrapper published once,
-- guarded by lib.__lsmBorderPatched. Five vendored copies of the library are still ONE library
-- instance to LibStub, so five callers produce one registration and the return value tells you
-- which call did it. Calling it is therefore unconditional and needs no coordination with anybody.
--
-- HERE, AT FILE LOAD, is early enough and is not fragile, and the timing DID change: the private
-- copy this replaced waited for OnEnable and this line does not. AbsorbTracker.toc pulls
-- libs\AceGUI-3.0-SharedMediaWidgets\widget.xml in with the other libraries, well before its
-- settings\OptionsSetup.lua entry, so the slot already holds AGSMW's own constructor by the time
-- this line runs; and a registration whose version is not strictly higher than the one already held
-- is refused, so another addon's later-loading copy of AGSMW cannot take the slot back at its own
-- fixed version. (Worded around the AceGUI entry point on purpose: C02's acceptance is a grep for
-- that identifier over core/, modules/ and settings/ returning nothing, and a prose mention is one
-- more hit an auditor has to read and dismiss.) It lives in this file rather than a second one
-- because this is where the addon's options surface is wired, which is where the library's own note
-- on the member says to call it from.
--
-- core/LSMPatch.lua IS GONE, last of the five copies to go. It was the one that diverged: it
-- published a callable NS.ApplyLSMBorderPatch() invoked from core/AbsorbTracker.lua's OnEnable
-- rather than doing its work off a PLAYER_LOGIN frame of its own, which is why it was sequenced
-- last and why its deletion had a call site to take out with it. This line is now the whole of the
-- fixup in this addon.
lib.__PatchLSM30Border()

-- NS.Helpers IS the library instance, not a table decorated from it. Two things then hold that a
-- copy-across would break: settings/UnitPanel.lua and settings/About.lua decorate the same table
-- the library's own members live on (so RenderUnitPanel can call RenderRows through `Helpers` like
-- every other page does), and a test that swaps a member out to spy on it — tests/test_panelpages.lua
-- does exactly that with ResetAllPositions — is swapping the one the library's own callers see.
NS.Helpers = lib:New(descriptor)
local Helpers = NS.Helpers

NS.RegisterOptionsPage = function(key, name, builder) Helpers.RegisterOptionsPage(key, name, builder) end
NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() Helpers.OpenOptionsPanel() end

-- AceDB profile changes (NS.OnProfileChanged) call this so any open page re-reads its values, and
-- so do `/at set`, `/at reset` and `/at resetall`.
NS.RefreshOptionsPanel = function() Helpers.RefreshAllPanels() end
