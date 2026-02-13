require "ISUI/AdminPanel/ISItemsListViewer"
require "ISUI/ISLabel"
local Prefs     = require("Transmog/Prefs")

TransmogListViewer = ISPanel:derive("TransmogListViewer")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local LABEL_HGT = FONT_HGT_MEDIUM + 6

-- local old_ISItemsListViewer_initialise = ISItemsListViewer.initialise
function TransmogListViewer:initialise()
    ISPanel.initialise(self);
    local btnWid = getTextManager():MeasureStringX(UIFont.Small, "Player 1") + 50

    self.playerSelect = ISComboBox:new(self.width - UI_BORDER_SPACING - btnWid - 1, UI_BORDER_SPACING + 1, btnWid, BUTTON_HGT, self, self.onSelectPlayer)
    self.playerSelect:initialise()
    self.playerSelect:addOption("Player 1")
    self.playerSelect:addOption("Player 2")
    self.playerSelect:addOption("Player 3")
    self.playerSelect:addOption("Player 4")
    self:addChild(self.playerSelect)

    self.ok = ISButton:new(UI_BORDER_SPACING+1, self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1, btnWid, BUTTON_HGT, getText("IGUI_CraftUI_Close"), self, ISItemsListViewer.onClick);
    self.ok.internal = "CLOSE";
    self.ok.anchorTop = false
    self.ok.anchorBottom = true
    self.ok:initialise();
    self.ok:instantiate();
    self.ok:enableCancelColor()
    self:addChild(self.ok);

    local top = UI_BORDER_SPACING*2 + FONT_HGT_MEDIUM+1
    self.panel = ISTabPanel:new(UI_BORDER_SPACING+1, top, self.width - (UI_BORDER_SPACING+1)*2, self.ok.y - UI_BORDER_SPACING - top);
    self.panel:initialise();
    self.panel.borderColor = { r = 0, g = 0, b = 0, a = 0};
    self.panel.target = self;
    self.panel.equalTabWidth = false
    self:addChild(self.panel);

    self:initList();

    local btnWid = getTextManager():MeasureStringX(UIFont.Small, "Player 1") + 50

    local arrowLabel = ""
    local arrowBtnW = 20

    local arrowX = self:getWidth() - (UI_BORDER_SPACING + 1) - arrowBtnW -- self.reset.x - arrowBtnW - UI_BORDER_SPACING
    local arrowY = self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1
    local tex = getTexture("media/ui/arrow_down.png")
    self.moreBtn = ISButton:new(arrowX, arrowY, arrowBtnW, BUTTON_HGT, arrowLabel, self,
        TransmogListViewer.onClickTransmogMenu)
    self.moreBtn:setImage(tex)
    self.moreBtn.anchorTop = false
    self.moreBtn.anchorLeft = false
    self.moreBtn.anchorBottom = true
    self.moreBtn.anchorRight = true
    self.moreBtn:initialise()
    self.moreBtn:instantiate()
    self.moreBtn.tooltip = getTextOrNull("IGUI_TransmogDE_Tooltip_BatchActions") or "Batch Actions"
    self:addChild(self.moreBtn)

    local resetX = self.moreBtn.x - (UI_BORDER_SPACING + 1) - btnWid
    local resetY = self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1
    self.reset = ISButton:new(resetX, resetY, btnWid, BUTTON_HGT, getText("IGUI_WorldMapEditor_Reset"), self,
        TransmogListViewer.onClickTransmog)
    self.reset.internal = "RESET"
    self.reset.anchorTop = false
    self.reset.anchorLeft = false
    self.reset.anchorBottom = true
    self.reset.anchorRight = true
    self.reset:initialise()
    self.reset:instantiate()
    self.reset:enableCancelColor()
    self.reset:setTooltip(getText("IGUI_TransmogDE_ListViewer_Reset_tooltip"))
    self:addChild(self.reset)

    local resetX = self.reset.x - (UI_BORDER_SPACING + 1) - btnWid
    local resetY = self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1
    self.remove = ISButton:new(resetX, resetY, btnWid, BUTTON_HGT, getText("IGUI_TransmogDE_ListViewer_Remove"), self,
        TransmogListViewer.onClickTransmog)
    self.remove.internal = "REMOVE"
    self.remove.anchorTop = false
    self.remove.anchorLeft = false
    self.remove.anchorBottom = true
    self.remove.anchorRight = true
    self.remove:initialise()
    self.remove:instantiate()
    self.remove:enableAcceptColor()
    self.remove:setTooltip(getText("IGUI_TransmogDE_ListViewer_Remove_tooltip"))
    self:addChild(self.remove)

    local hideShowX = self.remove.x - (UI_BORDER_SPACING + 1) - btnWid
    local hideShowY = self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1
    self.hideItem = ISButton:new(hideShowX, hideShowY, btnWid, BUTTON_HGT,
        getText("IGUI_TransmogDE_ListViewer_Hide"), self, TransmogListViewer.onClickTransmog)
    self.hideItem.internal = "HIDEITEM"
    self.hideItem.anchorTop = false
    self.hideItem.anchorLeft = false
    self.hideItem.anchorBottom = true
    self.hideItem.anchorRight = true
    self.hideItem:initialise()
    self.hideItem:instantiate()
    self.hideItem:enableCancelColor()
    self.hideItem:setTooltip(getText("IGUI_TransmogDE_ListViewer_Hide_tooltip"))
    self:addChild(self.hideItem)

    self.showItem = ISButton:new(hideShowX, hideShowY, btnWid, BUTTON_HGT,
        getText("IGUI_TransmogDE_ListViewer_Show"), self, TransmogListViewer.onClickTransmog)
    self.showItem.internal = "SHOWITEM"
    self.showItem.anchorTop = false
    self.showItem.anchorLeft = false
    self.showItem.anchorBottom = true
    self.showItem.anchorRight = true
    self.showItem:initialise()
    self.showItem:instantiate()
    self.showItem:enableAcceptColor()
    self.showItem:setTooltip(getText("IGUI_TransmogDE_ListViewer_Show_tooltip"))
    self:addChild(self.showItem)

    local isHidden = TransmogDE.isClothingHidden(self.item)
    self.hideItem:setVisible(not isHidden)
    self.showItem:setVisible(isHidden)
end

function TransmogListViewer:new(x, y, width, height, itemToTmog)
    local o = {}
    x = getCore():getScreenWidth() / 4 - (width / 2)
    y = getCore():getScreenHeight() / 2 - (height / 2)
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {
        r = 0.4,
        g = 0.4,
        b = 0.4,
        a = 1
    }
    o.backgroundColor = {
        r = 0,
        g = 0,
        b = 0,
        a = 0.8
    }
    o.width = width
    o.height = height
    o.moveWithMouse = true
    -- These two must be set before init, so it's passed to the ISItemsListTable
    o.item = itemToTmog
    o.isTransmogListViewer = true
    TransmogListViewer.instance = o
    return o
end

function TransmogListViewer:rebuildTabPanel()
    -- Remove old panel cleanly
    if self.panel then
        self.panel:setVisible(false)
        self:removeChild(self.panel)
        self.panel = nil
    end

    -- Recreate with the same geometry as initialise()
    local top = UI_BORDER_SPACING * 2 + FONT_HGT_MEDIUM + 1
    local x = UI_BORDER_SPACING + 1
    local y = top
    local w = self.width - (UI_BORDER_SPACING + 1) * 2
    local h = self.ok.y - UI_BORDER_SPACING - top

    local panel = ISTabPanel:new(x, y, w, h)
    panel:initialise()
    panel.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    panel.target = self
    panel.equalTabWidth = false

    self.panel = panel
    self:addChild(self.panel)

    self:initList()
end

function TransmogListViewer:setPlayer(player)
    if player then
        self.player = player
    end
end

function ISItemsListViewer:onSelectPlayer()
end

function TransmogListViewer:saveWindowState()
    if Prefs then
        Prefs.saveWindowState(self)
    end
end

-- Restore position + pin state + visibility (from INI)
function TransmogListViewer:restoreWindowState()
    Prefs.restoreWindowStateOrCenter(self)
end

function TransmogListViewer:onMouseUp(x, y)
    local moving   = self.moving   == true
    local resizing = self.resizing == true
    ISItemsListViewer.onMouseUp(self, x, y)
    if moving or resizing then self:saveWindowState() end
end

function TransmogListViewer:onMouseUpOutside(x, y)
    local moving   = self.moving   == true
    local resizing = self.resizing == true
    ISItemsListViewer.onMouseUpOutside(self, x, y)
    if moving or resizing then self:saveWindowState() end
end

local old_ISItemsListViewer_onClick = ISItemsListViewer.onClick
function ISItemsListViewer:onClick(button)
    old_ISItemsListViewer_onClick(self, button)
    if self.isTransmogListViewer then
        if button.internal == "CLOSE" then
            if TransmogListViewer.instance == self then
                TransmogListViewer.instance = nil
                self:saveWindowState()
            end
        end
    end
end

function TransmogListViewer:onClickTransmogMenu(button)
    local player = getSpecificPlayer(0) or getPlayer()
    if not player then return end

    local pn = tonumber(player:getPlayerNum()) or 0  -- ensure NUMBER 0..3
    if pn < 0 then pn = 0 end

    local x = button:getAbsoluteX()
    local y = button:getAbsoluteY() + button:getHeight()

    local function addTooltip(option, text)
        if not text or text == "" then return end

        local tip = ISToolTip:new()
        tip:initialise()
        tip:setVisible(false)
        tip.description = text
        -- tip.name = "" -- optional, if you want a bold title line
        -- tip.maxLineWidth = 400 -- optional clamp

        option.toolTip = tip
    end

    local menu = ISContextMenu.get(pn, x, y)
    if not menu then return end

    if menu.clear then menu:clear() end
    if menu.setX then menu:setX(x) end
    if menu.setY then menu:setY(y) end

    local hideAll = menu:addOption(
        getText("IGUI_TransmogDE_ListViewer_HideAllWorn"),
        self, TransmogListViewer.onBatchAction, "HIDE_ALL"
    )
    addTooltip(hideAll, getText("IGUI_TransmogDE_ListViewer_HideAllWorn_tooltip"))

    local showAll = menu:addOption(
        getText("IGUI_TransmogDE_ListViewer_ShowAllWorn"),
        self, TransmogListViewer.onBatchAction, "SHOW_ALL"
    )
    addTooltip(showAll, getText("IGUI_TransmogDE_ListViewer_ShowAllWorn_tooltip"))

    local removeAll = menu:addOption(
        getText("IGUI_TransmogDE_ListViewer_RemoveAllWorn"),
        self, TransmogListViewer.onBatchAction, "REMOVE_ALL"
    )
    removeAll.goodColor = true
    addTooltip(removeAll, getText("IGUI_TransmogDE_ListViewer_RemoveAllWorn_tooltip"))

    local resetAll = menu:addOption(
        getText("IGUI_TransmogDE_ListViewer_ResetAllWorn"),
        self, TransmogListViewer.onBatchAction, "RESET_ALL"
    )
    resetAll.badColor = true
    addTooltip(resetAll, getText("IGUI_TransmogDE_ListViewer_ResetAllWorn_tooltip"))

    menu:addToUIManager()
end

function TransmogListViewer:onBatchAction(action)
    -- All-batch ops: route via TransmogNet (server-authoritative in MP).
    -- focus item is passed only so notifyPlayer can refresh this UI selection.
    if action == "HIDE_ALL" then
        TransmogNet.requestHideAll(self.player, self.item)
    elseif action == "SHOW_ALL" then
        TransmogNet.requestShowAll(self.player, self.item)
    elseif action == "REMOVE_ALL" then
        TransmogNet.requestRemoveTransmogAll(self.player, self.item)
    elseif action == "RESET_ALL" then
        TransmogNet.requestResetDefaultAll(self.player, self.item)
    end
end

function TransmogListViewer:onClickTransmog(button)
    local request = button.internal

    if request == "REMOVE" then
        TransmogNet.requestRemoveTransmog(self.player, self.item)
        return
    end

    if request == "RESET" then
        TransmogNet.requestResetDefault(self.player, self.item)
        return
    end

    if request == "HIDEITEM" then
        TransmogNet.requestHide(self.player, self.item)
        return
    end

    if request == "SHOWITEM" then
        TransmogNet.requestShow(self.player, self.item)
        return
    end
end

function TransmogListViewer:close()
    TransmogListViewer.instance = nil
    TexturePickerModal.Close()
    ColorPickerModal.Close()
    
    self:setVisible(false);
    self:removeFromUIManager();
end

function TransmogListViewer:syncUIState()
    if not (self and self.item and self.hideItem and self.showItem) then return end

    local isHidden = TransmogDE.isClothingHidden(self.item)

    if self._lastHidden == nil or self._lastHidden ~= isHidden then
        TmogPrint("Updating Transmog UI")
        self._lastHidden = isHidden
        self.hideItem:setVisible(not isHidden)
        self.showItem:setVisible(isHidden)
        ColorPickerModal.updateItemToColor(self.player, self.item)
        TexturePickerModal.updateItemToTexture(self.player, self.item)
    end
end

function TransmogListViewer:updateItemToTmogData(player, clothing)
    -- Keep internal refs in sync (defensive; usually same objects)
    if player and player ~= self.player then
        self:setPlayer(player)
    end
    if clothing and clothing ~= self.item then
        self.item = clothing
    end
end

local function updateItemToTmog(player, clothing, forceOpen)
    local modal = TransmogListViewer.instance
    local item = clothing or modal and modal.item or nil
    if not item then return end
    if modal and modal:getIsVisible() then
        if not (clothing and forceOpen) then
            item = modal.item
        end
        if forceOpen then
            modal:rebuildTabPanel()
        end
        ColorPickerModal.updateItemToColor(player, item)
        TexturePickerModal.updateItemToTexture(player, item)
    elseif forceOpen then
        TransmogListViewer.OpenNew(player, clothing)

        ColorPickerModal.updateItemToColor(player, clothing)
        TexturePickerModal.updateItemToTexture(player, clothing)
    end
end

Events.TransmogClothingUpdate.Add(updateItemToTmog)

function TransmogListViewer.OpenNew(player, clothing)
    local x = 50
    local y = 200
    local width = 1000
    local height = 650
    local modal = TransmogListViewer:new(x, y, width, height, clothing)
    modal:initialise()
    modal:addToUIManager()
    modal:restoreWindowState()
    modal:removeChild(modal.playerSelect)
    modal:setPlayer(player)
    modal:setKeyboardFocus()
end

function TransmogListViewer.Open(player, clothing)
    updateItemToTmog(player, clothing, true)
end

function TransmogListViewer:initList()
    self.items = self.items or getAllItems();

    self.module = {};
    local moduleNames = {}
    local allItems = {}
    for i=0,self.items:size()-1 do
        local item = self.items:get(i);
        if not item:getObsolete() and not item:isHidden() then
            local isTransmogItem = TransmogDE.isTransmoggable(item) and (TransmogDE.immersiveModeItemCheck(item) or (getCore():getDebug() or isAdmin()))
            if isTransmogItem then
                local isLocationUnrestricted = (getCore():getDebug() or isAdmin()) or (not SandboxVars.TransmogDE.LimitTransmogToSameBodyLocation)
                local isSameBodyLocation = item:getBodyLocation() == self.item:getBodyLocation()
                local locationAllowed = isLocationUnrestricted or isSameBodyLocation
                if locationAllowed then
                    if not self.module[item:getModuleName()] then
                        self.module[item:getModuleName()] = {}
                        table.insert(moduleNames, item:getModuleName())
                    end
                    table.insert(self.module[item:getModuleName()], item);
                    table.insert(allItems, item)
                end
            end
        end
    end

    table.sort(moduleNames, function(a,b) return not string.sort(a, b) end)

    local listBox = TransmogItemsListTable:new(0, 0, self.panel.width, self.panel.height - self.panel.tabHeight, self);
    listBox:initialise();
    self.panel:addView("All", listBox);
    listBox:initList(allItems)

    for _,moduleName in ipairs(moduleNames) do
        if moduleName ~= "Moveables" then
            local cat1 = TransmogItemsListTable:new(0, 0, self.panel.width, self.panel.height - self.panel.tabHeight, self);
            cat1:initialise();
            self.panel:addView(moduleName, cat1);
            cat1:initList(self.module[moduleName])
        end
    end
    self.panel:activateView("All");
end

function TransmogListViewer:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)

    local z = 20
    local fullItemName = getItemNameFromFullType(self.item:getScriptItem():getFullName())
    local text = getTextOrNull("IGUI_TransmogDE_ListViewer_Standard_Item", fullItemName)
    local textSize = self.width / 2 - (getTextManager():MeasureStringX(UIFont.Medium, text) / 2)
    self:drawText(text, textSize, z, 1, 1, 1, 1, UIFont.Medium)

    self:syncUIState()
end

function TransmogListViewer:setKeyboardFocus()
    local view = self.panel:getActiveView()
    if not view then return end
    Core.UnfocusActiveTextEntryBox()
    view.filterWidgetMap.Type:focus()
end

TransmogItemsListTable = ISItemsListTable:derive("TransmogItemsListTable")
function TransmogItemsListTable:render()
    ISPanel.render(self)

    local y = self.datas.y + self.datas.height + UI_BORDER_SPACING + 3
    self:drawText(getText("IGUI_DbViewer_TotalResult") .. self.totalResult, 0, y, 1, 1, 1, 1, UIFont.Small)
    self:drawText(getText("IGUI_TransmogDE_Info"), 0, y + BUTTON_HGT, 1, 1, 1, 1, UIFont.Small)

    -- Show/Hide Prompt
    local isHidden = TransmogDE.isClothingHidden(self.viewer.item)
    local showOrHide = isHidden and "IGUI_TransmogDE_Info_Show" or "IGUI_TransmogDE_Info_Hide"
    self:drawText(getText(showOrHide), 0, y + BUTTON_HGT * 2, 1, 1, 1, 1, UIFont.Small)

    -- Reset Prompt
    self:drawText(getText("IGUI_TransmogDE_Info_Reset"), 0, y + BUTTON_HGT * 3, 1, 1, 1, 1, UIFont.Small)

    y = self.filters:getBottom()

    self:drawRectBorder(self.datas.x, y, self.datas:getWidth(), BUTTON_HGT, 1, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)
    self:drawRect(self.datas.x, y, self.datas:getWidth(), BUTTON_HGT, self.listHeaderColor.a, self.listHeaderColor.r,
        self.listHeaderColor.g, self.listHeaderColor.b)

    local x = 0
    for i, v in ipairs(self.datas.columns) do
        local size
        if i == #self.datas.columns then
            size = self.datas.width - x
        else
            size = self.datas.columns[i + 1].size - self.datas.columns[i].size
        end
        --        print(v.name, x, v.size)
        self:drawText(v.name, x + UI_BORDER_SPACING + 1, y + 3, 1, 1, 1, 1, UIFont.Small)
        self:drawRectBorder(self.datas.x + x, y, 1, BUTTON_HGT, 1, self.borderColor.r, self.borderColor.g,
            self.borderColor.b)
        x = x + size
    end
end

-- Remove a column and its associated filter widgets from the table
-- Returns true if a column was removed
local function _removeColumnByName(self, columnName)
    local scrollBox = self.datas
    local filters = self.filterWidgets
    if not scrollBox or not scrollBox.columns then
        return false
    end

    local removed = false

    for i = #scrollBox.columns, 1, -1 do
        local col = scrollBox.columns[i]
        if col and col.name == columnName then
            table.remove(scrollBox.columns, i)
            removed = true
        end
    end

    if removed and filters then
        for i = #filters, 1, -1 do
            local widget = filters[i]
            if widget and widget.columnName == columnName then
                -- DebugLog.log(DebugType.General, "[TransmogDE] Found Widget for column: " .. tostring(columnName))

                if widget and widget.getParent then
                    local parent = widget:getParent()
                    if parent == self or parent == self.datas then
                        -- DebugLog.log(DebugType.General, "[TransmogDE] Removing Widget UI element for: " .. tostring(columnName))
                        parent:removeChild(widget)
                    else
                        -- DebugLog.log(DebugType.General, "[TransmogDE] Widget parent is " .. tostring(parent))
                    end
                end

                table.remove(filters, i)
            end
        end
    end

    if self.filterWidgetMap and self.filterWidgetMap[columnName] then
        self.filterWidgetMap[columnName] = nil
    end

    return removed
end

function TransmogItemsListTable:createChildren()
    local result = ISItemsListTable.createChildren(self)

    _removeColumnByName(self, "#spawn")
    _removeColumnByName(self, "Loot")
    _removeColumnByName(self, "Forage")
    _removeColumnByName(self, "Craft")
    _removeColumnByName(self, "LootCategory")
    -- Expand the last remaining combo (DisplayCategory) to reach the right edge
    local lastCol = self.filterWidgetMap and self.filterWidgetMap.DisplayCategory
    if lastCol and lastCol.setWidth then
        -- rightEdge = full width of the table panel, minus 1px border line
        local rightEdge = self:getWidth()

        -- desired width = distance from current X to that right edge
        local desiredW = rightEdge - lastCol:getX()

        if desiredW > lastCol:getWidth() then
            lastCol:setWidth(desiredW)
        end
    end

    self:removeChild(self.buttonAdd1)
    self:removeChild(self.buttonAdd2)
    self:removeChild(self.buttonAdd5)
    self:removeChild(self.buttonAddMultiple)
    -- self:removeChild(self.filters)

    -- keep our double-click behavior
    self.datas:setOnMouseDoubleClick(self, self.sendItemToTransmog)

    return result
end

function TransmogItemsListTable:sendItemToTransmog(scriptItem)
    TransmogNet.requestTransmog(self.viewer.player, self.viewer.item, scriptItem:getFullName())
end

function TransmogItemsListTable:drawDatas(y, item, alt)
    if y + self:getYScroll() + self.itemheight < 0 or y + self:getYScroll() >= self.height then
        return y + self.itemheight
    end

    local a = 0.9

    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15)
    end

    if alt then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.6, 0.5, 0.5)
    end

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight, a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)

    local iconX = 4
    local iconSize = FONT_HGT_SMALL
    local xoffset = UI_BORDER_SPACING

    local clipX = self.columns[1].size
    local clipX2 = self.columns[2].size
    local clipY = math.max(0, y + self:getYScroll())
    local clipY2 = math.min(self.height, y + self:getYScroll() + self.itemheight)

    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getName(), xoffset, y + 3, 1, 1, 1, a, self.font)
    self:clearStencilRect()

    clipX = self.columns[2].size
    clipX2 = self.columns[3].size
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getDisplayName(), self.columns[2].size + iconX + iconSize + 4, y + 3, 1, 1, 1, a, self.font)
    self:clearStencilRect()

    clipX = self.columns[3].size
    clipX2 = self.columns[4].size
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    local it = item.item:getItemType()
    local itStr = it and it:toString() or "<nil>"
    self:drawText(itStr, self.columns[3].size + xoffset, y + 3, 1, 1, 1, a, self.font)
    self:clearStencilRect()

    if item.item:getDisplayCategory() ~= nil then
        self:drawText(getText("IGUI_ItemCat_" .. item.item:getDisplayCategory()), self.columns[4].size + xoffset, y + 4,
            1, 1, 1, a, self.font)
    else
        self:drawText("Error: No category set", self.columns[4].size + xoffset, y + 3, 1, 1, 1, a, self.font)
    end

    self:repaintStencilRect(0, clipY, self.width, clipY2 - clipY)

    local icon = item.item:getIcon()
    if item.item:getIconsForTexture() and not item.item:getIconsForTexture():isEmpty() then
        icon = item.item:getIconsForTexture():get(0)
    end
    if icon then
        local texture = tryGetTexture("Item_" .. icon)
        if texture then
            self:drawTextureScaledAspect2(texture, self.columns[2].size + iconX, y + (self.itemheight - iconSize) / 2,
                iconSize, iconSize, 1, 1, 1, 1)
        end
    end

    return y + self.itemheight
end

function TransmogItemsListTable:initList(module)
    if self.filterWidgetMap.LootCategory ~= nil then
        return ISItemsListTable.initList(self, module)
    end
    self.totalResult = 0
    local categoryNames = {}
    local displayCategoryNames = {}
    local categoryMap = {}
    local displayCategoryMap = {}
    for x, v in ipairs(module) do
        self.datas:addItem(v:getDisplayName(), v)
        local it = v:getItemType()
        local itStr = it and it:toString() or "<nil>"

        if not categoryMap[itStr] then
            categoryMap[itStr] = true
            table.insert(categoryNames, itStr)
        end
        if not displayCategoryMap[v:getDisplayCategory()] then
            displayCategoryMap[v:getDisplayCategory()] = true
            table.insert(displayCategoryNames, v:getDisplayCategory())
        end
        self.totalResult = self.totalResult + 1
    end
    table.sort(self.datas.items, function(a, b)
        return not string.sort(a.item:getDisplayName(), b.item:getDisplayName())
    end)

    local categoryCombo = self.filterWidgetMap.Category
    table.sort(categoryNames, function(a, b)
        return not string.sort(a, b)
    end)
    categoryCombo:addOption("<Any>")
    for _, categoryName in ipairs(categoryNames) do
        categoryCombo:addOption(categoryName)
    end

    local displayCombo = self.filterWidgetMap.DisplayCategory
    table.sort(displayCategoryNames, function(a, b)
        return not string.sort(a, b)
    end)
    displayCombo:addOption("<Any>")
    displayCombo:addOption("<No category set>")
    for _, displayCategoryName in ipairs(displayCategoryNames) do
        displayCombo:addOption(displayCategoryName)
    end
end
