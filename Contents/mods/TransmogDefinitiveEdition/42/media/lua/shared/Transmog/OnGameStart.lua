local TransmogClient = require('Transmog/TransmogClient')

local function isSinglePlayer()
    return (not isClient() and not isServer())
end

-- Only fetch global mod data here
Events.OnGameStart.Add(function()
    TransmogClient.requestTransmogModData()
end)

-- Run patching here once inventory + visuals exist
Events.OnCreatePlayer.Add(function(playerIndex, player)
    if not isSinglePlayer() then return end

    local modData = TransmogDE.GenerateTransmogGlobalModData()
    TransmogDE.patchAllItemsFromModData(modData)
    TmogPrint("OnCreatePlayer -> patchAllItemsFromModData")
end)

if isClient() then
    Events.OnReceiveGlobalModData.Add(TransmogClient.onReceiveGlobalModData);
    TmogPrint('OnReceiveGlobalModData.Add')
end