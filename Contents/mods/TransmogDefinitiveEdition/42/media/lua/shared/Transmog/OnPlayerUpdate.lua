if not TransmogDE then
    TransmogDE = {}
end

-- One-time init per playerNum
TransmogDE._playerInitDone = TransmogDE._playerInitDone or {}
-- Clothing dirty flags are shared with OnClothingUpdated.lua
TransmogDE._clothingDirty   = TransmogDE._clothingDirty   or {}

local function onPlayerUpdate(player)
    if not player or not instanceof(player, "IsoPlayer") then
        return
    end

    if not player:isLocalPlayer() then
        return
    end

    local playerNum = player:getPlayerNum() or 0

    -- 1) One-time initialization after the player is truly "ready"
    if not TransmogDE._playerInitDone[playerNum] then
        TransmogDE._playerInitDone[playerNum] = true

        TmogPrint("OnPlayerUpdate -> initial triggerUpdate for player " .. tostring(playerNum))

        TransmogDE.triggerUpdate(player)

        -- We don't need to do this since triggerUpdate actually handles all visual updates
        -- TransmogDE.triggerUpdateVisuals(player)
        
        -- We return here so we don't immediately re-run on the same tick.
        return
    end

    -- 2) Subsequent updates: only when clothing is dirty
    if TransmogDE._clothingDirty[playerNum] then
        TransmogDE._clothingDirty[playerNum] = nil

        TmogPrint("OnPlayerUpdate -> clothing dirty, triggerUpdate for player " .. tostring(playerNum))

        TransmogDE.triggerUpdate(player)
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)