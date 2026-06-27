-- /////////////////////////////////////////////////////////////////////////////
-- Visual masking rules
-- Key: visual "covering" BodyLocation
-- Value: list of visual BodyLocations that should be hidden if the covering
--        slot is visible.
--
-- NOTE:
--  * These are *visual* slots, i.e. what the player would see.
--  * The caller is responsible for deciding the visual slot
--    (original bodyLocation vs transmog target bodyLocation).
-- /////////////////////////////////////////////////////////////////////////////

local LEFTWRIST = "base:leftwrist"
local RIGHTWRIST = "base:rightwrist"
local FANNYPACK_BACK = "base:fannypackback"
local FANNYPACK_FRONT = "base:fannypackfront"
local SHORT_SLEEVE = "base:shortsleeveshirt"
local TANKTOP = "base:tanktop"
local JACKET_SUIT = "base:jacketsuit"
local JACKET = "base:jacket"
local SWEATER = "base:sweater"
local SWEATER_HAT = "base:sweaterhat"

TransmogDE.VisualMaskRules = {
    -- Suit Jackets/Long Jackets
    [JACKET_SUIT] = {
        LEFTWRIST,
        RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Jackets
    [JACKET] = {
        LEFTWRIST,
        RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Sweaters and Hoodies
    [SWEATER] = {
        -- If we hide watches for Sweaters we hide them for Sweater Vests too
        -- LEFTWRIST,
        -- RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Hoodies with hood up
    [SWEATER_HAT] = {
        -- Ignore hiding watches for all Sweater types, it doesnt look too horrible
        -- LEFTWRIST,
        -- RIGHTWRIST,
        FANNYPACK_BACK,
        FANNYPACK_FRONT,
    },
    -- Short Sleeve Shirts
    [SHORT_SLEEVE] = {
        TANKTOP,
    },
}

--- Add a new visual masking rule.
-- @param coveringSlot string  BodyLocation of the covering visual slot (e.g. "Jacket")
-- @param hiddenSlot   string  BodyLocation of the visual slot to hide (e.g. "FannyPackFront")
function TransmogDE.addVisualMaskRule(coveringSlot, hiddenSlot)
    if not coveringSlot or not hiddenSlot then return end

    local rules = TransmogDE.VisualMaskRules
    rules[coveringSlot] = rules[coveringSlot] or {}

    -- Avoid duplicates
    for _, existing in ipairs(rules[coveringSlot]) do
        if existing == hiddenSlot then
            return
        end
    end

    table.insert(rules[coveringSlot], hiddenSlot)
end

-- Return the *visual* BodyLocation for a given worn item.
-- This respects TransmogDE state:
--   * if the item is transmogged, we return the BodyLocation of the transmog target
--   * otherwise we return the item's own BodyLocation.
function TransmogDE.getItemVisualBodyLocation(item)
    if not item then
        return nil
    end

    local scriptItem = item:getScriptItem()
    if not scriptItem then
        return nil
    end

    -- Default: use the item's own body location.
    local bodyLoc = scriptItem:getBodyLocation() or item:getBodyLocation()

    -- If the item is transmogged, prefer the BodyLocation of the transmog target.
    if TransmogDE and TransmogDE.getItemTransmogModData and TransmogDE.isTransmoggable
        and TransmogDE.isTransmoggable(item) then

        local tmogData = TransmogDE.getItemTransmogModData(item)
        if tmogData and tmogData.transmogTo then
            local sm = getScriptManager()
            if sm then
                local targetScriptItem = sm:FindItem(tmogData.transmogTo)
                if targetScriptItem then
                    bodyLoc = targetScriptItem:getBodyLocation() or bodyLoc
                end
            end
        end
    end

    return bodyLoc
end

--- Get all visual slots that should be hidden when a given covering slot is visible.
-- @param coveringSlot string BodyLocation of the covering visual slot.
-- @return table<string, boolean>  Set-style table of hidden slots, e.g. { FannyPackFront = true, ... }
function TransmogDE.getHiddenVisualSlotsForCovering(item)
    local coveringSlot = TransmogDE.getItemVisualBodyLocation(item)
    local coveringSlotString = tostring(coveringSlot)
    TmogPrint("Slot name: " .. coveringSlotString)
    if coveringSlot then
        local out = {}
        local rules = TransmogDE.VisualMaskRules[coveringSlotString]
        if not rules then return out end

        for _, slot in ipairs(rules) do
            out[slot] = true
            TmogPrint("Hides: " .. tostring(slot))
        end

        return out
    end
end