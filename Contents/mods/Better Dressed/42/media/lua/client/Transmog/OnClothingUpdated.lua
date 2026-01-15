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
                    local hiddenForThis = TransmogDE.getHiddenVisualSlotsForCovering(item)
                    if hiddenForThis then
                        for slot, _ in pairs(hiddenForThis) do
                            hiddenVisualSlots[slot] = true
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
        local item = wornItems:getItemByIndex(i)

        ----------------------------------------------------------------
        -- 1) REAL ITEMS: create carriers if transmoggable & not masked
        ----------------------------------------------------------------
        if item and TransmogDE.isTransmoggable and TransmogDE.isTransmoggable(item)
            and not TransmogDE.getTransmogChild(item) then

            -- Determine the *visual* slot this REAL item represents.
            local visualLoc = TransmogDE.getItemVisualBodyLocation(item)
            local isMasked = visualLoc and hiddenVisualSlots[visualLoc] or false

            TmogPrint(tostring(item) .. " (real) isMasked = " .. tostring(isMasked)
                .. " | visualLoc=" .. tostring(visualLoc))

            if not isMasked then
                -- No existing child and not masked → create carrier.
                local tmogItem = TransmogDE.createTransmogItem(item, player)
                if tmogItem then
                    table.insert(toWear, tmogItem)
                end
            end
        end

        ----------------------------------------------------------------
        -- 2) CARRIERS: remove if masked OR parent missing/unequipped
        ----------------------------------------------------------------
        if item and TransmogDE.isTransmogItem and TransmogDE.isTransmogItem(item)
            and not item:hasTag("Hide_Everything") then

            local tmogParentId = item:getModData()['TransmogParent']
            local parentItem = tmogParentId and playerInv:getItemById(tmogParentId)

            -- If parent is missing or not equipped, we don't care about masking;
            -- the carrier is stale and should go.
            if not tmogParentId or not parentItem or not parentItem:isEquipped() then
                table.insert(toRemove, item)
            else
                -- Determine the *visual* slot this carrier represents via its parent.
                local visualLoc = TransmogDE.getItemVisualBodyLocation(parentItem)
                local isMasked = visualLoc and hiddenVisualSlots[visualLoc] or false

                TmogPrint(tostring(item) .. " (carrier) isMasked = " .. tostring(isMasked)
                    .. " | parent=" .. tostring(parentItem) ..
                    " | visualLoc=" .. tostring(visualLoc))

                if isMasked then
                    -- Parent still equipped, but its visual slot is now masked by some other item.
                    -- → Remove the carrier.
                    TmogPrint("Carrier masked, removing: " .. tostring(item) ..
                        " | VisualLoc: " .. tostring(visualLoc))
                    table.insert(toRemove, item)
                else
                    -- Still valid and not masked → keep and sync visuals.
                    TransmogDE.syncConditionVisualsForTmog(item)
                end
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

-- Per-player dirty flags, keyed by playerNum
TransmogDE._clothingDirty = TransmogDE._clothingDirty or {}

local function onClothingUpdated(player)
    if not player or not instanceof(player, "IsoPlayer") then
        return
    end

    -- Only care about the local player in SP (B42 is SP only)
    if not player:isLocalPlayer() then
        return
    end

    local playerNum = player:getPlayerNum() or 0

    -- Mark clothing dirty; OnPlayerUpdate will handle the heavy work.
    TransmogDE._clothingDirty[playerNum] = true

    TmogPrint("OnClothingUpdated -> mark clothing dirty for player " .. tostring(playerNum))

    if TransmogListViewer and TransmogListViewer.instance then
        TransmogListViewer.instance:initialise()
    end
end

Events.OnClothingUpdated.Add(onClothingUpdated)

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
