local function wearHideEverything(player)
    local playerInv = player:getInventory()

    local hideItem = playerInv:FindAndReturn("TransmogDE.Hide_Everything");
    if not hideItem then
        -- TmogPrint('Hide_Everything is missing, lets add it')
        hideItem = player:getInventory():AddItem('TransmogDE.Hide_Everything');
    end
    if not hideItem:isWorn() then
        -- TmogPrint('Hide_Everything is not equipped, lets wear it')
        player:setWornItem(hideItem:getBodyLocation(), hideItem)
        hideItem:setFavorite(true)
    end
    TmogPrint('wearHideEverything - Done')
end

local function wearTransmogItems(player)
    local wornItems = player:getWornItems()
    local playerInv = player:getInventory()

    local toWear = {}
    local toRemove = {}
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        -- TmogPrint("Worn item: " .. tostring(item:getScriptItem():getFullName()))
        if item and TransmogDE.isTransmoggable(item) and not TransmogDE.getTransmogChild(item) then
            -- check if it has an existing tmogitem
            -- if not create a new tmog item, and bind it using the parent item id
            local tmogItem = TransmogDE.createTransmogItem(item, player)
            table.insert(toWear, tmogItem)
        end
        if item and TransmogDE.isTransmogItem(item) and not item:hasTag("Hide_Everything") then
            -- check if it still has a worn parent
            local tmogParentId = item:getModData()['TransmogParent']
            local parentItem = tmogParentId and playerInv:getItemById(tmogParentId)
            -- use isEquipped, isWorn is only for clothing, does not include backpacks
            if not tmogParentId or not parentItem or not parentItem:isEquipped() then
                -- parent either does not exist anymore, or it's unequipped, or it was never set
                -- in in these cases, mark item to remove
                table.insert(toRemove, item)
            end
        end
    end

    for _, tmogItem in ipairs(toWear) do
        TransmogDE.setWornItemTmog(player, tmogItem)
    end

    for _, tmogItem in ipairs(toRemove) do
        wornItems:remove(tmogItem);
        playerInv:Remove(tmogItem);
    end

    player:resetModelNextFrame();

    if isClient() then
        sendClothing(player)
    end
    TmogPrint('wearTransmogItems, to wear:', #toWear, ' to remove:', #toRemove)
end

local function syncAllVisuals(player)
    local player = player or getPlayer() or getSpecificPlayer(0)
    if not player then return end
    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        -- TmogPrint("Worn item: " .. tostring(item:getScriptItem():getFullName()))
        if item and TransmogDE.isTransmogItem(item) then
            TransmogDE.syncConditionVisualsForTmog(item)
        end
    end
end

local function applyTransmogToPlayerItems(player)
    local player = player or getPlayer() -- getSpecificPlayer(playerNum);
    wearHideEverything(player);
    wearTransmogItems(player)
end

LuaEventManager.AddEvent("ApplyTransmogToPlayerItems");
LuaEventManager.AddEvent("SyncConditionVisuals");

Events.ApplyTransmogToPlayerItems.Add(applyTransmogToPlayerItems);
Events.SyncConditionVisuals.Add(syncAllVisuals);

local function onClothingUpdated(player)
    TmogPrint("onClothingUpdated Fired")
    TransmogDE.triggerUpdate()

    if TransmogListViewer.instance then
        TransmogListViewer.instance:initialise()
    end
end

Events.OnClothingUpdated.Add(onClothingUpdated)


Events.OnGameStart.Add(function()
    local player = getPlayer() or getSpecificPlayer(0) or nil
    if player then
        syncAllVisuals(player)
    end
end)

-- cache original function once
if not TransmogDE._orig_ISWearClothing_complete then
    TransmogDE._orig_ISWearClothing_complete = ISWearClothing.complete
end

function ISWearClothing:complete()
    -- run the original behavior first
    local result = TransmogDE._orig_ISWearClothing_complete(self)

    -- After vanilla equips the item, defer our sync one tick.
    if self.character then
        triggerEvent("OnClothingUpdated", self.character)
    end

    return result
end
