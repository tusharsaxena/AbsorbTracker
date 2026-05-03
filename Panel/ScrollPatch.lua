-- AbsorbTracker: Panel/ScrollPatch.lua
--
-- Always-visible scrollbar patch. AceGUI's stock ScrollFrame.FixScroll
-- auto-hides the scrollbar when content fits inside the viewport;
-- across our settings tabs that means General (short) shows no
-- scrollbar while Bar (longer) does — visually asymmetric. This
-- module decorates AddonTable.Helpers.PatchAlwaysShowScrollbar with
-- an override that always keeps the scrollbar (and its 20 px gutter)
-- shown, parks the thumb at the top when there's nothing to scroll,
-- and persists the gutter so the body content's right edge sits at
-- the same x across every panel.
--
-- Helpers.EnsureScroll (Panel/Helpers.lua) calls this after every
-- AceGUI ScrollFrame is created.

local AddonName, AddonTable = ...

local Helpers = AddonTable.Helpers

function Helpers.PatchAlwaysShowScrollbar(scroll)
    if not scroll or scroll._atAlwaysScrollbar then return end
    scroll._atAlwaysScrollbar = true

    local origFixScroll  = scroll.FixScroll
    local origMoveScroll = scroll.MoveScroll
    local origOnRelease  = scroll.OnRelease

    local scrollbar  = scroll.scrollbar
    local thumb      = scrollbar and scrollbar.GetThumbTexture and scrollbar:GetThumbTexture() or nil
    local sbName     = scrollbar and scrollbar.GetName and scrollbar:GetName() or nil
    local upBtn      = sbName and _G[sbName .. "ScrollUpButton"]   or nil
    local downBtn    = sbName and _G[sbName .. "ScrollDownButton"] or nil

    local currentEnabled

    local function setEnabled(want)
        if currentEnabled == want then return end
        currentEnabled = want
        if not scrollbar then return end

        if want then
            if scrollbar.Enable then scrollbar:Enable() end
            if thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(1, 1, 1, 1)
            end
            if upBtn   and upBtn.Enable   then upBtn:Enable()   end
            if downBtn and downBtn.Enable then downBtn:Enable() end
        else
            scrollbar:SetValue(0)
            if scrollbar.Disable then scrollbar:Disable() end
            if thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(0.5, 0.5, 0.5, 0.6)
            end
            if upBtn   and upBtn.Disable   then upBtn:Disable()   end
            if downBtn and downBtn.Disable then downBtn:Disable() end
        end
    end

    scroll.scrollBarShown = true
    if scrollbar then scrollbar:Show() end
    if scroll.scrollframe then
        scroll.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
    end
    if scroll.content and scroll.content.original_width then
        scroll.content.width = scroll.content.original_width - 20
    end

    scroll.FixScroll = function(self)
        if self.updateLock then return end
        self.updateLock = true

        if not self.scrollBarShown then
            self.scrollBarShown = true
            self.scrollbar:Show()
            self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
            if self.content.original_width then
                self.content.width = self.content.original_width - 20
            end
        end

        local status = self.status or self.localstatus
        local height, viewheight =
            self.scrollframe:GetHeight(), self.content:GetHeight()
        local offset = status.offset or 0

        if viewheight < height + 2 then
            setEnabled(false)
            self.scrollbar:SetValue(0)
            self.scrollframe:SetVerticalScroll(0)
            status.offset = 0
        else
            setEnabled(true)
            local value = (offset / (viewheight - height) * 1000)
            if value > 1000 then value = 1000 end
            self.scrollbar:SetValue(value)
            self:SetScroll(value)
            if value < 1000 then
                self.content:ClearAllPoints()
                self.content:SetPoint("TOPLEFT",  0, offset)
                self.content:SetPoint("TOPRIGHT", 0, offset)
                status.offset = offset
            end
        end

        self.updateLock = nil
    end

    scroll.MoveScroll = function(self, value)
        if currentEnabled == false then return end
        if origMoveScroll then return origMoveScroll(self, value) end
    end

    scroll.OnRelease = function(self)
        self.FixScroll  = origFixScroll
        self.MoveScroll = origMoveScroll
        self.OnRelease  = origOnRelease
        self._atAlwaysScrollbar = nil
        currentEnabled  = nil
        if thumb and thumb.SetVertexColor then
            thumb:SetVertexColor(1, 1, 1, 1)
        end
        if scrollbar and scrollbar.Enable then scrollbar:Enable() end
        if upBtn   and upBtn.Enable   then upBtn:Enable()   end
        if downBtn and downBtn.Enable then downBtn:Enable() end
        if origOnRelease then origOnRelease(self) end
    end
end
