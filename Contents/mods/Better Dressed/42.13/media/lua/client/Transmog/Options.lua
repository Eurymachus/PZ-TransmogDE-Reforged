local Options = {}

local panel = PZAPI.ModOptions:create("EURY_TRANSMOG", "Better Dressed - Transmog")

Options.hideDirt = panel:addTickBox(
    "hideDirt",
    "Hide Dirt",
    false,
    "Toggles visibility of Dirt on Clothing"
)
Options.hideBlood = panel:addTickBox(
    "hideBlood",
    "Hide Blood",
    false,
    "Toggles visibility of Blood on Clothing."
)
Options.hideHoles = panel:addTickBox(
    "hideHoles",
    "Hide Holes",
    false,
    "Toggles visibility of Holes on Clothing"
)
Options.hidePatches = panel:addTickBox(
    "hidePatches",
    "Hide Patches",
    false,
    "Toggles visibility of Patches on Clothing"
)

function panel:apply()
	for i=0, getNumActivePlayers() -1 do
        local player = getSpecificPlayer(i)
        if player then
            TransmogDE.reapplyVisualsForAllWorn(player)
            TransmogDE.refreshPlayerAndSyncUI(player)
        end
    end
end

-- Helpers: treat getValue() as boolean; guard against nil
Options.shouldHideDirt = function()
    local result = Options.hideDirt and Options.hideDirt:getValue() == true
    TmogPrint("shouldHideDirt: " .. tostring(result))
    return result
end

Options.shouldHideBlood = function()
    local result = Options.hideBlood and Options.hideBlood:getValue() == true
    TmogPrint("shouldHideBlood: " .. tostring(result))
    return result
end

Options.shouldHideHoles = function()
    local result = Options.hideHoles and Options.hideHoles:getValue() == true
    TmogPrint("shouldHideHoles: " .. tostring(result))
    return result
end

Options.shouldHidePatches = function()
    local result = Options.hidePatches and Options.hidePatches:getValue() == true
    TmogPrint("shouldHidePatches: " .. tostring(result))
    return result
end

return Options