local function TmogDebugPrintTags(item)
    if not item then
        TmogPrint("TmogDebugPrintTags: item=nil")
        return
    end

    local tags = item:getTags()
    if not tags then
        TmogPrint("TmogDebugPrintTags: no tags set")
        return
    end

    -- Convert Java Set → Lua array
    local arr = tags:toArray()
    if not arr then
        TmogPrint("TmogDebugPrintTags: toArray() returned nil")
        return
    end

    for i = 0, #arr - 1 do
        local tagObj = arr[i]
        if tagObj then
            TmogPrint("Tag: " .. tostring(tagObj))
        end
    end
end

local function wearHideEverything(player)
    local playerInv = player:getInventory()

    local hideItem = playerInv:FindAndReturn("TransmogDE.Hide_Everything");
    if not hideItem then
        TmogPrint('Hide_Everything is missing, lets add it')
        hideItem = player:getInventory():AddItem('TransmogDE.Hide_Everything');
        sendAddItemToContainer(playerInv, hideItem)
    end
    if not hideItem then
        TmogPrint("ERROR: failed to create TransmogDE.Hide_Everything")
        return
    end
    if not hideItem:isWorn() then
        TmogPrint('Hide_Everything is not equipped, lets wear it')
        local hideLoc = TransmogDE.ItemBodyLocation
                        and TransmogDE.ItemBodyLocation.Hide_Everything
        player:setWornItem(hideLoc, hideItem)
        hideItem:setFavorite(true)
        sendClothing(player, hideLoc, hideItem)
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
    local altVisualSlots = {}
    local hiddenProviderSlotTypes = {}
    local visibleProviderSlotTypes = {}

    if TransmogDE and TransmogDE.getHiddenVisualSlotsForCovering then
        for i = 0, wornItems:size() - 1 do
            local item = wornItems:getItemByIndex(i)

            -- Ignore nils, the Hide_Everything helper, and transmog carriers.
            if item
                and not item:hasTag(TransmogDE.ItemTag.Hide_Everything)
                and (not TransmogDE.isTransmogItem or not TransmogDE.isTransmogItem(item)) then

                -- If this clothing is explicitly hidden by TransmogDE, it should
                -- not act as a visual "covering" layer.
                if not TransmogDE.isClothingHidden or not TransmogDE.isClothingHidden(item) then
                    TmogPrint("Checking Visual Mask Rules for : " .. tostring(item:getDisplayName()))
                    local hiddenForThis = TransmogDE.getHiddenVisualSlotsForCovering(item)
                    if hiddenForThis then
                        local count = 0
                        for slot, _ in pairs(hiddenForThis) do
                            count = count + 1
                            hiddenVisualSlots[slot] = true
                        end
                        TmogPrint(tostring(count) .. " rules found!")
                    else
                        TmogPrint("No Visual Mask Rules")
                    end

                    if TransmogDE.getAltVisualSlotsForCovering then
                        local altForThis = TransmogDE.getAltVisualSlotsForCovering(item)
                        if altForThis then
                            for slot, _ in pairs(altForThis) do
                                altVisualSlots[slot] = true
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
        local item = wornItems:getItemByIndex(i)
        local script = item:getScriptItem()
        local isHideHelper = script and script:hasTag(TransmogDE.ItemTag.Hide_Everything)
        local itemDisplayName = item:getDisplayName()
        -- TmogDebugPrintTags(item)
        TmogPrint("Assessing item: " .. tostring(itemDisplayName))
        TmogPrint("BodyLocation: " .. tostring(script:getBodyLocation()))

        if item and not isHideHelper then
            local visualLoc = TransmogDE.getItemVisualBodyLocation(item)
            local visualLocString = tostring(visualLoc)
            local isMasked = visualLoc and hiddenVisualSlots[visualLocString] or false
            local isExplicitlyHidden = TransmogDE.isClothingHidden and TransmogDE.isClothingHidden(item) or false

            if TransmogDE.addHiddenProvidedAttachmentSlots then
                TransmogDE.addHiddenProvidedAttachmentSlots(hiddenProviderSlotTypes, item)
            end

            if not isMasked
                and not isExplicitlyHidden
                and TransmogDE.addVisibleProvidedAttachmentSlots then
                TransmogDE.addVisibleProvidedAttachmentSlots(visibleProviderSlotTypes, item)
            end
        end

        ----------------------------------------------------------------
        -- 1) REAL ITEMS: create carriers if transmoggable & not masked
        ----------------------------------------------------------------
        if item
            and not isHideHelper
            and TransmogDE.isTransmoggable
            and TransmogDE.isTransmoggable(item)
            and not TransmogDE.getTransmogChild(item) then

            -- Determine the *visual* slot this REAL item represents.
            local visualLoc = TransmogDE.getItemVisualBodyLocation(item)
            local visualLocString = tostring(visualLoc)
            local isMasked = visualLoc and hiddenVisualSlots[visualLocString] or false

            if not isMasked then
                -- No existing child and not masked → create carrier.
                local carrierVariant = TransmogDE.getDesiredTransmogCarrierVariant(item, altVisualSlots)
                local tmogItem = TransmogDE.createTransmogItem(item, player, carrierVariant == "alt")
                if tmogItem then
                    TmogPrint("Item to wear: " .. tostring(itemDisplayName))
                    table.insert(toWear, tmogItem)
                end
            else
                TmogPrint(tostring(itemDisplayName) .. " (real) isMasked = " .. tostring(isMasked) .. " | visualLoc=" .. visualLocString)
            end
        end

        ----------------------------------------------------------------
        -- 2) CARRIERS: remove if masked OR parent missing/unequipped
        ----------------------------------------------------------------
        if item
            and not isHideHelper
            and TransmogDE.isTransmogItem
            and TransmogDE.isTransmogItem(item) then

            local tmogParentId = item:getModData()['TransmogParent']
            local parentItem = tmogParentId and playerInv:getItemById(tmogParentId)
            local parentDisplayName = parentItem and parentItem:getDisplayName() or "No Known Parent"
            local parentUnequipped = parentItem and not parentItem:isEquipped()
            local pmd = parentItem and parentItem:getModData()

            -- If parent is missing or not equipped, we don't care about masking;
            -- the carrier is stale and should go.
            if not tmogParentId or not parentItem or parentUnequipped then
                TmogPrint("Item to remove: " .. tostring(itemDisplayName))

                TmogPrint(tostring(item) .. " (carrier)"
                    .. " | tmogParentId = ".. tostring(tmogParentId)
                    .. " | parentItem = " .. tostring(parentDisplayName)
                    .. " | parentUnquipped = " .. tostring(parentUnequipped))
                if pmd and pmd.Transmog and pmd.Transmog.childId == item:getID() then
                    --pmd.Transmog.childId = nil
                end
                table.insert(toRemove, item)
            else
                -- Determine the *visual* slot this carrier represents via its parent.
                local visualLoc = TransmogDE.getItemVisualBodyLocation(parentItem)
                local visualLocString = tostring(visualLoc)
                local isMasked = visualLoc and hiddenVisualSlots[visualLocString] or false
                local desiredCarrierVariant = TransmogDE.getDesiredTransmogCarrierVariant(parentItem, altVisualSlots)
                local currentCarrierVariant = TransmogDE.getTransmogCarrierVariant(item)
                local carrierVariantChanged = currentCarrierVariant ~= desiredCarrierVariant

                TmogPrint(tostring(item) .. " (carrier) isMasked = " .. tostring(isMasked)
                    .. " | parent=" .. tostring(parentDisplayName) ..
                    " | visualLoc=" .. visualLocString ..
                    " | currentCarrierVariant=" .. tostring(currentCarrierVariant) ..
                    " | desiredCarrierVariant=" .. tostring(desiredCarrierVariant))

                if isMasked then
                    TmogPrint("Item to remove: " .. tostring(itemDisplayName))
                    -- Parent still equipped, but its visual slot is now masked by some other item.
                    -- → Remove the carrier.
                    TmogPrint("Carrier masked, removing: " .. tostring(itemDisplayName) ..
                        " | VisualLoc: " .. visualLocString)
                    if pmd and pmd.Transmog and pmd.Transmog.childId == item:getID() then
                        pmd.Transmog.childId = nil
                    end
                    table.insert(toRemove, item)
                elseif carrierVariantChanged then
                    TmogPrint("Carrier variant changed, replacing: " .. tostring(itemDisplayName)
                        .. " | current=" .. tostring(currentCarrierVariant)
                        .. " | desired=" .. tostring(desiredCarrierVariant))

                    if pmd and pmd.Transmog and pmd.Transmog.childId == item:getID() then
                        pmd.Transmog.childId = nil
                    end

                    table.insert(toRemove, item)

                    local replacement = TransmogDE.createTransmogItem(parentItem, player, desiredCarrierVariant == "alt")
                    if replacement then
                        TmogPrint("Replacement item to wear: " .. tostring(parentDisplayName))
                        table.insert(toWear, replacement)
                    end
                else
                    -- Still valid and not masked → keep and sync visuals.
                    TransmogDE.syncConditionVisualsForTmog(item)
                    syncItemFields(player, item)
                    sendItemStats(item)
                end
            end
        end
    end

    if TransmogDE.syncHiddenProvidedAttachments then
        TransmogDE.syncHiddenProvidedAttachments(player, hiddenProviderSlotTypes, visibleProviderSlotTypes)
    end

    local toWearIDs = {}
    local toRemoveIDs = {}

    for _, tmogItem in ipairs(toWear) do
        toWearIDs[#toWearIDs+1] = tmogItem:getID()

        --TransmogDE.syncConditionVisualsForTmog(tmogItem)
        syncItemFields(player, tmogItem)
        sendItemStats(tmogItem)
        TransmogDE.setWornItemTmog(player, tmogItem)
    end

    for _, tmogItem in ipairs(toRemove) do
        toRemoveIDs[#toRemoveIDs+1] = tmogItem:getID()

        wornItems:remove(tmogItem)
        playerInv:Remove(tmogItem)
        sendRemoveItemFromContainer(playerInv, tmogItem)
    end

    TmogPrint('wearTransmogItems, to wear:', #toWear, ' to remove:', #toRemove)
    return toWearIDs, toRemoveIDs
end

local function applyTransmogToPlayerItems(player)
    if isClient() then
        TmogPrint("applyTransmogToPlayerItems: skip (MP)")
        return
    end
    if not player then
        TmogPrint("Critical Error applyTransmogToPlayerItems: Player not defined")
        return
    end
    wearHideEverything(player)
    local toWearTmogIDs, toRemoveTmogIDs = wearTransmogItems(player)
    sendClothing(player, nil, nil)
    if #toWearTmogIDs > 0 then
        TransmogNet.sendTransmogClothing(player, toWearTmogIDs)
    end
    if #toRemoveTmogIDs > 0 then
        syncVisuals(player)
    end
end

LuaEventManager.AddEvent("ApplyTransmogToPlayerItems");
Events.ApplyTransmogToPlayerItems.Add(applyTransmogToPlayerItems);

local function syncAllVisuals(player)
    local player = player or getPlayer() or getSpecificPlayer(0)
    if not player then return end
    local wornItems = player:getWornItems()
    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        -- TmogPrint("Worn item: " .. tostring(item:getScriptItem():getFullName()))
        if item and TransmogDE.isTransmogItem(item) then
            TransmogDE.syncConditionVisualsForTmog(item)
            syncItemFields(player, item)
            sendItemStats(item)
        end
    end
end

LuaEventManager.AddEvent("SyncConditionVisuals");
Events.SyncConditionVisuals.Add(syncAllVisuals);

-- Per-player dirty flags, keyed by playerNum
TransmogDE._clothingDirty = TransmogDE._clothingDirty or {}

local function onClothingUpdated(player)
    if not player or not instanceof(player, "IsoPlayer") then
        return
    end

    local playerNum = player:getPlayerNum() or 0

    -- Mark clothing dirty; OnPlayerUpdate will handle the heavy work.
    --if not TransmogDE.rebuildingWornItems[playerNum] then
        TmogPrint("OnClothingUpdated -> mark clothing dirty for player " .. tostring(playerNum))
        TransmogDE._clothingDirty[playerNum] = true
    --end
end

Events.OnClothingUpdated.Add(onClothingUpdated)
