require "ISUI/ISCollapsableWindowJoypad"
local Prefs     = require("Transmog/Prefs")

TexturePickerModal = ISCollapsableWindowJoypad:derive("TexturePickerModal")

function TexturePickerModal:createChildren()
    ISCollapsableWindowJoypad.createChildren(self)

    local titleBarHeight = self:titleBarHeight()

    local textureChoicesSize = self.textureChoices:size()
    local numColumns = 4
    local minNumRows = 4
    local numRows = math.ceil(textureChoicesSize / numColumns)

    local btnX = 0
    local btnH = 125

    local scrollPanelHeight = (minNumRows * btnH) + titleBarHeight
    local scrollPanelWidth = (numColumns * btnH) + 13

    self.scrollView = TmogScrollView:new(btnX, titleBarHeight, scrollPanelWidth, scrollPanelHeight)
    self.scrollView:initialise()
    self:addChild(self.scrollView)

    for row = 0, numRows - 1 do
        local rowElements = {}
        for col = 0, numColumns - 1 do
            local index = row * numColumns + col
            if index < textureChoicesSize then
                table.insert(rowElements, self.textureChoices:get(index))
                local textureChoice = getTexture('media/textures/' .. self.textureChoices:get(index) .. '.png')
                local button = ISButton:new(1 + btnX + (col * btnH), (row * btnH), btnH, btnH, "", self,
                    TexturePickerModal.onTextureSelected)
                button.internal = index
                button:setImage(textureChoice)
                button:forceImageSize(btnH - 2, btnH - 2)
                button:setBorderRGBA(1, 1, 1, 0.6)
                self.scrollView:addScrollChild(button)
            else
                break
            end
        end
        -- print(table.concat(rowElements, "\t"))
    end

    self.scrollView:setScrollHeight(numRows * btnH)
    self:setWidth(scrollPanelWidth)
    self:setHeight(scrollPanelHeight + 16)
end

function TexturePickerModal:onTextureSelected(button)
    TransmogNet.requestSetTexture(self.character, self.item, button.internal)
end

function TexturePickerModal:close()
    -- Clear singleton so later clothing updates can't "revive" this UI
    if TexturePickerModal.instance == self then
        TexturePickerModal.instance = nil
    end

    self:removeFromUIManager()
    if JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, self.prevFocus)
    end
end

-- Restore position + pin state + visibility (from INI)
function TexturePickerModal:restoreWindowState()
    Prefs.restoreWindowStateOrCenter(self)
end

function TexturePickerModal:saveWindowState()
    if Prefs then
        Prefs.saveWindowState(self)
    end
end

function TexturePickerModal:onMouseUp(x, y)
    local moving   = self.moving   == true
    local resizing = self.resizing == true
    ISCollapsableWindowJoypad.onMouseUp(self, x, y)
    if moving or resizing then self:saveWindowState() end
end

function TexturePickerModal:onMouseUpOutside(x, y)
    local moving   = self.moving   == true
    local resizing = self.resizing == true
    ISCollapsableWindowJoypad.onMouseUpOutside(self, x, y)
    if moving or resizing then self:saveWindowState() end
end

function TexturePickerModal.Open(player, clothing, textureChoices)
    local viewer = TransmogListViewer.instance
    if viewer and viewer.getIsVisible and viewer:getIsVisible() and viewer.item ~= clothing then
        TransmogListViewer.Open(player, clothing)
        return
    end

    if TexturePickerModal.instance then
        TexturePickerModal.instance:close()
    end

    if textureChoices and (textureChoices:size() > 1) then
        local modal = TexturePickerModal:new(player, clothing, textureChoices)
        modal:initialise()
        modal:addToUIManager()
        modal:restoreWindowState()
    end
end

function TexturePickerModal.Close()
    if TexturePickerModal.instance then
        TexturePickerModal.instance:close()
    end
end

function TexturePickerModal:updateTmogItemToTexture(clothing, textureChoices)
    if self.item ~= clothing then
        self.item = clothing
        self.title = "Set texture of: " .. clothing:getDisplayName()
    end
    if self.textureChoices ~= textureChoices then
        self.textureChoices = textureChoices

        if self.scrollView then
            self:removeChild(self.scrollView)
            self.scrollView = nil
        end

        self:createChildren()
    end
end

function TexturePickerModal.updateItemToTexture(player, clothing)
    local modal = TexturePickerModal.instance
    local tmogModal = TransmogListViewer.instance
    local isOpen = modal and modal:getIsVisible()
    local isTransmogOpen = tmogModal and tmogModal:getIsVisible()

    if clothing == nil then
        clothing = (isOpen and modal.item) or (isTransmogOpen and tmogModal.item) or nil
    end

    if not clothing then
        return
    end

    if isOpen or isTransmogOpen then
        local textureChoiceList = nil
        local md = TransmogDE.getItemTransmogModData(clothing)
        local transmogTo = md and md.transmogTo or nil

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

        if textureChoiceList and (textureChoiceList:size() > 1) then
            if isOpen then
                modal:updateTmogItemToTexture(clothing, textureChoiceList)
            else
                TexturePickerModal.Open(player, clothing, textureChoiceList)
            end
        else
            TexturePickerModal.Close()
        end
    end
end

function TexturePickerModal:new(character, item, textureChoices)
    local width = 260
    local height = 180
    local x = getCore():getScreenWidth() / 2 - (width / 2);
    local y = getCore():getScreenHeight() / 2 - (height / 2);
    local playerNum = character:getPlayerNum()
    local o = ISCollapsableWindowJoypad.new(self, x, y, width, height)
    o.character = character
    o.item = item
    o.textureChoices = textureChoices
    o.title = "Set texture of: " .. item:getDisplayName()
    o.desc = character:getDescriptor()
    o.playerNum = playerNum
    o:setResizable(false)
    TexturePickerModal.instance = o
    return o
end
