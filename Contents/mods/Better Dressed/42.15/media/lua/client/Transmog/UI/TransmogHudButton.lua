require "ISUI/ISButton"

TransmogHudButton = ISButton:derive("TransmogHudButton")
TransmogHudButton.instances = TransmogHudButton.instances or {}

local GAP_Y = 15

function TransmogHudButton:onClick()
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

function TransmogHudButton:getEquippedPanel()
    local pdata = getPlayerData(self.playerNum)
    return pdata and pdata.equipped or nil
end

local SCALE = 1 -- try 1.15–1.35 range

function TransmogHudButton:getSizeFromEquipped(eq)
    local w, h

    if eq and eq.searchBtn then
        w = eq.searchBtn:getWidth()
        h = eq.searchBtn:getHeight()
    elseif eq and eq.healthBtn then
        w = eq.healthBtn:getWidth()
        h = eq.healthBtn:getHeight()
    else
        w, h = 32, 32
    end

    return math.floor(w * SCALE), math.floor(h * SCALE)
end

function TransmogHudButton:getAnchorControl(eq)
    if not eq then return nil end

    local candidates = {
        eq.warManagerBtn,
        eq.adminBtn,
        eq.clientBtn,
        eq.safetyBtn,
        eq.debugBtn,
        eq.mapBtn,
        eq.zoneBtn,
        eq.searchBtn,
        eq.movableBtn,
        eq.buildBtn,
        eq.craftingBtn,
        eq.healthBtn,
        eq.invBtn,
        eq.offHand,
    }

    for i = 1, #candidates do
        local c = candidates[i]
        if c and c.getIsVisible and c:getIsVisible() then
            return c
        end
    end

    return eq.offHand or eq.mainHand
end

function TransmogHudButton:getLocalAnchorPosition(eq)
    local anchor = self:getAnchorControl(eq)
    if not anchor then
        return 0, 0
    end

    local x = anchor:getX()
    local y = anchor:getBottom() + GAP_Y
    return x, y
end

function TransmogHudButton:reposition()
    local eq = self:getEquippedPanel()
    if not eq then return end

    local x, y = self:getLocalAnchorPosition(eq)
    local w, h = self:getSizeFromEquipped(eq)

    self:setX(x)
    self:setY(y)
    self:setWidth(w)
    self:setHeight(h)

    local requiredHeight = y + h
    if eq:getHeight() < requiredHeight then
        eq:setHeight(requiredHeight)
    end
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

function TransmogHudButton:createForPlayer(playerNum)
    if playerNum == nil then return nil end

    local player = getSpecificPlayer(playerNum)
    if not player then return nil end

    local pdata = getPlayerData(playerNum)
    local eq = pdata and pdata.equipped or nil
    if not eq then return nil end

    local existing = self.instances[playerNum]
    if existing then
        if existing:getParent() ~= eq then
            local parent = existing:getParent()
            if parent and parent.removeChild then
                parent:removeChild(existing)
            else
                existing:removeFromUIManager()
            end
            self.instances[playerNum] = nil
        else
            existing:reposition()
            return existing
        end
    end

    local w, h = self:getSizeFromEquipped(eq)
    local x, y = 0, 0

    local btn = ISButton:new(x, y, w, h, "", nil, nil)
    setmetatable(btn, self)
    self.__index = self

    btn.playerNum = playerNum
    btn.target = btn
    btn.onclick = TransmogHudButton.onClick

    btn:initialise()
    btn:instantiate()

    eq:addChild(btn)

    btn:clearMaxDrawHeight()

    btn.borderColor = { r = 1, g = 1, b = 1, a = 0 }
    btn.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorMouseOver = { r = 0, g = 0, b = 0, a = 0 }
    btn.backgroundColorPressed = { r = 0, g = 0, b = 0, a = 0 }

    btn.iconTex = getTexture("media/ui/TransmogIcon.png")
    btn.tooltip = getTextOrNull("") or "Transmoggable Worn Items"

    btn:reposition()

    self.instances[playerNum] = btn
    return btn
end

function TransmogHudButton:removeForPlayer(playerNum)
    local btn = self.instances[playerNum]
    if not btn then return end

    local parent = btn:getParent()
    if parent and parent.removeChild then
        parent:removeChild(btn)
    else
        btn:removeFromUIManager()
    end

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