if not TransmogDE then
    TransmogDE = {}
end

TransmogClient = require("Transmog/TransmogClient")

TransmogDE._updateInFlight = TransmogDE._updateInFlight or {}

local function nowMs()
    return (getTimestampMs and getTimestampMs()) or (os.time() * 1000)
end

local lastInitRequest = 0

local function onPlayerUpdate(player)
    if not player or not instanceof(player, "IsoPlayer") then
        return
    end

    local playerNum = player:getPlayerNum() or 0

    -- 1) One-time init
    if not TransmogNet._playerInitDone[playerNum] then
        local now = nowMs()
        if (now - lastInitRequest) >= 1000 then
            lastInitRequest = now
            TransmogNet.hello(player)
            return
        end
    end

    -- 2) Mod Data Init
    --[[
    if TransmogNet._playerInitDone[playerNum]
    and not TransmogClient._modDataRequestDone[playerNum] then
        TransmogClient.requestTransmogDataNew(player, playerNum)
    end
    ]]

    -- 2) Subsequent updates: request server apply when dirty
    if TransmogDE._clothingDirty[playerNum] then
        TransmogDE._clothingDirty[playerNum] = nil
        TransmogNet.requestUpdate(player)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)