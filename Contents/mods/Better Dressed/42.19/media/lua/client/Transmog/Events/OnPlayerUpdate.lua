if not TransmogDE then
    TransmogDE = {}
end

TransmogClient = require("Transmog/TransmogClient")

TransmogDE._updateInFlight = TransmogDE._updateInFlight or {}
TransmogDE._lastUpdateRequest = TransmogDE._lastUpdateRequest or {}

local UPDATE_INTERVAL_MS = 100
local UPDATE_TIMEOUT_MS = 2000

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
        local now = nowMs()
        local inFlightSince = TransmogDE._updateInFlight[playerNum]
        local lastRequest = TransmogDE._lastUpdateRequest[playerNum] or 0

        if inFlightSince and (now - inFlightSince) < UPDATE_TIMEOUT_MS then
            return
        end

        if (now - lastRequest) < UPDATE_INTERVAL_MS then
            return
        end

        TransmogDE._clothingDirty[playerNum] = nil
        TransmogDE._updateInFlight[playerNum] = now
        TransmogDE._lastUpdateRequest[playerNum] = now
        TransmogNet.requestUpdate(player)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
