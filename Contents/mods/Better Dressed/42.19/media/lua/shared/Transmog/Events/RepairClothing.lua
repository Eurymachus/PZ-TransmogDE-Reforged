local old_ISRepairClothing_complete = ISRepairClothing.complete
function ISRepairClothing:complete()
    local result = old_ISRepairClothing_complete(self)

    local player = self.character
    local item = self.clothing
    if player and item and TransmogDE.isTransmoggable(item) then
        TmogPrint('ISRepairClothing:complete()')
        TransmogNet.syncConditionVisualsToTmog(player, item)
    end
    return result
end