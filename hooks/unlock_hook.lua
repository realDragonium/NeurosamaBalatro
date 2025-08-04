-- Unlock Hook
-- Hooks into notify_alert to capture unlock information

local UnlockDetector = SMODS.load_file("context/unlock_detector.lua")()
local ActionRegistry = SMODS.load_file("neuro/action_registry.lua")()
local UnlockActions = SMODS.load_file("actions/unlock_actions.lua")()

-- Store original notify_alert function
local original_notify_alert = notify_alert

-- Hook the notify_alert function to capture unlock information
function notify_alert(_achievement, _type)
    _type = _type or 'achievement'
    
    -- Capture unlock information for the detector
    local unlock_info = {
        achievement_key = _achievement,
        type = _type,
        name = "Unknown",
        subtext = ""
    }
    
    -- Extract name and subtext based on type
    if _type == 'achievement' then
        unlock_info.name = localize(_achievement, 'achievement_names') or _achievement
        unlock_info.subtext = localize(G.F_TROPHIES and 'k_trophy' or 'k_achievement')
    elseif _type == 'Joker' then
        if G.P_CENTERS[_achievement] then
            unlock_info.name = G.P_CENTERS[_achievement].name or _achievement
        end
        unlock_info.subtext = localize('k_joker')
    elseif _type == 'Voucher' then
        if G.P_CENTERS[_achievement] then
            unlock_info.name = G.P_CENTERS[_achievement].name or _achievement
        end
        unlock_info.subtext = localize('k_voucher')
    elseif _type == 'Back' then
        if G.P_CENTERS[_achievement] then
            unlock_info.name = G.P_CENTERS[_achievement].name or _achievement
        end
        unlock_info.subtext = localize('k_deck')
    end
    
    -- Special case for challenge unlock
    if _achievement == 'b_challenge' then
        unlock_info.subtext = localize('k_challenges')
    end
    
    -- Store the unlock info for the detector
    UnlockDetector._current_unlock = unlock_info
    
    -- Send unlock notification context (side alert - not dismissible via action)
    local unlock_context = UnlockDetector.build_unlock_context()
    if unlock_context ~= "" then
        sendInfoMessage(unlock_context, "UnlockNotification")
    end
    
    -- Call the original function
    return original_notify_alert(_achievement, _type)
end