-- AbsorbTracker: Options/Border.lua
--
-- Border sub-page: style, thickness, color (with class-color toggle).
--
-- Layout produces:
--     [Border Style]    | [Border Thickness (in px)]
--     [Use Class Color] | [Border Color]

local AddonName, AddonTable = ...

local flatDefaults = AddonTable.flatDefaults

local function lsmValues(mediaType)
    return function()
        local LSM = AddonTable.GetLSM()
        local list, out = LSM and LSM:HashTable(mediaType) or {}, {}
        for k in pairs(list) do out[k] = k end
        return out
    end
end

AddonTable.RegisterSchemaRows({
    {
        path    = "border",
        page    = "border",
        group   = "Border",
        order   = 10,
        type    = "string",
        label   = "Border Style",
        desc    = "LibSharedMedia border texture (edge style) used to draw the bar's border.",
        default = flatDefaults.border,
        dialogControl = "LSM30_Border",
        values = lsmValues("border"),
    },
    {
        path    = "borderSize",
        page    = "border",
        group   = "Border",
        order   = 20,
        type    = "number",
        label   = "Border Thickness (in px)",
        desc    = "Border edge size in pixels.",
        default = flatDefaults.borderSize,
        min = 1, max = 32, step = 1, fmt = "%d px",
    },
    {
        path    = "useClassColorBorder",
        page    = "border",
        group   = "Border",
        order   = 30,
        type    = "bool",
        label   = "Use Class Color",
        desc    = "Use your class color for the border. Greys out the Border Color picker.",
        default = flatDefaults.useClassColorBorder,
    },
    {
        path     = "borderColor",
        page     = "border",
        group    = "Border",
        order    = 40,
        type     = "color",
        label    = "Border Color",
        desc     = "RGBA border color (only used when Use Class Color is off).",
        default  = flatDefaults.borderColor,
        hasAlpha = true,
        disabledIf = "useClassColorBorder",
    },
})

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local H   = AddonTable.Helpers
    local ctx = H.CreatePanel("AbsorbTrackerBorderPanel", "Border", {
        pageKey         = "border",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Border setting on this profile to its addon default.",
    })
    if ctx.panel.defaultsBtn then
        ctx.panel.defaultsBtn:SetCallback("OnClick", function()
            H.RestoreDefaults("border", ctx)
        end)
    end

    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "border")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Border")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("border", "Border", build)
end
