local old_ISWashClothing_complete = ISWashClothing.complete
function ISWashClothing:complete()
    local result = old_ISWashClothing_complete(self)

    local player = self.character
    local item = self.item
    if player and item and TransmogDE.isTransmoggable(item) then
        TmogPrint('ISWashClothing:complete()')
        TransmogNet.syncConditionVisualsToTmog(player, item)
    end

    return result
end