-- AbsorbTracker: settings/About.lua
--
-- Top-level "Ka0s Absorb Tracker" page builder. Logo, addon Notes
-- one-liner, "Slash Commands" heading, and a row per NS.SlashCommands
-- entry so the about page stays in lockstep with /at help. Decorates
-- NS.Helpers.BuildMainContent; settings/Panel.lua's registerMain
-- calls it on first OnShow of the main panel.

local addonName, NS = ...

local Helpers = NS.Helpers

-- About page block sizing.
local MAIN_LOGO_SIZE      = 300
local MAIN_GAP_AFTER_LOGO = 8
local MAIN_GAP_AFTER_DESC = 12
local MAIN_GAP_BELOW_HEAD = 6

local LOGO_PATH = NS.Constants.LOGO_PATH

-- Deprecated-API access routes through the single Compat shim (Ka0s standard §11).
local function getMetadata(field)
    return NS.Compat.GetAddOnMetadata(NS.name, field)
end

local function addBlock(scroll, height)
    local AceGUI = NS.AceGUI
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height)
    scroll:AddChild(sp)
    return sp
end

function Helpers.BuildMainContent(ctx)
    local AceGUI = NS.AceGUI
    local scroll = Helpers.EnsureScroll(ctx)

    -- 1) Logo. SimpleGroup is a full-width child so AceGUI's List
    -- layout gives it the scroll's full width to live in; the texture
    -- inside is anchored TOPLEFT, sized to the source TGA's native
    -- dimensions, so it renders pixel-exact and left-aligned regardless
    -- of panel width.
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(MAIN_LOGO_SIZE)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(LOGO_PATH)
    logoTex:SetSize(MAIN_LOGO_SIZE, MAIN_LOGO_SIZE)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)

    addBlock(scroll, MAIN_GAP_AFTER_LOGO)

    -- 2) One-liner — full-width Label, left-aligned, GameFontHighlight.
    local notes = getMetadata("Notes") or ""
    if notes ~= "" then
        local desc = AceGUI:Create("Label")
        desc:SetFullWidth(true)
        desc:SetText(notes)
        if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
            desc.label:SetFontObject(_G.GameFontHighlight)
        end
        if desc.label and desc.label.SetJustifyH then
            desc.label:SetJustifyH("LEFT")
        end
        scroll:AddChild(desc)

        addBlock(scroll, MAIN_GAP_AFTER_DESC)
    end

    -- 3) Separator + "Slash Commands" heading: a single AceGUI Heading
    -- widget renders as a label flanked by side dividers, so this one
    -- widget delivers both the visual separator and the section title.
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetHeight(Helpers.SECTION_HEADING_H)
    heading:SetText("Slash Commands")
    if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
        heading.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(heading)

    addBlock(scroll, MAIN_GAP_BELOW_HEAD)

    -- 4) Slash-command rows pulled from NS.SlashCommands so
    -- this list stays in lockstep with /at help — adding a command in
    -- SlashCommands.lua surfaces here automatically.
    for _, entry in ipairs(NS.SlashCommands or {}) do
        local r = AceGUI:Create("Label")
        r:SetFullWidth(true)
        r:SetText(("|cffffff00/at %s|r  |cffffffff—|r  %s")
            :format(entry[1], entry[2]))
        if r.label and r.label.SetJustifyH then
            r.label:SetJustifyH("LEFT")
        end
        scroll:AddChild(r)
    end

    if scroll.DoLayout then scroll:DoLayout() end
end
