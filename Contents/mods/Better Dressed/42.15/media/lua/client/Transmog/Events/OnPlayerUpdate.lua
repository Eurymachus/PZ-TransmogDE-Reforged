if not TransmogDE then
    TransmogDE = {}
end

-- Clothing dirty flags are shared with OnClothingUpdated.lua
TransmogDE._clothingDirty   = TransmogDE._clothingDirty   or {}

local DRJ_Initialised = false

local function nowMs()
    return (getTimestampMs and getTimestampMs()) or (os.time() * 1000)
end

local lastInitRequest = 0
local lastDirtyRequest = 0

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

    -- 2) Subsequent updates: request server apply when dirty
    if TransmogDE._clothingDirty[playerNum] then
        TransmogDE._clothingDirty[playerNum] = nil

        TransmogNet.requestUpdate(player)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)