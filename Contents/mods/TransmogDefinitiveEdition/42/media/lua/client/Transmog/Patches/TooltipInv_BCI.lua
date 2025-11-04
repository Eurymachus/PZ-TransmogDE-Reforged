-- File: media/lua/client/TransmogDE/Tooltip_BCI_Compat.lua
-- Purpose: Interop with "Better Clothing Info Comparison" (BCIC).
-- If BCIC is loaded, we extend its RenderTooltip to add our final line + height.
-- Temporary Hack (Build 42.12) — reason: both mods customize ISToolTipInv pipeline.
require "ISUI/ISToolTipInv"

local BACKGROUND_ALPHA = 0.9

local function patchBCI()
    -- BCIC defines ISToolTipInv.bcic_render and a global RenderTooltip
    if not ISToolTipInv or not ISToolTipInv.bcic_render then
        return false
    end
    if type(RenderTooltip) ~= "function" then
        return false
    end
    if _G.__TransmogDE_BCI_Patched then
        return true
    end

    local _RenderTooltip = RenderTooltip

    -- Our extended copy of BCI's RenderTooltip with minimal edits:
    function RenderTooltip(self, offsetX, offsetY)
        local shouldAddLine = true
        if not self.item or not TransmogDE.isTransmoggable(self.item) then
            shouldAddLine = false
        end

        local itemModData = nil
        if shouldAddLine then
            itemModData = TransmogDE.getItemTransmogModData(self.item)
        end
        if itemModData and itemModData.transmogTo == self.item:getScriptItem():getFullName() then
            shouldAddLine = false
        end
        local addLine = nil
        if shouldAddLine then
            addLine = itemModData.transmogTo and
                          getText("IGUI_TransmogDE_Tooltip_TransmogTo", getItemNameFromFullType(itemModData.transmogTo)) or
                          getText("IGUI_TransmogDE_Tooltip_TransmogHidden") or nil
        end
        -- --- begin: copied structure from BCIC RenderTooltip ---
        local mx = getMouseX() + 24 + (offsetX or 0);
        local my = getMouseY() + 24 + (offsetY or 0);
        if not self.followMouse then
            mx = self:getX();
            my = self:getY()
            if self.anchorBottomLeft then
                mx = self.anchorBottomLeft.x;
                my = self.anchorBottomLeft.y
            end
        end

        local tt = self.tooltip
        tt:setX(mx + 11);
        tt:setY(my)
        tt:setWidth(50)

        -- Measure pass (BCI/vanilla)
        tt:setMeasureOnly(true)
        if self.item then
            if self.item:IsClothing() and bcic_DoTooltip then
                bcic_DoTooltip(tt, self.item) -- BCI’s measurement path
            else
                self.item:DoTooltip(tt)
            end
        end
        tt:setMeasureOnly(false)

        local baseW = tt:getWidth()
        local baseH = tt:getHeight()

        -- === TransmogDE: compute extra BEFORE clamp ===
        local defaultH = 44
        local extraH, extraW = 0, 0
        if addLine then
            -- Use the same font family as the tooltip to avoid mismatch
            local font = UIFont[getCore():getOptionTooltipFont()] or UIFont.Medium
            local tm = getTextManager()

            -- Gutters: match BCI’s left (+11) and keep a similar right pad
            local padLeft = 5 -- where we draw the text (x=5)
            local padRight = 12 -- add explicit right gutter so text never hugs the border

            -- width needed for our line including gutters
            extraW = tm:MeasureStringX(font, addLine) + padLeft + padRight

            -- height for one line using the tooltip’s spacing (fallback 18)
            local ls = self.tooltip.getLineSpacing and self.tooltip:getLineSpacing() or 18
            extraH = math.max(ls, 44)
        end

        -- Final tooltip width/height for clamping & bg/border
        -- Ensure we keep at least the vanilla width and also our line + gutters
        local tw = math.max(baseW, extraW)
        local th = baseH + extraH

        -- Clamp (BCI/vanilla math)
        local core = getCore()
        local maxX = core:getScreenWidth()
        local maxY = core:getScreenHeight()

        tt:setX(math.max(0, math.min(mx + 11, maxX - tw - 1)))
        if not self.followMouse and self.anchorBottomLeft then
            tt:setY(math.max(0, math.min(my - th, maxY - th - 1)))
        else
            tt:setY(math.max(0, math.min(my, maxY - th - 1)))
        end

        self:setX(tt:getX() - 11)
        self:setY(tt:getY())
        self:setWidth(tw + 11)
        self:setHeight(th)

        if self.followMouse then
            self:adjustPositionToAvoidOverlap({
                x = mx - 24 * 2,
                y = my - 24 * 2,
                width = 24 * 2,
                height = 24 * 2
            })
        end

        -- Background + border (unchanged)
        self:drawRect(0, 0, self.width, self.height, BACKGROUND_ALPHA, self.backgroundColor.r, self.backgroundColor.g,
            self.backgroundColor.b)
        self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
            self.borderColor.b)

        -- Draw pass: delegate to BCIC for clothing, otherwise vanilla
        if self.item then
            if self.item:IsClothing() and bcic_DoTooltip then
                bcic_DoTooltip(tt, self.item)
            else
                self.item:DoTooltip(tt)
            end
        end

        -- === TransmogDE: draw our final line INSIDE extended area ===
        if addLine then
            local font = UIFont.Medium
            local y = baseH + 4
            tt:DrawText(font, addLine, 5, y, 1, 0.6, 0, 1)
        end
        -- --- end: extended BCI RenderTooltip ---
    end

    _G.__TransmogDE_BCI_Patched = true
    return true
end

-- Entry: try to patch BCI; if not present we do nothing here.
Events.OnGameStart.Add(patchBCI)
