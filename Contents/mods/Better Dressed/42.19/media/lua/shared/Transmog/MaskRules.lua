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
    if player and player.resetEquippedHandsModels then
        player:resetEquippedHandsModels()
    elseif player and player.resetModelNextFrame then
        player:resetModelNextFrame()
    end
end

local function restoreTransmogHiddenAttachment(player, item)
    if not player or not item then return false end

    local md = item:getModData()
    local hidden = md and md.TransmogHiddenAttachment
    if not hidden then
        return false
    end

    if hidden.hadStaticModelOverride then
        item:setStaticModel(hidden.staticModel)
    else
        md.staticModel = nil
    end

    if hidden.hadWorldStaticModelOverride then
        item:setWorldStaticModel(hidden.worldStaticModel)
    else
        md.worldStaticModel = nil
    end

    md.TransmogHiddenAttachment = nil
    syncItemFields(player, item)
    refreshAttachedModels(player)

    return true
end

local function hideTransmogAttachment(player, item, location, hiddenSlotTypes)
    if not player or not item or not location then return false end

    local slotType = item:getAttachedSlotType()
    if not slotType or not hiddenSlotTypes[tostring(slotType)] then
        return false
    end

    local md = item:getModData()
    if md.TransmogHiddenAttachment then
        return false
    end

    md.TransmogHiddenAttachment = {
        location = location,
        slotType = slotType,
        staticModel = md.staticModel,
        worldStaticModel = md.worldStaticModel,
        hadStaticModelOverride = md.staticModel ~= nil,
        hadWorldStaticModelOverride = md.worldStaticModel ~= nil,
    }

    item:setStaticModel("")
    item:setWorldStaticModel("")
    syncItemFields(player, item)
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

    for slotType, _ in pairs(hiddenProviderSlotTypes) do
        if not (visibleProviderSlotTypes and visibleProviderSlotTypes[slotType]) then
            effectiveHiddenProviderSlotTypes[slotType] = true

            local locationNames = getAttachedLocationNameSetForSlotType(slotType)
            for locationName, _ in pairs(locationNames) do
                locationNamesToHide[locationName] = true
            end
        end
    end

    local attachedToHide = {}
    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local item = attachedItem and attachedItem:getItem()
        local location = getAttachmentLocationName(attachedItems, attachedItem)
        local slotType = item and item:getAttachedSlotType()
        local providedSlotHidden = slotType and effectiveHiddenProviderSlotTypes[tostring(slotType)]
        if item and location and (providedSlotHidden or locationNamesToHide[location]) then
            table.insert(attachedToHide, { item = item, location = location })
        end
    end

    for _, entry in ipairs(attachedToHide) do
        if hideTransmogAttachment(player, entry.item, entry.location, effectiveHiddenProviderSlotTypes) then
            changed = true
        end
    end

    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local md = item and item:getModData()
        local hidden = md and md.TransmogHiddenAttachment
        local slotType = hidden and tostring(hidden.slotType) or nil
        if hidden
            and not effectiveHiddenProviderSlotTypes[slotType]
            and (not visibleProviderSlotTypes or visibleProviderSlotTypes[slotType]) then
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

function TransmogDE.addHiddenProvidedAttachmentSlots(out, item)
    if not out or not item then
        return
    end

    local provided = getItemAttachmentSlotTypes(item)
    for slotType, _ in pairs(provided) do
        out[slotType] = true
    end
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
