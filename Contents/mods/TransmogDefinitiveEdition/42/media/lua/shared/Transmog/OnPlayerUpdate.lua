local hasInitialized = false

local function onReady(player)
    if hasInitialized then return end
    hasInitialized = true
    TmogPrint('Player Ready')
    TransmogDE.triggerUpdate(player)
end

Events.OnPlayerUpdate.Add(onReady)