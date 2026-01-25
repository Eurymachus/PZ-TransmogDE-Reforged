local function _filterList(list)
    if not list or #list == 0 then return list end
    local out = {}
    for i = 1, #list do
        local row = list[i]
        local rowItem = (row and row.items and row.items[1]) or row
        if not (rowItem and TransmogDE.isTransmogItem(rowItem)) then
            TmogPrint("Hiding row: " .. tostring(rowItem))
            out[#out + 1] = row
        end
    end
    return out
end

local function _isPlayersMainInventoryPane(self)
    if not self or not self.inventory or not getSpecificPlayer or not self.player then return false end
    local ply = getSpecificPlayer(self.player)
    return ply and (self.inventory == ply:getInventory()) or false
end

local _hooked = false
local function hideTransmogs()
    local _skipHide = getCore():getDebug() or isAdmin()
    if _skipHide or _hooked then return end
    _hooked = true

    -- Chain AFTER whoever last patched refreshContainer - Works with EquipmentUI
    local og_refreshContainer = ISInventoryPane.refreshContainer
    function ISInventoryPane:refreshContainer()
        og_refreshContainer(self)

        -- Only touch panes drawing the player's main inventory (left page, Equipment UI bottom grid)
        if not _isPlayersMainInventoryPane(self) then return end

        -- Filter the base itemslist
        local filteredItems = _filterList(self.itemslist)
        if filteredItems ~= self.itemslist then
            self.itemslist = filteredItems
            -- Equipment UI restores to cachedItemList after draw; keep it coherent.
            self.cachedItemList = filteredItems
        end
    end

    DebugLog.log(DebugType.General, "[TransmogDE] Post-refresh filter installed (compatible with Equipment UI).")
end

--Events.OnGameStart.Add(hideTransmogs)
