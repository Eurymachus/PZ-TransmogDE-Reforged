local TransmogClient = require('Transmog/TransmogClient')

local function isSinglePlayer()
    return (not isClient() and not isServer())
end

Events.OnGameStart.Add(function()
    -- Request global moddata
    if isClient() then
        TransmogClient.requestTransmogModData()
        return
    end
    -- Build/persist global transmog data
    local modData = TransmogDE.GenerateTransmogGlobalModData()

    TransmogDE.patchAllItemsFromModData(modData)
end)

if isClient() then
    Events.OnReceiveGlobalModData.Add(TransmogClient.onReceiveGlobalModData);
    -- TmogPrint('OnReceiveGlobalModData.Add')
end