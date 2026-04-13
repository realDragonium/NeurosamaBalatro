-- Close Overlay Action
-- Closes any active overlay (deck view, poker hands UI, settings, etc.)

local OverlayDetector = SMODS.load_file("context/overlay_detector.lua")()

-- Helper function to find close/back buttons in overlay UI
local function find_close_button(definition)
    local function search_for_close_button(node, depth)
        if not node or depth > 10 then return nil end
        
        if type(node) == "table" then
            -- Look for close/back button functions
            if node.config and node.config.button then
                local button = node.config.button
                if button == "exit_overlay_menu" or 
                   button == "back" or 
                   button == "close" or 
                   button == "cancel" or
                   button == "dismiss" then
                    return node
                end
            end
            
            -- Look for close/back button text
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    local lower_text = text:lower()
                    if lower_text:match("close") or 
                       lower_text:match("back") or 
                       lower_text:match("exit") or 
                       lower_text:match("cancel") then
                        return node
                    end
                end
            end
            
            -- Search child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    local found = search_for_close_button(child, depth + 1)
                    if found then return found end
                end
            end
            
            -- Search numbered children
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    local found = search_for_close_button(v, depth + 1)
                    if found then return found end
                end
            end
        end
        
        return nil
    end
    
    return search_for_close_button(definition, 0)
end

local function close_overlay_executor(params)
    if not G.OVERLAY_MENU then
        return false, "No overlay is currently active"
    end
    
    -- Analyze what type of overlay this is
    local overlay_info = OverlayDetector.analyze_overlay_type()
    local overlay_name = "overlay"
    if overlay_info then
        overlay_name = overlay_info.overlay_name or "overlay"
    end
    
    -- Try different ways to close the overlay
    local closed = false
    
    -- Method 1: Try standard exit overlay function
    if G.FUNCS and G.FUNCS.exit_overlay_menu then
        G.FUNCS.exit_overlay_menu()
        closed = true
    
    -- Method 2: Try to find and click close/back button
    elseif G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
        local close_button = find_close_button(G.OVERLAY_MENU.definition)
        if close_button and close_button.click then
            close_button:click()
            closed = true
        end
    
    -- Method 3: Try direct removal
    elseif G.OVERLAY_MENU and G.OVERLAY_MENU.remove then
        G.OVERLAY_MENU:remove()
        G.OVERLAY_MENU = nil
        closed = true
    
    -- Method 4: Try pressing Escape key equivalent
    elseif G.CONTROLLER and G.CONTROLLER.key then
        G.CONTROLLER.key('escape', false)
        closed = true
    end
    
    if closed then
        return true, "Closed " .. overlay_name
    else
        return false, "Failed to close overlay"
    end
end

local function create_close_overlay_action()
    -- Only available when there's an active overlay
    if G.OVERLAY_MENU then
        return {
            name = "close_overlay",
            definition = {
                name = "close_overlay",
                description = "Close the currently open overlay (deck view, poker hands UI, etc.)",
                parameters = {}
            },
            executor = close_overlay_executor
        }
    end
    
    return nil
end

return create_close_overlay_action