require "ISUI/ISToolTipInv"

local BACKGROUND_ALPHA = 0.9

local function getTransmogLine(item)
    if not item or not TransmogDE or not TransmogDE.isTransmoggable(item) then
        return nil
    end
    local md = TransmogDE.getItemTransmogModData(item)
    if not md or not md.transmogTo then
        return nil
    end
    return getText("IGUI_TransmogDE_Tooltip_TransmogTo", getItemNameFromFullType(md.transmogTo))
end

local old_render = ISToolTipInv.render

function ISToolTipInv:render()
    -- vanilla guard: don’t show if a context menu is up
    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then
        return
    end

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
                      getText("IGUI_TransmogDE_Tooltip_TransmogHidden")
    end
    -- ----- mouse anchoring (vanilla) -----
    local mx = getMouseX() + 24
    local my = getMouseY() + 24
    if not self.followMouse then
        mx = self:getX();
        my = self:getY()
        if self.anchorBottomLeft then
            mx = self.anchorBottomLeft.x;
            my = self.anchorBottomLeft.y
        end
    end

    local PADX = 0
    local tt = self.tooltip

    tt:setX(mx + PADX)
    tt:setY(my)
    tt:setWidth(50)

    -- ----- MEASURE PASS (vanilla) -----
    tt:setMeasureOnly(true)
    if self.item then
        self.item:DoTooltip(tt)
    end
    tt:setMeasureOnly(false)

    -- capture base size
    local baseW = tt:getWidth()
    local baseH = tt:getHeight()

    -- ======= TransmogDE: compute extra line BEFORE clamping =======
    local defaultH = 44
    local extraH, extraW = 0, 0
    if addLine then
        local font = UIFont.Medium
        local tm = getTextManager()
        extraW = tm:MeasureStringX(font, addLine) + 10 -- 5px pad on each side
        -- We don’t have lineHeight from ObjectTooltip; use a safe value.
        extraH = math.max(tt:getLineSpacing() or defaultH, defaultH)
    end

    local tw = math.max(baseW, extraW) -- widen if our line is longer
    local th = baseH + extraH -- add our line height

    -- ----- CLAMP (vanilla math, but using tw/th we computed) -----
    local core = getCore()
    local maxX = core:getScreenWidth()
    local maxY = core:getScreenHeight()

    tt:setX(math.max(0, math.min(mx + PADX, maxX - tw - 1)))
    if not self.followMouse and self.anchorBottomLeft then
        tt:setY(math.max(0, math.min(my - th, maxY - th - 1)))
    else
        tt:setY(math.max(0, math.min(my, maxY - th - 1)))
    end

    self:setX(tt:getX() - PADX)
    self:setY(tt:getY())
    self:setWidth(tw + PADX)
    self:setHeight(th)

    -- ----- avoid overlap (vanilla) -----
    if self.followMouse then
        self:adjustPositionToAvoidOverlap({
            x = mx - 24 * 2,
            y = my - 24 * 2,
            width = 24 * 2,
            height = 24 * 2
        })
    end

    -- ----- draw bg + border (vanilla) -----
    self:drawRect(0, 0, self.width, self.height, BACKGROUND_ALPHA, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)

    -- ----- DRAW PASS (vanilla) -----
    if self.item then
        self.item:DoTooltip(tt)
    end

    -- ======= TransmogDE: draw our final line INSIDE the new area =======
    if addLine then
        local font = UIFont.Medium
        local y = baseH + 4 -- just below vanilla content
        tt:DrawText(font, addLine, 10, y, 1, 0.6, 0, 1)
    end
end
