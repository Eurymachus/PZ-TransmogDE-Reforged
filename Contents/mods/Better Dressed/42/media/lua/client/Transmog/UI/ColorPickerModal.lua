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
	local immutableColor = ImmutableColor.new(Color.new(color.r, color.g, color.b, 1))
	TransmogDE.setClothingColorModdata(self.item, immutableColor)
	TransmogDE.forceUpdateClothing(self.item)
end

function ColorPickerModal:close()
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

function ColorPickerModal.Open(clothing, player)
	if ColorPickerModal.instance then
		ColorPickerModal.instance:close()
	end
	local modal = ColorPickerModal:new(clothing, player)
	modal:initialise()
	modal:addToUIManager()
	modal:restoreWindowState()
end

function ColorPickerModal.Close()
	if ColorPickerModal.instance then
		ColorPickerModal.instance:close()
	end
end

function ColorPickerModal.updateItemToColor(player, clothing)
	local isOpen = ColorPickerModal.instance and ColorPickerModal.instance:getIsVisible()
	local isTransmogOpen = TransmogListViewer.instance and TransmogListViewer.instance:getIsVisible()
	if isOpen or isTransmogOpen then
		local transmogTo = TransmogDE.getItemTransmogModData(clothing).transmogTo
		if transmogTo then
			local tmogScriptItem = ScriptManager.instance:getItem(transmogTo)
			if tmogScriptItem then
				local tmogClothingItemAsset = TransmogDE.getClothingItemAsset(tmogScriptItem)
				if tmogClothingItemAsset:getAllowRandomTint() then
					ColorPickerModal.Open(clothing, player)
				else
					ColorPickerModal.Close()
				end
			end
		end
	end
end

Events.TransmogClothingUpdate.Add(ColorPickerModal.updateItemToColor);

function ColorPickerModal:new(item, character)
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
