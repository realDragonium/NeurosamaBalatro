-- Menu Context Builder
-- Handles main menu state information including overlays and tabs

local MenuContext = {}

-- Get current deck selection for New Run tab
function MenuContext.get_current_deck()
    if G.GAME and G.GAME.viewed_back then
        return G.GAME.viewed_back.name or "Unknown"
    elseif G.GAME and G.GAME.selected_back then
        return G.GAME.selected_back.name or "Unknown"
    end
    return "Unknown"
end

-- Get current stake name for New Run tab
function MenuContext.get_current_stake()
    local stake_level = 1
    if G.GAME and G.GAME.stake then
        stake_level = G.GAME.stake or 1
    end
    
    -- Get stake name from stake level
    if G.P_CENTER_POOLS and G.P_CENTER_POOLS["Stake"] and G.P_CENTER_POOLS["Stake"][stake_level] then
        return G.P_CENTER_POOLS["Stake"][stake_level].name
    end
    
    return "Stake " .. stake_level
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
    if G.SAVED_GAME and G.SAVED_GAME.GAME then
        save_info.has_save = true
        local saved_game = G.SAVED_GAME.GAME
        
        -- Get ante information
        local ante = 1
        if saved_game.round_resets and saved_game.round_resets.ante then
            ante = saved_game.round_resets.ante
        end
        
        -- Get deck information
        local deck_name = "Unknown Deck"
        if G.SAVED_GAME.BACK and G.SAVED_GAME.BACK.name then
            deck_name = G.SAVED_GAME.BACK.name
        end
        
        -- Get stake information
        local stake_name = "Unknown Stake"
        if saved_game.stake and G.P_CENTER_POOLS and G.P_CENTER_POOLS["Stake"] and G.P_CENTER_POOLS["Stake"][saved_game.stake] then
            stake_name = G.P_CENTER_POOLS["Stake"][saved_game.stake].name
        end
        
        -- Get money information
        local money = saved_game.dollars or 0
        
        -- Get current round/blind info if available
        local round_info = ""
        if saved_game.round then
            round_info = " (Round " .. (saved_game.round or 1) .. ")"
        end
        
        save_info.save_details = "Ante " .. ante .. round_info .. ", $" .. money .. " with " .. deck_name .. " (" .. stake_name .. ")"
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

    -- Check if overlay menu is active and get current tab
    if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup then
        table.insert(parts, "Menu Overlay: Active")
        table.insert(parts, "Current Tab: " .. G.SETTINGS.current_setup)

        -- Tab-specific context
        if G.SETTINGS.current_setup == "New Run" then
            local current_deck = MenuContext.get_current_deck()
            local current_stake = MenuContext.get_current_stake()
            table.insert(parts, "Selected Deck: " .. current_deck)
            table.insert(parts, "Selected Stake: " .. current_stake)

            -- List available decks
            local decks = MenuContext.get_available_decks()
            if #decks > 0 then
                table.insert(parts, "Available Decks:")
                for _, deck in ipairs(decks) do
                    local deck_desc = "  " .. deck.index .. ". " .. deck.name
                    if deck.name == MenuContext.get_current_deck() then
                        deck_desc = deck_desc .. " [SELECTED]"
                    end
                    table.insert(parts, deck_desc)
                end
            end

        elseif G.SETTINGS.current_setup == "Continue" then
            local save_info = MenuContext.get_save_info()
            if save_info.has_save then
                table.insert(parts, "Save File: " .. save_info.save_details)
            else
                table.insert(parts, "Save File: None available")
            end

        elseif G.SETTINGS.current_setup == "Challenges" then
            table.insert(parts, "Challenge Mode: Available")
        end

    else
        table.insert(parts, "Main Menu: No overlay active")
    end

    return table.concat(parts, "\n")
end

-- Store original functions for hooks
local original_change_selected_back = nil
local original_change_stake = nil

-- Initialize UI hooks to send context updates when selections change
function MenuContext.init_ui_hooks(api_handler)
    if not api_handler then return end
    
    -- Hook into deck selection changes
    if G.FUNCS and G.FUNCS.change_selected_back and not original_change_selected_back then
        original_change_selected_back = G.FUNCS.change_selected_back
        
        G.FUNCS.change_selected_back = function(args)
            -- Call original function
            local result = original_change_selected_back(args)
            
            -- Send deck change context update if we're in New Run tab
            if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup == "New Run" then
                MenuContext.send_deck_context_update(api_handler)
            end
            
            return result
        end
    end
    
    -- Hook into stake selection changes
    if G.FUNCS and G.FUNCS.change_stake and not original_change_stake then
        original_change_stake = G.FUNCS.change_stake
        
        G.FUNCS.change_stake = function(args)
            -- Call original function
            local result = original_change_stake(args)
            
            -- Send stake change context update if we're in New Run tab
            if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup == "New Run" then
                MenuContext.send_stake_context_update(api_handler)
            end
            
            return result
        end
    end
end

-- Send deck change context update
function MenuContext.send_deck_context_update(api_handler)
    if not api_handler then return end
    
    local current_deck = MenuContext.get_current_deck()
    local context_message = "Selected Deck: " .. current_deck
    api_handler:send_context(context_message, false)
end

-- Send stake change context update
function MenuContext.send_stake_context_update(api_handler)
    if not api_handler then return end
    
    local current_stake = MenuContext.get_current_stake()
    local context_message = "Selected Stake: " .. current_stake
    api_handler:send_context(context_message, false)
end

return MenuContext