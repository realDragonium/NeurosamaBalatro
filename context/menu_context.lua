-- Menu Context Builder
-- Handles main menu state information including overlays and tabs

local MenuContext = {}

-- Get current menu state and overlay info
function MenuContext.get_menu_state()
    local state = {
        has_overlay = false,
        current_tab = "None",
        current_deck = "Unknown",
        current_stake = 1
    }
    
    -- Check if overlay menu is active
    if G.OVERLAY_MENU then
        state.has_overlay = true
        
        -- Get current tab
        if G.SETTINGS and G.SETTINGS.current_setup then
            state.current_tab = G.SETTINGS.current_setup
        end
    end
    
    -- Get current deck selection (if available)
    if G.GAME and G.GAME.viewed_back then
        state.current_deck = G.GAME.viewed_back.name or "Unknown"
    elseif G.GAME and G.GAME.selected_back then
        state.current_deck = G.GAME.selected_back.name or "Unknown"
    end
    
    -- Get current stake level (if available)
    if G.GAME and G.GAME.stake then
        state.current_stake = G.GAME.stake or 1
    end
    
    return state
end

-- Get available decks
function MenuContext.get_available_decks()
    local decks = {}
    
    if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back then
        for i, deck in ipairs(G.P_CENTER_POOLS.Back) do
            if deck then
                table.insert(decks, {
                    index = i,
                    name = deck.name or "Unknown Deck",
                    key = deck.key or "unknown"
                })
            end
        end
    end
    
    return decks
end

-- Get save file info (for continue tab)
function MenuContext.get_save_info()
    local save_info = {
        has_save = false,
        save_details = "No save file"
    }
    
    -- Check if there's a save file to continue
    if G.GAME and G.GAME.round_resets then
        save_info.has_save = true
        local ante = G.GAME.round_resets.ante or 1
        local deck_name = G.GAME.selected_back and G.GAME.selected_back.name or "Unknown Deck"
        save_info.save_details = "Ante " .. ante .. " with " .. deck_name
    end
    
    return save_info
end

-- Build menu context string
function MenuContext.build_context_string()
    local parts = {}
    
    -- Only show menu context when in menu states
    if G.STATE ~= G.STATES.MAIN_MENU and G.STATE ~= G.STATES.MENU then
        return ""
    end
    
    local menu_state = MenuContext.get_menu_state()
    
    if menu_state.has_overlay then
        table.insert(parts, "Menu Overlay: Active")
        table.insert(parts, "Current Tab: " .. menu_state.current_tab)
        
        -- Tab-specific context
        if menu_state.current_tab == "New Run" then
            table.insert(parts, "Selected Deck: " .. menu_state.current_deck)
            table.insert(parts, "Selected Stake: " .. menu_state.current_stake)
            
            -- List available decks
            local decks = MenuContext.get_available_decks()
            if #decks > 0 then
                table.insert(parts, "Available Decks:")
                for _, deck in ipairs(decks) do
                    local deck_desc = "  " .. deck.index .. ". " .. deck.name
                    if deck.name == menu_state.current_deck then
                        deck_desc = deck_desc .. " [SELECTED]"
                    end
                    table.insert(parts, deck_desc)
                end
            end
            
        elseif menu_state.current_tab == "Continue" then
            local save_info = MenuContext.get_save_info()
            if save_info.has_save then
                table.insert(parts, "Save File: " .. save_info.save_details)
            else
                table.insert(parts, "Save File: None available")
            end
            
        elseif menu_state.current_tab == "Challenges" then
            table.insert(parts, "Challenge Mode: Available")
        end
        
    else
        table.insert(parts, "Main Menu: No overlay active")
    end
    
    return table.concat(parts, "\n")
end

return MenuContext