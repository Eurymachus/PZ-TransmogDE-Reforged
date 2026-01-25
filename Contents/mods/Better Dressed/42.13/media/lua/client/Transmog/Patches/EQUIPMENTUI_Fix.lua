-- EquipmentUI_HardResetDynamicSlots.lua
-- Better Dressed - Transmog (client-only)
--
-- Fixes EquipmentUI + Better Dressed interaction where dynamic EquipmentSlot widgets can become orphaned
-- (not referenced by dynamicSlotsByBodyLocation anymore), leaving stale item refs and causing slot/widget
-- count to grow over time -> FPS decay when the panel is visible.
--
-- Strategy:
--   - Track every dynamic EquipmentSlot created/reused by BodySlotDisplay
--   - On each updateDynamicEquipmentSlots(): hard-reset ALL dynamic slots, then rebuild from worn items.
--   - Avoid pool duplication with a per-slot inPool flag.
--   - Hide TransmogDE utility locations from dynamic slots.

local function _normalizeModId(id)
    return (id and tostring(id) or ""):lower()
        :gsub("\\", "")
        :gsub("/", "")
        :gsub("%s+", "")
end

local function _isModActive(modId)
    local mods = getActivatedMods and getActivatedMods() or nil
    if not mods then return false end

    local needle = _normalizeModId(modId)

    for i = 0, mods:size() - 1 do
        if _normalizeModId(mods:get(i)) == needle then
            return true
        end
    end

    return false
end

if not _isModActive("Equipment_UI") then
    TmogPrint("Equipment UI not installed -> skipping Fix")
    return
end

local MOD = "TransmogDE"
local DEBUG = getCore():getDebug()

local function dlog(msg)
    if not DEBUG then return end
    DebugLog.log(DebugType.General, "[" .. MOD .. "] " .. tostring(msg))
end

local HIDDEN_BODYLOC_IDS = {
    ["TransmogDE:Transmog_Location"] = true,
    ["TransmogDE:Hide_Everything_Location"] = true,
}

local function bodyLocId(bodyLocation)
    if not bodyLocation then return nil end
    if bodyLocation.getId then
        return tostring(bodyLocation:getId())
    end
    return tostring(bodyLocation)
end

local function ensureDynTracking(self)
    self.__TransmogDE_allDynSlots = self.__TransmogDE_allDynSlots or {}
end

local function markInPool(slot, inPool)
    slot.__TransmogDE_inPool = inPool and true or false
end

local function pushToPool(self, slot)
    if not slot then return end
    if slot.__TransmogDE_inPool then
        return -- already pooled; prevent pool growth from duplicates
    end
    markInPool(slot, true)
    table.insert(self.dynamicSlotPool, slot)
end

local function popFromPool(self)
    if #self.dynamicSlotPool > 0 then
        local slot = self.dynamicSlotPool[#self.dynamicSlotPool]
        table.remove(self.dynamicSlotPool, #self.dynamicSlotPool)
        if slot then
            markInPool(slot, false)
            return slot
        end
    end
    return nil
end

local function hardResetAllDynamicSlots(self)
    ensureDynTracking(self)

    -- Hide + clear every dynamic slot we have ever seen.
    for i = 1, #self.__TransmogDE_allDynSlots do
        local slot = self.__TransmogDE_allDynSlots[i]
        if slot then
            slot:setVisible(false)
            if slot.setItem then slot:setItem(nil) end
            slot.item = nil
            pushToPool(self, slot)
        end
    end

    -- Replace map entirely; don't rely on it being accurate.
    self.dynamicSlotsByBodyLocation = {}
end

local function trackSlot(self, slot)
    ensureDynTracking(self)
    if slot.__TransmogDE_tracked then return end
    slot.__TransmogDE_tracked = true
    table.insert(self.__TransmogDE_allDynSlots, slot)
end

local function tryPatch()
    local okBSD, BodySlotDisplay = pcall(require, "EquipmentUI/UI/BodySlotDisplay")
    if not okBSD or not BodySlotDisplay then
        return false
    end

    local okSET, SETTINGS = pcall(require, "EquipmentUI/Settings")
    if not okSET or not SETTINGS then
        return false
    end

    if BodySlotDisplay.__TransmogDE_HardResetDynPatched then
        return true
    end

    ---------------------------------------------------------------------
    -- Wrap createDynamicEquipmentSlot to track slot widgets reliably
    ---------------------------------------------------------------------
    if BodySlotDisplay.createDynamicEquipmentSlot and not BodySlotDisplay.__TransmogDE_Patched_CreateDyn then
        local _oldCreate = BodySlotDisplay.createDynamicEquipmentSlot

        BodySlotDisplay.createDynamicEquipmentSlot = function(self, bodyLocation)
            local slot = _oldCreate(self, bodyLocation)
            if slot then
                trackSlot(self, slot)
                -- When EquipmentUI creates brand new slots, they aren't in the pool yet.
                -- Ensure our pool flag is sane.
                if slot.__TransmogDE_inPool == nil then
                    markInPool(slot, false)
                end
            end
            return slot
        end

        BodySlotDisplay.__TransmogDE_Patched_CreateDyn = true
    end

    ---------------------------------------------------------------------
    -- Replace updateDynamicEquipmentSlots with a hard-reset rebuild
    ---------------------------------------------------------------------
    if BodySlotDisplay.updateDynamicEquipmentSlots and not BodySlotDisplay.__TransmogDE_Patched_UpdateDyn then
        BodySlotDisplay.updateDynamicEquipmentSlots = function(self, ...)
            -- Defensive initialisation
            self.dynamicSlotPool = self.dynamicSlotPool or {}
            self.dynamicSlotsByBodyLocation = self.dynamicSlotsByBodyLocation or {}
            self.superSlotsByBodyLocation = self.superSlotsByBodyLocation or {}

            -- Hard reset avoids orphan slots & pool duplication
            hardResetAllDynamicSlots(self)

            local player = getSpecificPlayer(self.playerNum)
            local wornItems = player and player:getWornItems()
            if not wornItems then
                self.dynamicEquipmentY = SETTINGS.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET
                return
            end

            local MAX_COLUMN = 5
            local column, row = 0, 0

            for i = 1, wornItems:size() do
                local wornItem = wornItems:get(i - 1)
                local item = wornItem and wornItem:getItem()

                if item and not item:isHidden() then
                    local loc = wornItem:getLocation()
                    local id = bodyLocId(loc)

                    -- Hide TransmogDE utility locations from dynamic slots
                    if not (id and HIDDEN_BODYLOC_IDS[id]) then
                        -- Only create dynamic slots for locations not covered by super slots
                        if not self.superSlotsByBodyLocation[loc] then
                            if column >= MAX_COLUMN then
                                column = 0
                                row = row + 1
                            end

                            -- Prefer pool reuse (prevents creating endless children)
                            local slot = popFromPool(self)
                            if slot then
                                slot.bodyLocation = loc
                                slot:setVisible(true)
                                slot:setItem(nil)
                            else
                                slot = self:createDynamicEquipmentSlot(loc)
                            end

                            if slot then
                                trackSlot(self, slot)
                                slot:setX(SETTINGS.EQUIPMENT_DYNAMIC_SLOT_X_OFFSET + (column * (SETTINGS.SLOT_SIZE + SETTINGS.EQUIPMENT_DYNAMIC_SLOT_MARGIN)))
                                slot:setY(SETTINGS.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET + (row * (SETTINGS.SLOT_SIZE + SETTINGS.EQUIPMENT_DYNAMIC_SLOT_MARGIN)))
                                slot:setItem(item)
                                self.dynamicSlotsByBodyLocation[loc] = slot
                            end

                            column = column + 1
                        end
                    end
                end
            end

            if column > 0 then row = row + 1 end
            self.dynamicEquipmentY = SETTINGS.EQUIPMENT_DYNAMIC_SLOT_Y_OFFSET + (row * (SETTINGS.SLOT_SIZE + 4)) + 8
        end

        BodySlotDisplay.__TransmogDE_Patched_UpdateDyn = true
    end

    ---------------------------------------------------------------------
    -- Patch updateSlots so it also clears ALL dynamic slots (not just map entries)
    ---------------------------------------------------------------------
    if BodySlotDisplay.updateSlots and not BodySlotDisplay.__TransmogDE_Patched_UpdateSlots then
        local _oldUpdateSlots = BodySlotDisplay.updateSlots

        BodySlotDisplay.updateSlots = function(self, ...)
            -- Clear all tracked dynamic slots to prevent ghosts even if map is wrong
            if self.__TransmogDE_allDynSlots then
                for i = 1, #self.__TransmogDE_allDynSlots do
                    local slot = self.__TransmogDE_allDynSlots[i]
                    if slot then
                        if slot.setItem then slot:setItem(nil) end
                        slot.item = nil
                    end
                end
            end
            return _oldUpdateSlots(self, ...)
        end

        BodySlotDisplay.__TransmogDE_Patched_UpdateSlots = true
    end

    BodySlotDisplay.__TransmogDE_HardResetDynPatched = true
    dlog("EquipmentUI patched (hard reset dynamic slots + hide TransmogDE utility locations)")
    return true
end

-- Attach lazily: EquipmentUI loads when UI opens. Try once/sec until patched.
local tickCount = 0
local function onTick()
    tickCount = tickCount + 1
    if (tickCount % 60) ~= 0 then return end
    if tryPatch() then
        Events.OnTick.Remove(onTick)
    end
end

Events.OnGameStart.Add(function()
    if not tryPatch() then
        Events.OnTick.Add(onTick)
    end
end)
