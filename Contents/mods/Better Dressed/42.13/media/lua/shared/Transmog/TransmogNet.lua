TransmogNet = TransmogNet or {}

TransmogNet.MODULE_ID = "EURY_TRANSMOG"
TransmogNet.Commands = {
    REQUEST_TRANSMOG = "REQUEST_TRANSMOG",
    INIT_PLAYER      = "INIT_PLAYER",
    REQUEST_UPDATE   = "REQUEST_UPDATE",

    -- Single-item ops
    HIDE             = "HIDE",
    SHOW             = "SHOW",
    REMOVE_TRANSMOG  = "REMOVE_TRANSMOG",
    RESET_DEFAULT    = "RESET_DEFAULT",
    SET_COLOR        = "SET_COLOR",
    SET_TEXTURE      = "SET_TEXTURE",

    -- Worn-items batch ops
    HIDE_ALL             = "HIDE_ALL",
    SHOW_ALL             = "SHOW_ALL",
    REMOVE_TRANSMOG_ALL  = "REMOVE_TRANSMOG_ALL",
    RESET_DEFAULT_ALL    = "RESET_DEFAULT_ALL",

    -- Server -> client completion/feedback
    NOTIFY           = "NOTIFY",
    WEAR_ORDER       = "WEAR_ORDER"
}

-- One-time init per playerNum
TransmogNet._playerInitDone = TransmogNet._playerInitDone or {}

TransmogNet.REQUESTS = TransmogNet.REQUESTS or {}
TransmogNet.NEXT_REQUEST_ID = TransmogNet.NEXT_REQUEST_ID or 0

TransmogNet.nextRequestId = function()
    TransmogNet.NEXT_REQUEST_ID = TransmogNet.NEXT_REQUEST_ID + 1
    return TransmogNet.NEXT_REQUEST_ID
end

local function newRequest(focusItem, toItem)
    local id = TransmogNet.nextRequestId()
    TransmogNet.REQUESTS[id] = {
        focus = focusItem:getID(),
        to    = toItem, -- optional (transmog only)
    }
    return id
end

TransmogNet.getRequestData = function(requestID)
    if not requestID then return nil end
    local requestData = TransmogNet.REQUESTS[requestID]
    if not requestData then return nil end

    -- caller decides when to clear; most paths clear after notify
    return requestData
end

TransmogNet.updateRequestItemRef = function(requestID, ref)
    local request = TransmogNet.REQUESTS[requestID]
    if not request.ref then
        request.ref = ref
        return true
    end
    return false
end

-- INVENTORY HELPERS

-- =========================================================
-- Server-side absolute resolution (itemId + ref.kind + fields)
-- =========================================================

local function findItemInContainerById(container, itemId)
    if not (container and itemId) then return nil end
    local items = container:getItems()
    if not items then return nil end
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getID and it:getID() == itemId then
            return it
        end
    end
    return nil
end

local function getSquareFromRef(ref)
    if not (ref and ref.x and ref.y and ref.z) then return nil end
    local cell = getCell()
    if not cell then return nil end
    return cell:getGridSquare(ref.x, ref.y, ref.z)
end

local function getObjectAtSquareIndex(square, objectIndex)
    if not (square and objectIndex ~= nil) then return nil end
    local objs = square:getObjects()
    if not objs then return nil end
    if objectIndex < 0 or objectIndex >= objs:size() then return nil end
    return objs:get(objectIndex)
end

local function getContainerFromObject(obj, containerIndex)
    if not obj then return nil end

    -- Multi-container objects (preferred)
    if containerIndex ~= nil and obj.getContainerByIndex and obj.getContainerCount then
        local cnt = obj:getContainerCount()
        if cnt and containerIndex >= 0 and containerIndex < cnt then
            return obj:getContainerByIndex(containerIndex)
        end
        return nil
    end

    -- Single-container objects
    if obj.getContainer then
        return obj:getContainer()
    end

    return nil
end

local function resolveItem_player(player, itemId)
    local inv = player and player:getInventory() or nil
    return findItemInContainerById(inv, itemId)
end

local function resolveItem_world(player, itemId, ref)
    local sq = getSquareFromRef(ref)
    if not sq then return nil end
    local obj = getObjectAtSquareIndex(sq, ref.objectIndex)
    if not obj then return nil end
    local container = getContainerFromObject(obj, ref.containerIndex)
    return findItemInContainerById(container, itemId)
end

local function resolveItem_corpse(player, itemId, ref)
    -- Same addressing as world objects: square + objectIndex + containerIndex
    return resolveItem_world(player, itemId, ref)
end

local function resolveItem_vehicle(player, itemId, ref)
    if not (ref and ref.vehicleId and ref.partId) then return nil end
    local veh = getVehicleById(ref.vehicleId)
    if not veh then return nil end
    local part = veh:getPartById(ref.partId)
    if not part then return nil end
    local container = part:getItemContainer()
    return findItemInContainerById(container, itemId)
end

local function resolveItem_floor(player, itemId, ref)
    local sq = getSquareFromRef(ref)
    if not sq then return nil end

    -- Floor loot is represented as IsoWorldInventoryObject entries (each holds one item).
    -- We resolve by scanning world objects on that square and matching InventoryItem:getID().
    local wobs = sq:getWorldObjects()
    if not wobs then return nil end

    for i = 0, wobs:size() - 1 do
        local wo = wobs:get(i)
        if wo and wo.getItem then
            local it = wo:getItem()
            if it and it.getID and it:getID() == itemId then
                return it
            end
        end
    end

    return nil
end

local function resolveItemByRef(player, itemId, ref)
    if not (player and itemId and ref and ref.kind) then return nil end

    local k = ref.kind
    if k == "player" then
        return resolveItem_player(player, itemId)
    elseif k == "world" then
        return resolveItem_world(player, itemId, ref)
    elseif k == "corpse" then
        return resolveItem_corpse(player, itemId, ref)
    elseif k == "vehicle" then
        return resolveItem_vehicle(player, itemId, ref)
    elseif k == "floor" then
        return resolveItem_floor(player, itemId, ref)
    end

    return nil
end

-- END --

local function _refreshPlayerAndVisuals(player, focusItem)
    -- One visual refresh per completed operation
    player:resetModelNextFrame()
    if instanceof(player, "IsoPlayer") and player:isLocalPlayer() and getPlayerInfoPanel(player:getPlayerNum()) then
        getPlayerInfoPanel(player:getPlayerNum()).charScreen.refreshNeeded = true
    end

    -- Refresh Transmog UI (ListViewer listens to this)
    TmogPrint("trigger TransmogClothingUpdate ")
    triggerEvent("TransmogClothingUpdate", player, focusItem)
end

-- Client-only: unified post-apply notification + refresh
TransmogNet.notifyPlayer = function(player, result)
    if not player then return end
    if not result then return end

    local ok = result.ok == true
    local cmd = result.command
    local requestID = result.requestID
    local count = result.count or 0

    -- Resolve focus item for UI refresh (kept client-side only)
    -- Resolve request context (client-only)
    local req = nil
    local focusItem = nil
    local tmogItem = nil
    if requestID then
        req = TransmogNet.REQUESTS[requestID]
        if req and req.focus and req.ref then
            focusItem = resolveItemByRef(player, req.focus, req.ref)
            if not focusItem then
                TmogPrint("Warning: Item ID" .. tostring(req.focus) .. " not found.")
            else
                tmogItem = TransmogDE.getTransmogChild(focusItem)
                if not tmogItem and not TransmogDE.isClothingHidden(focusItem) then
                    TmogPrint("Warning: Carrier for Item ID " .. tostring(req.focus) .. " not found.")
                end
            end
        end
    end

    if not ok then
        local failText = getTextOrNull("IGUI_TransmogDE_Text_RequestFailed") or "Transmog Request failed!"
        HaloTextHelper.addGoodText(player, failText)
        return
    end

    -- Success feedback
    if cmd == TransmogNet.Commands.REQUEST_TRANSMOG then
        if req and focusItem and req.to then
            local fromName = getItemNameFromFullType(focusItem:getScriptItem():getFullName())
            local toName = getItemNameFromFullType(req.to)
            local text = getText("IGUI_TransmogDE_Text_WasTransmoggedTo", fromName, toName)
            HaloTextHelper.addGoodText(player, text)
        end
    elseif cmd == TransmogNet.Commands.HIDE then
        if focusItem then
            local fromName = getItemNameFromFullType(focusItem:getScriptItem():getFullName())
            local text = getText("IGUI_TransmogDE_Text_WasHidden", fromName)
            HaloTextHelper.addGoodText(player, text)
        end
    elseif cmd == TransmogNet.Commands.SHOW then
        if focusItem then
            local fromName = getItemNameFromFullType(focusItem:getScriptItem():getFullName())
            local text = getText("IGUI_TransmogDE_Text_WasShown", fromName)
            HaloTextHelper.addGoodText(player, text)
        end
    elseif cmd == TransmogNet.Commands.REMOVE_TRANSMOG then
        if focusItem then
            local fromName = getItemNameFromFullType(focusItem:getScriptItem():getFullName())
            local text = getTextOrNull("IGUI_TransmogDE_Text_WasRemoved", fromName) or ("Removed transmog: " .. tostring(fromName))
            HaloTextHelper.addGoodText(player, text)
        end
    elseif cmd == TransmogNet.Commands.RESET_DEFAULT then
        if focusItem then
            local toName = getItemNameFromFullType(focusItem:getScriptItem():getFullName())
            local text = getText("IGUI_TransmogDE_Text_WasReset", toName)
            HaloTextHelper.addGoodText(player, text)
        end
    elseif cmd == TransmogNet.Commands.HIDE_ALL then
        local actionText = getText("IGUI_TransmogDE_Text_BatchActionHide")
        local haloText = getTextOrNull("IGUI_TransmogDE_Text_BatchActionDone", actionText) or (actionText .. " - Complete")
        HaloTextHelper.addGoodText(player, haloText)
    elseif cmd == TransmogNet.Commands.SHOW_ALL then
        local actionText = getText("IGUI_TransmogDE_Text_BatchActionShow")
        local haloText = getTextOrNull("IGUI_TransmogDE_Text_BatchActionDone", actionText) or (actionText .. " - Complete")
        HaloTextHelper.addGoodText(player, haloText)
    elseif cmd == TransmogNet.Commands.REMOVE_TRANSMOG_ALL then
        local actionText = getText("IGUI_TransmogDE_Text_BatchActionRemove")
        local haloText = getTextOrNull("IGUI_TransmogDE_Text_BatchActionDone", actionText) or (actionText .. " - Complete")
        HaloTextHelper.addGoodText(player, haloText)
    elseif cmd == TransmogNet.Commands.RESET_DEFAULT_ALL then
        local actionText = getText("IGUI_TransmogDE_Text_BatchActionReset")
        local haloText = getTextOrNull("IGUI_TransmogDE_Text_BatchActionDone", actionText) or (actionText .. " - Complete")
        HaloTextHelper.addGoodText(player, haloText)
    elseif cmd == TransmogNet.Commands.SET_COLOR then
        if focusItem and result.data then
            local color = result.data
            local immutableColor = ImmutableColor.new(Color.new(color.r, color.g, color.b, 1))
            TransmogDE.setClothingColor(focusItem, immutableColor)
            if tmogItem then
                TransmogDE.setClothingColor(tmogItem, immutableColor)
            end
        end
    elseif cmd == TransmogNet.Commands.SET_TEXTURE then
        if focusItem and result.data then
            local texture = result.data
            TransmogDE.setClothingTexture(focusItem, texture)
            if tmogItem then
                TransmogDE.setClothingTexture(TransmogDE.getTransmogChild(focusItem), texture)
            end
        end
    end

    _refreshPlayerAndVisuals(player, focusItem)

    if requestID then
        TransmogNet.REQUESTS[requestID] = nil
    end
end

TransmogNet.initPlayerComplete = function(player, args)
    if not (args and args.ok) then
        TmogPrint("Failed to init player")
        return
    end
    TransmogNet._playerInitDone[player:getPlayerNum()] = true
end

TransmogNet.updatePlayer = function(player, args)
    TmogPrint("Update Request complete - Model Refresh Required")
    local item = nil
    if (args and args.itemId) then
        item = resolveItemByRef(player, args.itemId, args.ref)
    end
    _refreshPlayerAndVisuals(player, item)
    TransmogDE._clothingDirty[player:getPlayerNum()] = nil
end

TransmogNet.wearTransmogItems = function(player, args)
    TmogPrint("Wear Items")
    if not (args and args.toWearIDs) then return end
    local tmogItemIDs = args.toWearIDs
    if #tmogItemIDs <= 0 then return end
    for i = 0, #tmogItemIDs - 1 do
        local tmogItem = resolveItemByRef(player, tmogItemIDs[i], { kind = "player" })
        if tmogItem then
            TransmogDE.setWornItemTmog(player, tmogItem)
        end
    end
    _refreshPlayerAndVisuals(player)
end

local serverCommandReceivers = {
    INIT_PLAYER     = TransmogNet.initPlayerComplete,
    REQUEST_UPDATE  = TransmogNet.updatePlayer,
    NOTIFY          = TransmogNet.notifyPlayer,
    WEAR_ORDER      = TransmogNet.wearTransmogItems,
}

local serverCommandRecieved = function(module, command, args)
    if module ~= TransmogNet.MODULE_ID then return end
    local fn = serverCommandReceivers[command]
    if fn then fn(getPlayer(), args) end
end
Events.OnServerCommand.Add(serverCommandRecieved)

local function notifyClient(player, requestID, command, ok, count, data)
    local args = {
        requestID = requestID,
        command   = command,
        ok        = ok == true,
        count     = count or 0,
        data      = data
    }

    if isServer() then
        sendServerCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.NOTIFY, args)
        return
    end

    serverCommandRecieved(TransmogNet.MODULE_ID, TransmogNet.Commands.NOTIFY, args)
end

-- ============================
-- TODO :: IMPLEMENT CUSTOM WORN ORDER UPDATE
-- ============================

local function countWornTransmoggables(player)
    local worn = player and player.getWornItems and player:getWornItems()
    if not worn then return 0 end
    local n = 0
    local transmogItemIDs = {}
    for i = 0, worn:size() - 1 do
        local it = worn:getItemByIndex(i)
        if it and TransmogDE.isTransmoggable and TransmogDE.isTransmoggable(it) then
            n = n + 1
        end
        if it and TransmogDE.isTransmogItem(it) then
            transmogItemIDs[#transmogItemIDs+1] = it:getID()
        end
    end
    return n, transmogItemIDs
end

TransmogNet.sendTransmogClothing = function(player, toWearIDs)
    TmogPrint("sendTransmogClothing fired")
    if not isServer() then return end
    if not toWearIDs or #toWearIDs <= 0 then return end
    sendServerCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.WEAR_ORDER, { toWearIDs = toWearIDs })
end

-- ====================================
-- Server receives client init/update/transmog/hide/show/remove/reset
-- ====================================

TransmogNet.initPlayerRecieved = function(player, args)
    TmogPrint("Server recv INIT_PLAYER from " .. tostring(player and player:getUsername() or "nil"))
    -- Trigger the server-side apply path (server will handle wear/add/remove + transmit)
    TransmogDE.triggerUpdate(player)
    sendServerCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.INIT_PLAYER, { ok = true })
end

TransmogNet.requestUpdateRecieved = function(player, args)
    TmogPrint("Server recv REQUEST_UPDATE from " .. tostring(player and player:getUsername() or "nil"))
    TransmogDE.triggerUpdate(player)
    sendServerCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.REQUEST_UPDATE, { ok = true })
end

TransmogNet.requestTransmogRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.data and args.ref and args.ref.kind) then return end

    local requestID = args.requestID
    local itemId    = args.itemId
    local toType    = args.data
    local ref       = args.ref

    local itemToTmog = resolveItemByRef(player, itemId, ref)
    if not itemToTmog then
        TmogPrint("Transmog [" .. tostring(requestID) .. "] failed: could not resolve itemId [" .. tostring(itemId) .. "] kind [" .. tostring(ref.kind) .. "]")
        notifyClient(player, requestID, TransmogNet.Commands.REQUEST_TRANSMOG, false, 0)
        return
    end

    local toItem = ScriptManager.instance:getItem(toType)
    if not toItem then
        TmogPrint("Transmog [" .. tostring(requestID) .. "] failed: missing ScriptItem [" .. tostring(toType) .. "]")
        notifyClient(player, requestID, TransmogNet.Commands.REQUEST_TRANSMOG, false, 0)
        return
    end

    -- Optional safety gate (recommended)
    if TransmogDE.isTransmoggable and not TransmogDE.isTransmoggable(itemToTmog) then
        TmogPrint("Transmog [" .. tostring(requestID) .. "] failed: item not transmoggable")
        notifyClient(player, requestID, TransmogNet.Commands.REQUEST_TRANSMOG, false, 0)
        return
    end

    TransmogDE.setItemTransmog(itemToTmog, toItem)
    TransmogDE.forceUpdateClothing(itemToTmog)
    TransmogDE.triggerUpdate(player)

    notifyClient(player, requestID, TransmogNet.Commands.REQUEST_TRANSMOG, true, 1)
end

TransmogNet.requestHideRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.ref and args.ref.kind) then return end
    local item = resolveItemByRef(player, args.itemId, args.ref)
    if not item then
        notifyClient(player, args.requestID, TransmogNet.Commands.HIDE, false, 0)
        return
    end
    TransmogDE.setClothingHidden(item)
    TransmogDE.triggerUpdate(player)
    notifyClient(player, args.requestID, TransmogNet.Commands.HIDE, true, 1)
end

TransmogNet.requestShowRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.ref and args.ref.kind) then return end
    local item = resolveItemByRef(player, args.itemId, args.ref)
    if not item then
        notifyClient(player, args.requestID, TransmogNet.Commands.SHOW, false, 0)
        return
    end
    TransmogDE.setClothingShown(item)
    TransmogDE.triggerUpdate(player)
    notifyClient(player, args.requestID, TransmogNet.Commands.SHOW, true, 1)
end

TransmogNet.requestRemoveTransmogRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.ref and args.ref.kind) then return end
    local item = resolveItemByRef(player, args.itemId, args.ref)
    if not item then
        notifyClient(player, args.requestID, TransmogNet.Commands.REMOVE_TRANSMOG, false, 0)
        return
    end
    TransmogDE.removeTransmog(item)
    TransmogDE.triggerUpdate(player)
    notifyClient(player, args.requestID, TransmogNet.Commands.REMOVE_TRANSMOG, true, 1)
end

TransmogNet.requestResetDefaultRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.ref and args.ref.kind) then return end
    local item = resolveItemByRef(player, args.itemId, args.ref)
    if not item then
        notifyClient(player, args.requestID, TransmogNet.Commands.RESET_DEFAULT, false, 0)
        return
    end
    TransmogDE.setItemToDefault(item)
    TransmogDE.triggerUpdate(player)
    notifyClient(player, args.requestID, TransmogNet.Commands.RESET_DEFAULT, true, 1)
end

TransmogNet.requestSetColorRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.ref and args.ref.kind and args.data) then return end
    local item = resolveItemByRef(player, args.itemId, args.ref)
    if not item then
        notifyClient(player, args.requestID, TransmogNet.Commands.SET_COLOR, false, 0)
        return
    end

    local color = args.data
	local immutableColor = ImmutableColor.new(Color.new(color.r, color.g, color.b, 1))
	TransmogDE.setClothingColorModdata(item, immutableColor)
	TransmogDE.forceUpdateClothing(item)
    TransmogDE.triggerUpdate(player)

    notifyClient(player, args.requestID, TransmogNet.Commands.SET_COLOR, true, 1, color)
end

TransmogNet.requestSetTextureRecieved = function(player, args)
    if not (args and args.requestID and args.itemId and args.ref and args.ref.kind and args.data) then return end
    local item = resolveItemByRef(player, args.itemId, args.ref)
    if not item then
        notifyClient(player, args.requestID, TransmogNet.Commands.SET_TEXTURE, false, 0)
        return
    end
    
    local texture = args.data
	TransmogDE.setClothingTextureModdata(item, texture)
	TransmogDE.forceUpdateClothing(item)
    TransmogDE.triggerUpdate(player)
    
    notifyClient(player, args.requestID, TransmogNet.Commands.SET_TEXTURE, true, 1, texture)
end

-- ====================================
-- Server receives batch ops (wornItems only)
-- ====================================

TransmogNet.requestHideAllRecieved = function(player, args)
    local requestID = args and args.requestID
    TransmogDE.hideAllWornTransmogs(player)
    TransmogDE.triggerUpdate(player)
    local count, tmogIds = countWornTransmoggables(player)
    notifyClient(player, requestID, TransmogNet.Commands.HIDE_ALL, true, count, tmogIds)
end

TransmogNet.requestShowAllRecieved = function(player, args)
    local requestID = args and args.requestID
    TransmogDE.showAllWornTransmogs(player)
    TransmogDE.triggerUpdate(player)
    local count, tmogIds = countWornTransmoggables(player)
    notifyClient(player, requestID, TransmogNet.Commands.SHOW_ALL, true, count, tmogIds)
end

TransmogNet.requestRemoveTransmogAllRecieved = function(player, args)
    local requestID = args and args.requestID
    TransmogDE.removeAllWornTransmogs(player)
    TransmogDE.triggerUpdate(player)
    local count, tmogIds = countWornTransmoggables(player)
    notifyClient(player, requestID, TransmogNet.Commands.REMOVE_TRANSMOG_ALL, true, count, tmogIds)
end

TransmogNet.requestResetDefaultAllRecieved = function(player, args)
    local requestID = args and args.requestID
    TransmogDE.resetDefaultAllWornTransmogs(player)
    TransmogDE.triggerUpdate(player)
    local count, tmogIds = countWornTransmoggables(player)
    notifyClient(player, requestID, TransmogNet.Commands.RESET_DEFAULT_ALL, true, count, tmogIds)
end

local clientCommandReceivers = {
    REQUEST_TRANSMOG    = TransmogNet.requestTransmogRecieved,
    INIT_PLAYER         = TransmogNet.initPlayerRecieved,
    REQUEST_UPDATE      = TransmogNet.requestUpdateRecieved,
    HIDE                = TransmogNet.requestHideRecieved,
    SHOW                = TransmogNet.requestShowRecieved,
    REMOVE_TRANSMOG     = TransmogNet.requestRemoveTransmogRecieved,
    RESET_DEFAULT       = TransmogNet.requestResetDefaultRecieved,
    SET_COLOR           = TransmogNet.requestSetColorRecieved,
    SET_TEXTURE         = TransmogNet.requestSetTextureRecieved,

    HIDE_ALL            = TransmogNet.requestHideAllRecieved,
    SHOW_ALL            = TransmogNet.requestShowAllRecieved,
    REMOVE_TRANSMOG_ALL = TransmogNet.requestRemoveTransmogAllRecieved,
    RESET_DEFAULT_ALL   = TransmogNet.requestResetDefaultAllRecieved,
}

local clientCommandRecieved = function(module, command, player, args)
    if module ~= TransmogNet.MODULE_ID then return end
    local fn = clientCommandReceivers[command]
    if fn then fn(player, args) end
end
Events.OnClientCommand.Add(clientCommandRecieved)

-- ====================================
-- Client sends request (IDs + ref only)
-- ====================================
-- ref payload examples:
--   { kind="player" }
--   { kind="world",  x=...,y=...,z=..., objectIndex=..., containerIndex=... }
--   { kind="corpse", x=...,y=...,z=..., objectIndex=..., containerIndex=... }
--   { kind="floor",  x=...,y=...,z=... }
--   { kind="vehicle", vehicleId=..., partId="Trunk" }

local function findObjectIndexOnSquare(square, obj)
    if not (square and obj) then return nil end
    local objs = square:getObjects()
    if not objs then return nil end
    for i = 0, objs:size() - 1 do
        if objs:get(i) == obj then
            return i
        end
    end
    return nil
end

local function findContainerIndexOnObject(obj, container)
    if not (obj and container) then return nil end
    if not (obj.getContainerCount and obj.getContainerByIndex) then return nil end
    local cnt = obj:getContainerCount()
    if not cnt then return nil end
    for i = 0, cnt - 1 do
        local c = obj:getContainerByIndex(i)
        if c == container then
            return i
        end
    end
    return nil
end

local function buildRef(player, item)
    if not item then return nil end

    local container = item.getContainer and item:getContainer() or nil
    if not container then
        -- Floor items can sometimes have no container client-side depending on source/UI.
        -- In that case we can’t absolutely resolve it, so caller will fall back to player.
        return nil
    end

    -- 1) Player inventory (covers worn items + worn bags)
    if player and container == player:getInventory() then
        return { kind = "player" }
    end

    -- 2) Vehicle container
    if container.getVehiclePart then
        local part = container:getVehiclePart()
        if part then
            local veh = part:getVehicle()
            if veh then
                local partId = part.getId and part:getId() or (part.getIdString and part:getIdString() or nil)
                return {
                    kind = "vehicle",
                    vehicleId = veh:getId(),
                    partId    = partId,
                }
            end
        end
    end

    -- 3) Parent-based containers (world objects / corpses / floor-square containers)
    local parent = container.getParent and container:getParent() or nil

    -- Floor container parent can be the square itself in some cases
    if parent and instanceof(parent, "IsoGridSquare") then
        return {
            kind = "floor",
            x = parent:getX(),
            y = parent:getY(),
            z = parent:getZ(),
        }
    end

    -- World object / corpse container
    if parent and parent.getSquare then
        local sq = parent:getSquare()
        if sq then
            local objectIndex = nil
            if parent.getObjectIndex then
                objectIndex = parent:getObjectIndex()
                if objectIndex ~= nil and objectIndex < 0 then objectIndex = nil end
            end
            if objectIndex == nil then
                objectIndex = findObjectIndexOnSquare(sq, parent)
            end

            local containerIndex = findContainerIndexOnObject(parent, container)

            if objectIndex ~= nil then
                return {
                    kind = (instanceof(parent, "IsoDeadBody") and "corpse") or "world",
                    x = sq:getX(),
                    y = sq:getY(),
                    z = sq:getZ(),
                    objectIndex    = objectIndex,
                    containerIndex = containerIndex, -- may be nil for single-container objects
                }
            end
        end
    end

    -- 4) Last-resort: if we can’t classify, don’t guess.
    return nil
end

TransmogNet.hello = function(player)
    local playerNum = player:getPlayerNum()
    if isClient() then
        TmogPrint("hello -> send INIT_PLAYER p=" .. tostring(playerNum))
        sendClientCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.INIT_PLAYER, {})
        return true
    end
    TransmogDE.triggerUpdate(player)
    _refreshPlayerAndVisuals(player)
    TransmogNet._playerInitDone[playerNum] = true
end
 
TransmogNet.requestUpdate = function(player)
    local playerNum = player:getPlayerNum()
    if isClient() then
        TmogPrint("send REQUEST_UPDATE p=" .. tostring(playerNum))
        sendClientCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.REQUEST_UPDATE, {})
        return
    end
    TransmogDE.triggerUpdate(player)
    _refreshPlayerAndVisuals(player)
end

-- =========================================================
-- Client request helpers for transmog/hide/show/remove/reset
-- =========================================================

TransmogNet.triggerUpdate = function(player, item)
    TmogPrint("TransmogNet triggerUpdate running...")
    if isClient() then
        TmogPrint("TransmogNet triggerUpdate client skipped")
        return
    end
    local args = {}
    if item and item.getID then
        local itemId = item:getID()
        local ref = buildRef(player, item)
        if not ref then ref = { kind = "player" } end
        if not ref.kind then ref.kind = "player" end
        args = {
            itemId    = itemId,
            ref       = ref,
        }
    end
    TransmogDE.triggerUpdate(player)
    if isServer() then
        if item and item.getID then
            TmogPrint("TransmogNet triggerUpdate server")
            sendServerCommand(player, TransmogNet.MODULE_ID, TransmogNet.Commands.REQUEST_UPDATE, args)
        end
        return
    end
    TmogPrint("TransmogNet triggerUpdate singleplayer")
    serverCommandRecieved(TransmogNet.MODULE_ID, TransmogNet.Commands.REQUEST_UPDATE, args)
end

local function requestOpClient(player, command, item, requestID, data)
    if not (item and item.getID) then
        TransmogNet.REQUESTS[requestID] = nil
        TmogPrint("Op Request failed: item missing ID cmd=" .. tostring(command))
        TransmogNet.notifyPlayer(player, {
            ok = false,
            command = command,
            requestID = requestID,
            count = 0
        })
        return
    end

    local itemId = item:getID()
    local ref = buildRef(player, item)
    if not ref then ref = { kind = "player" } end
    if not ref.kind then ref.kind = "player" end

    if not TransmogNet.updateRequestItemRef(requestID, ref) then
        TmogPrint("Item location reference already exists or was not updated")
    end

    local args = {
            requestID = requestID,
            itemId    = itemId,
            ref       = ref,
            data      = data,
        }

    if isClient() then
        sendClientCommand(player, TransmogNet.MODULE_ID, command, args)
        return
    end

    clientCommandRecieved(TransmogNet.MODULE_ID, command, player, args)
end

local function requestBatchClient(player, command, requestID)
    local args = {
        requestID = requestID,
    }
    if isClient() then
        sendClientCommand(player, TransmogNet.MODULE_ID, command, args)
        return
    end

    clientCommandRecieved(TransmogNet.MODULE_ID, command, player, args)
end

-- Single-item public API

TransmogNet.requestTransmog = function(player, itemToTmog, fullType)
    local requestID = newRequest(itemToTmog, fullType)
    requestOpClient(player, TransmogNet.Commands.REQUEST_TRANSMOG, itemToTmog, requestID, fullType)
end

TransmogNet.requestHide = function(player, item)
    local requestID = newRequest(item)
    requestOpClient(player, TransmogNet.Commands.HIDE, item, requestID)
end

TransmogNet.requestShow = function(player, item)
    local requestID = newRequest(item)
    requestOpClient(player, TransmogNet.Commands.SHOW, item, requestID)
end

TransmogNet.requestRemoveTransmog = function(player, item)
    local requestID = newRequest(item)
    requestOpClient(player, TransmogNet.Commands.REMOVE_TRANSMOG, item, requestID)
end

TransmogNet.requestResetDefault = function(player, item)
    local requestID = newRequest(item)
    requestOpClient(player, TransmogNet.Commands.RESET_DEFAULT, item, requestID)
end

TransmogNet.requestSetColor = function(player, item, color)
    local requestID = newRequest(item)
    requestOpClient(player, TransmogNet.Commands.SET_COLOR, item, requestID, color)
end

TransmogNet.requestSetTexture = function(player, item, texture)
    local requestID = newRequest(item)
    requestOpClient(player, TransmogNet.Commands.SET_TEXTURE, item, requestID, texture)
end

-- All-worn public API (no item resolution; applies to wornItems only)
-- focusItem is optional, used only to refresh the UI selection after completion.

TransmogNet.requestHideAll = function(player, focusItem)
    local requestID = newRequest(focusItem)
    requestBatchClient(player, TransmogNet.Commands.HIDE_ALL, requestID)
end

TransmogNet.requestShowAll = function(player, focusItem)
    local requestID = newRequest(focusItem)
    requestBatchClient(player, TransmogNet.Commands.SHOW_ALL, requestID)
end

TransmogNet.requestRemoveTransmogAll = function(player, focusItem)
    local requestID = newRequest(focusItem)
    requestBatchClient(player, TransmogNet.Commands.REMOVE_TRANSMOG_ALL, requestID)
end

TransmogNet.requestResetDefaultAll = function(player, focusItem)
    local requestID = newRequest(focusItem)
    requestBatchClient(player, TransmogNet.Commands.RESET_DEFAULT_ALL, requestID)
end

return TransmogNet