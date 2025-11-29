TransmogDE = TransmogDE or {}

TransmogDE.ImmersiveModeMap = {}
TransmogDE.BackupClothingItemAsset = {}
TransmogDE.TmogItemToOgItemBodylocation = {}

TransmogDE.GenerateTransmogGlobalModData = function()
    TmogPrint('Server TransmogModData')
    local scriptManager = getScriptManager();
    local allItems = scriptManager:getAllItems()
    local transmogModData = TransmogDE.getTransmogModData()
    local itemToTransmogMap = transmogModData.itemToTransmogMap or {}
    local transmogToItemMap = transmogModData.transmogToItemMap or {}

    local serverTransmoggedItemCount = 0
    local size = allItems:size() - 1;
    for i = 0, size do
        local item = allItems:get(i);
        if TransmogDE.isTransmoggable(item) then
            local fullName = item:getFullName()
            serverTransmoggedItemCount = serverTransmoggedItemCount + 1
            if not itemToTransmogMap[fullName] then
                table.insert(transmogToItemMap, fullName)
                itemToTransmogMap[fullName] = 'TransmogDE.TransmogItem_' .. #transmogToItemMap
            end
            -- TmogPrint(fullName .. ' -> ' .. tostring(itemToTransmogMap[fullName]))
        end
    end

    if #transmogToItemMap >= 5000 then
        TmogPrint("ERROR: Reached limit of transmoggable items")
    end

    ModData.add("TransmogModData", transmogModData)
    ModData.transmit("TransmogModData")

    TmogPrint('Transmogged items count: ' .. tostring(serverTransmoggedItemCount))

    return transmogModData
end

TransmogDE.patchAllItemsFromModData = function(modData)
    for originalItemName, tmogItemName in pairs(modData.itemToTransmogMap) do
        local ogItem = ScriptManager.instance:getItem(originalItemName)
        local tmogItem = ScriptManager.instance:getItem(tmogItemName)
        if ogItem ~= nil and tmogItem ~= nil then
            local originalClothingItemAsset = ogItem:getClothingItemAsset()

            if originalClothingItemAsset then
                local tmogClothingItemAsset = tmogItem:getClothingItemAsset()
                tmogItem:setClothingItemAsset(originalClothingItemAsset)

                --[[if not SandboxVars.TransmogDE.DisableHeadGearFix and
                    (originalClothingItemAsset:isHat() or originalClothingItemAsset:isMask()) then
                    -- Since we use the tmog item to check textureChoices and colorTint in Transmog\InventoryContextMenu.lua
                    -- using the backup will be handy to ensure we always select the original textureChoices and colorTint
                    TransmogDE.BackupClothingItemAsset[originalItemName] = originalClothingItemAsset
                    -- Hide hats to avoid having the hair being compressed if wearning an helmet or something similiar
                    ogItem:setClothingItemAsset(tmogClothingItemAsset)
                end]]

                -- If can be canBeEquipped but not getBodyLocation, then it's a backpack!
                -- So, we force the backpacks to have a BodyLocation, so that it can be hidden by pz using the group:setHideModel!
                if ogItem:getType() == Type.Container and ogItem:InstanceItem(nil):canBeEquipped() ~= "" and
                    ogItem:getBodyLocation() == "" then
                    ogItem:DoParam("BodyLocation = " .. ogItem:InstanceItem(nil):canBeEquipped())
                end
            end

            -- store this map for the wear tmog fix
            TransmogDE.TmogItemToOgItemBodylocation[tmogItemName] = ogItem:getBodyLocation()
        end
    end
end

TransmogDE.triggerUpdate = function(player)
    TmogPrint('triggerUpdate')
    triggerEvent("ApplyTransmogToPlayerItems", player)
end

TransmogDE.triggerUpdateVisuals = function(player)
    TmogPrint('triggerUpdateVisuals')
    triggerEvent("SyncConditionVisuals", player)
end

TransmogDE.invalidBodyLocations = {
    TransmogLocation = true,
    Bandage = true,
    Wound = true,
    ZedDmg = true,
    Hide_Everything = true,
    Fur = true, -- Support for "the furry mod"
    Face_Tattoo = true, -- Support for "elies tattoo"
    Back_Tattoo = true, -- Support for "elies tattoo"
    RightLeg_Tattoo = true, -- Support for "elies tattoo"
    LeftLeg_Tattoo = true, -- Support for "elies tattoo"
    LowerBody_Tattoo = true, -- Support for "elies tattoo"
    UpperBody_Tattoo = true, -- Support for "elies tattoo"
    RightArm_Tattoo = true, -- Support for "elies tattoo"
    LeftArm_Tattoo = true -- Support for "elies tattoo"
}

TransmogDE.addBodyLocationToIgnore = function(bodyLocation)
    TransmogDE.invalidBodyLocations[bodyLocation] = true
end

TransmogDE.isTransmoggableBodylocation = function(bodyLocation)
    return not TransmogDE.invalidBodyLocations[bodyLocation] and not string.find(bodyLocation, "MakeUp_")
end

local clothingTypes = {
    Clothing = true,
    AlarmClockClothing = true,
}

TransmogDE.isTransmoggable = function(scriptItem)
    if not scriptItem then
        return false
    end
    if scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end

    if not scriptItem.getTypeString then
        return false
    end
    local typeString = scriptItem:getTypeString()
    local isClothing = clothingTypes[typeString] == true
    local bodyLocation = scriptItem:getBodyLocation()
    local isBackpack = typeString == "Container" and (scriptItem:InstanceItem(nil):canBeEquipped() or bodyLocation)
    local isClothingItemAsset = scriptItem:getClothingItemAsset() ~= nil
    local isWorldRender = scriptItem:isWorldRender()
    local isNotHidden = not scriptItem:isHidden()
    local isNotTransmog = scriptItem:getModuleName() ~= "TransmogDE"
    -- local isNotCosmetic = not scriptItem:isCosmetic()
    if (isClothing or isBackpack) and TransmogDE.isTransmoggableBodylocation(bodyLocation) -- and isNotCosmetic
    and isNotTransmog and isWorldRender and isClothingItemAsset and isNotHidden and isNotHidden then
        return true
    end
    return false
end

TransmogDE.isTransmogItem = function(scriptItem)
    if scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end

    return scriptItem:getModuleName() == "TransmogDE"
end

TransmogDE.getTransmogModData = function()
    local TransmogModData = ModData.get("TransmogModData");
    return TransmogModData or {
        itemToTransmogMap = {},
        transmogToItemMap = {}
    }
end

TransmogDE.createTransmogItem = function(ogItem, player)
    local transmogModData = TransmogDE.getTransmogModData()
    local itemTmogModData = TransmogDE.getItemTransmogModData(ogItem)

    local tmogItemName = transmogModData.itemToTransmogMap[itemTmogModData.transmogTo]

    if not tmogItemName then
        return
    end

    local tmogItem = player:getInventory():AddItem(tmogItemName);

    -- set tmogItem as child of ogItem
    itemTmogModData.childId = tmogItem:getID()
    -- set ogItem as parent of tmogItem
    tmogItem:getModData()['TransmogParent'] = ogItem:getID()

    -- For debug purpose
    tmogItem:setName('Tmog: ' .. ogItem:getName())

    TransmogDE.setClothingColorModdata(ogItem, TransmogDE.getClothingColor(ogItem))
    TransmogDE.setClothingTextureModdata(ogItem, TransmogDE.getClothingTexture(ogItem))
    TransmogDE.setClothingColor(ogItem, TransmogDE.getClothingColor(ogItem))
    TransmogDE.setClothingTexture(ogItem, TransmogDE.getClothingTexture(ogItem))
    TransmogDE.setClothingColor(tmogItem, TransmogDE.getClothingColor(ogItem))
    TransmogDE.setClothingTexture(tmogItem, TransmogDE.getClothingTexture(ogItem))

    -- don't wear the new item yet
    -- player:setWornItem(tmogItem:getBodyLocation(), tmogItem)

    TmogPrint('createTransmogItem', ogItem:getName())
    return tmogItem
end

-- Item Specific Code

TransmogDE.getClothingItemAsset = function(scriptItem)
    if scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end
    local fullName = scriptItem:getFullName()

    -- Temporarily disabling Headgear Fix
    --local clothingItemAsset = TransmogDE.BackupClothingItemAsset[fullName] or scriptItem:getClothingItemAsset()
    local clothingItemAsset = scriptItem:getClothingItemAsset()

    return clothingItemAsset
end

-- Return (and lazily initialize) Transmog moddata for a given item.
-- Fields:
--   originalColor    = first-seen tint (table or nil)
--   originalTexture  = first-seen texture index (or nil)
--   color            = current/default tint used by transmog
--   texture          = current/default texture used by transmog
--   transmogTo       = current transmog target fullType
--   lastTransmogTo   = last non-hidden transmog target
--   childId          = carrier item id (if any)
TransmogDE.getItemTransmogModData = function(item)
    local itemModData = item:getModData()
    local tmog = itemModData['Transmog']

    -- If already initialized, ensure original* fields exist for legacy saves.
    if tmog then
        -- Legacy compatibility: if originalColor/Texture missing, seed them once.
        if not tmog.originalColor and tmog.color then
            tmog.originalColor = {
                r = tmog.color.r,
                g = tmog.color.g,
                b = tmog.color.b,
                a = tmog.color.a or 1.0,
            }
        end
        if tmog.originalTexture == nil and tmog.texture ~= nil then
            tmog.originalTexture = tmog.texture
        end
        return tmog
    end

    -- First-time initialization: capture how the item looks RIGHT NOW.
    local clothingItemAsset = TransmogDE.getClothingItemAsset(item:getScriptItem())
    local visual = item:getVisual()
    local colorObj = visual and visual.getTint and visual:getTint() or nil

    local textureChoice = visual and visual.getTextureChoice and visual:getTextureChoice() or nil

    local originalColor = colorObj and clothingItemAsset and clothingItemAsset.getAllowRandomTint and clothingItemAsset:getAllowRandomTint() and {
        r = colorObj:getRedFloat(),
        g = colorObj:getGreenFloat(),
        b = colorObj:getBlueFloat(),
        a = colorObj:getAlphaFloat()
    } or nil

    local fullName = item:getScriptItem():getFullName()

    tmog = {
        -- Original look at discovery/craft time
        originalColor = originalColor,
        originalTexture = textureChoice,

        -- Active/default look used by transmog logic (starts as original)
        color = originalColor and {
            r = originalColor.r,
            g = originalColor.g,
            b = originalColor.b,
            a = originalColor.a,
        } or nil,
        texture = textureChoice,

        transmogTo = fullName,
        lastTransmogTo = fullName,
        childId = nil,
    }

    itemModData['Transmog'] = tmog
    return tmog
end

TransmogDE.getTransmogChild = function(invItem)
    local itemTmogModData = TransmogDE.getItemTransmogModData(invItem)
    if not itemTmogModData.childId then
        return
    end

    local container = invItem:getContainer()
    -- find the item by ID, ensure it exists, then return it
    return container:getItemById(itemTmogModData.childId)
end

TransmogDE.getTransmogParent = function(invItem)
    if not invItem then return nil end
    local parentID = invItem:getModData() and invItem:getModData().TransmogParent
    if not parentID then return nil end

    -- 1) Try same container first (fast path)
    local container = invItem:getContainer()
    if container then
        local found = container:getItemById(parentID)
        if found then return found end
    end

    --[[
    -- 2) Try player’s worn items (most common for transmog pairs)
    local player = getPlayer()
    if player then
        local worn = player:getWornItems()
        for i = 0, worn:size() - 1 do
            local item = worn:getItemByIndex(i)
            if item and item:getID() == parentID then
                return item
            end
        end
    end

    -- 3) As fallback, search player inventory (if carrier somehow desynced)
    if player then
        local inv = player:getInventory()
        local found = inv and inv:getItemById(parentID)
        if found then return found end
    end
    ]]

    return nil
end

TransmogDE.setClothingColorModdata = function(item, color)
    if color == nil then
        return
    end

    local itemModData = TransmogDE.getItemTransmogModData(item)
    itemModData.color = {
        r = color:getRedFloat(),
        g = color:getGreenFloat(),
        b = color:getBlueFloat(),
        a = color:getAlphaFloat()
    }
end

TransmogDE.setClothingTextureModdata = function(item, textureIdx)
    if textureIdx == nil then
        return
    end

    local itemModData = TransmogDE.getItemTransmogModData(item)
    itemModData.texture = textureIdx
end

TransmogDE.setClothingColor = function(item, color)
    if color == nil then
        return
    end

    item:getVisual():setTint(color)
    
    item:synchWithVisual();

    getPlayer():resetModelNextFrame();
end

TransmogDE.setClothingTexture = function(item, textureIndex)
    if textureIndex < 0 or textureIndex == nil then
        return
    end

    if item:getClothingItem():hasModel() then
        item:getVisual():setTextureChoice(textureIndex)
    else
        item:getVisual():setBaseTexture(textureIndex)
    end

    item:synchWithVisual();

    getPlayer():resetModelNextFrame();
    -- TmogPrint('setClothingTexture' .. tostring(textureIndex))
end

TransmogDE.getClothingColor = function(item)
    local itemModData = TransmogDE.getItemTransmogModData(item)
    local parsedColor = itemModData.color and
                            ImmutableColor.new(
            Color.new(itemModData.color.r, itemModData.color.g, itemModData.color.b, itemModData.color.a))
    return parsedColor or item:getVisual():getTint()
end

TransmogDE.getClothingTexture = function(item)
    local itemModData = TransmogDE.getItemTransmogModData(item)

    if itemModData.texture then
        return itemModData.texture
    end

    -- Very similiar to what is done inside: media\lua\client\OptionScreens\CharacterCreationMain.lua
    local clothingItem = item:getVisual():getClothingItem()
    local texture = clothingItem:hasModel() and item:getVisual():getTextureChoice() or item:getVisual():getBaseTexture()
    return texture
end

TransmogDE.setItemTransmog = function(itemToTmog, scriptItem)
    local moddata = TransmogDE.getItemTransmogModData(itemToTmog)

    if scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end

    moddata.transmogTo = scriptItem:getFullName()
    moddata.lastTransmogTo = scriptItem:getFullName()
end

-- Reset transmog mapping to this item's own script,
-- but KEEP current tint/texture and do not touch carriers (except clearing stale childId).
-- Used for style-variant swaps (ISClothingExtraAction) so colors survive equip/unequip.
TransmogDE.setTransmogToSelfKeepVisuals = function(item, supressUpdates)
    local moddata = TransmogDE.getItemTransmogModData(item)
    local isHidden = TransmogDE.isClothingHidden(item)
    local fromName = moddata.transmogTo and getItemNameFromFullType(moddata.transmogTo) or nil

    moddata.transmogTo = item:getScriptItem():getFullName()
    moddata.lastTransmogTo = item:getScriptItem():getFullName()

    local toName = getItemNameFromFullType(moddata.transmogTo)
    local text = nil
    if fromName and fromName ~= toName or isHidden then
        text = getText("IGUI_TransmogDE_Text_WasReset", toName)
    end
    if not supressUpdates then
        if text then
            HaloTextHelper.addGoodText(getPlayer(), text)
        end
    end
    TransmogDE.forceUpdateClothing(item)
end

-- ==========================================================
-- Is Transmogged
-- ==========================================================
-- Purpose:
--   Returns true if the given item currently has an active
--   transmog applied (i.e., its transmogTo field points to
--   a different script item than itself).
--
-- Inputs:
--   item (InventoryItem) -- the item to check
--
-- Output:
--   boolean -- true if actively transmogged, false otherwise
--
-- Usage:
--   if TransmogDE.isTransmogged(item) then
--       ...
--   end
--
TransmogDE.isTransmogged = function(item)
    if not item then
        return false
    end

    local moddata = TransmogDE.getItemTransmogModData(item)
    if not moddata or not moddata.transmogTo then
        return false
    end

    local scriptItem = item:getScriptItem()
    if scriptItem and scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end

    local selfFullName = scriptItem and scriptItem:getFullName()
    if not selfFullName then
        return false
    end

    return moddata.transmogTo ~= selfFullName
end

-- ==========================================================
-- Remove Transmog (keep visuals)
-- ==========================================================
-- Purpose:
--   Removes any active transmog link from the given item but
--   keeps its current tint, texture, and appearance intact.
--   Also removes any existing transmog carrier item.
--
-- Inputs:
--   item (InventoryItem)  -- item to remove transmog from
--   suppressUpdates (bool) -- if true, no halo text feedback
--
-- Usage:
--   TransmogDE.removeTransmog(item)
--
-- Notes:
--   - Differs from setItemToDefault(), which restores the
--     *original* appearance snapshot (original tint/texture).
--   - This function only clears the transmog link and carrier,
--     leaving the current visuals untouched.
--
TransmogDE.removeTransmog = function(item, suppressUpdates)
    if not item then
        return
    end

    local moddata = TransmogDE.getItemTransmogModData(item)
    if not moddata then
        return
    end

    TransmogDE.setTransmogToSelfKeepVisuals(item)
end

-- Reset this item back to its original appearance and transmog target.
-- This should match how it looked when first picked up/crafted
-- (based on the initial snapshot from getItemTransmogModData).
TransmogDE.setItemToDefault = function(item, supressUpdates)
    if not item then
        return
    end

    local moddata = TransmogDE.getItemTransmogModData(item)
    if not moddata then
        return
    end

    local wasHidden = TransmogDE.isClothingHidden and TransmogDE.isClothingHidden(item) or false
    local fromName = moddata.transmogTo and getItemNameFromFullType(moddata.transmogTo) or nil

    -- Resolve the item’s own script fullType as the canonical default target.
    local scriptItem = item:getScriptItem()
    if scriptItem and scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end
    local selfFullName = scriptItem and scriptItem:getFullName() or moddata.transmogTo

    -- Choose default color/texture from immutable originals when available,
    -- with sane fallbacks for legacy data.
    local defaultColorTbl = moddata.originalColor or moddata.color or nil
    local defaultTexture  = (moddata.originalTexture ~= nil and moddata.originalTexture)
                         or (moddata.texture ~= nil and moddata.texture)
                         or nil

    -- Apply default tint back onto the item visual.
    if defaultColorTbl then
        local c = Color.new(
            defaultColorTbl.r or 1.0,
            defaultColorTbl.g or 1.0,
            defaultColorTbl.b or 1.0,
            defaultColorTbl.a or 1.0
        )
        local immutable = ImmutableColor.new(c)
        TransmogDE.setClothingColor(item, immutable)

        -- Keep active color in sync with the default snapshot.
        moddata.color = {
            r = defaultColorTbl.r or 1.0,
            g = defaultColorTbl.g or 1.0,
            b = defaultColorTbl.b or 1.0,
            a = defaultColorTbl.a or 1.0,
        }
    else
        -- If absolutely nothing is stored, clear any custom tint.
        -- This lets the engine/scriptItem decide its natural look.
        item:getVisual():setTint(nil)
    end

    -- Apply default texture back onto the item visual.
    if defaultTexture ~= nil then
        TransmogDE.setClothingTexture(item, defaultTexture)
        moddata.texture = defaultTexture
    end

    -- Reset mapping so we no longer transmog into anything else.
    moddata.transmogTo = selfFullName
    moddata.lastTransmogTo = selfFullName

    local toName = getItemNameFromFullType(selfFullName)
    local text = nil
    if (fromName and fromName ~= toName) or wasHidden then
        text = getText("IGUI_TransmogDE_Text_WasReset", toName)
    end

    if not supressUpdates and text then
        HaloTextHelper.addGoodText(getPlayer(), text)
    end

    -- Rebuild the carrier so the visible item matches the restored defaults.
    TransmogDE.forceUpdateClothing(item)
end

-- Returns true if this clothing item is currently hidden by TransmogDE
TransmogDE.isClothingHidden = function(item)
    if not item then
        return false
    end
    local md = TransmogDE.getItemTransmogModData(item)
    return md.transmogTo == nil
end

TransmogDE.setClothingHidden = function(item, suppressUpdates)
    if not item then
        return
    end
    local moddata = TransmogDE.getItemTransmogModData(item)

    if moddata.transmogTo ~= nil then
        moddata.lastTransmogTo = moddata.transmogTo
    end
    moddata.transmogTo = nil

    if not suppressUpdates then
        local fromName = getItemNameFromFullType(item:getScriptItem():getFullName())
        local text = getText("IGUI_TransmogDE_Text_WasHidden", fromName)

        HaloTextHelper.addGoodText(getPlayer(), text)
    end
    TransmogDE.forceUpdateClothing(item)
end

TransmogDE.setClothingShown = function(item, suppressUpdates)
    local moddata = TransmogDE.getItemTransmogModData(item)

    if moddata.lastTransmogTo ~= nil then
        moddata.transmogTo = moddata.lastTransmogTo
    else
        item:getScriptItem():getFullName()
    end

    if not suppressUpdates then
        local fromName = getItemNameFromFullType(item:getScriptItem():getFullName())
        local text = getText("IGUI_TransmogDE_Text_WasShown", fromName)

        HaloTextHelper.addGoodText(getPlayer(), text)
    end
    TransmogDE.forceUpdateClothing(item)
end

TransmogDE.removeAllWornTransmogs = function()
    local player = getPlayer()
    if not player then
        return
    end
    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) then
            TransmogDE.removeTransmog(item, true)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

TransmogDE.resetDefaultAllWornTransmogs = function()
    local player = getPlayer()
    if not player then
        return
    end
    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) then
            TransmogDE.setItemToDefault(item, true)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

TransmogDE.hideAllWornTransmogs = function()
    local player = getPlayer()
    if not player then
        return
    end
    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) and (not TransmogDE.isClothingHidden(item)) then
            TransmogDE.setClothingHidden(item, true)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

TransmogDE.showAllWornTransmogs = function()
    local player = getPlayer()
    if not player then
        return
    end
    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) and TransmogDE.isClothingHidden(item) then
            TransmogDE.setClothingShown(item, true)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

-- Converted from java\characters\WornItems\WornItems.java using chatgtp -> public void setItem(String var1, InventoryItem var2)
-- This is needed to avoid item clipping!
TransmogDE.setWornItemTmog = function(player, tmogItem)
    local wornItems = player:getWornItems()
    local group = getClassFieldVal(wornItems, getClassField(wornItems, 0));
    local items = getClassFieldVal(wornItems, getClassField(wornItems, 1));

    local ogItemBodylocation = TransmogDE.TmogItemToOgItemBodylocation[tmogItem:getScriptItem():getFullName()]
    if not ogItemBodylocation then
        return
    end

    wornItems:remove(tmogItem)

    -- Use the ogItem bodyLoc, so that they are in the correct order, otherwise, we'll get clipping
    -- This ensures that for example, backpacks are on TOP of trousers

    local insertAt = items:size()
    for i = 0, items:size() - 1 do
        local wornItem = items:get(i)
        local wornItemItem = wornItem:getItem()
        if TransmogDE.isTransmogItem(wornItemItem) and not wornItemItem:hasTag("Hide_Everything") then
            local wornOgItemLocation = TransmogDE.TmogItemToOgItemBodylocation[wornItemItem:getScriptItem()
                :getFullName()]
            -- TmogPrint('wornOgitemLocation', wornOgItemLocation)
            -- TmogPrint('ogItemBodylocation', ogItemBodylocation)
            if group:indexOf(wornOgItemLocation) > group:indexOf(ogItemBodylocation) then
                insertAt = i
                break
            end
        end
    end

    local newWornItem = WornItem.new("TransmogLocation", tmogItem)
    items:add(insertAt, newWornItem)
end

-- Usefull for forcing the item to be removed and re-added after changing color, texture, and tmog
TransmogDE.forceUpdateClothing = function(item)
    local moddata = TransmogDE.getItemTransmogModData(item)
    local container = item:getContainer()
    if not container then
        TmogPrint('forceUpdateClothing container is nil')
        return
    end
    local childItem = container:getItemById(moddata.childId)
    local player = instanceof(container:getParent(), "IsoGameCharacter") and container:getParent()

    -- find the item by ID, ensure it exists, then remove it from container and player
    if not childItem or not player then
        TmogPrint("forceUpdateClothing childItem or player missing!")
        return
    end

    -- Remove the old tmog item
    player:getWornItems():remove(childItem)
    container:Remove(childItem);


    -- Create and wear new tmog item
    local tmogItem = TransmogDE.createTransmogItem(item, player)
    if not tmogItem then
        TmogPrint("forceUpdateClothing tmogItem missing")
        return
    end

    TransmogDE.syncConditionVisualsForTmog(tmogItem)
    TransmogDE.setWornItemTmog(player, tmogItem)

    player:resetModelNextFrame();
    
    if instanceof(player, 'IsoPlayer') and player:isLocalPlayer() and getPlayerInfoPanel(player:getPlayerNum()) then
		getPlayerInfoPanel(player:getPlayerNum()).charScreen.refreshNeeded = true
	end

    if isClient() then
        sendClothing(player)
    end
end

local function clearHoles(vDst)
    if not (vDst and BloodBodyPartType and BloodBodyPartType.MAX) then return end
    local maxIndex = BloodBodyPartType.MAX:index()
    for idx = 0, maxIndex - 1 do
        vDst:removeHole(idx)
    end
end

local function clearPatches(vDst)
    if not (vDst and BloodBodyPartType and BloodBodyPartType.MAX) then return end
    local maxIndex = BloodBodyPartType.MAX:index()
    for idx = 0, maxIndex - 1 do
        vDst:removePatch(idx)
    end
end

function TransmogDE.syncConditionVisuals(carrierItem, sourceItem)
    TmogPrint("syncConditionVisuals triggered for: " .. tostring(sourceItem))
    if not (carrierItem and sourceItem and carrierItem.getVisual and sourceItem.getVisual) then
        return false
    end

    local vDst = carrierItem:getVisual()
    local vSrc = sourceItem:getVisual()
    if not (vDst and vSrc) then
        return false
    end

    local OPS = TransmogDE.Options or {}

    local hideBlood   = OPS.shouldHideBlood   and OPS.shouldHideBlood()   or false
    local hideDirt    = OPS.shouldHideDirt    and OPS.shouldHideDirt()    or false
    local hideHoles   = OPS.shouldHideHoles   and OPS.shouldHideHoles()   or false
    local hidePatches = OPS.shouldHidePatches and OPS.shouldHidePatches() or false

    -- Blood
    if hideBlood then
        vDst:removeBlood()
    else
        vDst:copyBlood(vSrc)
    end

    -- Dirt
    if hideDirt then
        vDst:removeDirt()
    else
        vDst:copyDirt(vSrc)
    end

    -- Holes
    if hideHoles then
        clearHoles(vDst)
    else
        vDst:copyHoles(vSrc)
    end

    -- Patches
    if hidePatches then
        clearPatches(vDst)
    else
        vDst:copyPatches(vSrc)
    end

    carrierItem:synchWithVisual()
    -- sourceItem:synchWithVisual()
    return true
end

function TransmogDE.syncConditionVisualsToTmog(ogItem)
    local tmogItem = TransmogDE.getTransmogChild(ogItem)
    if not tmogItem then return false end
    return TransmogDE.syncConditionVisuals(tmogItem, ogItem)
end

function TransmogDE.syncConditionVisualsForTmog(tmogItem)
    if tmogItem:hasTag("Hide_Everything") then return false end
    local ogItem = TransmogDE.getTransmogParent(tmogItem)
    if not ogItem then return false end
    return TransmogDE.syncConditionVisuals(tmogItem, ogItem)
end

-- Immersive mode code

TransmogDE.getImmersiveModeData = function()
    return ModData.getOrCreate('TransmogImmersiveModeData')
end

TransmogDE.immersiveModeItemCheck = function(item)
    if SandboxVars.TransmogDE.ImmersiveModeToggle ~= true then
        return true
    end
    return TransmogDE.getImmersiveModeData()[item:getFullName()] == true
end