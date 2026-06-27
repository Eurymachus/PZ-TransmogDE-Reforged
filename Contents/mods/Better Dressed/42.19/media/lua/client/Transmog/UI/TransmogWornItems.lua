require "ISUI/ISCollapsableWindowJoypad"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"

local Prefs = require("Transmog/Prefs")

TransmogWornItems = ISCollapsableWindowJoypad:derive("TransmogWornItems")

--[[

    TransmogWornItems.Open(getSpecificPlayer(0))

]]

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------

local function _safeCategory(item)
    local categoryText = getTextOrNull("IGUI_TransmogDE_WornItems_Category_Other") or "Other"
    if not item then return categoryText end
    return item:getDisplayCategory() or categoryText
end

-- ---------------------------------------------------------
-- Header
-- ---------------------------------------------------------

local TransmogWornItemsHeader = ISPanel:derive("TransmogWornItemsHeader")

function TransmogWornItemsHeader:new(x, y, w, h, owner)
    local o = ISPanel.new(self, x, y, w, h)
    o.owner = owner
    o.backgroundColor = { r = 1, g = 1, b = 1, a = 0.1 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    o.drawBorder = false
    return o
end

function TransmogWornItemsHeader:prerender()
    ISPanel.prerender(self)

    local ui = self.owner
    local w = self.width
    local h = self.height

    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = math.floor((h - fontH) / 2)

    self:drawRect(0, 0, self.width, self.height, 0.15, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 1, 1, 1)

    local scrollbarW = 0
    if ui.list and ui.list.vscroll then
        scrollbarW = ui.list.vscroll.width or 0
    end

    local usableW = w - scrollbarW
    local actionsW = ui.actionsColW or 150
    local dividerX = usableW - actionsW

    local labelItem = getTextOrNull("IGUI_TransmogDE_WornItems_Header_Item") or "Item"

    self:drawText(labelItem, ui._pad, ty, 1, 1, 1, 0.85, font)

    local actionsLabel = getTextOrNull("IGUI_TransmogDE_WornItems_Header_Actions") or "Actions"
    local actionsLabelW = getTextManager():MeasureStringX(font, actionsLabel)
    local actionsLabelX = dividerX + math.floor((actionsW - actionsLabelW) / 2)
    self:drawText(actionsLabel, actionsLabelX, ty, 1, 1, 1, 0.85, font)
end

-- ---------------------------------------------------------
-- List frame
-- ---------------------------------------------------------

local TransmogWornItemsListFrame = ISPanel:derive("TransmogWornItemsListFrame")

function TransmogWornItemsListFrame:new(x, y, w, h, owner)
    local o = ISPanel.new(self, x, y, w, h)
    o.owner = owner
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    o.drawBorder = false
    return o
end

function TransmogWornItemsListFrame:prerender()
    ISPanel.prerender(self)

    self:drawRect(0, 0, self.width, self.height, 0.15, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 1, 1, 1)
end

-- ---------------------------------------------------------
-- List
-- ---------------------------------------------------------

local TransmogWornItemsList = ISScrollingListBox:derive("TransmogWornItemsList")

function TransmogWornItemsList:new(x, y, w, h, owner)
    local o = ISScrollingListBox.new(self, x, y, w, h)
    o.owner = owner
    o.itemheight = 40
    o.font = UIFont.Small
    return o
end

function TransmogWornItemsList:_isRowHovered(y, h)
    if not self:isMouseOver() then return false end
    local my = self:getMouseY()
    return my >= y and my < (y + h)
end

function TransmogWornItemsList:_getSlotAt(rowY, mx, my)
    local ui = self.owner

    local slotSize = ui._slotSize
    local slotGap = ui._slotGap
    local actionsW = ui.actionsColW or 150

    local usableW = self.width - ((self.vscroll and (self.vscroll.width or 0)) or 0)
    local dividerX = usableW - actionsW

    local totalSlotsW = (slotSize * 6) + (slotGap * 5)
    local slotsStartX = dividerX + math.floor((actionsW - totalSlotsW) / 2)

    local slotY = rowY + math.floor((self.itemheight - slotSize) / 2)

    for visualIndex = 1, 6 do
        local slotX = slotsStartX + ((visualIndex - 1) * (slotSize + slotGap))
        local slotId = 7 - visualIndex

        if mx >= slotX and mx <= (slotX + slotSize)
        and my >= slotY and my <= (slotY + slotSize) then
            return slotId
        end
    end

    return nil
end

function TransmogWornItemsList:_hideSlotTooltip()
    if self.slotToolTip then
        self.slotToolTip:setVisible(false)
        self.slotToolTip:removeFromUIManager()
    end
end

function TransmogWornItemsList:_showSlotTooltip(text)
    if not text or text == "" then
        self:_hideSlotTooltip()
        return
    end

    if not self.slotToolTip then
        self.slotToolTip = ISToolTip:new()
        self.slotToolTip:initialise()
        self.slotToolTip:setOwner(self)
        self.slotToolTip.followMouse = true
        self.slotToolTip.maxLineWidth = 300
    end

    self.slotToolTip.description = text
    self.slotToolTip:addToUIManager()
    self.slotToolTip:setVisible(true)
end

function TransmogWornItemsList:onMouseDown(x, y)
    self:_hideSlotTooltip()
    return ISScrollingListBox.onMouseDown(self, x, y)
end

function TransmogWornItemsList:onMouseUp(x, y)
    local index = self:rowAt(x, y)
    if index == -1 then
        return ISScrollingListBox.onMouseUp(self, x, y)
    end

    local item = self.items[index]
    if not item then
        return ISScrollingListBox.onMouseUp(self, x, y)
    end

    local row = item.item
    if not row or row.empty then
        return ISScrollingListBox.onMouseUp(self, x, y)
    end

    local rowY = self:topOfItem(index)
    local slotId = self:_getSlotAt(rowY, x, y)

    if slotId then
        if self.owner and self.owner.onActionSlotClicked then
            self:_hideSlotTooltip()
            self.owner:onActionSlotClicked(row, slotId)
        end
        return
    end

    if self.owner and self.owner.player then
        self:_hideSlotTooltip()
        TransmogListViewer.Open(self.owner.player, row.item)
        return
    end

    return ISScrollingListBox.onMouseUp(self, x, y)
end

function TransmogWornItemsList:onMouseMove(dx, dy)
    local mx = self:getMouseX()
    local my = self:getMouseY()

    local index = self:rowAt(mx, my)
    if index == -1 then
        self:_hideSlotTooltip()
        return ISScrollingListBox.onMouseMove(self, dx, dy)
    end

    local item = self.items[index]
    local row = item and item.item or nil
    if not row or row.empty then
        self:_hideSlotTooltip()
        return ISScrollingListBox.onMouseMove(self, dx, dy)
    end

    local rowY = self:topOfItem(index)
    local slotId = self:_getSlotAt(rowY, mx, my)

    if slotId and self.owner and self.owner.getRowSlotTooltip then
        local text = self.owner:getRowSlotTooltip(row, slotId)
        self:_showSlotTooltip(text)
    else
        self:_hideSlotTooltip()
    end

    return ISScrollingListBox.onMouseMove(self, dx, dy)
end

function TransmogWornItemsList:onMouseMoveOutside(dx, dy)
    self:_hideSlotTooltip()
    return ISScrollingListBox.onMouseMoveOutside(self, dx, dy)
end

function TransmogWornItems:onActionSlotClicked(row, slotId)
    local item = row and row.item
    if not item then return end

    if slotId == 1 then
        if row.hasTransmogState then
            TransmogNet.requestResetDefault(self.player, item)
        end
        return
    end

    if slotId == 2 then
        if row.hasTransmog then
            TransmogNet.requestRemoveTransmog(self.player, item)
        end
        return
    end

    if slotId == 3 then
        if row.isHidden then
            TransmogNet.requestShow(self.player, item)
        else
            TransmogNet.requestHide(self.player, item)
        end
        return
    end

    if slotId == 4 then
        TransmogListViewer.Open(self.player, item)
        return
    end

    if slotId == 5 then
        if row.canTexture then
            local md = TransmogDE.getItemTransmogModData(item)
            local transmogTo = md and md.transmogTo or nil
            local textureChoiceList = nil

            if transmogTo then
                local tmogScriptItem = ScriptManager.instance:getItem(transmogTo)
                if tmogScriptItem then
                    local tmogClothingItemAsset = TransmogDE.getClothingItemAsset(tmogScriptItem)
                    if tmogClothingItemAsset then
                        textureChoiceList = tmogClothingItemAsset:hasModel()
                            and tmogClothingItemAsset:getTextureChoices()
                            or tmogClothingItemAsset:getBaseTextures()
                    end
                end
            end

            if textureChoiceList and textureChoiceList:size() > 1 then
                TexturePickerModal.Open(self.player, item, textureChoiceList)
            end
        end
        return
    end

    if slotId == 6 then
        if row.canColor then
            ColorPickerModal.Open(self.player, item)
        end
        return
    end
end

function TransmogWornItemsList:doDrawItem(y, item, alt)
    local ui = self.owner
    local rowItem = item and item.item

    if rowItem and rowItem.empty then
        local rowText = getTextOrNull("IGUI_TransmogDE_WornItems_NoItems_Row") or "No worn items available"
        local txt = item.text or rowText
        local th = getTextManager():getFontHeight(UIFont.Small)
        local ty = y + (self.itemheight - th) / 2

        self:drawText(
            txt,
            self.width / 2 - getTextManager():MeasureStringX(UIFont.Small, txt) / 2,
            ty,
            0.6, 0.6, 0.6, 0.8,
            UIFont.Small
        )

        return y + self.itemheight
    end

    local h = self.itemheight

    if y + self:getYScroll() + h < 0 or y + self:getYScroll() >= self.height then
        return y + h
    end

    -- Row frame and hover emphasis.
    if self:_isRowHovered(y, h) then
        self:drawRectBorder(0, y, self.width, h, 0.45, 0.75, 0.45, 0.85)
    else
        self:drawRectBorder(0, y, self.width, h, 0.15, 1, 1, 1)
    end

    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = y + math.floor((h - fontH) / 2)

    local metrics = ui:getActionSlotMetrics(self.width, (self.vscroll and (self.vscroll.width or 0)) or 0)
    local actionsW = metrics.actionsW
    local dividerX = metrics.dividerX

    local pad = ui._pad
    local iconSize = ui._iconSize
    local iconX = pad
    local iconY = y + math.floor((h - iconSize) / 2)

    -- Draw the icon as it is in the inventory
    local iconAlpha = rowItem.isHidden and 0.25 or 1.0
    ISInventoryItem.renderItemIcon(self, rowItem.item, iconX, iconY, iconAlpha, iconSize, iconSize)

    local textX = iconX + iconSize + ui._iconGap
    local textW = dividerX - textX - 6
    if textW < 10 then textW = 10 end

    local itemText = getTextOrNull("IGUI_TransmogDE_WornItems_Unknown") or "Unknown"
    local itemName = (rowItem and rowItem.itemName) or itemText
    local targetText = getTextOrNull("IGUI_TransmogDE_WornItems_Default") or "Default"
    local targetName = (rowItem and rowItem.targetName) or targetText

    local itemColor = {
        r = 1.0,
        g = 1.0,
        b = 1.0,
        a = 0.95
    }

    local targetColor = {
        r = 0.6,
        g = 0.9,
        b = 0.6,
        a = 0.9
    }

    local arrowColor = {
        r = 0.85,
        g = 0.85,
        b = 0.85,
        a = 0.7
    }

    -- Cache the separator arrow texture on the owner.
    -- Vanilla uses several arrow textures; ArrowRight reads best here as a source -> target separator.
    if ui._mapArrowTex == nil then
        ui._mapArrowTex = getTexture("media/ui/ArrowRight.png")
    end

    local tm = getTextManager()
    local itemNameW = tm:MeasureStringX(font, itemName)

    local arrowGap = 10
    local arrowW = 14
    local arrowH = 14

    if ui._mapArrowTex then
        local tw = ui._mapArrowTex:getWidthOrig()
        local th = ui._mapArrowTex:getHeightOrig()
        if tw and th and tw > 0 and th > 0 then
            arrowW = math.min(12, tw)
            arrowH = math.min(12, th)
        end
    end

    -- Draw source text, separator arrow, and target text as separate elements so each part
    -- can keep its own style and long names stay bounded to the left text region.
    local reservedArrowW = arrowW + (arrowGap * 2)
    local maxItemW = textW - reservedArrowW
    if maxItemW < 0 then maxItemW = 0 end

    local itemDrawW = math.min(itemNameW, maxItemW)
    if itemDrawW > 0 then
        if self.drawTextClipped then
            self:drawTextClipped(itemName, textX, ty, itemDrawW, itemColor.r, itemColor.g, itemColor.b, itemColor.a, font)
        else
            self:drawText(itemName, textX, ty, itemColor.r, itemColor.g, itemColor.b, itemColor.a, font)
        end
    end

    local arrowX = textX + itemDrawW + arrowGap
    local baselineBias = 1
    local arrowY = y + math.floor((h - arrowH) / 2) + baselineBias

    if ui._mapArrowTex then
        self:drawTextureScaledAspect(ui._mapArrowTex, arrowX, arrowY, arrowW, arrowH, arrowColor.a, arrowColor.r, arrowColor.g, arrowColor.b)
    else
        -- Fallback if the texture fails to load.
        self:drawText(">", arrowX, ty, arrowColor.r, arrowColor.g, arrowColor.b, arrowColor.a, font)
    end

    local targetX = arrowX + arrowW + arrowGap

    if rowItem.hasTransmog and rowItem.transmogItem then
        local targetIconSize = iconSize
        local targetIconY = y + math.floor((h - targetIconSize) / 2)

        ISInventoryItem.renderItemIcon(self, rowItem.transmogItem, targetX, targetIconY, iconAlpha, targetIconSize, targetIconSize)

        targetX = targetX + targetIconSize + ui._iconGap
    end

    local targetW = textW - (targetX - textX)
    if targetW < 0 then targetW = 0 end

    if targetW > 0 then
        if self.drawTextClipped then
            self:drawTextClipped(targetName, targetX, ty, targetW, targetColor.r, targetColor.g, targetColor.b, targetColor.a, font)
        else
            self:drawText(targetName, targetX, ty, targetColor.r, targetColor.g, targetColor.b, targetColor.a, font)
        end
    end

    local slotSize = ui._slotSize
    local slotGap = ui._slotGap
    local slotY = y + math.floor((h - slotSize) / 2)

    local slotsStartX = metrics.slotsStartX

    -- Slot enable state model
    local function isSlotEnabled(slotId, row)
        if slotId == 1 then return row.hasTransmogState end
        if slotId == 2 then return row.hasTransmog end
        if slotId == 3 then return true end
        if slotId == 4 then return true end
        if slotId == 5 then return row.canTexture end
        if slotId == 6 then return row.canColor end
        return false
    end

    -- Cache slot textures once on the owner.
    ui:cacheSlotTextures()

    -- Point this at your existing transmog symbol asset.
    if ui._slotTexTransmog == nil then
        ui._slotTexTransmog = getTexture("media/ui/TransmogIcon.png")
    end

    local mx = self:getMouseX()
    local my = self:getMouseY()
    local isRowHovered = self:_isRowHovered(y, h)

    local iconInset = 0

    local function drawSlotTexture(tex, x, y, size, a, r, g, b)
        if not tex then return end
        self:drawTextureScaledAspect(tex, x, y, size, size, a, r, g, b)
    end

    for visualIndex = 1, 6 do
        local slotX = slotsStartX + ((visualIndex - 1) * (slotSize + slotGap))
        local slotId = 7 - visualIndex
        local enabled = isSlotEnabled(slotId, rowItem)

        local hovered = false
        if isRowHovered then
            hovered = mx >= slotX and mx <= (slotX + slotSize)
                and my >= slotY and my <= (slotY + slotSize)
        end

        local iconX = slotX + iconInset
        local iconY = slotY + iconInset
        local iconW = slotSize - (iconInset * 2)

        local baseAlpha = enabled and 0.82 or 0.22
        local hoverAlpha = enabled and 1.00 or 0.32
        local drawAlpha = hovered and hoverAlpha or baseAlpha

        local slotIconAlpha = drawAlpha
        if slotId ~= 1 and slotId ~= 4 then
            slotIconAlpha = slotIconAlpha * iconAlpha
        end

        if slotId == 1 then
            local r, g, b = enabled and 0.95 or 0.70, enabled and 0.25 or 0.70, enabled and 0.25 or 0.70
            if hovered and enabled then
                r, g, b = 1.0, 0.35, 0.35
            end
            drawSlotTexture(ui._slotTexReset, iconX, iconY, iconW, slotIconAlpha, r, g, b)

        elseif slotId == 2 then
            local tex = ui._slotTexToggleOff
            if rowItem.hasTransmog then
                tex = hovered and ui._slotTexToggleOnOver or ui._slotTexToggleOn
            end
            drawSlotTexture(tex, iconX, iconY, iconW, slotIconAlpha, 1, 1, 1)

        elseif slotId == 3 then
            local tex = rowItem.isHidden and ui._slotTexEyeOff or ui._slotTexEyeOn
            drawSlotTexture(tex, iconX, iconY, iconW, slotIconAlpha, 1, 1, 1)

        elseif slotId == 4 then
            drawSlotTexture(ui._slotTexTransmog, iconX, iconY, iconW, slotIconAlpha, 1, 1, 1)

        elseif slotId == 5 then
            if rowItem.canTexture and rowItem.texturePreview then
                self:drawTextureScaledAspect(
                    rowItem.texturePreview,
                    iconX,
                    iconY,
                    iconW,
                    iconW,
                    slotIconAlpha,
                    1,1,1
                )

                if hovered then
                    self:drawRectBorder(iconX, iconY, iconW, iconW, 0.6, 1,1,1)
                end
            end

        elseif slotId == 6 then
            if rowItem.canColor then
                local c = rowItem.item and rowItem.colorPreview or nil
                local cr, cg, cb, ca = 0.35, 0.35, 0.35, slotIconAlpha

                if c then
                    if c.getRedFloat then
                        cr = c:getRedFloat()
                        cg = c:getGreenFloat()
                        cb = c:getBlueFloat()
                    else
                        cr = c.r or cr
                        cg = c.g or cg
                        cb = c.b or cb
                        ca = ((c.a ~= nil) and c.a or 1.0) * drawAlpha
                    end
                end

                self:drawRect(iconX, iconY, iconW, iconW, ca, cr, cg, cb)

                if hovered then
                    self:drawRectBorder(iconX, iconY, iconW, iconW, 0.6, 1, 1, 1)
                end
            end
        end
    end

    return y + h
end

function TransmogWornItems:getActionSlotMetrics(totalW, scrollbarW)
    local actionsW = self.actionsColW or 150
    local usableW = totalW - (scrollbarW or 0)
    local dividerX = usableW - actionsW

    local slotSize = self._slotSize
    local slotGap = self._slotGap
    local totalSlotsW = (slotSize * 6) + (slotGap * 5)
    local slotsStartX = dividerX + math.floor((actionsW - totalSlotsW) / 2)

    return {
        actionsW = actionsW,
        usableW = usableW,
        dividerX = dividerX,
        slotSize = slotSize,
        slotGap = slotGap,
        totalSlotsW = totalSlotsW,
        slotsStartX = slotsStartX,
    }
end

function TransmogWornItems:cacheSlotTextures()
    if self._slotTexReset == nil then
        self._slotTexReset = getTexture("media/ui/Entity/Icon_Returned_48x48.png")
    end
    if self._slotTexToggleOff == nil then
        self._slotTexToggleOff = getTexture("media/ui/Entity/widget_toggle_off.png")
    end
    if self._slotTexToggleOn == nil then
        self._slotTexToggleOn = getTexture("media/ui/Entity/widget_toggle_on.png")
    end
    if self._slotTexToggleOnOver == nil then
        self._slotTexToggleOnOver = getTexture("media/ui/Entity/widget_toggle_on_over.png")
    end
    if self._slotTexEyeOff == nil then
        self._slotTexEyeOff = getTexture("media/ui/eye_hidden.png")
    end
    if self._slotTexEyeOn == nil then
        self._slotTexEyeOn = getTexture("media/ui/eye_shown.png")
    end
    if self._slotTexTransmog == nil then
        self._slotTexTransmog = getTexture("media/ui/TransmogIcon.png")
    end
end

function TransmogWornItems:getRowSlotTooltip(row, slotId)
    if not row then return nil end

    if slotId == 1 then
        if row.hasTransmogState then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Reset")
                or "Reset this item's transmog visuals"
        end
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Reset_Disabled")
            or "Nothing to reset"

    elseif slotId == 2 then
        if row.hasTransmog then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Remove")
                or "Remove this item's transmog"
        end
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Remove_Disabled")
            or "No transmog applied"

    elseif slotId == 3 then
        if row.isHidden then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Show")
                or "Show this worn item"
        end
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Hide")
            or "Hide this worn item"

    elseif slotId == 4 then
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Transmog")
            or "Transmog this Item"

    elseif slotId == 5 then
        if row.canTexture then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Texture")
                or "Change this item's texture"
        end

    elseif slotId == 6 then
        if row.canColor then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_Color")
                or "Change this item's colour"
        end
    end

    return nil
end

function TransmogWornItems:getFooterBatchTooltip(slotId, button)
    if slotId == 1 then
        if button and button._enabled then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_ResetAll")
                or "Reset all transmog visuals"
        end
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_ResetAll_Disabled")
            or "No worn items have transmog state to reset"

    elseif slotId == 2 then
        if button and button._enabled then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_RemoveAll")
                or "Remove all transmogs"
        end
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_RemoveAll_Disabled")
            or "No worn items have transmog applied"

    elseif slotId == 3 then
        if button and button._mode == "show" then
            if button._enabled then
                return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_ShowAll")
                    or "Show all worn items"
            end
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_ShowAll_Disabled")
                or "No hidden worn items"
        end

        if button and button._enabled then
            return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_HideAll")
                or "Hide all worn items"
        end
        return getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_HideAll_Disabled")
            or "No shown worn items"
    end

    return nil
end

-- ---------------------------------------------------------
-- Footer
-- ---------------------------------------------------------

local TransmogWornItemsFooter = ISPanel:derive("TransmogWornItemsFooter")

function TransmogWornItemsFooter:new(x, y, w, h, owner)
    local o = ISPanel.new(self, x, y, w, h)
    o.owner = owner
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    o.drawBorder = false
    return o
end

function TransmogWornItemsFooter:prerender()
    ISPanel.prerender(self)

    local ui = self.owner

    self:drawRect(0, 0, self.width, self.height, 0.15, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 1, 1, 1)

    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = math.floor((self.height - fontH) / 2)

    local sortLabel = getTextOrNull("IGUI_TransmogDE_WornItems_Sort_label") or "Sort:"

    self:drawText(sortLabel, 8, ty, 1, 1, 1, 0.85, font)

    if not ui then return end
    ui:cacheSlotTextures()

    local function drawFooterTexture(tex, x, y, size, a, r, g, b)
        if not tex then return end
        self:drawTextureScaledAspect(tex, x, y, size, size, a, r, g, b)
    end

    for slotId = 1, 3 do
        local btn = ui.footerBatchButtons and ui.footerBatchButtons[slotId] or nil
        if btn then
            local enabled = btn._enabled == true
            local hovered = btn.mouseOver == true

            local alpha = enabled and 0.82 or 0.22
            if hovered and enabled then
                alpha = 1.0
            elseif hovered and not enabled then
                alpha = 0.32
            end

            local x = btn.x
            local y = btn.y
            local size = btn.width

            if slotId == 1 then
                local r, g, b = enabled and 0.95 or 0.70, enabled and 0.25 or 0.70, enabled and 0.25 or 0.70
                if hovered and enabled then
                    r, g, b = 1.0, 0.35, 0.35
                end
                drawFooterTexture(ui._slotTexReset, x, y, size, alpha, r, g, b)

            elseif slotId == 2 then
                local tex = enabled and ui._slotTexToggleOn or ui._slotTexToggleOff
                if hovered and enabled then
                    tex = ui._slotTexToggleOnOver
                end
                drawFooterTexture(tex, x, y, size, alpha, 1, 1, 1)

            elseif slotId == 3 then
                local tex = ui._slotTexEyeOn
                if btn._mode == "show" then
                    tex = ui._slotTexEyeOff
                end
                drawFooterTexture(tex, x, y, size, alpha, 1, 1, 1)
            end
        end
    end
end

-- ---------------------------------------------------------
-- Window
-- ---------------------------------------------------------

function TransmogWornItems.Open(player)
    if not player then return end

    if TransmogWornItems.instance then
        local modal = TransmogWornItems.instance
        modal.player = player
        modal.playerNum = player:getPlayerNum()
        modal:setVisible(true)
        modal:addToUIManager()
        modal:refreshList()
        modal:bringToTop()
        return modal
    end

    local modal = TransmogWornItems:new(player)
    modal:initialise()
    modal:addToUIManager()
    modal:restoreWindowState()
    modal:refreshList()
    modal:bringToTop()
    return modal
end

local function updateWornItemsList(player, clothing, forceOpen)
    local modal = TransmogWornItems.instance
    if not modal then return end
    if not modal:getIsVisible() then return end

    if player and modal.player ~= player then
        modal.player = player
        modal.playerNum = player:getPlayerNum()
    end

    modal:refreshList()
end

Events.TransmogClothingUpdate.Add(updateWornItemsList)

function TransmogWornItems.Close()
    if TransmogWornItems.instance then
        TransmogWornItems.instance:close()
    end
end

function TransmogWornItems:new(player)
    local width = 900
    local height = 350
    local x = getCore():getScreenWidth() / 2 - (width / 2)
    local y = getCore():getScreenHeight() / 2 - (height / 2)

    local o = ISCollapsableWindowJoypad.new(self, x, y, width, height)
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.title = getTextOrNull("IGUI_TransmogDE_WornItems_title") or "Transmoggable Worn Items"

    o.resizable = false

    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1.0 }
    o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1.0 }

    o.contentPanel = nil
    o.header = nil
    o.listFrame = nil
    o.list = nil
    o.footer = nil

    o.sortNameBtn = nil
    o.sortCategoryBtn = nil

    o.sortMode = "name"
    o.sortAsc = true

    o._pad = 8
    o._headerH = 24
    o._footerH = 32
    o._titleGap = 8
    o._iconSize = 28
    o._iconGap = 8
    o._slotSize = 32
    o._slotGap = 4
    o._actionsColInset = 8
    o.actionsColW = (o._slotSize * 6) + (o._slotGap * 5) + (o._actionsColInset * 2)

    TransmogWornItems.instance = o
    return o
end

function TransmogWornItems:createChildren()
    ISCollapsableWindowJoypad.createChildren(self)

    local pad = 10
    local titleH = self:titleBarHeight()

    local contentX = pad
    local contentY = titleH + pad
    local contentW = self.width - (pad * 2)
    local contentH = self.height - titleH - (pad * 2)

    self.contentPanel = ISPanel:new(contentX, contentY, contentW, contentH)
    self.contentPanel:initialise()
    self.contentPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    self.contentPanel.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    self.contentPanel.drawBorder = false
    self.contentPanel.moveWithMouse = false
    self:addChild(self.contentPanel)

    self:createHeader()
    self:createFooter()
    self:createListFrame()
    self:createList()
    self:createFooterControls()
end

function TransmogWornItems:createHeader()
    local y = 0
    self.header = TransmogWornItemsHeader:new(0, y, self.contentPanel.width, self._headerH, self)
    self.header:initialise()
    self.contentPanel:addChild(self.header)
end

function TransmogWornItems:createFooter()
    local y = self.contentPanel.height - self._footerH
    self.footer = TransmogWornItemsFooter:new(0, y, self.contentPanel.width, self._footerH, self)
    self.footer:initialise()
    self.contentPanel:addChild(self.footer)
end

function TransmogWornItems:createListFrame()
    local listY = self._headerH - 1
    local listH = self.contentPanel.height - self._headerH - self._footerH + 2

    self.listFrame = TransmogWornItemsListFrame:new(0, listY, self.contentPanel.width, listH, self)
    self.listFrame:initialise()
    self.contentPanel:addChild(self.listFrame)
end

function TransmogWornItems:createList()
    self.list = TransmogWornItemsList:new(1, 1, self.listFrame.width - 2, self.listFrame.height - 2, self)
    self.list:initialise()
    self.list:instantiate()
    self.listFrame:addChild(self.list)
end

function TransmogWornItems:getListScrollbarWidth()
    if self.list and self.list.vscroll then
        return self.list.vscroll.width or 0
    end
    return 0
end

function TransmogWornItems:buildBatchState(rows)
    local state = {
        hasRows = false,
        anyTransmogState = false,
        anyTransmog = false,
        anyShown = false,
        allHidden = false,
        showHideMode = nil, -- "hide" or "show"
    }

    local count = rows and #rows or 0
    if count == 0 then
        return state
    end

    state.hasRows = true
    state.allHidden = true

    for i = 1, count do
        local row = rows[i]

        if row.hasTransmogState then
            state.anyTransmogState = true
        end

        if row.hasTransmog then
            state.anyTransmog = true
        end

        if not row.isHidden then
            state.anyShown = true
            state.allHidden = false
        end
    end

    if state.anyShown then
        state.showHideMode = "hide"
    elseif state.allHidden then
        state.showHideMode = "show"
    end

    return state
end

function TransmogWornItems:updateFooterBatchButtons()
    if not self.footerBatchButtons then return end

    local state = self.batchState or {}
    local b1 = self.footerBatchButtons[1]
    local b2 = self.footerBatchButtons[2]
    local b3 = self.footerBatchButtons[3]

    if b1 then
        b1:setTitle("")
        b1._enabled = state.anyTransmogState == true
        b1.tooltip = self:getFooterBatchTooltip(1, b1)
    end

    if b2 then
        b2:setTitle("")
        b2._enabled = state.anyTransmog == true
        b2.tooltip = self:getFooterBatchTooltip(2, b2)
    end

    if b3 then
        b3:setTitle("")
        b3._enabled = state.showHideMode ~= nil
        b3._mode = state.showHideMode
        b3.tooltip = self:getFooterBatchTooltip(3, b3)
    end
end

function TransmogWornItems:createFooterControls()
    local btnSize = 20
    local gap = 4
    local leftPad = 8

    local label = getTextOrNull("IGUI_TransmogDE_WornItems_Sort_label") or "Sort:"
    local labelW = getTextManager():MeasureStringX(UIFont.Small, label)

    local y = math.floor((self.footer.height - btnSize) / 2)
    local xName = leftPad + labelW + 8
    local xCat = xName + btnSize + gap

    self.sortNameBtn = ISButton:new(xName, y, btnSize, btnSize, "A", self, TransmogWornItems.onSortName)
    self.sortNameBtn:initialise()
    self.sortNameBtn:instantiate()
    self.sortNameBtn.tooltip = getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_SortName")
        or "Sort by item name"
    self.footer:addChild(self.sortNameBtn)

    self.sortCategoryBtn = ISButton:new(xCat, y, btnSize, btnSize, "C", self, TransmogWornItems.onSortCategory)
    self.sortCategoryBtn:initialise()
    self.sortCategoryBtn:instantiate()
    self.sortCategoryBtn.tooltip = getTextOrNull("IGUI_TransmogDE_WornItems_Tooltip_SortCategory")
        or "Sort by category"
    self.footer:addChild(self.sortCategoryBtn)

    local listW = self.list and self.list.width or self.footer.width
    local listX = self.list and self.list.x or 0
    local metrics = self:getActionSlotMetrics(listW, self:getListScrollbarWidth())
    local slotSize = self._slotSize
    local slotGap = self._slotGap
    local slotY = math.floor((self.footer.height - slotSize) / 2)

    self.footerBatchButtons = {}

    for slotId = 1, 3 do
        local visualIndex = 7 - slotId
        local x = listX + metrics.slotsStartX + ((visualIndex - 1) * (slotSize + slotGap))

        local btn = ISButton:new(x, slotY, slotSize, slotSize, "", self, TransmogWornItems.onFooterBatchClicked)
        btn.internal = tostring(slotId)
        btn:initialise()
        btn:instantiate()
        btn.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
        btn.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
        btn.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0.0 }
        btn._enabled = false
        btn._mode = nil
        self.footer:addChild(btn)

        self.footerBatchButtons[slotId] = btn
    end

    self:updateFooterBatchButtons()
end

function TransmogWornItems:onFooterBatchClicked(button)
    local slotId = tonumber(button.internal)
    if not slotId then return end
    if button._enabled ~= true then return end

    local rows = self.rows or {}
    local focusRow = rows[1]
    local focusItem = focusRow and focusRow.item or nil
    if not focusItem then return end

    if slotId == 1 then
        TransmogNet.requestResetDefaultAll(self.player, focusItem)
        return
    end

    if slotId == 2 then
        TransmogNet.requestRemoveTransmogAll(self.player, focusItem)
        return
    end

    if slotId == 3 then
        if button._mode == "hide" then
            TransmogNet.requestHideAll(self.player, focusItem)
        elseif button._mode == "show" then
            TransmogNet.requestShowAll(self.player, focusItem)
        end
        return
    end
end

function TransmogWornItems:onSortName()
    if self.sortMode == "name" then
        self.sortAsc = not self.sortAsc
    else
        self.sortMode = "name"
        self.sortAsc = true
    end

    self:refreshList()
end

function TransmogWornItems:onSortCategory()
    if self.sortMode == "category" then
        self.sortAsc = not self.sortAsc
    else
        self.sortMode = "category"
        self.sortAsc = true
    end

    self:refreshList()
end

local function _getTexturePreview(md)
    if not md then return nil end

    local transmogTo = md.transmogTo
    local textureChoice = md.texture

    if not textureChoice then return nil end

    local script = transmogTo and ScriptManager.instance:getItem(transmogTo)
    if not script then return nil end

    local asset = TransmogDE.getClothingItemAsset(script)
    if not asset then return nil end

    local textureChoiceList = asset:hasModel()
        and asset:getTextureChoices()
        or asset:getBaseTextures()

    if not textureChoiceList then return nil end

    local idx = tonumber(textureChoice)
    if idx and idx >= 0 and idx < textureChoiceList:size() then
        local texName = textureChoiceList:get(idx)
        return getTexture('media/textures/' .. texName .. '.png')
    end

    return nil
end

function TransmogWornItems:buildItemList()
    local rows = {}
    if not self.player then return rows end

    local worn = self.player:getWornItems()
    if not worn then return rows end

    for i = 0, worn:size() - 1 do
        local entry = worn:get(i)
        local item = entry and entry:getItem() or nil

        if item
        and TransmogDE.isTransmoggable(item)
        then
            local targetName = getTextOrNull("IGUI_TransmogDE_WornItems_Default") or "Default"
            local transmogItem = item
            local hasTransmog = TransmogDE.isTransmogged(item)
            local hasTransmogState = TransmogDE.hasTransmogState(item)
            local isHidden = TransmogDE.isClothingHidden(item)
            local canColor = TransmogDE.canColorTmogItem(item)
            local canTexture = TransmogDE.canTextureTmogItem(item)
            local moddata = TransmogDE.getItemTransmogModData(item)
            if hasTransmog then
                targetName = getItemNameFromFullType(moddata.transmogTo)
                local proxy = instanceItem(moddata.transmogTo)
                if proxy then
                    TransmogDE.copyVisuals(proxy, item)
                    transmogItem = proxy
                end
            end
            local colorPreview = nil
            if canColor then
                colorPreview = TransmogDE.getClothingColor(item)
            end
            local texturePreview = nil
            if canTexture then
                texturePreview = _getTexturePreview(moddata)
            end
            table.insert(rows, {
                item = item,
                transmogItem = transmogItem,
                itemName = item:getDisplayName(),
                itemCat = _safeCategory(item),
                targetName = targetName,
                hasTransmog = hasTransmog,
                hasTransmogState = hasTransmogState,
                isHidden = isHidden,
                canColor = canColor,
                canTexture = canTexture,
                colorPreview = colorPreview,
                texturePreview = texturePreview,
            })
        end
    end

    return rows
end

function TransmogWornItems:refreshList()
    if not self.list then return end

    local rows = self:buildItemList()
    self.rows = rows
    self.batchState = self:buildBatchState(rows)

    table.sort(rows, function(a, b)
        if self.sortMode == "category" then
            if a.itemCat ~= b.itemCat then
                if self.sortAsc then
                    return a.itemCat < b.itemCat
                else
                    return a.itemCat > b.itemCat
                end
            end
        end

        if self.sortAsc then
            return a.itemName < b.itemName
        else
            return a.itemName > b.itemName
        end
    end)

    self.list:clear()

    for i = 1, #rows do
        local row = rows[i]
        self.list:addItem(row.itemName, row)
    end

    if #rows == 0 then
        self.list:addItem(
            getTextOrNull("IGUI_TransmogDE_WornItems_NoItems") or "No worn transmoggable items available",
            { empty = true }
        )
    end

    self:updateFooterBatchButtons()
end

function TransmogWornItems:restoreWindowState()
    if Prefs then
        Prefs.restoreWindowStateOrCenter(self)
    end
end

function TransmogWornItems:saveWindowState()
    if Prefs then
        Prefs.saveWindowState(self)
    end
end

function TransmogWornItems:onMouseUp(x, y)
    local moving = self.moving == true
    local resizing = self.resizing == true
    ISCollapsableWindowJoypad.onMouseUp(self, x, y)
    if moving or resizing then
        self:saveWindowState()
    end
end

function TransmogWornItems:onMouseUpOutside(x, y)
    local moving = self.moving == true
    local resizing = self.resizing == true
    ISCollapsableWindowJoypad.onMouseUpOutside(self, x, y)
    if moving or resizing then
        self:saveWindowState()
    end
end

function TransmogWornItems:close()
    if TransmogWornItems.instance == self then
        TransmogWornItems.instance = nil
    end

    if self.list and self.list._hideSlotTooltip then
        self.list:_hideSlotTooltip()
    end

    self:saveWindowState()
    self:removeFromUIManager()

    if JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, self.prevFocus)
    end
end