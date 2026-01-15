local old_ISWashClothing_complete = ISWashClothing.complete
function ISWashClothing:complete()
    local result = old_ISWashClothing_complete(self)

    TmogPrint('ISWashClothing:complete()')
    local player = self.character
    local item = self.item
    if player and item and instanceof(item, "Clothing") then
        local tmog = TransmogDE.getTransmogChild(item)
        if tmog then
            TransmogDE.syncConditionVisualsForTmog(tmog)
            if not isServer() then
                player:resetModelNextFrame()
            end
        end
    else
        -- triggerEvent("SyncConditionVisuals", player)
    end

    return result
end