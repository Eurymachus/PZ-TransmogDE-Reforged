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

-- Return the *visual* BodyLocation for a given worn item.
-- This respects TransmogDE state:
--   * if the item is transmogged, we return the BodyLocation of the transmog target
--   * otherwise we return the item's own BodyLocation.
local function getItemVisualBodyLocation(item)
    if not item then
        return nil
    end

    local scriptItem = item:getScriptItem()
    if not scriptItem then
        return nil
    end

    -- Default: use the item's own body location.
    local bodyLoc = scriptItem:getBodyLocation() or item:getBodyLocation()

    -- If the item is transmogged, prefer the BodyLocation of the transmog target.
    if TransmogDE and TransmogDE.getItemTransmogModData and TransmogDE.isTransmoggable
        and TransmogDE.isTransmoggable(item) then

        local tmogData = TransmogDE.getItemTransmogModData(item)
        if tmogData and tmogData.transmogTo then
            local sm = getScriptManager()
            if sm then
                local targetScriptItem = sm:FindItem(tmogData.transmogTo)
                if targetScriptItem then
                    bodyLoc = targetScriptItem:getBodyLocation() or bodyLoc
                end
            end
        end
    end

    return bodyLoc
end
local function wearTransmogItems(player)
    local wornItems = player:getWornItems()
    local playerInv = player:getInventory()

    local toWear = {}
    local toRemove = {}

    -- //////////////////////////////////////////////////////////////
    -- Step 1: Build a set of visual BodyLocations that should be
    --         considered hidden for this outfit, based on our
    --         TransmogDE.VisualMaskRules.
    -- //////////////////////////////////////////////////////////////
    local hiddenVisualSlots = {}

    if TransmogDE and TransmogDE.getHiddenVisualSlotsForCovering then
        for i = 0, wornItems:size() - 1 do
            local item = wornItems:getItemByIndex(i)

            -- Ignore nils, the Hide_Everything helper, and transmog carriers.
            if item
                and not item:hasTag("Hide_Everything")
                and (not TransmogDE.isTransmogItem or not TransmogDE.isTransmogItem(item)) then

                -- If this clothing is explicitly hidden by TransmogDE, it should
                -- not act as a visual "covering" layer.
                if not TransmogDE.isClothingHidden or not TransmogDE.isClothingHidden(item) then
                    local visualLoc = getItemVisualBodyLocation(item)
                    if visualLoc then
                        local hiddenForThis = TransmogDE.getHiddenVisualSlotsForCovering(visualLoc)
                        if hiddenForThis then
                            for slot, _ in pairs(hiddenForThis) do
                                hiddenVisualSlots[slot] = true
                            end
                        end
                    end
                end
            end
        end
    end

    -- //////////////////////////////////////////////////////////////
    -- Step 2: Maintain carriers (create/remove) while respecting
    --         the hiddenVisualSlots set built above.
    -- //////////////////////////////////////////////////////////////
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        -- TmogPrint("Worn item: " .. tostring(item:getScriptItem():getFullName()))
        if item and TransmogDE.isTransmoggable and TransmogDE.isTransmoggable(item)
            and not TransmogDE.getTransmogChild(item) then

            -- If this item's *visual* slot is masked by the current outfit,
            -- skip creating/wearing a carrier for it.
            local visualLoc = getItemVisualBodyLocation(item)
            if not (visualLoc and hiddenVisualSlots[visualLoc]) then
                -- check if it has an existing tmogitem
                -- if not create a new tmog item, and bind it using the parent item id
                local tmogItem = TransmogDE.createTransmogItem(item, player)
                if tmogItem then
                    table.insert(toWear, tmogItem)
                end
            end
        end

        if item and TransmogDE.isTransmogItem and TransmogDE.isTransmogItem(item)
            and not item:hasTag("Hide_Everything") then
            -- check if it still has a worn parent
            local tmogParentId = item:getModData()['TransmogParent']
            local parentItem = tmogParentId and playerInv:getItemById(tmogParentId)
            -- use isEquipped, isWorn is only for clothing, does not include backpacks
            if not tmogParentId or not parentItem or not parentItem:isEquipped() then
                -- parent either does not exist anymore, or it's unequipped, or it was never set
                -- in these cases, mark item to remove
                table.insert(toRemove, item)
            else
                TransmogDE.syncConditionVisualsForTmog(item)
            end
        end
    end

    for _, tmogItem in ipairs(toWear) do
        TransmogDE.setWornItemTmog(player, tmogItem)
        TransmogDE.syncConditionVisualsForTmog(tmogItem)
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
    TransmogDE.triggerUpdate(player)

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
