-- View Available Decks Action
-- Shows all available decks with their effects

-- Helper function to extract text from UI nodes
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

local function get_deck_description(deck)
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

local function view_available_decks_executor(params)
    -- Build and send context with available decks
    local context_parts = {"Available Decks:"}
    
    if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Back then
        for i, deck in ipairs(G.P_CENTER_POOLS.Back) do
            if deck then
                local deck_desc = "  " .. i .. ". " .. get_deck_description(deck)
                
                -- Mark currently selected deck
                local current_deck = G.GAME and G.GAME.viewed_back and G.GAME.viewed_back.name
                if not current_deck and G.GAME and G.GAME.selected_back then
                    current_deck = G.GAME.selected_back.name
                end
                
                if deck.name == current_deck then
                    deck_desc = deck_desc .. " [SELECTED]"
                end
                
                table.insert(context_parts, deck_desc)
            end
        end
    end
    
    local context_message = table.concat(context_parts, "\n")
    if sendWebSocketMessage then
        sendWebSocketMessage(context_message, true)
    end
    
    return true, "Available decks information provided"
end


local function create_view_available_decks_action()
    -- Only create if we're in New Run tab
    if not (G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup == "New Run") then
        return nil
    end

    return {
        name = "view_available_decks",
        definition = {
            name = "view_available_decks",
            description = "View all available decks with their effects",
            parameters = {}
        },
        executor = view_available_decks_executor
    }
end

return create_view_available_decks_action