local old_ISRepairClothing_complete = ISRepairClothing.complete
function ISRepairClothing:complete()
    local result = old_ISRepairClothing_complete(self)

    TmogPrint('ISRepairClothing:complete()')
    local player = self.character
    local item = self.clothing
    --[[
    if player and item and item:isEquipped() then
        local tmog = TransmogDE.getTransmogChild(item)
        if tmog then
            TransmogDE.syncConditionVisualsForTmog(tmog)
            if not isServer() then
                player:resetModelNextFrame()
            end
        end
    else
        TransmogDE.triggerUpdate(player)
    end
    ]]
    TransmogNet.triggerUpdate(player, item)
    return result
end