local old_ISClothingExtraAction_perform = ISClothingExtraAction.perform
function ISClothingExtraAction:perform()
    local result = old_ISClothingExtraAction_perform(self)

    TmogPrint('ISClothingExtraAction:perform()')
    TransmogDE.triggerUpdate(self.character)

    return result
end

------------------------------------------------------------
-- Was this item ACTUALLY transmogged?
-- True if transmogTo points to something other than its own type.
------------------------------------------------------------
local function _hadActiveTransmog(item)
    if not item then
        return false
    end

    local md = item:getModData()
    local tmog = md and md.Transmog or nil
    if not tmog or not tmog.transmogTo then
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

    return tmog.transmogTo ~= selfFullName
end

------------------------------------------------------------
-- createItem override:
--  - Preserve transmog on style swaps ONLY if it was active before.
--  - Otherwise, treat as clean variant change (no bogus transmog).
------------------------------------------------------------
local old_ISClothingExtraAction_createItem = ISClothingExtraAction.createItem

function ISClothingExtraAction:createItem(item, itemType)
    -- item  = original item (before style change)
    local hadTransmog = _hadActiveTransmog(item)

    local newItem = old_ISClothingExtraAction_createItem(self, item, itemType)
    if not newItem then
        TmogPrint('[TransmogDE] ISClothingExtraAction:createItem() no new item Created')
        return nil
    end

    local md = newItem:getModData()
    local tmog = md and md.Transmog or nil

    if hadTransmog and tmog then
        -- Original item was really transmogged:
        -- keep its mapping, but the carrier link is invalid for this new instance.
        tmog.childId = nil

        TmogPrint('[TransmogDE] ISClothingExtraAction:createItem() preserve active transmog on variant')
        -- Let our normal pipeline rebuild the carrier for this new item.
        TransmogDE.forceUpdateClothing(newItem)
        triggerEvent("TransmogClothingUpdate", self.character, newItem)
    else
        -- Original item was NOT transmogged (reset/default):
        -- this is just a style variant swap. Ensure the new item maps to itself,
        -- keeps its visuals, and has no stale carrier link.
        TmogPrint('[TransmogDE] ISClothingExtraAction:createItem() normalize non-transmog variant')
        TransmogDE.setTransmogToSelfKeepVisuals(newItem, true)
    end

    return newItem
end

LuaEventManager.AddEvent("TransmogClothingUpdate");