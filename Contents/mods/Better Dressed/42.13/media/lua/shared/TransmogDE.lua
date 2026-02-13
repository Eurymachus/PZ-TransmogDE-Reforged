TransmogDE = TransmogDE or {}

TransmogDE.ImmersiveModeMap = {}
TransmogDE.BackupClothingItemAsset = {}
TransmogDE.TmogItemToOgItemBodylocation = {}

-- HELPERS



local function _dbgTextureDump(tag, item)
    if not isDebugEnabled() then return end
    if not item then
        TmogPrint(tag .. " item=nil")
        return
    end

    local vis = item.getVisual and item:getVisual() or nil
    local ci_item = item.getClothingItem and item:getClothingItem() or nil
    local ci_vis = (vis and vis.getClothingItem) and vis:getClothingItem() or nil

    local hasModel_item = (ci_item and ci_item.hasModel) and ci_item:hasModel() or nil
    local hasModel_vis  = (ci_vis  and ci_vis.hasModel)  and ci_vis:hasModel()  or nil

    local tc = (vis and vis.getTextureChoice) and vis:getTextureChoice() or nil
    local bt = (vis and vis.getBaseTexture) and vis:getBaseTexture() or nil

    local md = item.getModData and item:getModData() or nil
    local tm = md and md.Transmog or nil
    local mdTex = tm and tm.texture or nil
    local mdOrig = tm and tm.originalTexture or nil

    TmogPrint(tag
        .. " type=" .. tostring(item.getFullType and item:getFullType() or item:getType())
        .. " id=" .. tostring(item.getID and item:getID() or "nil")
        .. " hasModel_item=" .. tostring(hasModel_item)
        .. " hasModel_vis=" .. tostring(hasModel_vis)
        .. " visTexChoice=" .. tostring(tc)
        .. " visBaseTex=" .. tostring(bt)
        .. " md.texture=" .. tostring(mdTex)
        .. " md.originalTexture=" .. tostring(mdOrig)
    )
end

-- HELPERS END

TransmogDE.DestroyTransmogGlobalModData = function(regenerate)
    TmogPrint("Destroying TransmogModData")

    -- Explicitly wipe the ModData entry
    ModData.remove("TransmogModData")

    -- Transmit removal so clients drop it too
    ModData.transmit("TransmogModData")

    -- Also clear any cached reference on the Lua side
    if TransmogDE._transmogModData then
        TransmogDE._transmogModData = nil
    end

    if regenerate then
        TmogPrint("Regenerating TransmogModData")
        TransmogDE.GenerateTransmogGlobalModData()
    end
end

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
        local fullName = item:getFullName()
        if TransmogDE.isTransmoggable(item) then
            serverTransmoggedItemCount = serverTransmoggedItemCount + 1
            if not itemToTransmogMap[fullName] then
                table.insert(transmogToItemMap, fullName)
                itemToTransmogMap[fullName] = 'TransmogDE.TransmogItem_' .. #transmogToItemMap
            end
            --TmogPrint(fullName .. ' -> ' .. tostring(itemToTransmogMap[fullName]))
        else
            --TmogPrint(fullName .. ' is not Transmoggable.')
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

local function tableCount(t)
    if not t then return 0 end
    local c = 0
    for _ in pairs(t) do
        c = c + 1
    end
    return c
end

TransmogDE.patchAllItemsFromModData = function(modData)
    TmogPrint('patchAllItemsFromModData')
    local map = modData.itemToTransmogMap
    TmogPrint("itemToTransmogMap size: " .. tostring(map and tableCount(map)))
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
                if ogItem:getItemType() == ItemType.CONTAINER then
                    --TmogPrint("Validating BodyLocation for ogItem [" .. tostring(originalItemName) .. "] as an ItemType.CONTAINER")
                    local inst = ogItem:InstanceItem(nil)
                    local equipLocation = inst:canBeEquipped()
                    --TmogPrint("equipLocation = " .. tostring(equipLocation))
                    if equipLocation ~= "" then
                        local bodyLocation = ogItem:getBodyLocation()
                        if not bodyLocation then
                            --TmogPrint("Setting BodyLocation = " .. tostring(equipLocation))
                            ogItem:DoParam("BodyLocation", tostring(equipLocation))
                        end
                    end
                end
            end

            local newBodyLocation = ogItem:getBodyLocation()
            --TmogPrint("New BodyLocation = " .. tostring(newBodyLocation))
            -- store this map for the wear tmog fix
            TransmogDE.TmogItemToOgItemBodylocation[tmogItemName] = newBodyLocation
        end
    end
end

TransmogDE.triggerUpdate = function(player)
    --TmogPrint('triggerUpdate')
    triggerEvent("ApplyTransmogToPlayerItems", player)
end

TransmogDE.triggerUpdateVisuals = function(player)
    --TmogPrint('triggerUpdateVisuals')
    triggerEvent("SyncConditionVisuals", player)
end

TransmogDE.invalidBodyLocations = {
    -- New 42.13 registry IDs
    ["transmogde:transmog_location"]         = true,
    ["transmogde:hide_everything_location"]  = true,
    ["base:bandage"]                         = true,
    ["base:wound"]                           = true,
    ["base:zeddmg"]                          = true,

    -- SPNCC (character customisation layers)
    ["spncc:blank"]          = true,
    ["spncc:bodyhair"]       = true,
    ["spncc:muscle"]         = true,
    ["spncc:face"]           = true,
    ["spncc:bodydetail"]     = true,
    ["spncc:stubblebeard"]   = true,
    ["spncc:stubblehead"]    = true,
    ["spncc:bodydetail2"]    = true,
    ["spncc:face_model"]     = true,

    -- AuthenticZ
    ["AZ:HeadExtra"]         = true,
    ["AZ:HeadExtraHair"]     = true,
    ["AZ:HeadExtraPlus"]     = true,
    ["AZ:NeckExtra"]         = true,
    ["AZ:LegsExtra"]         = true,
    ["AZ:TorsoRigPlus2"]     = true,
    ["AZ:TorsoExtraPlus1"]   = true,
}

TransmogDE.addBodyLocationToIgnore = function(bodyLocation)
    local location = tostring(bodyLocation)
    TransmogDE.invalidBodyLocations[location] = true
end

TransmogDE.isTransmoggableBodylocation = function(bodyLocation)
    local location = tostring(bodyLocation)
    -- Reject only explicit invalid locations
    if TransmogDE.invalidBodyLocations[location] or string.find(location, "makeup_", 1, true) then
        return false
    end

    return true
end

TransmogDE.isTransmoggable = function(item)
    if not item then return false end

    -- Allow both InventoryItem and ScriptItem
    local scriptItem = item
    if scriptItem.getScriptItem then
        scriptItem = scriptItem:getScriptItem()
    end
    if not scriptItem then return false end

    local itemType = scriptItem.getItemType and scriptItem:getItemType() or nil
    if not itemType then return false end

    -- Clothing types (registry-backed)
    local isClothingType =
        itemType == ItemType.CLOTHING
        or itemType == ItemType.ALARM_CLOCK_CLOTHING

    -- Backpack-style containers
    local isBackpack = false
    if itemType == ItemType.CONTAINER then
        local inst = item.getScriptItem and item or scriptItem:InstanceItem(nil)
        if inst and (inst:canBeEquipped() or inst:getBodyLocation()) then
            isBackpack = true
            --isClothingType = false
        end
    end

    -- Early-out: must be clothing OR backpack
    if not (isClothingType or isBackpack) then
        return false
    end

    -- Body location (ItemBodyLocation, 42.13)
    local bodyLocation = scriptItem:getBodyLocation()
    if not TransmogDE.isTransmoggableBodylocation(bodyLocation) then
        --TmogPrint("Bodylocation [" .. tostring(bodyLocation) .. "] not transmogable for " .. "item [" .. tostring(item:getDisplayName()) .. "]")
        return false
    end

    -- Final gates
    if scriptItem:getModuleName() == "TransmogDE" then return false end
    if scriptItem.isHidden and scriptItem:isHidden() then return false end
    if scriptItem.isWorldRender and not scriptItem:isWorldRender() then return false end
    if scriptItem:getClothingItemAsset() == nil then return false end

    return true
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
    --_dbgTextureDump("createTransmogItem ENTER og", ogItem)
    local transmogModData = TransmogDE.getTransmogModData()
    local itemTmogModData = TransmogDE.getItemTransmogModData(ogItem)

    --_dbgTextureDump("createTransmogItem AFTER getItemTransmogModData og", ogItem)

    local tmogItemName = transmogModData.itemToTransmogMap[itemTmogModData.transmogTo]

    if not tmogItemName then
        return
    end

    local tmogItem = player:getInventory():AddItem(tmogItemName);
    -- MP: server must transmit the new inventory item to clients
    sendAddItemToContainer(player:getInventory(), tmogItem)

    -- set tmogItem as child of ogItem
    itemTmogModData.childId = tmogItem:getID()
    -- set ogItem as parent of tmogItem
    tmogItem:getModData()['TransmogParent'] = ogItem:getID()

    -- For debug purpose
    tmogItem:setName('Tmog: ' .. ogItem:getName())
    tmogItem:setCustomName(true)

    -- Cache once so we don't resample mid-apply
    local ogColor = TransmogDE.getClothingColor(ogItem)
    local ogTex   = TransmogDE.getClothingTexture(ogItem)

    TransmogDE.setClothingColorModdata(ogItem, ogColor)
    TransmogDE.setClothingTextureModdata(ogItem, ogTex)

    TransmogDE.setClothingColor(ogItem, ogColor)
    TransmogDE.setClothingTexture(ogItem, ogTex)

    TransmogDE.setClothingColor(tmogItem, ogColor)
    TransmogDE.setClothingTexture(tmogItem, ogTex)

    -- don't wear the new item yet
    -- player:setWornItem(tmogItem:getBodyLocation(), tmogItem)

    TmogPrint("createTransmogItem for " .. tostring(ogItem:getName()) .. " with ID: " .. tostring(tmogItem:getID()))
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
        return tmog
    end

    -- First-time initialization: capture how the item looks RIGHT NOW.
    local clothingItemAsset = TransmogDE.getClothingItemAsset(item:getScriptItem())
    local visual = item:getVisual()
    local colorObj = visual and visual.getTint and visual:getTint() or nil

    local baseTexture   = visual and visual.getBaseTexture and visual:getBaseTexture() or nil
    local textureChoice = visual and visual.getTextureChoice and visual:getTextureChoice() or nil

    -- Prefer baseTexture because getTextureChoice() is commonly -1 for "use base texture"
    local initialTexture = (baseTexture ~= nil and baseTexture ~= -1) and baseTexture or textureChoice

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
        originalTexture = initialTexture,

        -- Active/default look used by transmog logic (starts as original)
        color = originalColor and {
            r = originalColor.r,
            g = originalColor.g,
            b = originalColor.b,
            a = originalColor.a,
        } or nil,
        texture = initialTexture,

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
    -- if not container then return end
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
    TmogPrint("Attempt: Item[".. item:getDisplayName() .. "] to TextureIndex[" .. tostring(textureIdx) .. "]")
    if textureIdx == nil or textureIdx < 0 then
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
end

TransmogDE.setClothingTexture = function(item, textureIndex)
    if textureIndex == nil or textureIndex < 0 then
        return
    end

    if item:getClothingItem():hasModel() then
        item:getVisual():setTextureChoice(textureIndex)
    else
        item:getVisual():setBaseTexture(textureIndex)
    end

    item:synchWithVisual();
end

TransmogDE.getClothingColor = function(item)
    local itemModData = TransmogDE.getItemTransmogModData(item)
    local parsedColor = itemModData.color and
                            ImmutableColor.new(
            Color.new(itemModData.color.r, itemModData.color.g, itemModData.color.b, itemModData.color.a))
    return parsedColor or item:getVisual():getTint()
end

-- Returns ColorInfo or nil
TransmogDE.getClothingColorAsInfo = function(item)
    if not item then return nil end

    -- Prefer transmog modData if present
    local md = TransmogDE.getItemTransmogModData(item)
    local c  = md and md.color or nil

    if c and c.r and c.g and c.b then
        -- c.r/g/b/a are already floats 0..1 in your schema
        local a = (c.a ~= nil) and c.a or 1
        return ColorInfo.new(c.r, c.g, c.b, a)
    end

    -- Fallback to current visual tint (ImmutableColor)
    local tint = item:getVisual() and item:getVisual():getTint() or nil
    if tint then
        return ColorInfo.new(tint:getR(), tint:getG(), tint:getB(), tint:getA())
    end

    return nil
end

TransmogDE.getClothingTexture = function(item)
    local itemModData = TransmogDE.getItemTransmogModData(item)

    -- In Lua, -1 is truthy, but for visuals it means "no explicit choice".
    -- Treat negatives as unset and fall through to visual-derived texture.
    local t = itemModData.texture
    if t ~= nil and t >= 0 then
        return t
    end

    -- Very similiar to what is done inside: media\lua\client\OptionScreens\CharacterCreationMain.lua
    local clothingItem = item:getVisual():getClothingItem()
    local texture = clothingItem:hasModel()
        and item:getVisual():getTextureChoice()
        or  item:getVisual():getBaseTexture()

    -- If hasModel() path returns -1 (no choice), fall back to baseTexture
    if texture ~= nil and texture < 0 then
        texture = item:getVisual():getBaseTexture()
    end

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
    --local fromName = moddata.transmogTo and getItemNameFromFullType(moddata.transmogTo) or nil

    moddata.transmogTo = item:getScriptItem():getFullName()
    moddata.lastTransmogTo = item:getScriptItem():getFullName()

    -- Variant swaps can copy modData across, so never keep an old carrier link.
    moddata.childId = nil

    -- Only rebuild the carrier if we actually have one already.
    -- (When wearing a variant from inventory via ISClothingExtraAction there is no carrier yet.)
    local container = item:getContainer()
    local childId = tonumber(moddata.childId)
    if container and childId and container:getItemById(childId) then
        TransmogDE.forceUpdateClothing(item)
    end
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
TransmogDE.removeTransmog = function(item)
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
TransmogDE.setItemToDefault = function(item)
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
        --local immutable = ImmutableColor.new(c)
        --TransmogDE.setClothingColor(item, immutable)

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
        --item:getVisual():setTint(nil)
    end

    -- Apply default texture back onto the item visual.
    if defaultTexture ~= nil then
        --TransmogDE.setClothingTexture(item, defaultTexture)
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

    -- UI feedback is handled by TransmogNet.notifyPlayer

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

TransmogDE.setClothingHidden = function(item)
    if not item then
        return
    end
    local moddata = TransmogDE.getItemTransmogModData(item)

    if moddata.transmogTo ~= nil then
        moddata.lastTransmogTo = moddata.transmogTo
    end
    moddata.transmogTo = nil

    -- UI feedback is handled by TransmogNet.notifyPlayer

    TransmogDE.forceUpdateClothing(item)
end

TransmogDE.setClothingShown = function(item)
    local moddata = TransmogDE.getItemTransmogModData(item)

    if moddata.lastTransmogTo ~= nil then
        moddata.transmogTo = moddata.lastTransmogTo
    else
        item:getScriptItem():getFullName()
    end

    -- UI feedback is handled by TransmogNet.notifyPlayer

    TransmogDE.forceUpdateClothing(item)
end

TransmogDE.removeAllWornTransmogs = function(player)
    if not player then player = getPlayer() end

    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) then
            TransmogDE.removeTransmog(item, true)
            TransmogNet.updateItem(player, item)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

TransmogDE.resetDefaultAllWornTransmogs = function(player)
    if not player then player = getPlayer() end

    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) then
            TransmogDE.setItemToDefault(item, true)
            TransmogNet.updateItem(player, item)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

TransmogDE.hideAllWornTransmogs = function(player)
    if not player then player = getPlayer() end
    
    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) and (not TransmogDE.isClothingHidden(item)) then
            TransmogDE.setClothingHidden(item, true)
            TransmogNet.updateItem(player, item)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

TransmogDE.showAllWornTransmogs = function(player)
    if not player then player = getPlayer() end
    
    local wornItems = player:getWornItems()
    if not wornItems or not (wornItems:size() > 0) then
        return
    end

    for i = 0, wornItems:size() - 1 do
        local item = wornItems:getItemByIndex(i);
        if item and TransmogDE.isTransmoggable(item) and TransmogDE.isClothingHidden(item) then
            TransmogDE.setClothingShown(item, true)
            TransmogNet.updateItem(player, item)
        end
    end
    -- triggerEvent("OnClothingUpdated", player)
end

-- Converted from java\characters\WornItems\WornItems.java using chatgtp -> public void setItem(String var1, InventoryItem var2)
-- This is needed to avoid item clipping!
TransmogDE.setWornItemTmog = function(player, tmogItem)
    --TmogPrint("Attempting to set worn Item: " .. tostring(tmogItem))
    local wornItems = player:getWornItems()
    local group = getClassFieldVal(wornItems, getClassField(wornItems, 0));
    local items = getClassFieldVal(wornItems, getClassField(wornItems, 1));

    local ogItemBodylocation = TransmogDE.TmogItemToOgItemBodylocation[tmogItem:getScriptItem():getFullName()]
    if not ogItemBodylocation then
        --TmogPrint("setWornItemTmog ogItemBodylocation is nil")
        return
    end

    wornItems:remove(tmogItem)

    -- Use the ogItem bodyLoc, so that they are in the correct order, otherwise, we'll get clipping
    -- This ensures that for example, backpacks are on TOP of trousers

    local insertAt = items:size()
    --TmogPrint("setWornItemTmog insertAt [items:size]: " .. tostring(insertAt))
    for i = 0, items:size() - 1 do
        local wornItem = items:get(i)
        local wornItemItem = wornItem:getItem()
        if TransmogDE.isTransmogItem(wornItemItem) and not wornItemItem:hasTag(TransmogDE.ItemTag.Hide_Everything) then
            local wornOgItemLocation = TransmogDE.TmogItemToOgItemBodylocation[wornItemItem:getScriptItem()
                :getFullName()]
            --TmogPrint('wornOgitemLocation', wornOgItemLocation)
            --TmogPrint('ogItemBodylocation', ogItemBodylocation)
            if group:indexOf(wornOgItemLocation) > group:indexOf(ogItemBodylocation) then
                insertAt = i
                break
            end
        end
    end
    --TmogPrint("setWornItemTmog finally insertAt: " .. tostring(insertAt))
    local newWornItem = WornItem.new(TransmogDE.ItemBodyLocation.TransmogLocation, tmogItem)
    items:add(insertAt, newWornItem)
    --TmogPrint("setWornItemTmog final items:size: " .. tostring(items:size()))
end

-- Usefull for forcing the item to be removed and re-added after changing color, texture, and tmog
TransmogDE.forceUpdateClothing = function(item)
    TmogPrint("Attempting to forceUpdateClothing")

    --_dbgTextureDump("forceUpdateClothing ENTER", item)

    local moddata = TransmogDE.getItemTransmogModData(item)
    local container = item:getContainer()
    if not container then
        TmogPrint('forceUpdateClothing container is nil')
        return
    end

    local player = instanceof(container:getParent(), "IsoGameCharacter") and container:getParent()
    if not player then
        TmogPrint("forceUpdateClothing player missing!")
        return
    end

    local childId = tonumber(moddata.childId)
    if not childId then
        TmogPrint("forceUpdateClothing childId not numeric")
        return
    end

    -- find the item by ID, ensure it exists, then remove it from container and player
    local childItem = container:getItemById(childId)
    if not childItem then
        TmogPrint("forceUpdateClothing childItem missing!")
        return
    end

    -- Remove the old tmog item
    player:getWornItems():remove(childItem)
    container:Remove(childItem);
    sendRemoveItemFromContainer(container, childItem)

    -- Create and wear new tmog item
    local tmogItem = TransmogDE.createTransmogItem(item, player)
    if not tmogItem then
        TmogPrint("forceUpdateClothing tmogItem missing")
        return
    end

    if not TransmogDE.syncConditionVisualsForTmog(tmogItem) then
        TmogPrint("forceUpdateClothing tmogItem visuals not synced")
    end

    TransmogDE.setWornItemTmog(player, tmogItem)
    --_dbgTextureDump("forceUpdateClothing EXIT", item)
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
    --TmogPrint("syncConditionVisuals triggered for: " .. tostring(sourceItem))
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
    if tmogItem:hasTag(TransmogDE.ItemTag.Hide_Everything) then return false end
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