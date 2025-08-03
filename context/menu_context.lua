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
local original_change_viewed_back = nil
local original_change_stake = nil

-- Initialize UI hooks to send context updates when selections change
function MenuContext.init_ui_hooks(api_handler)
    if not api_handler then return end
    
    -- Hook into deck selection changes
    if G.FUNCS and G.FUNCS.change_viewed_back and not original_change_viewed_back then
        original_change_viewed_back = G.FUNCS.change_viewed_back
        
        G.FUNCS.change_viewed_back = function(args)
            -- Call original function
            local result = original_change_viewed_back(args)
            
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

-- Helper function to extract text from UI nodes (copied from view_available_decks)
local function extract_text_from_ui_nodes(ui_node)
    local text_parts = {}
    
    local function traverse_node(node)
        if not node then return end
        
        -- Check if this node has text
        if node.config and node.config.text then
            if type(node.config.text) == "string" then
                table.insert(text_parts, node.config.text)
            elseif type(node.config.text) == "table" then
                for _, text_line in ipairs(node.config.text) do
                    if type(text_line) == "string" then
                        table.insert(text_parts, text_line)
                    end
                end
            end
        end
        
        -- Recursively check child nodes
        if node.nodes then
            for _, child in ipairs(node.nodes) do
                traverse_node(child)
            end
        end
    end
    
    traverse_node(ui_node)
    
    if #text_parts == 0 then
        return ""
    end
    
    local result = table.concat(text_parts, " ")
    -- Clean up formatting tags and normalize whitespace
    result = result:gsub("{[^}]*}", "")
    result = result:gsub("%s+", " ")
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    
    return result
end

-- Get detailed deck description with unlock conditions
local function get_detailed_deck_description()
    if not (G.GAME and G.GAME.viewed_back) then
        return "Unknown Deck"
    end
    
    local deck = G.GAME.viewed_back.effect and G.GAME.viewed_back.effect.center
    if not deck then
        return "Unknown Deck"
    end
    
    local desc = deck.name or "Unknown Deck"
    
    if not deck.unlocked then
        -- Show unlock condition
        if deck.unlock_condition then
            if deck.unlock_condition.type == 'win_deck' then
                local other_deck_name = "Unknown Deck"
                if G.P_CENTERS[deck.unlock_condition.deck] and G.P_CENTERS[deck.unlock_condition.deck].unlocked then
                    other_deck_name = G.P_CENTERS[deck.unlock_condition.deck].name or "Unknown Deck"
                end
                desc = desc .. " [LOCKED - Win with " .. other_deck_name .. "]"
            elseif deck.unlock_condition.type == 'discover_amount' then
                desc = desc .. " [LOCKED - Discover " .. tostring(deck.unlock_condition.amount) .. " Jokers]"
            elseif deck.unlock_condition.type == 'win_stake' then
                local stake_name = "Unknown Stake"
                if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Stake and G.P_CENTER_POOLS.Stake[deck.unlock_condition.stake] then
                    stake_name = G.P_CENTER_POOLS.Stake[deck.unlock_condition.stake].name or "Unknown Stake"
                end
                desc = desc .. " [LOCKED - Win on " .. stake_name .. "]"
            else
                desc = desc .. " [LOCKED]"
            end
        else
            desc = desc .. " [LOCKED]"
        end
    else
        -- Use Back:generate_UI to get properly formatted description
        local effect_desc = ""
        
        -- Create a fake Back object to call generate_UI on
        local fake_back = {
            effect = {
                center = deck,
                config = deck.config
            },
            name = deck.name
        }
        
        -- Try to call Back:generate_UI
        if Back and Back.generate_UI then
            local success, ui_result = pcall(Back.generate_UI, fake_back, deck)
            if success and ui_result then
                -- Extract text from UI nodes
                effect_desc = extract_text_from_ui_nodes(ui_result)
            end
        end
        
        if effect_desc ~= "" then
            desc = desc .. " (" .. effect_desc .. ")"
        end
    end
    
    return desc
end

-- Send deck change context update
function MenuContext.send_deck_context_update(api_handler)
    if not api_handler then return end
    
    local detailed_deck = get_detailed_deck_description()
    local context_message = "Selected Deck: " .. detailed_deck
    api_handler:send_context(context_message, true)  -- Silent update
end

-- Get detailed stake description (copied from view_available_stakes)
local function get_detailed_stake_description()
    local stake_level = 1
    if G.GAME and G.GAME.stake then
        stake_level = G.GAME.stake or 1
    end
    
    -- Get stake object from stake level
    local stake = nil
    if G.P_CENTER_POOLS and G.P_CENTER_POOLS["Stake"] and G.P_CENTER_POOLS["Stake"][stake_level] then
        stake = G.P_CENTER_POOLS["Stake"][stake_level]
    end
    
    if not stake then
        return "Stake " .. stake_level
    end
    
    local desc = stake.name or "Unknown Stake"
    
    -- Try to get localized description similar to deck approach
    if G.localization and G.localization.descriptions and G.localization.descriptions.Stake and G.localization.descriptions.Stake[stake.key] then
        local desc_template = G.localization.descriptions.Stake[stake.key].text
        if desc_template then
            local effect_desc = ""
            if type(desc_template) == "table" then
                effect_desc = table.concat(desc_template, " ")
            else
                effect_desc = tostring(desc_template)
            end
            
            -- Get loc_vars for variable substitution
            local loc_vars = {}
            if stake.loc_vars and type(stake.loc_vars) == 'function' then
                local res = stake:loc_vars() or {}
                loc_vars = res.vars or {}
            end
            
            -- Replace variables in the description
            if type(loc_vars) == "table" then
                local i = 1
                for k, v in pairs(loc_vars) do
                    if type(v) == "number" then
                        effect_desc = effect_desc:gsub("#" .. i .. "#", tostring(v))
                        i = i + 1
                    elseif type(v) == "string" then
                        effect_desc = effect_desc:gsub("#" .. i .. "#", v)
                        i = i + 1
                    end
                end
            end
            
            -- Clean up formatting codes
            effect_desc = effect_desc:gsub("{[^}]*}", "")
            effect_desc = effect_desc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            
            if effect_desc ~= "" then
                desc = desc .. " (" .. effect_desc .. ")"
            end
        end
    end
    
    return desc
end

-- Send stake change context update
function MenuContext.send_stake_context_update(api_handler)
    if not api_handler then return end
    
    local detailed_stake = get_detailed_stake_description()
    local context_message = "Selected Stake: " .. detailed_stake
    api_handler:send_context(context_message, true)  -- Silent update
end

return MenuContext