TransmogClient = TransmogClient or {}
TransmogClient._modDataRequestDone = {}

TransmogClient.requestTransmogModData = function()
    TmogPrint('requestTransmogModData')

    ModData.request("TransmogModData")
end

TransmogClient.requestTransmogDataNew = function(player, playerNum)
    TransmogClient._modDataRequestDone[playerNum] = true
    if isClient() then
        TmogPrint("send REQUEST_MODDATA p=" .. tostring(playerNum))
        sendClientCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.REQUEST_MODDATA, {})
        return
    end

    local modData = TransmogDE.GenerateTransmogGlobalModData()
    TransmogDE.patchAllItemsFromModData(modData)
end

TransmogClient.onReceiveGlobalModData = function(module, packet)
    TmogPrint('onReceiveGlobalModData: ' .. module .. tostring(packet))
    if module ~= "TransmogModData" or not packet then
        return
    end

    ModData.add("TransmogModData", packet)

    TransmogDE.patchAllItemsFromModData(packet)
end

return TransmogClient
