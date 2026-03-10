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

local function _isTransmoggable(item)
    if not item then return false end
    if TransmogDE and type(TransmogDE.isTransmoggable) == "function" then
        return TransmogDE.isTransmoggable(item) == true
    end
    return true
end

local function _safeCategory(item)
    if not item then return "Other" end
    return item:getDisplayCategory() or "Other"
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

    self:drawText("Item", ui._pad, ty, 1, 1, 1, 0.85, font)

    local actionsLabel = "Actions"
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
    o.itemheight = 32
    o.font = UIFont.Small
    return o
end

function TransmogWornItemsList:_isRowHovered(y, h)
    if not self:isMouseOver() then return false end
    local my = self:getMouseY()
    return my >= y and my < (y + h)
end

function TransmogWornItemsList:doDrawItem(y, item, alt)
    local ui = self.owner
    local e = item and item.item
    local h = self.itemheight

    if y + self:getYScroll() + h < 0 or y + self:getYScroll() >= self.height then
        return y + h
    end

    -- row border
    self:drawRectBorder(0, y, self.width, h, 0.25, 1, 1, 1)

    if self:_isRowHovered(y, h) then
        self:drawRect(0, y, self.width, h, 0.12, 1, 1, 1)
    else
        self:drawRect(0, y, self.width, h, 0.00, 1, 1, 1)
    end

    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = y + math.floor((h - fontH) / 2)

    local actionsW = ui.actionsColW or 150
    local usableW = self.width - ((self.vscroll and (self.vscroll.width or 0)) or 0)
    local dividerX = usableW - actionsW

    local pad = ui._pad
    local iconSize = ui._iconSize
    local iconX = pad
    local iconY = y + math.floor((h - iconSize) / 2)

    if e and e.iconTex then
        self:drawTextureScaledAspect(e.iconTex, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    else
        self:drawRect(iconX, iconY, iconSize, iconSize, 0.10, 1, 1, 1)
        self:drawRectBorder(iconX, iconY, iconSize, iconSize, 0.4, 1, 1, 1)
    end

    local textX = iconX + iconSize + ui._iconGap
    local textW = dividerX - textX - 6
    if textW < 10 then textW = 10 end

    local leftText = ((e and e.itemName) or "Unknown") .. " -> " .. ((e and e.targetName) or "Default")

    if self.drawTextClipped then
        self:drawTextClipped(leftText, textX, ty, textW, 1, 1, 1, 0.95, font)
    else
        self:drawText(leftText, textX, ty, 1, 1, 1, 0.95, font)
    end

    local slotSize = ui._slotSize
    local slotGap = ui._slotGap
    local slotY = y + math.floor((h - slotSize) / 2)

    local totalSlotsW = (slotSize * 6) + (slotGap * 5)
    local slotsStartX = dividerX + math.floor((actionsW - totalSlotsW) / 2)

    for slot = 1, 6 do
        local slotX = slotsStartX + ((slot - 1) * (slotSize + slotGap))
        self:drawRectBorder(slotX, slotY, slotSize, slotSize, 0.35, 1, 1, 1)
    end

    return y + h
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

    self:drawRect(0, 0, self.width, self.height, 0.15, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 1, 1, 1)

    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = math.floor((self.height - fontH) / 2)

    self:drawText("Sort:", 8, ty, 1, 1, 1, 0.85, font)
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
    o.title = getTextOrNull("IGUI_TransmogDE_WornItems_Title") or "Transmoggable Worn Items"

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
    o._slotSize = 25
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
    self:createSortButtons()
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

function TransmogWornItems:createSortButtons()
    local btnSize = 20
    local gap = 4
    local leftPad = 8

    local label = "Sort:"
    local labelW = getTextManager():MeasureStringX(UIFont.Small, label)

    local y = math.floor((self.footer.height - btnSize) / 2)
    local xName = leftPad + labelW + 8
    local xCat = xName + btnSize + gap

    self.sortNameBtn = ISButton:new(xName, y, btnSize, btnSize, "A", self, TransmogWornItems.onSortName)
    self.sortNameBtn:initialise()
    self.sortNameBtn:instantiate()
    self.footer:addChild(self.sortNameBtn)

    self.sortCategoryBtn = ISButton:new(xCat, y, btnSize, btnSize, "C", self, TransmogWornItems.onSortCategory)
    self.sortCategoryBtn:initialise()
    self.sortCategoryBtn:instantiate()
    self.footer:addChild(self.sortCategoryBtn)
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

function TransmogWornItems:buildItemList()
    local rows = {}
    if not self.player then return rows end

    local worn = self.player:getWornItems()
    if not worn then return rows end

    for i = 0, worn:size() - 1 do
        local entry = worn:get(i)
        local item = entry and entry:getItem() or nil

        if item 
        and _isTransmoggable(item)
        then
            table.insert(rows, {
                item = item,
                itemName = item:getDisplayName(),
                itemCat = _safeCategory(item),
                iconTex = item:getTex(),
                targetName = "Default",
                canReset = false,
                canRemove = false,
                isHidden = false,
                canTexture = false,
                canColour = false,
            })
        end
    end

    return rows
end

function TransmogWornItems:refreshList()
    if not self.list then return end

    local rows = self:buildItemList()

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

    self:saveWindowState()
    self:removeFromUIManager()

    if JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, self.prevFocus)
    end
end