require "ISUI/ISCollapsableWindowJoypad"
local Prefs     = require("Transmog/Prefs")

ColorPickerModal = ISCollapsableWindowJoypad:derive("ColorPickerModal")

function ColorPickerModal:createChildren()
	ISCollapsableWindowJoypad.createChildren(self)

	local titleBarHeight = self:titleBarHeight()

	local paddingUnit = 16                   -- eg: only left, or only right, or only top etc etc
	local paddingUnitDouble = paddingUnit * 2 -- eg: left and right or top and bottom

	self.colorPickerX = 16
	self.colorPickerY = titleBarHeight + self.colorPickerX
	self.colorPicker = ISColorPicker:new(self.colorPickerX, self.colorPickerY)
	self.colorPicker:initialise()
	self.colorPicker.pickedTarget = self;
	self.colorPicker.resetFocusTo = self;
	self.colorPicker.keepOnScreen = true
	-- Disable removeSelf for this component, otherwise it auto closes on click
	self.colorPicker.removeSelf = function() end
	self.colorPicker.pickedFunc = self.onColorSelected

	self:setWidth(paddingUnitDouble + self.colorPicker:getWidth())
	self:setHeight(self:titleBarHeight() + self.colorPicker:getHeight() + paddingUnitDouble)

	self:addChild(self.colorPicker)
end

function ColorPickerModal:onColorSelected(color)
	TransmogNet.requestSetColor(self.character, self.item, color)
end

function ColorPickerModal:close()
	-- Clear singleton so later clothing updates can't "revive" this UI
	if ColorPickerModal.instance == self then
		ColorPickerModal.instance = nil
	end

	self:removeFromUIManager()
	if JoypadState.players[self.playerNum + 1] then
		setJoypadFocus(self.playerNum, self.prevFocus)
	end
end

-- Restore position + pin state + visibility (from INI)
function ColorPickerModal:restoreWindowState()
    Prefs.restoreWindowStateOrCenter(self)
end

function ColorPickerModal:saveWindowState()
    if Prefs then
        Prefs.saveWindowState(self)
    end
end

function ColorPickerModal:onMouseUp(x, y)
    local moving   = self.moving   == true
    local resizing = self.resizing == true
    ISCollapsableWindowJoypad.onMouseUp(self, x, y)
    if moving or resizing then self:saveWindowState() end
end

function ColorPickerModal:onMouseUpOutside(x, y)
    local moving   = self.moving   == true
    local resizing = self.resizing == true
    ISCollapsableWindowJoypad.onMouseUpOutside(self, x, y)
    if moving or resizing then self:saveWindowState() end
end

function ColorPickerModal:setInitialFromItem()
	local color = TransmogDE.getClothingColorAsInfo(self.item)
	if not color then return end
	self.colorPicker:setInitialColor(color)
end

function ColorPickerModal:updateTmogItemToColor(clothing)
	self.item = clothing
	self:setInitialFromItem()
end

function ColorPickerModal.Open(player, clothing)
	if ColorPickerModal.instance then
		ColorPickerModal.instance:close()
	end
	local modal = ColorPickerModal:new(player, clothing)
	modal:initialise()
	modal:addToUIManager()
	modal:restoreWindowState()
	modal:setInitialFromItem()
end

function ColorPickerModal.Close()
	if ColorPickerModal.instance then
		ColorPickerModal.instance:close()
	end
end

function ColorPickerModal.updateItemToColor(player, clothing)
	local modal = ColorPickerModal.instance
	local isOpen = modal and modal:getIsVisible()
	local isTransmogOpen = TransmogListViewer.instance and TransmogListViewer.instance:getIsVisible()
	if isOpen or isTransmogOpen then
		local transmogTo = TransmogDE.getItemTransmogModData(clothing).transmogTo
		if transmogTo then
			local tmogScriptItem = ScriptManager.instance:getItem(transmogTo)
			if tmogScriptItem then
				local tmogClothingItemAsset = TransmogDE.getClothingItemAsset(tmogScriptItem)
				if tmogClothingItemAsset:getAllowRandomTint() then
					if isOpen then
						modal:updateTmogItemToColor(clothing)
					else
						ColorPickerModal.Open(player, clothing)
					end
				else
					ColorPickerModal.Close()
				end
			end
		end
	end
end

Events.TransmogClothingUpdate.Add(ColorPickerModal.updateItemToColor);

function ColorPickerModal:new(character, item)
	local width = 550
	local height = 200
	local x = getCore():getScreenWidth() / 2 - (width / 2);
	local y = getCore():getScreenHeight() / 2 - (height / 2);
	local playerNum = character:getPlayerNum()
	local o = ISCollapsableWindowJoypad.new(self, x, y, width, height)
	o.character = character
	o.item = item
	o.title = "Set color of: " .. item:getName();
	o.desc = character:getDescriptor();
	o.playerNum = playerNum
	o:setResizable(false)
	ColorPickerModal.instance = o
	return o
end
