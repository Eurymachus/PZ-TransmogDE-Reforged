local _orig_ISWearClothing_complete = ISWearClothing.complete
function ISWearClothing:complete()
    -- run the original behavior first
    local result = _orig_ISWearClothing_complete(self)

    -- After vanilla equips the item, defer our sync one tick.
    if self.character then
        TransmogNet.triggerUpdate(self.character, self.item)
    end

    return result
end