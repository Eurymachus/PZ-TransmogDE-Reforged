require "ISUI/ISButton"

local Prefs = require("Transmog/Prefs")

TransmogHudButton = ISButton:derive("TransmogHudButton")
TransmogHudButton.instances = TransmogHudButton.instances or {}

local BUTTON_SIZE = 42
local DEFAULT_MARGIN_X = 80
local DEFAULT_MARGIN_Y = 220
local DRAG_THRESHOLD = 4

local function getPlayerKey(playerNum)
    return "TransmogHudButton." .. tostring(playerNum or 0) .. "."
end

local function isWorldMapVisible()
    return ISWorldMap_instance and ISWorldMap_instance:isVisible()
end

local function isAnnotatedMapVisible()
    if not UIManager or not UIManager.getUI then return false end

    local uis = UIManager.getUI()
    if not uis then return false end

    for i = 0, uis:size() - 1 do
        local ui = uis:get(i)
        if ui
            and ui.Type == "ISMapWrapper"
            and ui.mapUI
            and ui:isVisible()
        then
            return true
        end
    end

    return false
end

function TransmogHudButton:syncVisibility()
    local mapVisible = isWorldMapVisible() == true or isAnnotatedMapVisible() == true
    if self._hiddenForWorldMap == mapVisible then return end

    self._hiddenForWorldMap = mapVisible
    self:setVisible(not mapVisible)

    if not mapVisible then
        self:setAlwaysOnTop(true)
        self:bringToTop()
    end
end

function TransmogHudButton:onClick()
    if self.suppressClick then
        self.suppressClick = false
        return
    end

    local player = getSpecificPlayer(self.playerNum)
    if not player then return end

    if self.modalIsOpen then
        local modal = TransmogWornItems.instance
        if modal then
            modal:close()
            return
        end
    end
    TransmogWornItems.Open(player)
end

function TransmogHudButton:getDefaultPosition()
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    return sw - self:getWidth() - DEFAULT_MARGIN_X, sh - self:getHeight() - DEFAULT_MARGIN_Y
end

function TransmogHudButton:restorePosition()
    local key = getPlayerKey(self.playerNum)
    local x = tonumber(Prefs.get(key .. "x", nil))
    local y = tonumber(Prefs.get(key .. "y", nil))

    if not x or not y then
        x, y = self:getDefaultPosition()
    end

    x, y = Prefs.clampToScreen(x, y, self:getWidth(), self:getHeight())
    self:setX(x)
    self:setY(y)
end

function TransmogHudButton:savePosition()
    local key = getPlayerKey(self.playerNum)
    Prefs.set(key .. "x", math.floor(self:getX()))
    Prefs.set(key .. "y", math.floor(self:getY()))
end

function TransmogHudButton:reposition()
    local x, y = Prefs.clampToScreen(self:getX(), self:getY(), self:getWidth(), self:getHeight())
    self:setX(x)
    self:setY(y)
end

function TransmogHudButton:render()
    ISButton.render(self)

    if not self.iconTex then return end

    local pad = 0
    local x = pad
    local y = pad
    local w = self:getWidth() - (pad * 2)
    local h = self:getHeight() - (pad * 2)

    local modal = TransmogWornItems.instance
    self.modalIsOpen = modal and modal:isVisible() or false

    if self.mouseOver or self.modalIsOpen then
        self:drawTextureScaledAspect(self.iconTex, x, y, w, h, 1, 1, 1, 1)
    else
        self:drawTextureScaledAspect(self.iconTex, x, y, w, h, 0.8, 0.8, 0.8, 1)
    end
end

function TransmogHudButton:onMouseDown(x, y)
    ISButton.onMouseDown(self, x, y)

    self.dragging = true
    self.wasDragged = false
    self.suppressClick = false
    self.dragStartMouseX = getMouseX()
    self.dragStartMouseY = getMouseY()
    self.dragStartX = self:getX()
    self.dragStartY = self:getY()
end

function TransmogHudButton:onMouseMove(dx, dy)
    ISButton.onMouseMove(self, dx, dy)

    if not self.dragging then return end

    local mouseX = getMouseX()
    local mouseY = getMouseY()
    local deltaX = mouseX - self.dragStartMouseX
    local deltaY = mouseY - self.dragStartMouseY

    if not self.wasDragged and (math.abs(deltaX) >= DRAG_THRESHOLD or math.abs(deltaY) >= DRAG_THRESHOLD) then
        self.wasDragged = true
    end

    if self.wasDragged then
        local x, y = Prefs.clampToScreen(
            self.dragStartX + deltaX,
            self.dragStartY + deltaY,
            self:getWidth(),
            self:getHeight()
        )
        self:setX(x)
        self:setY(y)
    end
end

function TransmogHudButton:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function TransmogHudButton:onMouseUp(x, y)
    local wasDragged = self.wasDragged == true

    self.dragging = false
    self.wasDragged = false
    self.dragStartMouseX = nil
    self.dragStartMouseY = nil
    self.dragStartX = nil
    self.dragStartY = nil

    if wasDragged then
        self.suppressClick = true
        self:savePosition()
    end

    ISButton.onMouseUp(self, x, y)
end

function TransmogHudButton:onMouseUpOutside(x, y)
    local wasDragged = self.wasDragged == true

    self.dragging = false
    self.wasDragged = false
    self.dragStartMouseX = nil
    self.dragStartMouseY = nil
    self.dragStartX = nil
    self.dragStartY = nil

    if wasDragged then
        self:savePosition()
    end

    if ISButton.onMouseUpOutside then
        ISButton.onMouseUpOutside(self, x, y)
    end
end

function TransmogHudButton:createForPlayer(playerNum)
    if playerNum == nil then return nil end

    local player = getSpecificPlayer(playerNum)
    if not player then return nil end

    local existing = self.instances[playerNum]
    if existing then
        existing:setAlwaysOnTop(true)
        existing:bringToTop()
        existing:syncVisibility()
        existing:reposition()
        return existing
    end

    local btn = ISButton:new(0, 0, BUTTON_SIZE, BUTTON_SIZE, "", nil, nil)
    setmetatable(btn, self)
    self.__index = self

    btn.playerNum = playerNum
    btn.target = btn
    btn.onclick = TransmogHudButton.onClick

    btn:initialise()
    btn:instantiate()
    btn:setAlwaysOnTop(true)
    btn:addToUIManager()
    btn:bringToTop()
    btn:clearMaxDrawHeight()

    btn.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    btn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorPressed = { r = 0, g = 0, b = 0, a = 0 }

    btn.iconTex = getTexture("media/ui/TransmogIcon.png")
    btn.tooltip = getTextOrNull("IGUI_TransmogDE_WornItems_title") or "Transmoggable Worn Items"

    btn:restorePosition()
    btn:syncVisibility()

    self.instances[playerNum] = btn
    return btn
end

function TransmogHudButton:removeForPlayer(playerNum)
    local btn = self.instances[playerNum]
    if not btn then return end

    btn:removeFromUIManager()
    self.instances[playerNum] = nil
end

function TransmogHudButton:createForAllPlayers()
    for playerNum = 0, 3 do
        if getSpecificPlayer(playerNum) then
            self:createForPlayer(playerNum)
        end
    end
end

function TransmogHudButton:repositionAll()
    for playerNum, btn in pairs(self.instances) do
        if btn and getSpecificPlayer(playerNum) then
            btn:reposition()
        end
    end
end

function TransmogHudButton:syncAllVisibility()
    for playerNum, btn in pairs(self.instances) do
        if btn and getSpecificPlayer(playerNum) then
            btn:syncVisibility()
        end
    end
end

local function createTransmogHudButtons()
    TransmogHudButton:createForAllPlayers()
end

Events.OnCreatePlayer.Add(function(playerNum, player)
    if player then
        TransmogHudButton:createForPlayer(playerNum)
    end
end)

Events.OnGameStart.Add(createTransmogHudButtons)

Events.OnResolutionChange.Add(function()
    TransmogHudButton:repositionAll()
end)

Events.OnTick.Add(function()
    TransmogHudButton:syncAllVisibility()
end)
