require "ISUI/ISToolTipInv"

local BACKGROUND_ALPHA = 0.9

---------------------------------------------------------
-- If BCI is active, DON'T override ISToolTipInv here.
-- BCI will call TransmogDE.getTooltipLines(item) itself.
---------------------------------------------------------
if _G.BCI_TooltipInv_Active then
    return
end

---------------------------------------------------------
-- No BCI present:
--   TransmogDE owns ISToolTipInv.render and appends its
--   lines underneath vanilla DoTooltip for relevant items.
---------------------------------------------------------

local old_render = ISToolTipInv.render

local function RenderTooltip_Transmog(self)
    -- vanilla guard: don’t show if a context menu is up
    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then
        return
    end

    local item = self.item
    local tt   = self.tooltip

    if not item or not tt then
        if old_render then
            return old_render(self)
        end
        return
    end

    -- Precompute transmog lines; if none, just fall back fully.
    local tLines = TransmogDE.getTooltipLines(item)
    if not tLines then
        if old_render then
            return old_render(self)
        end
        return
    end

    -- ----- mouse anchoring (vanilla-ish) -----
    local mx = getMouseX() + 24
    local my = getMouseY() + 24
    if not self.followMouse then
        mx = self:getX()
        my = self:getY()
        if self.anchorBottomLeft then
            mx = self.anchorBottomLeft.x
            my = self.anchorBottomLeft.y
        end
    end

    local PADX = 0
    local TEXT_X = 12

    tt:setX(mx + PADX)
    tt:setY(my)
    tt:setWidth(50)

    -- ----- MEASURE PASS: vanilla base -----
    tt:setMeasureOnly(true)
    item:DoTooltip(tt)
    tt:setMeasureOnly(false)

    local baseW = tt:getWidth()
    local baseH = tt:getHeight()

    -- ----- MEASURE PASS: transmog lines -----
    local extraW, extraH = 0, 0
    do
        local font = UIFont.Medium
        local tm = getTextManager()
        local lineH = tt:getLineSpacing() or 18
        local padLeft, padRight = 5, 5

        for _, line in ipairs(tLines) do
            local text = line.text or ""
            if text ~= "" then
                local w = tm:MeasureStringX(font, text) + padLeft + padRight
                if w > extraW then
                    extraW = w
                end
                extraH = extraH + lineH
            end
        end
        extraH = extraH + 10
    end

    local tw = math.max(baseW, extraW)
    local th = baseH + extraH

    -- ----- CLAMP -----
    local core = getCore()
    local maxX = core:getScreenWidth()
    local maxY = core:getScreenHeight()

    tt:setX(math.max(0, math.min(mx + PADX, maxX - tw - 1)))
    tt:setY(math.max(0, math.min(my, maxY - th - 1)))

    self:setX(tt:getX() - PADX)
    self:setY(tt:getY())
    self:setWidth(tw + PADX)
    self:setHeight(th)

    -- ----- overlap guard -----
    if self.followMouse then
        self:adjustPositionToAvoidOverlap({
            x = mx - 24 * 2,
            y = my - 24 * 2,
            width = 24 * 2,
            height = 24 * 2
        })
    end

    -- ----- draw bg + border -----
    self:drawRect(
        0, 0,
        self.width, self.height,
        BACKGROUND_ALPHA,
        self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b
    )
    self:drawRectBorder(
        0, 0,
        self.width, self.height,
        self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b
    )

    -- ----- DRAW PASS: vanilla base -----
    item:DoTooltip(tt)

    -- ----- DRAW PASS: transmog lines -----
    do
        local font = UIFont.Medium
        local y = baseH + 5
        local lineH = tt:getLineSpacing() or 18

        for _, line in ipairs(tLines) do
            local text = line.text or ""
            if text ~= "" then
                local r = line.r or 1.0
                local g = line.g or 0.6
                local b = line.b or 0.0
                tt:DrawText(font, text, TEXT_X, y, r, g, b, 1.0)
                y = y + lineH
            end
        end
    end
end

function ISToolTipInv:render()
    return RenderTooltip_Transmog(self)
end

local old_new = ISToolTipInv.new
function ISToolTipInv:new(item)
    local o = old_new(self, item)
    o.backgroundColor.a = BACKGROUND_ALPHA
    return o
end
