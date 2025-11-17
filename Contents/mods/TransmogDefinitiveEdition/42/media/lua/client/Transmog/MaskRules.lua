TransmogDE = TransmogDE or {}

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

TransmogDE.VisualMaskRules = {
    -- Jackets (leather, suit jackets, bombers, etc.)
    -- In vanilla behaviour, these visually cover fannypacks.
    Jacket = {
        "FannyPackFront",
        "FannyPackBack",
    },

    -- Full-body suits / overalls which clearly cloak the waist area.
    -- You can adjust this once we look at specific items you care about.
    FullSuit = {
        "FannyPackFront",
        "FannyPackBack",
        -- If we decide later that things like belt pouches / rigs
        -- should be hidden too, we can add:
        -- "BeltExtra",
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

--- Get all visual slots that should be hidden when a given covering slot is visible.
-- @param coveringSlot string BodyLocation of the covering visual slot.
-- @return table<string, boolean>  Set-style table of hidden slots, e.g. { FannyPackFront = true, ... }
function TransmogDE.getHiddenVisualSlotsForCovering(coveringSlot)
    local out = {}
    local rules = TransmogDE.VisualMaskRules[coveringSlot]
    if not rules then return out end

    for _, slot in ipairs(rules) do
        out[slot] = true
    end

    return out
end
