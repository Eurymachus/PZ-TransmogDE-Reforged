require "ISUI/ISInventoryPane"

local SECTION_KEY = "BetterContainers:EquippedAttachedSection"

local function hasHotbarAttachmentSlot(item)
    if not item then
        return false
    end

    local ok, attachedSlot = pcall(function()
        return item:getAttachedSlot()
    end)

    return ok
        and attachedSlot ~= nil
        and attachedSlot > -1
end

local function isHiddenDetachedAttachment(playerObj, item)
    if not playerObj or not item then
        return false
    end

    local md = item:getModData()
    local hidden = md and md.TransmogHiddenAttachment
    if not (hidden and hidden.location) then
        return false
    end

    if playerObj:isEquipped(item) then
        return false
    end

    if not hasHotbarAttachmentSlot(item) then
        return false
    end

    return playerObj:getAttachedItem(hidden.location) ~= item
end

local function collectHiddenDetachedAttachments(playerObj)
    local out = {}
    local inv = playerObj and playerObj:getInventory()
    local items = inv and inv:getItems()
    if not items then
        return out
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if isHiddenDetachedAttachment(playerObj, item) then
            out[#out + 1] = item
        end
    end

    return out
end

local function removeGroupedItemsFromStacks(pane, groupedSet)
    if not pane or not pane.itemslist or not groupedSet then
        return
    end

    local keptStacks = {}
    for _, stack in ipairs(pane.itemslist) do
        if stack and (stack._bcEquippedAttachedSeparator or stack._bcEquippedAttachedChild) then
            keptStacks[#keptStacks + 1] = stack
        else
            local keptItems = {}
            local weight = 0
            local stackItems = stack and stack.items
            for i = 2, stackItems and #stackItems or 0 do
                local item = stackItems[i]
                if item and not groupedSet[item] then
                    keptItems[#keptItems + 1] = item
                    weight = weight + item:getUnequippedWeight()
                end
            end

            if #keptItems > 0 then
                table.insert(keptItems, 1, keptItems[1])
                stack.items = keptItems
                stack.count = #keptItems
                stack.weight = weight
                stack.equipped = false
                keptStacks[#keptStacks + 1] = stack
            end
        end
    end

    pane.itemslist = keptStacks
end

local function findSection(pane)
    if not pane or not pane.itemslist then
        return nil, nil
    end

    for index, stack in ipairs(pane.itemslist) do
        if stack and stack._bcEquippedAttachedSeparator then
            return stack, index
        end
    end

    return nil, nil
end

local function buildItemStack(pane, item, index)
    local name = SECTION_KEY .. ":BetterDressedHidden:" .. tostring(index) .. ":" .. tostring(item)
    pane.collapsed[name] = true

    return {
        _bcEquippedAttachedChild = true,
        _transmogDEHiddenAttachmentChild = true,
        invPanel = pane,
        name = name,
        cat = item:getDisplayCategory() or item:getCategory(),
        count = 2,
        weight = item:getUnequippedWeight(),
        equipped = false,
        inHotbar = true,
        items = { item, item },
    }
end

local function injectHiddenAttachments(pane)
    if not pane or not pane.parent or not pane.parent.onCharacter then
        return
    end
    if not pane.itemslist or not pane.collapsed then
        return
    end

    local playerObj = getSpecificPlayer(pane.player)
    if not playerObj or pane.inventory ~= playerObj:getInventory() then
        return
    end

    local sectionStack, sectionIndex = findSection(pane)
    if not sectionStack then
        return
    end

    local hiddenItems = collectHiddenDetachedAttachments(playerObj)
    if #hiddenItems == 0 then
        return
    end

    local sectionItems = sectionStack._bcEquippedAttachedItems or {}
    sectionStack._bcEquippedAttachedItems = sectionItems

    local seen = {}
    for _, item in ipairs(sectionItems) do
        seen[item] = true
    end

    local groupedSet = {}
    local toAdd = {}
    for _, item in ipairs(hiddenItems) do
        groupedSet[item] = true
        if not seen[item] then
            seen[item] = true
            sectionItems[#sectionItems + 1] = item
            toAdd[#toAdd + 1] = item
        end
    end

    removeGroupedItemsFromStacks(pane, groupedSet)
    sectionStack, sectionIndex = findSection(pane)
    if not sectionStack then
        return
    end

    sectionStack._bcEquippedAttachedCount = #sectionItems
    if #toAdd == 0 or pane.bcEquippedAttachedCollapsed == true then
        return
    end

    local insertIndex = sectionIndex + 1
    while pane.itemslist[insertIndex] and pane.itemslist[insertIndex]._bcEquippedAttachedChild do
        insertIndex = insertIndex + 1
    end

    for index, item in ipairs(toAdd) do
        table.insert(pane.itemslist, insertIndex, buildItemStack(pane, item, index))
        insertIndex = insertIndex + 1
    end
end

local function patchBetterContainersEquippedItems()
    if not ISInventoryPane or ISInventoryPane.__TransmogDE_BetterContainersEquippedItemsPatch then
        return
    end

    local originalRefreshContainer = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self, ...)
        local result = originalRefreshContainer(self, ...)
        injectHiddenAttachments(self)
        if self.updateScrollbars then
            self:updateScrollbars()
        end
        return result
    end

    ISInventoryPane.__TransmogDE_BetterContainersEquippedItemsPatch = true
end

Events.OnGameStart.Add(patchBetterContainersEquippedItems)
