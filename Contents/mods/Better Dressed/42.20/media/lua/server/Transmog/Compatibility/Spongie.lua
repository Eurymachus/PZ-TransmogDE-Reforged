if not getActivatedMods or not getActivatedMods():contains("SPNCC") then return end

local FaceManager_Shared = require("CharacterCustomisation/FaceManager_Shared")
local ok, FaceManager_Server = pcall(require, "CharacterCustomisation/FaceManager_Server")
if not ok then
    ok, FaceManager_Server = pcall(require, "CharacterCustomisation/FaceManager/Main")
end
if not ok or not FaceManager_Server then return end

local function getBloodSyncItems(player)
    if FaceManager_Shared.GetWornBloodSyncItems then
        return FaceManager_Shared.GetWornBloodSyncItems(player)
    end
    if FaceManager_Shared.GetWornItemsWithTag and SPNCC and SPNCC.ItemTag then
        return FaceManager_Shared.GetWornItemsWithTag(player, SPNCC.ItemTag.CanHaveBlood)
    end
    return nil
end

local function getSourceVisual(player, snapshot)
    if FaceManager_Shared.GetBloodAndDirtVisual then
        return FaceManager_Shared.GetBloodAndDirtVisual(player, snapshot)
    end
    return snapshot or (player.getVisual and player:getVisual())
end

local function syncVisual(itemVisual, sourceVisual)
    local changed = false
    for index = 0, BloodBodyPartType.MAX:index() - 1 do
        local part = BloodBodyPartType.FromIndex(index)
        local blood = sourceVisual:getBlood(part)
        local dirt = sourceVisual:getDirt(part)
        if itemVisual:getBlood(part) ~= blood then
            itemVisual:setBlood(part, blood)
            changed = true
        end
        if itemVisual:getDirt(part) ~= dirt then
            itemVisual:setDirt(part, dirt)
            changed = true
        end
    end
    return changed
end

FaceManager_Server.SyncBlood = function(player, snapshot)
    if not player then return end

    local items = getBloodSyncItems(player)
    local sourceVisual = getSourceVisual(player, snapshot)
    if not items or #items == 0 or not sourceVisual then return end

    local changed = false
    for _, item in ipairs(items) do
        local itemVisual = item and item.getVisual and item:getVisual()
        if itemVisual and syncVisual(itemVisual, sourceVisual) then
            changed = true
            item:synchWithVisual()
            if syncItemFields then syncItemFields(player, item) end
            if item.syncItemFields then item:syncItemFields() end
            if sendItemStats then sendItemStats(item) end
        end
    end

    if not changed then return end

    if player.resetModel then player:resetModel() end
    if isServer() then
        sendServerCommand(player, "EURY_TRANSMOG", "SPONGIE_RESET_MODEL", {})
    end
end
