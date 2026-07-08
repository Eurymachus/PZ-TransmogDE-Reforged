
if not TransmogDE then
    TransmogDE = {}
end

local function transmogTooltipLine(value)
    return {
        label = getTextOrNull("IGUI_TransmogDE_Tooltip_Label") or "Transmog:",
        value = value,
        labelR = 1.0, labelG = 0.6, labelB = 0.0,
        valueR = 1.0, valueG = 1.0, valueB = 0.8,
    }
end

local function addTransmogTooltipLine(lines, value)
    table.insert(lines, transmogTooltipLine(value))
end

---------------------------------------------------------
-- Single source of truth for Transmog tooltip lines
--
-- Returns:
--   nil  -> no transmog info
--   or { { text="...", r=1,g=0.6,b=0 }, ... }
--
-- Logic based on previously shipped Transmog_TooltipInv.lua:
--   - Shows hidden attached-model state for any item.
--   - Shows normal transmog state for TransmogDE.isTransmoggable(item).
--   - Uses TransmogDE.getItemTransmogModData(item) for normal transmog state.
--   - If transmogTo == original script full name -> no line.
--   - If transmogTo set        -> "Transmogged to: %1".
--   - If transmogTo missing    -> "Transmog: Hidden".
---------------------------------------------------------
function TransmogDE.getTooltipLines(item)
    if not item or not TransmogDE then
        return nil
    end

    local lines = {}

    if TransmogDE.isAttachmentModelHidden and TransmogDE.isAttachmentModelHidden(item) then
        addTransmogTooltipLine(lines,
            getTextOrNull("IGUI_TransmogDE_Tooltip_AttachmentHiddenValue")
                or "<Hidden> (while attached)"
        )
    end

    if not TransmogDE.isTransmoggable
        or not TransmogDE.getItemTransmogModData
        or not TransmogDE.isTransmoggable(item) then
        return #lines > 0 and lines or nil
    end

    local md = TransmogDE.getItemTransmogModData(item)
    if not md then
        return #lines > 0 and lines or nil
    end

    local scriptItem = item.getScriptItem and item:getScriptItem() or nil
    local baseFullName = scriptItem and scriptItem.getFullName and scriptItem:getFullName() or nil

    -- If explicitly transmogged back to itself -> no special line.
    if md.transmogTo and baseFullName and md.transmogTo == baseFullName then
        return #lines > 0 and lines or nil
    end

    if md.transmogTo then
        local targetName = getItemNameFromFullType and getItemNameFromFullType(md.transmogTo) or md.transmogTo
        addTransmogTooltipLine(lines, targetName)
    else
        -- Hidden / no-appearance case
        addTransmogTooltipLine(lines,
            getTextOrNull("IGUI_TransmogDE_Tooltip_TransmogHiddenValue") or "<Hidden>"
        )
    end

    if #lines == 0 then
        return nil
    end

    return lines
end
