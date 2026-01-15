local Tmog = rawget(_G, "TransmogDE")
if not Tmog then
    Tmog = {}
    _G.TransmogDE = Tmog
end

Tmog.Options = Tmog.Options or {}
local OPS = Tmog.Options

local options = PZAPI.ModOptions:create("EURY_TRANSMOG", "Transmog [Reforged]")

OPS.hideDirt = options:addTickBox(
    "hideDirt",
    "Hide Dirt",
    false,
    "Toggles visibility of Dirt on Clothing"
)
OPS.hideBlood = options:addTickBox(
    "hideBlood",
    "Hide Blood",
    false,
    "Toggles visibility of Blood on Clothing."
)
OPS.hideHoles = options:addTickBox(
    "hideHoles",
    "Hide Holes",
    false,
    "Toggles visibility of Holes on Clothing"
)
OPS.hidePatches = options:addTickBox(
    "hidePatches",
    "Hide Patches",
    false,
    "Toggles visibility of Patches on Clothing"
)

function options:apply()
    if Tmog.triggerUpdate and getPlayer() then
        Tmog.triggerUpdate(getPlayer())
    end
end

-- Helpers: treat getValue() as boolean; guard against nil
function OPS.shouldHideDirt()
    local result = OPS.hideDirt and OPS.hideDirt:getValue() == true
    -- TmogPrint("shouldHideDirt: " .. tostring(result))
    return result
end

function OPS.shouldHideBlood()
    local result = OPS.hideBlood and OPS.hideBlood:getValue() == true
    -- TmogPrint("shouldHideBlood: " .. tostring(result))
    return result
end

function OPS.shouldHideHoles()
    local result = OPS.hideHoles and OPS.hideHoles:getValue() == true
    -- TmogPrint("shouldHideHoles: " .. tostring(result))
    return result
end

function OPS.shouldHidePatches()
    local result = OPS.hidePatches and OPS.hidePatches:getValue() == true
    -- TmogPrint("shouldHidePatches: " .. tostring(result))
    return result
end