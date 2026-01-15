-- ==========================================================
-- [TransmogDE] Timed Action Queue Logger (Debug Helper)
-- ==========================================================
local _orig_Add = ISTimedActionQueue.add
function ISTimedActionQueue.add(action)
    if action then
        local className = tostring(action.Type) or action.__index and tostring(action.__index) or "Unknown"
        TmogPrint("[TAQ] Queued: " .. className)
    end
    return _orig_Add(action)
end