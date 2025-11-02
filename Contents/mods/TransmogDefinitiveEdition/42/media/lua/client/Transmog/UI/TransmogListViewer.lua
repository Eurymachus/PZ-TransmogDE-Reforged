require "ISUI/AdminPanel/ISItemsListViewer"
require "ISUI/ISLabel"

TransmogListViewer = ISItemsListViewer:derive("TransmogListViewer");

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local LABEL_HGT = FONT_HGT_MEDIUM + 6

-- local old_ISItemsListViewer_initialise = ISItemsListViewer.initialise
function TransmogListViewer:initialise()
    ISItemsListViewer.initialise(self)
    local btnWid = getTextManager():MeasureStringX(UIFont.Small, "Player 1")+50
    
    self.reset = ISButton:new(self:getWidth() - (UI_BORDER_SPACING+1) - btnWid, self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1, btnWid, BUTTON_HGT, getText("IGUI_WorldMapEditor_Reset"), self, TransmogListViewer.onClickReset);
    --self.reset = ISButton:new(self.ok.x - (UI_BORDER_SPACING + 1) - btnWid, self:getHeight() - UI_BORDER_SPACING - BUTTON_HGT - 1, btnWid, BUTTON_HGT, getText("IGUI_WorldMapEditor_Reset"), self, TransmogListViewer.onClickReset);
    self.reset.internal = "RESET";
    self.reset.anchorTop = false
    self.reset.anchorLeft = false
    self.reset.anchorBottom = true
    self.reset.anchorRight = true
    self.reset:initialise();
    self.reset:instantiate();
    self.reset:enableCancelColor()
    self:addChild(self.reset);
end

function TransmogListViewer:new(x, y, width, height, itemToTmog)
  local o = {}
  x = getCore():getScreenWidth() / 2 - (width / 2);
  y = getCore():getScreenHeight() / 2 - (height / 2);
  o = ISPanel:new(x, y, width, height);
  setmetatable(o, self)
  self.__index = self
  o.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 };
  o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.8 };
  o.width = width;
  o.height = height;
  o.moveWithMouse = true;
  -- These two must be set before init, so it's passed to the ISItemsListTable
  o.itemToTmog = itemToTmog;
  o.isTransmogListViewer = true
  TransmogListViewer.instance = o;
  return o;
end

function TransmogListViewer:onClickReset(button)
    if button.internal == "RESET" then
        TransmogDE.setItemToDefault(self.itemToTmog)
        TransmogDE.triggerUpdate()
    end
end

function TransmogListViewer:updateItemToTmog(clothing)
    self.itemToTmog = clothing
end

function TransmogListViewer.Open(itemToTmog)
  if TransmogListViewer.instance then
      --TransmogListViewer.instance:close()
      TransmogListViewer.instance:updateItemToTmog(itemToTmog)
      return
  end
  local x = 50
  local y = 200
  local width = 1000
  local height = 650
  local modal = TransmogListViewer:new(x, y, width, height, itemToTmog)
  modal:initialise();
  modal:addToUIManager();
  modal:removeChild(modal.playerSelect);
  modal.instance:setKeyboardFocus()
end

function TransmogListViewer:initList()
  -- Hack to use as litte code as possible and keep backcompatibility
  -- getAllItems is used inside the original function (ISItemsListViewer.initList)
  local backupGetAllItems = getAllItems;
  getAllItems = function()
    local filteredItems = ArrayList:new()
    local allItems = backupGetAllItems()
    for i = 0, allItems:size() - 1 do
      local item = allItems:get(i);
      if TransmogDE.isTransmoggable(item) and TransmogDE.immersiveModeItemCheck(item) then
        local isSameBodyLocation = item:getBodyLocation() == self.itemToTmog:getBodyLocation()
        if not SandboxVars.TransmogDE.LimitTransmogToSameBodyLocation then
          filteredItems:add(item)
        else
          if isSameBodyLocation then
            filteredItems:add(item)
          end
        end
      end
    end
    return filteredItems
  end

  ISItemsListViewer.initList(self);

  -- put the original function back in it's place
  getAllItems = backupGetAllItems;
end

function TransmogListViewer:prerender()
  local z = 20;
  self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
    self.backgroundColor.b);
  self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
    self.borderColor.b);
  local text = getTextOrNull("IGUI_TransmogDE_ListViewer_Standard") or "Transmog List - Standard Mode"
  self:drawText(text, self.width / 2 - (getTextManager():MeasureStringX(UIFont.Medium, text) / 2), z, 1, 1, 1, 1,
    UIFont.Medium);
end

local old_ISItemsListTable_render = ISItemsListTable.render
function ISItemsListTable:render()
    if not self.viewer.isTransmogListViewer then
        old_ISItemsListTable_render(self)
        return
    end
    ISPanel.render(self);
    
    local y = self.datas.y + self.datas.height + UI_BORDER_SPACING + 3
    self:drawText(getText("IGUI_DbViewer_TotalResult") .. self.totalResult, 0, y, 1,1,1,1,UIFont.Small)
    self:drawText(getText("IGUI_TransmogDE_Info"), 0, y + BUTTON_HGT, 1,1,1,1,UIFont.Small)
    self:drawText(getText("IGUI_TransmogDE_Info2"), 0, y + BUTTON_HGT*2, 1,1,1,1,UIFont.Small)

    y = self.filters:getBottom()
    
    self:drawRectBorder(self.datas.x, y, self.datas:getWidth(), BUTTON_HGT, 1, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    self:drawRect(self.datas.x, y, self.datas:getWidth(), BUTTON_HGT, self.listHeaderColor.a, self.listHeaderColor.r, self.listHeaderColor.g, self.listHeaderColor.b);

    local x = 0;
    for i,v in ipairs(self.datas.columns) do
        local size;
        if i == #self.datas.columns then
            size = self.datas.width - x
        else
            size = self.datas.columns[i+1].size - self.datas.columns[i].size
        end
--        print(v.name, x, v.size)
        self:drawText(v.name, x+UI_BORDER_SPACING+1, y+3, 1,1,1,1,UIFont.Small);
        self:drawRectBorder(self.datas.x + x, y, 1, BUTTON_HGT, 1, self.borderColor.r, self.borderColor.g, self.borderColor.b);
        x = x + size;
    end
end

-- Remove a column and its associated filter widgets from the table
-- Returns true if a column was removed
local function _removeColumnByName(self, columnName)
    local scrollBox = self.datas
    local filters = self.filterWidgets
    if not scrollBox or not scrollBox.columns then return false end

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
                --DebugLog.log(DebugType.General, "[TransmogDE] Found Widget for column: " .. tostring(columnName))

                if widget and widget.getParent then
                    local parent = widget:getParent()
                    if parent == self or parent == self.datas then
                        --DebugLog.log(DebugType.General, "[TransmogDE] Removing Widget UI element for: " .. tostring(columnName))
                        parent:removeChild(widget)
                    else
                        --DebugLog.log(DebugType.General, "[TransmogDE] Widget parent is " .. tostring(parent))
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

local old_ISItemsListTable_createChildren = ISItemsListTable.createChildren
function ISItemsListTable:createChildren()
    local result = old_ISItemsListTable_createChildren(self)

    if self.viewer.isTransmogListViewer then
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

        self:removeChild(self.buttonAdd1);
        self:removeChild(self.buttonAdd2);
        self:removeChild(self.buttonAdd5);
        self:removeChild(self.buttonAddMultiple);
        --self:removeChild(self.filters);

        -- keep our double-click behavior
        self.datas:setOnMouseDoubleClick(self, self.sendItemToTransmog);
    end

    return result
end

function ISItemsListTable:sendItemToTransmog(scriptItem)
  local text = getText("IGUI_TransmogDE_Text_TransmoggedTo", getItemNameFromFullType(scriptItem:getFullName()))
  HaloTextHelper.addGoodText(getPlayer(), text)
  TransmogDE.setItemTransmog(self.viewer.itemToTmog, scriptItem)
  TransmogDE.forceUpdateClothing(self.viewer.itemToTmog)
end

local old_ISItemsListTable_drawDatas = ISItemsListTable.drawDatas
function ISItemsListTable:drawDatas(y, item, alt)
    if #self.columns >= 5 then
      return old_ISItemsListTable_drawDatas(self, y, item, alt)
    end
    if y + self:getYScroll() + self.itemheight < 0 or y + self:getYScroll() >= self.height then
        return y + self.itemheight
    end
    
    local a = 0.9;

    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15);
    end

    if alt then
        self:drawRect(0, (y), self:getWidth(), self.itemheight, 0.3, 0.6, 0.5, 0.5);
    end

    self:drawRectBorder(0, (y), self:getWidth(), self.itemheight, a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

    local iconX = 4
    local iconSize = FONT_HGT_SMALL;
    local xoffset = UI_BORDER_SPACING;

    local clipX = self.columns[1].size
    local clipX2 = self.columns[2].size
    local clipY = math.max(0, y + self:getYScroll())
    local clipY2 = math.min(self.height, y + self:getYScroll() + self.itemheight)
    
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getName(), xoffset, y + 3, 1, 1, 1, a, self.font);
    self:clearStencilRect()

    clipX = self.columns[2].size
    clipX2 = self.columns[3].size
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getDisplayName(), self.columns[2].size + iconX + iconSize + 4, y + 3, 1, 1, 1, a, self.font);
    self:clearStencilRect()

    clipX = self.columns[3].size
    clipX2 = self.columns[4].size
    self:setStencilRect(clipX, clipY, clipX2 - clipX, clipY2 - clipY)
    self:drawText(item.item:getTypeString(), self.columns[3].size + xoffset, y + 3, 1, 1, 1, a, self.font);
    self:clearStencilRect()

    if item.item:getDisplayCategory() ~= nil then
        self:drawText(getText("IGUI_ItemCat_" .. item.item:getDisplayCategory()), self.columns[4].size + xoffset, y + 4, 1, 1, 1, a, self.font);
        else
        self:drawText("Error: No category set", self.columns[4].size + xoffset, y + 3, 1, 1, 1, a, self.font);
    end

    self:repaintStencilRect(0, clipY, self.width, clipY2 - clipY)

    local icon = item.item:getIcon()
    if item.item:getIconsForTexture() and not item.item:getIconsForTexture():isEmpty() then
        icon = item.item:getIconsForTexture():get(0)
    end
    if icon then
        local texture = tryGetTexture("Item_" .. icon)
        if texture then
            self:drawTextureScaledAspect2(texture, self.columns[2].size + iconX, y + (self.itemheight - iconSize) / 2, iconSize, iconSize,  1, 1, 1, 1);
        end
    end
    
    return y + self.itemheight
end

local old_ISItemsListTable_initList = ISItemsListTable.initList
function ISItemsListTable:initList(module)
    if self.filterWidgetMap.LootCategory ~= nil then
        DebugLog.log(DebugType.General, "[TransmogDE] Default Init List")
        return old_ISItemsListTable_initList(self, module)
    end
    DebugLog.log(DebugType.General, "[TransmogDE] Transmog Init List")
    self.totalResult = 0;
    local categoryNames = {}
    local displayCategoryNames = {}
    local lootCategoryNames = {}
    local categoryMap = {}
    local displayCategoryMap = {}
    local lootCategoryMap = {}
    local spawnNumMap = {}
    for x,v in ipairs(module) do
        self.datas:addItem(v:getDisplayName(), v);
        if not categoryMap[v:getTypeString()] then
            categoryMap[v:getTypeString()] = true
            table.insert(categoryNames, v:getTypeString())
        end
        if not displayCategoryMap[v:getDisplayCategory()] then
            displayCategoryMap[v:getDisplayCategory()] = true
            table.insert(displayCategoryNames, v:getDisplayCategory())
        end
        if not lootCategoryMap[getText("Sandbox_" .. v:getLootType().. "LootNew")] then
            lootCategoryMap[getText("Sandbox_" .. v:getLootType() .. "LootNew")] = true
            table.insert(lootCategoryNames, getText("Sandbox_" .. v:getLootType() .. "LootNew"))
        end
        self.totalResult = self.totalResult + 1;
    end
    table.sort(self.datas.items, function(a,b) return not string.sort(a.item:getDisplayName(), b.item:getDisplayName()); end);

    local combo = self.filterWidgetMap.Category
    table.sort(categoryNames, function(a,b) return not string.sort(a, b) end)
    combo:addOption("<Any>")
    for _,categoryName in ipairs(categoryNames) do
        combo:addOption(categoryName)
    end

    local combo = self.filterWidgetMap.DisplayCategory
    table.sort(displayCategoryNames, function(a,b) return not string.sort(a, b) end)
    combo:addOption("<Any>")
    combo:addOption("<No category set>")
    for _,displayCategoryName in ipairs(displayCategoryNames) do
        combo:addOption(displayCategoryName)
    end
end
