-- Unlock Detector
-- Detects when unlock notifications appear and provides context + dismissal actions

local UnlockDetector = {}

-- Check if there's currently an unlock notification active
function UnlockDetector.has_active_unlock()
    return G.achievement_notification ~= nil
end

-- Extract information about the current unlock notification
function UnlockDetector.get_unlock_info()
    if not G.achievement_notification then
        return nil
    end
    
    -- Try to extract unlock information from the notification
    local unlock_info = {
        type = "unknown",
        achievement_key = "unknown",
        name = "Unknown Unlock",
        subtext = "Achievement"
    }
    
    -- If we have stored unlock info from the hook, use it
    if UnlockDetector._current_unlock then
        unlock_info = UnlockDetector._current_unlock
    else
        -- If no stored info, we have a generic unlock notification
        unlock_info.name = "Unlock Notification"
        unlock_info.subtext = "Something was unlocked"
    end
    
    return unlock_info
end

-- Dismiss the current unlock notification
function UnlockDetector.dismiss_unlock()
    if G.achievement_notification then
        G.achievement_notification:remove()
        G.achievement_notification = nil
        UnlockDetector._current_unlock = nil
        return true
    end
    return false
end

-- Build context string for unlock notifications
function UnlockDetector.build_unlock_context()
    local unlock_info = UnlockDetector.get_unlock_info()
    if not unlock_info then
        return ""
    end
    
    local context_parts = {}
    
    table.insert(context_parts, "🎉 UNLOCK NOTIFICATION:")
    
    -- If we have detailed info from the hook
    if UnlockDetector._current_unlock then
        table.insert(context_parts, "Type: " .. (unlock_info.type or "unknown"))
        table.insert(context_parts, "Item: " .. (unlock_info.name or "Unknown"))
        table.insert(context_parts, "Category: " .. (unlock_info.subtext or "Unknown"))
        
        if unlock_info.achievement_key and unlock_info.achievement_key ~= "unknown" then
            table.insert(context_parts, "Key: " .. unlock_info.achievement_key)
        end
    else
        -- Generic info for existing notifications
        table.insert(context_parts, "An achievement notification is currently visible")
        table.insert(context_parts, "Details: Check the notification panel on the right side")
    end
    
    table.insert(context_parts, "Status: Side notification (auto-dismisses)")
    
    return table.concat(context_parts, "\n")
end

-- Storage for current unlock info (set by the hooked notify_alert function)
UnlockDetector._current_unlock = nil

return UnlockDetector