
if not TransmogDE then
    TransmogDE = {}
end

---------------------------------------------------------
-- Single source of truth for Transmog tooltip lines
--
-- Returns:
--   nil  -> no transmog info
--   or { { text="...", r=1,g=0.6,b=0 }, ... }
--
-- Logic based on previously shipped Transmog_TooltipInv.lua:
--   - Only for items TransmogDE.isTransmoggable(item).
--   - Uses TransmogDE.getItemTransmogModData(item).
--   - If transmogTo == original script full name -> no line.
--   - If transmogTo set        -> "Transmogged to: %1".
--   - If transmogTo missing    -> "Transmog: Hidden".
---------------------------------------------------------
function TransmogDE.getTooltipLines(item)
    if not item
        or not TransmogDE
        or not TransmogDE.isTransmoggable
        or not TransmogDE.getItemTransmogModData
    then
        return nil
    end

    if not TransmogDE.isTransmoggable(item) then
        return nil
    end

    local md = TransmogDE.getItemTransmogModData(item)
    if not md then
        return nil
    end

    local scriptItem = item.getScriptItem and item:getScriptItem() or nil
    local baseFullName = scriptItem and scriptItem.getFullName and scriptItem:getFullName() or nil

    -- If explicitly transmogged back to itself -> no special line.
    if md.transmogTo and baseFullName and md.transmogTo == baseFullName then
        return nil
    end

    local lines = {}

    if md.transmogTo then
        local targetName = getItemNameFromFullType and getItemNameFromFullType(md.transmogTo) or md.transmogTo
        local text = getText("IGUI_TransmogDE_Tooltip_TransmogTo", targetName)
        table.insert(lines, {
            text = text,
            r = 1.0, g = 0.6, b = 0.0,
        })
    else
        -- Hidden / no-appearance case
        local text = getText("IGUI_TransmogDE_Tooltip_TransmogHidden")
        table.insert(lines, {
            text = text,
            r = 1.0, g = 0.6, b = 0.0,
        })
    end

    if #lines == 0 then
        return nil
    end

    return lines
end