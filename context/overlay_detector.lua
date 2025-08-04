-- Overlay Detector
-- Detects dismissible overlay menus (like unlock overlays, not just side notifications)

local OverlayDetector = {}

-- Check if there's currently an unlock overlay active
function OverlayDetector.has_active_unlock_overlay()
    -- Check common overlay variables
    if G.OVERLAY_MENU then
        return true
    end
    
    -- Check other possible overlay indicators
    if G.FUNCS and G.FUNCS.overlay_menu and G.OVERLAY_MENU then
        return true
    end
    
    return false
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