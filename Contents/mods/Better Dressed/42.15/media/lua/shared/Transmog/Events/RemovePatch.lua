local old_ISRemovePatch_complete = ISRemovePatch.complete
function ISRemovePatch:complete()
    local result = old_ISRemovePatch_complete(self)

    local player = self.character
    local item = self.clothing
    if player and item and TransmogDE.isTransmoggable(item) then
        TmogPrint('ISRemovePatch:complete()')
        TransmogNet.syncConditionVisualsToTmog(player, item)
    end
    return result
end