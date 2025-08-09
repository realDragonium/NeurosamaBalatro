-- View Poker Hands Action
-- Opens the poker hands UI and provides context about hand levels for viewers

local function view_poker_hands_send_context()
    -- Get poker hand levels information
    local context_parts = {}
    table.insert(context_parts, "🃏 Poker Hand Levels:")
    
    if not G.GAME or not G.GAME.hands then
        table.insert(context_parts, "No hand data available")
    else
        local hand_levels = {}
        
        -- Get visible poker hands and their levels
        for hand_name, hand_data in pairs(G.GAME.hands) do
            -- Check if this hand type is visible/unlocked
            local is_visible = true
            if SMODS and SMODS.is_poker_hand_visible then
                is_visible = SMODS.is_poker_hand_visible(hand_name)
            end
            
            if is_visible and hand_data.level and hand_data.level > 0 then
                -- Get localized hand name
                local display_name = hand_name
                if G.localization and G.localization.misc and G.localization.misc.poker_hands then
                    display_name = G.localization.misc.poker_hands[hand_name] or hand_name
                end
                
                table.insert(hand_levels, {
                    name = display_name,
                    level = hand_data.level,
                    chips = hand_data.chips or 0,
                    mult = hand_data.mult or 0,
                    played = hand_data.played or 0
                })
            end
        end
        
        -- Sort by level descending, then by name
        table.sort(hand_levels, function(a, b)
            if a.level == b.level then
                return a.name < b.name
            end
            return a.level > b.level
        end)
        
        if #hand_levels == 0 then
            table.insert(context_parts, "No poker hands unlocked yet")
        else
            table.insert(context_parts, "Total Hand Types: " .. #hand_levels)
            table.insert(context_parts, "\nHand Levels (sorted by level):")
            
            for i, hand in ipairs(hand_levels) do
                local level_text = hand.name .. " - Level " .. hand.level .. 
                                   " (" .. hand.chips .. " chips, " .. hand.mult .. "x mult)"
                if hand.played > 0 then
                    level_text = level_text .. " [played " .. hand.played .. " times]"
                end
                table.insert(context_parts, "  " .. level_text)
            end
        end
    end
    
    local context_message = table.concat(context_parts, "\n")
    if sendWebSocketMessage then
        sendWebSocketMessage(context_message, true)
    end
end

local function view_poker_hands_executor(params)
    -- First, try to open the poker hands UI
    local poker_hands_opened = false
    
    -- Try to find and click the poker hands button/area
    local poker_hands_button = nil
    
    -- Look for poker hands UI elements by ID
    if G.buttons then
        local poker_hands_button_ids = {
            'poker_hands',
            'poker_hands_button',
            'view_poker_hands',
            'hand_levels',
            'your_hands'
        }
        
        for _, button_id in ipairs(poker_hands_button_ids) do
            poker_hands_button = G.buttons:get_UIE_by_ID(button_id)
            if poker_hands_button then
                break
            end
        end
    end
    
    -- Try clicking the found button
    if poker_hands_button and poker_hands_button.click then
        poker_hands_button:click()
        poker_hands_opened = true
    end
    
    -- Fallback: try G.FUNCS for poker hands
    if not poker_hands_opened and G.FUNCS then
        local poker_hands_funcs = {'poker_hands', 'your_hands', 'view_poker_hands', 'hand_levels'}
        for _, func_name in ipairs(poker_hands_funcs) do
            if G.FUNCS[func_name] then
                G.FUNCS[func_name]()
                poker_hands_opened = true
                break
            end
        end
    end
    
    -- Another fallback: try to find and click through menu UI
    if not poker_hands_opened then
        local function find_poker_hands_button(node)
            if not node then return nil end
            
            -- Check if this node is a poker hands button
            if node.config then
                -- Check button function
                if node.config.button == 'poker_hands' or node.config.button == 'your_hands' then
                    return node
                end
                
                -- Check for poker hands related text
                if node.config.text then
                    local text = node.config.text
                    if type(text) == "string" and (text:lower():find("poker") and text:lower():find("hand")) then
                        return node
                    end
                end
            end
            
            -- Check child nodes recursively
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    local found_button = find_poker_hands_button(child)
                    if found_button then return found_button end
                end
            end
            
            return nil
        end
        
        -- Search through overlay menu
        if G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
            poker_hands_button = find_poker_hands_button(G.OVERLAY_MENU.definition)
        elseif G.MENU and G.MENU.definition then
            poker_hands_button = find_poker_hands_button(G.MENU.definition)
        end
        
        -- Click if found
        if poker_hands_button and poker_hands_button.click then
            poker_hands_button:click()
            poker_hands_opened = true
        end
    end
    
    -- Wait a moment for UI to open, then send context
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 0.3, -- Small delay to let UI open
        func = function()
            view_poker_hands_send_context()
            return true
        end
    }))
    
    if poker_hands_opened then
        return true, "Opened poker hands view - context will follow"
    else
        return false, "Could not open poker hands view"
    end
end

local function create_view_poker_hands_action()
    -- Available during gameplay states where poker hands can be viewed
    local valid_states = {
        G.STATES.SELECTING_HAND,
        G.STATES.SHOP,
        G.STATES.BLIND_SELECT,
        G.STATES.MAIN_MENU,
        G.STATES.MENU
    }
    
    local is_valid_state = false
    for _, state in ipairs(valid_states) do
        if G.STATE == state then
            is_valid_state = true
            break
        end
    end
    
    if not is_valid_state then
        return nil
    end
    
    return {
        name = "view_poker_hands",
        definition = {
            name = "view_poker_hands",
            description = "Open poker hands UI to view hand levels, chips, and multipliers for viewers",
            parameters = {}
        },
        executor = view_poker_hands_executor
    }
end

return create_view_poker_hands_action