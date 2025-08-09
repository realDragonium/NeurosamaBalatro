-- Overlay Detector
-- Detects dismissible overlay menus (like unlock overlays, not just side notifications)

local OverlayDetector = {}

-- Analyze what type of overlay is currently active
function OverlayDetector.analyze_overlay_type()
    if not G.OVERLAY_MENU then
        return nil
    end
    
    local overlay_type = {
        is_unlock_overlay = false,
        is_poker_hands_ui = false,
        is_settings_menu = false,
        overlay_name = "Unknown Overlay"
    }
    
    -- Check overlay definition for clues
    if G.OVERLAY_MENU.definition then
        local def = G.OVERLAY_MENU.definition
        
        -- Look for unlock-specific indicators
        local has_unlock_content = OverlayDetector.check_for_unlock_content(def)
        if has_unlock_content then
            overlay_type.is_unlock_overlay = true
            overlay_type.overlay_name = "Unlock Overlay"
        end
        
        -- Look for poker hands UI indicators
        local has_poker_hands_content = OverlayDetector.check_for_poker_hands_content(def)
        if has_poker_hands_content then
            overlay_type.is_poker_hands_ui = true
            overlay_type.overlay_name = "Poker Hands UI"
        end
        
        -- Look for settings menu indicators
        local has_settings_content = OverlayDetector.check_for_settings_content(def)
        if has_settings_content then
            overlay_type.is_settings_menu = true
            overlay_type.overlay_name = "Settings Menu"
        end
    end
    
    return overlay_type
end

-- Check if there's currently an unlock overlay active
function OverlayDetector.has_active_unlock_overlay()
    -- Check if overlay exists
    if not G.OVERLAY_MENU then
        return false
    end
    
    -- Try to determine if this is specifically an unlock overlay
    -- by examining the overlay content
    local overlay_info = OverlayDetector.analyze_overlay_type()
    return overlay_info and overlay_info.is_unlock_overlay
end

-- Get information about the current overlay
function OverlayDetector.get_overlay_info()
    if not OverlayDetector.has_active_unlock_overlay() then
        return nil
    end
    
    local overlay_info = {
        type = "overlay",
        name = "Overlay Menu",
        dismissible = true,
        details = {}
    }
    
    -- Try to determine what kind of overlay this is and extract details
    if G.OVERLAY_MENU then
        overlay_info.name = "Unlock Overlay"
        overlay_info.type = "unlock_overlay"
        
        -- Try to extract unlock details from the overlay
        if G.OVERLAY_MENU.definition then
            local def = G.OVERLAY_MENU.definition
            overlay_info.details = OverlayDetector.extract_overlay_details(def)
        end
    end
    
    return overlay_info
end

-- Check if overlay contains unlock-specific content
function OverlayDetector.check_for_unlock_content(definition)
    local found_unlock = false
    
    local function traverse_for_unlock(node, depth)
        if not node or depth > 10 or found_unlock then return end
        
        if type(node) == "table" then
            -- Look for unlock-specific text patterns
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    if text:match("[Uu]nlocked") or text:match("Achievement") or text:match("New.*unlocked") then
                        found_unlock = true
                        return
                    end
                elseif type(text) == "table" then
                    for _, text_line in ipairs(text) do
                        if type(text_line) == "string" and (text_line:match("[Uu]nlocked") or text_line:match("Achievement") or text_line:match("New.*unlocked")) then
                            found_unlock = true
                            return
                        end
                    end
                end
            end
            
            -- Look for unlock-specific button functions
            if node.config and node.config.button then
                local button = node.config.button
                if button == "dismiss_unlock" or button == "unlock_continue" then
                    found_unlock = true
                    return
                end
            end
            
            -- Traverse child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    traverse_for_unlock(child, depth + 1)
                end
            end
            
            -- Traverse numbered children
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    traverse_for_unlock(v, depth + 1)
                end
            end
        end
    end
    
    traverse_for_unlock(definition, 0)
    return found_unlock
end

-- Check if overlay contains poker hands UI content
function OverlayDetector.check_for_poker_hands_content(definition)
    local found_poker_hands = false
    
    local function traverse_for_poker_hands(node, depth)
        if not node or depth > 10 or found_poker_hands then return end
        
        if type(node) == "table" then
            -- Look for poker hands specific text patterns
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    if text:match("[Pp]oker [Hh]ands") or text:match("Hand Levels") or text:match("Royal Flush") or text:match("Straight Flush") then
                        found_poker_hands = true
                        return
                    end
                elseif type(text) == "table" then
                    for _, text_line in ipairs(text) do
                        if type(text_line) == "string" and (text_line:match("[Pp]oker [Hh]ands") or text_line:match("Hand Levels") or text_line:match("Royal Flush") or text_line:match("Straight Flush")) then
                            found_poker_hands = true
                            return
                        end
                    end
                end
            end
            
            -- Look for poker hands specific button functions
            if node.config and node.config.button then
                local button = node.config.button
                if button == "poker_hands" or button == "your_hands" or button == "hand_levels" then
                    found_poker_hands = true
                    return
                end
            end
            
            -- Traverse child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    traverse_for_poker_hands(child, depth + 1)
                end
            end
            
            -- Traverse numbered children
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    traverse_for_poker_hands(v, depth + 1)
                end
            end
        end
    end
    
    traverse_for_poker_hands(definition, 0)
    return found_poker_hands
end

-- Check if overlay contains settings menu content
function OverlayDetector.check_for_settings_content(definition)
    local found_settings = false
    
    local function traverse_for_settings(node, depth)
        if not node or depth > 10 or found_settings then return end
        
        if type(node) == "table" then
            -- Look for settings specific text patterns
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    if text:match("[Ss]ettings") or text:match("[Oo]ptions") or text:match("Audio") or text:match("Graphics") then
                        found_settings = true
                        return
                    end
                elseif type(text) == "table" then
                    for _, text_line in ipairs(text) do
                        if type(text_line) == "string" and (text_line:match("[Ss]ettings") or text_line:match("[Oo]ptions") or text_line:match("Audio") or text_line:match("Graphics")) then
                            found_settings = true
                            return
                        end
                    end
                end
            end
            
            -- Look for settings specific button functions
            if node.config and node.config.button then
                local button = node.config.button
                if button == "settings" or button == "options" or button == "audio_settings" then
                    found_settings = true
                    return
                end
            end
            
            -- Traverse child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    traverse_for_settings(child, depth + 1)
                end
            end
            
            -- Traverse numbered children
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    traverse_for_settings(v, depth + 1)
                end
            end
        end
    end
    
    traverse_for_settings(definition, 0)
    return found_settings
end

-- Extract details from overlay definition
function OverlayDetector.extract_overlay_details(definition)
    local details = {
        unlocked_items = {},
        unlock_type = "unknown"
    }
    
    -- Recursively search for unlock information in the UI definition
    local function traverse_ui(node, depth)
        if not node or depth > 10 then return end
        
        if type(node) == "table" then
            -- Look for text that might indicate what was unlocked
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    -- Check for unlock-related text patterns
                    if text:match("unlocked") or text:match("Unlocked") then
                        table.insert(details.unlocked_items, text)
                    end
                elseif type(text) == "table" then
                    for _, text_line in ipairs(text) do
                        if type(text_line) == "string" and (text_line:match("unlocked") or text_line:match("Unlocked")) then
                            table.insert(details.unlocked_items, text_line)
                        end
                    end
                end
            end
            
            -- Look for object references that might indicate what was unlocked
            if node.config and node.config.object then
                local obj = node.config.object
                if obj.config and obj.config.center then
                    local center = obj.config.center
                    if center.name then
                        table.insert(details.unlocked_items, center.name)
                        details.unlock_type = center.set or "unknown"
                    end
                end
            end
            
            -- Traverse child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    traverse_ui(child, depth + 1)
                end
            end
            
            -- Traverse numbered children
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    traverse_ui(v, depth + 1)
                end
            end
        end
    end
    
    traverse_ui(definition, 0)
    return details
end

-- Dismiss the current overlay
function OverlayDetector.dismiss_overlay()
    if G.OVERLAY_MENU then
        -- Try different ways to dismiss the overlay
        if G.FUNCS and G.FUNCS.exit_overlay_menu then
            G.FUNCS.exit_overlay_menu()
            return true
        elseif G.OVERLAY_MENU.remove then
            G.OVERLAY_MENU:remove()
            G.OVERLAY_MENU = nil
            return true
        end
    end
    
    return false
end

-- Build context string for overlay
function OverlayDetector.build_overlay_context()
    local overlay_info = OverlayDetector.get_overlay_info()
    if not overlay_info then
        return ""
    end
    
    local context_parts = {}
    
    table.insert(context_parts, "🎮 UNLOCK OVERLAY ACTIVE:")
    table.insert(context_parts, "Type: " .. (overlay_info.type or "unknown"))
    
    -- Add details about what was unlocked
    if overlay_info.details and #overlay_info.details.unlocked_items > 0 then
        table.insert(context_parts, "Unlocked Items:")
        for _, item in ipairs(overlay_info.details.unlocked_items) do
            table.insert(context_parts, "  - " .. item)
        end
        if overlay_info.details.unlock_type ~= "unknown" then
            table.insert(context_parts, "Category: " .. overlay_info.details.unlock_type)
        end
    else
        table.insert(context_parts, "Name: " .. (overlay_info.name or "Unknown Overlay"))
    end
    
    table.insert(context_parts, "Status: Can be dismissed with dismiss_overlay action")
    
    return table.concat(context_parts, "\n")
end

return OverlayDetector