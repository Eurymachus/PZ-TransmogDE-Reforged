local old_ISClothingExtraAction_perform = ISClothingExtraAction.perform
function ISClothingExtraAction:perform()
    local result = old_ISClothingExtraAction_perform(self)

    TmogPrint('ISClothingExtraAction:perform()')

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
    if isClient() then
        TmogPrint("ClothingExtraAction MP skip on Client")
        return
    end
    TmogPrint("ClothingExtraAction Fired")
    -- item  = original item (before style change)
    local hadTransmog = _hadActiveTransmog(item)

    local newItem = old_ISClothingExtraAction_createItem(self, item, itemType)
    if not newItem then
        TmogPrint('[TransmogDE] ISClothingExtraAction:createItem() no new item Created')
        return nil
    end
    self._transmogData = {}
    self._transmogData.newItem = newItem
    self._transmogData.hadTransmog = hadTransmog

    return newItem
end

local old_ISClothingExtraAction_complete = ISClothingExtraAction.complete

function ISClothingExtraAction:complete()
    local result = old_ISClothingExtraAction_complete(self)
    if result then
        if not isClient() and self._transmogData then
            local item = self._transmogData.newItem
            local md = item:getModData()
            local tmog = md and md.Transmog or nil
            if self._transmogData.hadTransmog and tmog then
                tmog.childId = nil

                TmogPrint('[TransmogDE] ISClothingExtraAction:createItem() preserve active transmog on variant')
                -- Let our normal pipeline rebuild the carrier for this new item.
                TransmogDE.forceUpdateClothing(item)
                TransmogNet.triggerUpdate(self.character, item)
            else
                -- Original item was NOT transmogged (reset/default):
                -- this is just a style variant swap. Ensure the new item maps to itself,
                -- keeps its visuals, and has no stale carrier link.
                TmogPrint('[TransmogDE] ISClothingExtraAction:createItem() normalize non-transmog variant')
                TransmogDE.setTransmogToSelfKeepVisuals(item, true)
                TransmogNet.triggerUpdate(self.character, item)
            end
        end
    end
    return result
end

LuaEventManager.AddEvent("TransmogClothingUpdate");