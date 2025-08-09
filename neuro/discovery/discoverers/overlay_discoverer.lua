-- Overlay Discoverer
-- Handles actions available when overlays are active (like deck view, poker hands UI, etc.)

local OverlayDetector = SMODS.load_file("context/overlay_detector.lua")()

-- Load overlay actions
local create_close_overlay_action = assert(SMODS.load_file("actions/menu/close_overlay.lua"))()

local OverlayDiscoverer = {}

-- Check if this discoverer applies - when there's any overlay active
function OverlayDiscoverer.is_applicable(current_state)
    return G.OVERLAY_MENU ~= nil
end

function OverlayDiscoverer.discover(current_state)
    local actions = {}
    
    -- When an overlay is active, we only want to provide the close overlay action
    local close_action = create_close_overlay_action()
    if close_action then
        table.insert(actions, close_action)
    end
    
    return actions
end

-- Check if we should suppress other discoverers when overlay is active
function OverlayDiscoverer.should_suppress_other_discoverers()
    if not G.OVERLAY_MENU then
        return false
    end
    
    -- Analyze overlay type to determine if we should suppress other actions
    local overlay_info = OverlayDetector.analyze_overlay_type()
    if overlay_info then
        -- For deck view, poker hands UI, and settings - suppress other actions
        if overlay_info.is_poker_hands_ui or overlay_info.is_settings_menu then
            return true
        end
        
        -- Check for deck view overlay patterns
        if overlay_info.overlay_name and (overlay_info.overlay_name:match("Deck") or overlay_info.overlay_name:match("deck")) then
            return true
        end
        
        -- For unlock overlays, don't suppress other actions (they handle their own logic)
        if overlay_info.is_unlock_overlay then
            return false
        end
    end
    
    -- Additional check: if we can detect it's a deck-related overlay by checking the overlay content
    if OverlayDiscoverer.is_deck_overlay() then
        return true
    end
    
    -- By default, if there's an overlay, suppress other actions unless it's specifically an unlock overlay
    return overlay_info and not overlay_info.is_unlock_overlay
end

-- Helper function to detect if the current overlay is a deck view overlay
function OverlayDiscoverer.is_deck_overlay()
    if not G.OVERLAY_MENU or not G.OVERLAY_MENU.definition then
        return false
    end
    
    -- Look for deck-specific patterns in the overlay
    local function search_for_deck_content(node, depth)
        if not node or depth > 10 then return false end
        
        if type(node) == "table" then
            -- Look for deck-related text
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    local lower_text = text:lower()
                    if lower_text:match("deck") or lower_text:match("cards") or 
                       lower_text:match("hearts") or lower_text:match("spades") or
                       lower_text:match("clubs") or lower_text:match("diamonds") then
                        return true
                    end
                end
            end
            
            -- Search child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    if search_for_deck_content(child, depth + 1) then
                        return true
                    end
                end
            end
            
            -- Search numbered children
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    if search_for_deck_content(v, depth + 1) then
                        return true
                    end
                end
            end
        end
        
        return false
    end
    
    return search_for_deck_content(G.OVERLAY_MENU.definition, 0)
end

return OverlayDiscoverer