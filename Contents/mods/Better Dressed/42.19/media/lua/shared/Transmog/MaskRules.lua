-- /////////////////////////////////////////////////////////////////////////////
-- Visual masking rules
-- Key: visual "covering" BodyLocation
-- Value: list of visual BodyLocations that should be hidden if the covering
--        slot is visible.
--
-- NOTE:
--  * These are *visual* slots, i.e. what the player would see.
--  * The caller is responsible for deciding the visual slot
--    (original bodyLocation vs transmog target bodyLocation).
-- /////////////////////////////////////////////////////////////////////////////

local LEFTWRIST = "base:leftwrist"
local RIGHTWRIST = "base:rightwrist"
local FANNYPACK_BACK = "base:fannypackback"
local FANNYPACK_FRONT = "base:fannypackfront"
local SHORT_SLEEVE = "base:shortsleeveshirt"
local TANKTOP = "base:tanktop"
local JACKET_SUIT = "base:jacketsuit"
local JACKET = "base:jacket"
local SWEATER = "base:sweater"
local SWEATER_HAT = "base:sweaterhat"

local FALLBACK_ATTACHMENT_SLOT_DEFS = {
    SmallBeltLeft = {
        Knife = "Belt Left Upside",
        NotKnife = "Belt Left Upside",
        Hammer = "Belt Left",
        HammerRotated = "Belt Rotated Left",
        Nightstick = "Nightstick Left",
        Screwdriver = "Belt Left Screwdriver",
        Wrench = "Wrench Left",
        MeatCleaver = "MeatCleaver Belt Left",
        Walkie = "Walkie Belt Left",
        Sword = "Belt Left Upside",
    },
    SmallBeltRight = {
        Knife = "Belt Right Upside",
        NotKnife = "Belt Right Upside",
        Hammer = "Belt Right",
        HammerRotated = "Belt Rotated Right",
        Nightstick = "Nightstick Right",
        Screwdriver = "Belt Right Screwdriver",
        Wrench = "Wrench Right",
        MeatCleaver = "MeatCleaver Belt Right",
        Walkie = "Walkie Belt Right",
        Sword = "Belt Right Upside",
    },
    HolsterRight = {
        Holster = "Holster Right",
        HolsterSmall = "Holster Right",
    },
    HolsterLeft = {
        Holster = "Holster Left",
        HolsterSmall = "Holster Left",
    },
    HolsterShoulder = {
        Holster = "Holster Shoulder",
        HolsterSmall = "Holster Shoulder",
    },
    BedrollBottom = {
        Bedroll = "Bedroll Bottom",
    },
    BedrollBottomBig = {
        Bedroll = "Bedroll Bottom Big",
    },
    BedrollBottomALICE = {
        Bedroll = "Bedroll Bottom ALICE",
    },
    WebbingRight = {
        Knife = "Webbing Right Knife",
        Walkie = "Webbing Right Walkie",
        Webbing = "Webbing Right Walkie",
    },
    WebbingLeft = {
        Knife = "Webbing Left Knife",
        Walkie = "Webbing Left Walkie",
        Webbing = "Webbing Left Walkie",
    },
    HolsterAnkle = {
        HolsterSmall = "Holster Ankle",
    },
}

TransmogDE.VisualMaskRules = {
    -- Suit Jackets/Long Jackets
    [JACKET_SUIT] = {
        LEFTWRIST,
        RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Jackets
    [JACKET] = {
        LEFTWRIST,
        RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Sweaters and Hoodies
    [SWEATER] = {
        -- If we hide watches for Sweaters we hide them for Sweater Vests too
        -- LEFTWRIST,
        -- RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Hoodies with hood up
    [SWEATER_HAT] = {
        -- Ignore hiding watches for all Sweater types, it doesnt look too horrible
        -- LEFTWRIST,
        -- RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Short Sleeve Shirts
    [SHORT_SLEEVE] = {
        TANKTOP,
    },
}

-- Temporary test switch: keep vanilla BodyLocations hide rules active, but skip
-- Better Dressed's manual supplemental mask rules.
TransmogDE.EnableVisualMaskRules = false

local function addHiddenSlot(out, slot)
    if not slot then return end
    out[tostring(slot)] = true
    TmogPrint("Hides: " .. tostring(slot))
end

local function addVanillaHiddenSlots(out, coveringSlot)
    local group = BodyLocations and BodyLocations.getGroup and BodyLocations.getGroup("Human")
    if not group or not coveringSlot then return end

    local allLocations = group:getAllLocations()
    if not allLocations then return end

    local size = allLocations:size()
    for i = 0, size - 1 do
        local location = allLocations:get(i)
        local hiddenSlot = location and location:getId()

        if hiddenSlot and group:isHideModel(coveringSlot, hiddenSlot) then
            addHiddenSlot(out, hiddenSlot)
        end
    end
end

local function addAltSlot(out, slot)
    if not slot then return end
    out[tostring(slot)] = true
    TmogPrint("Alts: " .. tostring(slot))
end

local function addVanillaAltSlots(out, coveringSlot)
    local group = BodyLocations and BodyLocations.getGroup and BodyLocations.getGroup("Human")
    if not group or not coveringSlot then return end

    local allLocations = group:getAllLocations()
    if not allLocations then return end

    local size = allLocations:size()
    for i = 0, size - 1 do
        local location = allLocations:get(i)
        local altSlot = location and location:getId()

        if altSlot and group:isAltModel(coveringSlot, altSlot) then
            addAltSlot(out, altSlot)
        end
    end
end

local function getHotbarSlotDef(slotType)
    if ISHotbarAttachDefinition then
        for _, slotDef in ipairs(ISHotbarAttachDefinition) do
            if slotDef and slotDef.type == slotType then
                return slotDef
            end
        end
    end

    local fallbackAttachments = FALLBACK_ATTACHMENT_SLOT_DEFS[slotType]
    if fallbackAttachments then
        return { type = slotType, attachments = fallbackAttachments }
    end
end

local function getAttachedLocationNameSetForSlotType(slotType)
    local slotDef = getHotbarSlotDef(slotType)
    local out = {}

    if not slotDef or not slotDef.attachments then
        return out
    end

    for _, locationName in pairs(slotDef.attachments) do
        if locationName and locationName ~= "null" then
            out[tostring(locationName)] = true
        end
    end

    return out
end

local function addProvidedAttachmentSlotTypes(out, provided)
    if not out or not provided then
        return
    end

    if provided.size and provided.get then
        for i = 0, provided:size() - 1 do
            local slotType = provided:get(i)
            if slotType then
                out[tostring(slotType)] = true
            end
        end
        return
    end

    if type(provided) == "table" then
        for _, slotType in pairs(provided) do
            if slotType then
                out[tostring(slotType)] = true
            end
        end
    end
end

local function getItemAttachmentSlotTypes(item)
    local out = {}
    if not item or not item.getAttachmentsProvided then
        return out
    end

    local provided = item:getAttachmentsProvided()
    addProvidedAttachmentSlotTypes(out, provided)

    return out
end

local function getProvidedAttachmentLocationNameSet(item)
    local out = {}
    local provided = getItemAttachmentSlotTypes(item)

    for slotType, _ in pairs(provided) do
        local locationNames = getAttachedLocationNameSetForSlotType(slotType)
        for locationName, _ in pairs(locationNames) do
            out[locationName] = true
        end
    end

    return out
end

local function getScriptAttachmentSlotTypes(scriptItem)
    local out = {}
    if not scriptItem then
        return out
    end

    local provided = nil
    if scriptItem.getAttachmentsProvided then
        local ok, result = pcall(function()
            return scriptItem:getAttachmentsProvided()
        end)
        if ok then
            provided = result
        end
    end

    provided = provided or scriptItem.attachmentsProvided
    addProvidedAttachmentSlotTypes(out, provided)

    return out
end

local function getVisualTransmogFullType(item)
    if not item then return nil end
    if TransmogDE and TransmogDE.getItemTransmogModData and TransmogDE.isTransmoggable
        and TransmogDE.isTransmoggable(item) then

        local tmogData = TransmogDE.getItemTransmogModData(item)
        if tmogData and tmogData.transmogTo then
            return tmogData.transmogTo
        end
    end
end

local function getVisualAttachmentSlotTypes(item)
    local out = {}
    if not item then
        return out
    end

    local scriptItem = item:getScriptItem()
    local itemFullType = scriptItem and scriptItem:getFullName() or nil
    local visualFullType = getVisualTransmogFullType(item)

    if not visualFullType or visualFullType == itemFullType then
        return getItemAttachmentSlotTypes(item)
    end

    local visualItem = nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, result = pcall(function()
            return InventoryItemFactory.CreateItem(visualFullType)
        end)
        if ok then
            visualItem = result
        end
    end

    if visualItem then
        return getItemAttachmentSlotTypes(visualItem)
    end

    local sm = getScriptManager()
    local targetScriptItem = sm and sm:FindItem(visualFullType) or nil
    if targetScriptItem then
        return getScriptAttachmentSlotTypes(targetScriptItem)
    end

    return out
end

local function getAttachmentLocationName(attachedItems, attachedItem)
    if not attachedItem then return nil end

    if attachedItem.getLocation then
        return attachedItem:getLocation()
    end

    local item = attachedItem.getItem and attachedItem:getItem() or nil
    if attachedItems and item and attachedItems.getLocation then
        return attachedItems:getLocation(item)
    end
end

local function sendAttachedItemUpdate(player, location, item)
    if isServer() and sendAttachedItem then
        sendAttachedItem(player, location, item)
    end
end

local function refreshAttachedModels(player)
    if not player then
        return
    end

    if player.resetEquippedHandsModels then
        player:resetEquippedHandsModels()
    end

    if player.resetModelNextFrame then
        player:resetModelNextFrame()
    end
end

local function captureHiddenAttachmentVisual(item)
    local md = item and item:getModData()
    if not md then
        return nil
    end

    local visual = md.TransmogHiddenAttachmentVisual
    if visual and visual.captured == true then
        return visual
    end

    visual = {
        captured = true,
        staticModel = item.getStaticModel and item:getStaticModel() or nil,
        worldStaticModel = item.getWorldStaticModel and item:getWorldStaticModel() or nil,
        weaponSprite = item.getWeaponSprite and item:getWeaponSprite() or nil,
        hadStaticModelOverride = rawget(md, "staticModel") ~= nil,
        staticModelOverride = rawget(md, "staticModel"),
        hadWorldStaticModelOverride = rawget(md, "worldStaticModel") ~= nil,
        worldStaticModelOverride = rawget(md, "worldStaticModel"),
    }

    md.TransmogHiddenAttachmentVisual = visual
    return visual
end

local function applyHiddenAttachmentVisual(item)
    if not item then
        return false
    end

    local visual = captureHiddenAttachmentVisual(item)
    local wasApplied = visual and visual.applied == true

    if item.setStaticModel then
        item:setStaticModel("")
    end
    if item.setWorldStaticModel then
        item:setWorldStaticModel("")
    end
    if item.setWeaponSprite then
        item:setWeaponSprite("")
    end

    if visual then
        visual.applied = true
    end

    return not wasApplied
end

local function restoreHiddenAttachmentVisual(item)
    local md = item and item:getModData()
    local visual = md and md.TransmogHiddenAttachmentVisual
    if not visual then
        return
    end

    if item.setStaticModel then
        if visual.hadStaticModelOverride then
            item:setStaticModel(visual.staticModelOverride)
        else
            rawset(md, "staticModel", nil)
        end
    end

    if item.setWorldStaticModel then
        if visual.hadWorldStaticModelOverride then
            item:setWorldStaticModel(visual.worldStaticModelOverride)
        else
            rawset(md, "worldStaticModel", nil)
        end
    end

    if item.setWeaponSprite then
        item:setWeaponSprite(visual.weaponSprite)
    end

    md.TransmogHiddenAttachmentVisual = nil
end

local function shouldKeepHiddenAttachmentAttached(item)
    return item
        and item.canEmitLight
        and item:canEmitLight()
        and item:getType() ~= "CandleLit"
        and item:getType() ~= "Lantern_HurricaneLit"
        and not instanceof(item, "HandWeapon")
end

local function restoreTransmogHiddenAttachment(player, item)
    if not player or not item then return false end

    local md = item:getModData()
    local hidden = md and md.TransmogHiddenAttachment
    if not hidden then
        return false
    end

    local location = hidden.location
    local equipped = player:isEquipped(item)
    local refreshed = false
    md.TransmogHiddenAttachment = nil

    if equipped then
        player:removeAttachedItem(item)
        refreshAttachedModels(player)
        refreshed = true
    end

    restoreHiddenAttachmentVisual(item)

    if location and not equipped then
        item:setAttachedToModel(location)
        player:setAttachedItem(location, item)
    end

    syncItemModData(player, item)
    if not refreshed then
        refreshAttachedModels(player)
    end

    return true
end

local function tableHasAny(tbl)
    if not tbl then
        return false
    end

    for _, _ in pairs(tbl) do
        return true
    end

    return false
end

local function hideTransmogAttachment(player, item, location, hiddenSlotTypes, manual, allowLocationMatch)
    if not player or not item or not location then return false end

    local slotType = item:getAttachedSlotType()
    if not allowLocationMatch and (not slotType or not hiddenSlotTypes[tostring(slotType)]) then
        return false
    end

    local md = item:getModData()
    if md.TransmogHiddenAttachment then
        if manual == true then
            md.TransmogHiddenAttachment.manual = true
            md.TransmogAttachmentForceVisible = nil
        end
        return false
    end

    md.TransmogHiddenAttachment = {
        location = location,
        slotType = slotType,
        manual = manual == true,
        locationMatched = allowLocationMatch == true,
    }
    md.TransmogAttachmentForceVisible = nil

    applyHiddenAttachmentVisual(item)
    item:setAttachedToModel(location)
    if shouldKeepHiddenAttachmentAttached(item) then
        player:setAttachedItem(location, item)
    else
        player:removeAttachedItem(item)
    end
    syncItemModData(player, item)
    refreshAttachedModels(player)

    return true
end

function TransmogDE.syncHiddenProvidedAttachments(player, hiddenProviderSlotTypes, visibleProviderSlotTypes)
    if not player or not hiddenProviderSlotTypes then
        return
    end

    local inv = player:getInventory()
    local attachedItems = player:getAttachedItems()
    if not inv or not attachedItems then
        return
    end

    local changed = false
    local effectiveHiddenProviderSlotTypes = {}
    local locationNamesToHide = {}

    local explicitHiddenLocations = hiddenProviderSlotTypes.__locations
    if explicitHiddenLocations then
        for locationName, _ in pairs(explicitHiddenLocations) do
            locationNamesToHide[locationName] = true
        end
    end

    for slotType, _ in pairs(hiddenProviderSlotTypes) do
        if slotType ~= "__locations" then
        if not (visibleProviderSlotTypes and visibleProviderSlotTypes[slotType]) then
            effectiveHiddenProviderSlotTypes[slotType] = true

            local locationNames = getAttachedLocationNameSetForSlotType(slotType)
            for locationName, _ in pairs(locationNames) do
                locationNamesToHide[locationName] = true
            end
        end
        end
    end

    local attachedToHide = {}
    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local item = attachedItem and attachedItem:getItem()
        local location = getAttachmentLocationName(attachedItems, attachedItem)
        local slotType = item and item:getAttachedSlotType()
        local md = item and item:getModData()
        local providedSlotHidden = slotType and effectiveHiddenProviderSlotTypes[tostring(slotType)]
        local forceVisible = md and md.TransmogAttachmentForceVisible == true
        local locationHidden = location and locationNamesToHide[location] == true
        if item and location and not forceVisible and (providedSlotHidden or locationHidden) then
            table.insert(attachedToHide, {
                item = item,
                location = location,
                locationMatched = locationHidden and not providedSlotHidden,
            })
        end
    end

    for _, entry in ipairs(attachedToHide) do
        if hideTransmogAttachment(player, entry.item, entry.location, effectiveHiddenProviderSlotTypes, false, entry.locationMatched) then
            changed = true
        end
    end

    local items = inv:getItems()
    local hasEffectiveHiddenProviders = tableHasAny(effectiveHiddenProviderSlotTypes) or tableHasAny(locationNamesToHide)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local md = item and item:getModData()
        local hidden = md and md.TransmogHiddenAttachment
        local slotType = hidden and tostring(hidden.slotType) or nil
        local forceVisible = md and md.TransmogAttachmentForceVisible == true
        local hiddenLocation = hidden and hidden.location
        local hiddenBySlotType = slotType and effectiveHiddenProviderSlotTypes[slotType] == true
        local hiddenByLocation = hiddenLocation and locationNamesToHide[hiddenLocation] == true
        if hidden then
            applyHiddenAttachmentVisual(item)
            if shouldKeepHiddenAttachmentAttached(item)
                and hiddenLocation
                and not player:isEquipped(item)
                and player:getAttachedItem(hiddenLocation) ~= item then
                item:setAttachedToModel(hiddenLocation)
                player:setAttachedItem(hiddenLocation, item)
                changed = true
            end
        end
        if hidden
            and (forceVisible or hidden.manual ~= true)
            and (forceVisible or not hiddenBySlotType)
            and (forceVisible or not hiddenByLocation)
            and (forceVisible or not hasEffectiveHiddenProviders or not visibleProviderSlotTypes or visibleProviderSlotTypes[slotType]) then
            if restoreTransmogHiddenAttachment(player, item) then
                changed = true
            end
        end
    end

    if changed then
        local hotbar = getPlayerHotbar and getPlayerHotbar(player:getPlayerNum()) or nil
        if hotbar then
            hotbar.needsRefresh = true
            if hotbar.reloadIcons then
                hotbar:reloadIcons()
            end
        end
        if ISInventoryPage then
            ISInventoryPage.renderDirty = true
        end
    end
end

function TransmogDE.isAttachedItem(player, item)
    if not player or not item then
        return false
    end

    local attachedItems = player:getAttachedItems()
    if not attachedItems then
        return false
    end

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        if attachedItem and attachedItem:getItem() == item then
            return true
        end
    end

    return false
end

function TransmogDE.isAttachmentModelHidden(item)
    local md = item and item:getModData()
    return md and md.TransmogHiddenAttachment ~= nil
end

function TransmogDE.isAttachedOrHiddenAttachment(player, item)
    if TransmogDE.isAttachmentModelHidden and TransmogDE.isAttachmentModelHidden(item) then
        return true
    end

    return TransmogDE.isAttachedItem and TransmogDE.isAttachedItem(player, item) or false
end

function TransmogDE.hideAttachmentModel(player, item)
    if not player or not item then
        return false
    end

    local attachedItems = player:getAttachedItems()
    if not attachedItems then
        return false
    end

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        if attachedItem and attachedItem:getItem() == item then
            local location = getAttachmentLocationName(attachedItems, attachedItem)
            local slotType = item:getAttachedSlotType()
            if not slotType then
                return false
            end
            return hideTransmogAttachment(player, item, location, { [tostring(slotType)] = true }, true, false)
        end
    end

    return false
end

function TransmogDE.showAttachmentModel(player, item)
    if not player or not item then
        return false
    end

    local md = item:getModData()
    md.TransmogAttachmentForceVisible = true

    if restoreTransmogHiddenAttachment(player, item) then
        return true
    end

    refreshAttachedModels(player)
    return true
end

function TransmogDE.hideProvidedAttachmentSlots(player, providerItem)
    if not player or not providerItem then
        return false
    end

    local attachedItems = player:getAttachedItems()
    if not attachedItems then
        return false
    end

    local providerLocations = getProvidedAttachmentLocationNameSet(providerItem)
    local changed = false
    local toHide = {}

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local item = attachedItem and attachedItem:getItem()
        local location = getAttachmentLocationName(attachedItems, attachedItem)
        if item and location and providerLocations[location] then
            table.insert(toHide, { item = item, location = location })
        end
    end

    for _, entry in ipairs(toHide) do
        local slotType = entry.item:getAttachedSlotType()
        local hiddenSlotTypes = {}
        if slotType then
            hiddenSlotTypes[tostring(slotType)] = true
        end

        if hideTransmogAttachment(player, entry.item, entry.location, hiddenSlotTypes, false, true) then
            changed = true
        end
    end

    return changed
end

function TransmogDE.restoreProvidedAttachmentSlots(player, providerItem)
    if not player or not providerItem then
        return false
    end

    local inv = player:getInventory()
    if not inv then
        return false
    end

    local providerLocations = getProvidedAttachmentLocationNameSet(providerItem)
    local changed = false
    local items = inv:getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local md = item and item:getModData()
        local hidden = md and md.TransmogHiddenAttachment
        if hidden and hidden.location and providerLocations[hidden.location] then
            if restoreTransmogHiddenAttachment(player, item) then
                changed = true
            end
        end
    end

    return changed
end

function TransmogDE.addHiddenProvidedAttachmentSlots(out, item)
    if not out or not item then
        return
    end

    local attachments = TransmogDE.getAttachmentTransmogModData and TransmogDE.getAttachmentTransmogModData(item) or nil
    local slots = attachments and attachments.slots or nil
    if not slots then
        return
    end

    out.__locations = out.__locations or {}

    for locationName, visible in pairs(slots) do
        if locationName ~= "__all" and visible == false then
            out.__locations[locationName] = true
        end
    end

    if slots.__all == false then
        local locations = getProvidedAttachmentLocationNameSet(item)
        for locationName, _ in pairs(locations) do
            out.__locations[locationName] = true
        end
    end
end

function TransmogDE.setProvidedAttachmentSlotsHidden(item)
    local attachments = TransmogDE.getAttachmentTransmogModData and TransmogDE.getAttachmentTransmogModData(item) or nil
    if not attachments then
        return
    end

    attachments.slots = {}

    local locations = getProvidedAttachmentLocationNameSet(item)
    for locationName, _ in pairs(locations) do
        attachments.slots[locationName] = false
    end
end

function TransmogDE.hasProvidedAttachmentSlots(item)
    if not item then
        return false
    end

    local provided = getItemAttachmentSlotTypes(item)
    for _, _ in pairs(provided) do
        return true
    end

    return false
end

function TransmogDE.addVisibleProvidedAttachmentSlots(out, item)
    if not out or not item then
        return
    end

    local provided = getVisualAttachmentSlotTypes(item)
    for slotType, _ in pairs(provided) do
        out[slotType] = true
    end
end

local function patchHotbarHiddenAttachments()
    if not ISHotbar or ISHotbar.__TransmogDE_HiddenAttachmentPatch then
        return
    end

    local originalUpdate = ISHotbar.update
    ISHotbar.update = function(self)
        local hiddenItems = nil
        if self and self.attachedItems and self.chr then
            hiddenItems = {}
            for slotIndex, item in pairs(self.attachedItems) do
                local md = item and item:getModData()
                if md and md.TransmogHiddenAttachment then
                    if md.TransmogHiddenAttachment.location and item:getAttachedToModel() == nil then
                        item:setAttachedToModel(md.TransmogHiddenAttachment.location)
                    end
                    if shouldKeepHiddenAttachmentAttached(item) and not self.chr:isEquipped(item) then
                        applyHiddenAttachmentVisual(item)
                    else
                        hiddenItems[slotIndex] = item
                        self.attachedItems[slotIndex] = nil
                        self.chr:removeAttachedItem(item)
                    end
                end
            end
        end

        local result = originalUpdate(self)

        if hiddenItems and self and self.attachedItems then
            for slotIndex, item in pairs(hiddenItems) do
                if item:getAttachedSlot() == slotIndex then
                    self.attachedItems[slotIndex] = item
                end
            end
        end

        return result
    end

    ISHotbar.__TransmogDE_HiddenAttachmentPatch = true
end

local function repairHiddenAttachmentLocation(item)
    local md = item and item:getModData()
    local hidden = md and md.TransmogHiddenAttachment
    if hidden and hidden.location and item:getAttachedToModel() == nil then
        item:setAttachedToModel(hidden.location)
    end
end

local function enforceHiddenAttachmentDetached(player, item)
    local md = item and item:getModData()
    if player and md and md.TransmogHiddenAttachment then
        if shouldKeepHiddenAttachmentAttached(item)
            and md.TransmogHiddenAttachment.location
            and not player:isEquipped(item) then
            applyHiddenAttachmentVisual(item)
            item:setAttachedToModel(md.TransmogHiddenAttachment.location)
            player:setAttachedItem(md.TransmogHiddenAttachment.location, item)
        else
            player:removeAttachedItem(item)
        end
        refreshAttachedModels(player)
    end
end

local function patchUnequipHiddenAttachments()
    if not ISUnequipAction or ISUnequipAction.__TransmogDE_HiddenAttachmentPatch then
        return
    end

    local originalAnimEvent = ISUnequipAction.animEvent
    ISUnequipAction.animEvent = function(self, event, parameter)
        if self and self.item then
            repairHiddenAttachmentLocation(self.item)
        end
        local result = originalAnimEvent(self, event, parameter)
        if self and self.item then
            enforceHiddenAttachmentDetached(self.character, self.item)
        end
        return result
    end

    local originalPerform = ISUnequipAction.perform
    ISUnequipAction.perform = function(self)
        if self and self.item then
            repairHiddenAttachmentLocation(self.item)
        end
        local result = originalPerform(self)
        if self and self.item then
            enforceHiddenAttachmentDetached(self.character, self.item)
        end
        return result
    end

    ISUnequipAction.__TransmogDE_HiddenAttachmentPatch = true
end

local function isToggleableLight(item)
    return shouldKeepHiddenAttachmentAttached(item)
        and not instanceof(item, "HandWeapon")
        and item.canBeActivated
        and item:canBeActivated()
end

local function getHiddenAttachmentLight(player)
    local inv = player and player:getInventory()
    local items = inv and inv:getItems()
    if not items then
        return nil
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local md = item and item:getModData()
        if md and md.TransmogHiddenAttachment and isToggleableLight(item) then
            return item
        end
    end
end

local function toggleLightItem(player, item)
    local md = item and item:getModData()
    local hidden = md and md.TransmogHiddenAttachment
    if hidden and hidden.location and shouldKeepHiddenAttachmentAttached(item) and not player:isEquipped(item) then
        applyHiddenAttachmentVisual(item)
        item:setAttachedToModel(hidden.location)
        if player:getAttachedItem(hidden.location) ~= item then
            player:setAttachedItem(hidden.location, item)
            refreshAttachedModels(player)
        end
    end

    item:setActivated(not item:isActivated())
    if syncItemActivated then
        syncItemActivated(player, item)
    end
    item:playActivateDeactivateSound()
end

local function patchItemBindingHiddenAttachmentLights()
    if not ItemBindingHandler or ItemBindingHandler.__TransmogDE_HiddenAttachmentPatch then
        return
    end

    ItemBindingHandler.toggleLight = function(key)
        local playerObj = getSpecificPlayer(0)
        if not playerObj then
            return
        end

        if getCore():isKey("ToggleVehicleHeadlights", key) then
            local vehicle = playerObj:getVehicle()
            if vehicle and vehicle:isDriver(playerObj) and not playerObj:isAiming() then
                if vehicle:hasHeadlights() then
                    ISVehicleMenu.onToggleHeadlights(playerObj)
                end
                return
            end
        end

        local secondary = playerObj:getSecondaryHandItem()
        if isToggleableLight(secondary) or (secondary and secondary:canEmitLight()
            and secondary:getType() ~= "CandleLit"
            and secondary:getType() ~= "Lantern_HurricaneLit"
            and secondary:canBeActivated()) then
            toggleLightItem(playerObj, secondary)
            return
        end

        local primary = playerObj:getPrimaryHandItem()
        if isToggleableLight(primary) or (primary and primary:canEmitLight()
            and primary:getType() ~= "CandleLit"
            and primary:getType() ~= "Lantern_HurricaneLit"
            and primary:canBeActivated()) then
            toggleLightItem(playerObj, primary)
            return
        end

        local attachedItems = playerObj:getAttachedItems()
        for i = 1, attachedItems:size() do
            local item = attachedItems:getItemByIndex(i - 1)
            if isToggleableLight(item) then
                toggleLightItem(playerObj, item)
                return
            end
        end

        local hiddenLight = getHiddenAttachmentLight(playerObj)
        if hiddenLight then
            toggleLightItem(playerObj, hiddenLight)
            return
        end

        if playerObj:isAiming() then return end
        local function predicateLightSource(item)
            return item:canEmitLight() and (item:getLightStrength() > 0)
        end
        local function compareLightStrength(a, b)
            return a:getLightStrength() - b:getLightStrength()
        end
        local lightSource = playerObj:getInventory():getBestEvalRecurse(predicateLightSource, compareLightStrength)
        if lightSource ~= nil then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, lightSource)
            ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, lightSource, 50, instanceof(lightSource, "HandWeapon"), false))
        end
    end

    ItemBindingHandler.__TransmogDE_HiddenAttachmentPatch = true
end

Events.OnGameStart.Add(patchHotbarHiddenAttachments)
Events.OnGameStart.Add(patchUnequipHiddenAttachments)
Events.OnGameStart.Add(patchItemBindingHiddenAttachmentLights)

--- Add a new visual masking rule.
-- @param coveringSlot string  BodyLocation of the covering visual slot (e.g. "Jacket")
-- @param hiddenSlot   string  BodyLocation of the visual slot to hide (e.g. "FannyPackFront")
function TransmogDE.addVisualMaskRule(coveringSlot, hiddenSlot)
    if not coveringSlot or not hiddenSlot then return end

    local rules = TransmogDE.VisualMaskRules
    rules[coveringSlot] = rules[coveringSlot] or {}

    -- Avoid duplicates
    for _, existing in ipairs(rules[coveringSlot]) do
        if existing == hiddenSlot then
            return
        end
    end

    table.insert(rules[coveringSlot], hiddenSlot)
end

-- Return the *visual* BodyLocation for a given worn item.
-- This respects TransmogDE state:
--   * if the item is transmogged, we return the BodyLocation of the transmog target
--   * otherwise we return the item's own BodyLocation.
function TransmogDE.getItemVisualBodyLocation(item)
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

--- Get all visual slots that should be hidden when a given covering slot is visible.
-- @param coveringSlot string BodyLocation of the covering visual slot.
-- @return table<string, boolean>  Set-style table of hidden slots, e.g. { FannyPackFront = true, ... }
function TransmogDE.getHiddenVisualSlotsForCovering(item)
    local coveringSlot = TransmogDE.getItemVisualBodyLocation(item)
    local coveringSlotString = tostring(coveringSlot)
    TmogPrint("Slot name: " .. coveringSlotString)
    if coveringSlot then
        local out = {}

        addVanillaHiddenSlots(out, coveringSlot)

        if TransmogDE.EnableVisualMaskRules ~= false then
            local rules = TransmogDE.VisualMaskRules[coveringSlotString]
            if rules then
                for _, slot in ipairs(rules) do
                    addHiddenSlot(out, slot)
                end
            end
        end

        return out
    end
end

function TransmogDE.getAltVisualSlotsForCovering(item)
    local coveringSlot = TransmogDE.getItemVisualBodyLocation(item)
    local coveringSlotString = tostring(coveringSlot)
    TmogPrint("Alt slot name: " .. coveringSlotString)
    if coveringSlot then
        local out = {}
        addVanillaAltSlots(out, coveringSlot)
        return out
    end
end
