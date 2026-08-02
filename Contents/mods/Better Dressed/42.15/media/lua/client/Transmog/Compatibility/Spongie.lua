if not getActivatedMods or not getActivatedMods():contains("SPNCC") then return end

local function onServerCommand(module, command, args)
    if module ~= "EURY_TRANSMOG" or command ~= "SPONGIE_RESET_MODEL" then return end

    local player = getPlayer()
    if not player then return end

    if player.resetModelNextFrame then
        player:resetModelNextFrame()
    else
        player:resetModel()
    end
end

Events.OnServerCommand.Add(onServerCommand)
