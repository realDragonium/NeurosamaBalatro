-- Unlock Actions
-- Handles actions related to unlock overlays and notifications

local OverlayDetector = SMODS.load_file("context/overlay_detector.lua")()

local UnlockActions = {}

-- Dismiss the current unlock overlay (not the side notification)
function UnlockActions.dismiss_overlay(params)
    if not OverlayDetector.has_active_unlock_overlay() then
        return false, "No unlock overlay is currently active"
    end
    
    local overlay_info = OverlayDetector.get_overlay_info()
    local dismissed = OverlayDetector.dismiss_overlay()
    
    if dismissed then
        local message = "Dismissed unlock overlay"
        if overlay_info and overlay_info.name then
            message = message .. ": " .. overlay_info.name
        end
        return true, message
    else
        return false, "Failed to dismiss unlock overlay"
    end
end

return UnlockActions