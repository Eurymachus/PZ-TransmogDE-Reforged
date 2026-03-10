require("TransmogDE")

Events.OnServerStarted.Add(function()
    local moddata = TransmogDE.GenerateTransmogGlobalModData()
    TransmogDE.patchAllItemsFromModData(moddata)
end)