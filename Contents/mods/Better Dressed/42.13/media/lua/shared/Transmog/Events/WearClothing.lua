local _orig_ISWearClothing_complete = ISWearClothing.complete
function ISWearClothing:complete()
    -- run the original behavior first
    local result = _orig_ISWearClothing_complete(self)

    local player = self.character
    local item = self.item
    if player and item then
        TmogPrint('ISWearClothing:complete()')
        TransmogNet.triggerUpdate(player, item)
    end

    return result
end