-- View Current Deck Action
-- Shows current deck composition during gameplay

local CardUtils = SMODS.load_file("context/card_utils.lua")()

local function get_card_description(card)
    local desc = ""
    
    if card.config and card.config.card then
        local rank = card.config.card.rank or "Unknown"
        local suit = card.config.card.suit or "Unknown"
        
        -- Convert rank/suit to readable names
        if rank and G.localization and G.localization.misc and G.localization.misc.ranks then
            rank = G.localization.misc.ranks[rank] or rank
        end
        if suit and G.localization and G.localization.misc and G.localization.misc.suits_plural then
            suit = G.localization.misc.suits_plural[suit] or suit
        end
        
        desc = rank .. " of " .. suit
    else
        desc = "Unknown Card"
    end
    
    -- Add enhancement if present
    if card.config and card.config.center and card.config.center.name then
        local enhancement = card.config.center.name
        if enhancement ~= "Base" then
            desc = desc .. " [" .. enhancement .. "]"
        end
    end
    
    -- Add special attributes using shared CardUtils function
    local special_attrs = CardUtils.get_card_attributes(card)
    if #special_attrs > 0 then
        desc = desc .. " [" .. table.concat(special_attrs, ", ") .. "]"
    end
    
    return desc
end

local function view_deck_send_context()
    local context_parts = {}
    
    if not G.deck or not G.deck.cards then
        table.insert(context_parts, "Current Deck: No cards in deck")
    else
        local deck_size = #G.deck.cards
        table.insert(context_parts, "🃏 Current Deck Overview:")
        
        -- Get deck name if available
        local deck_name = "Unknown Deck"
        if G.GAME and G.GAME.selected_back then
            deck_name = G.GAME.selected_back.name or deck_name
        end
        table.insert(context_parts, "Deck Type: " .. deck_name)
        table.insert(context_parts, "Total Cards: " .. deck_size)
        
        -- Count cards by suit
        local suit_counts = {Spades = 0, Hearts = 0, Diamonds = 0, Clubs = 0}
        local enhanced_cards = {}
        local special_cards = {}
        
        for _, card in ipairs(G.deck.cards) do
            -- Count by suit
            if card.config and card.config.card and card.config.card.suit then
                local suit = card.config.card.suit
                local suit_name = "Unknown"
                if suit and G.localization and G.localization.misc and G.localization.misc.suits_plural then
                    suit_name = G.localization.misc.suits_plural[suit] or suit
                end
                if suit_counts[suit_name] then
                    suit_counts[suit_name] = suit_counts[suit_name] + 1
                end
            end
            
            -- Check for enhancements
            if card.config and card.config.center and card.config.center.name and card.config.center.name ~= "Base" then
                table.insert(enhanced_cards, card.config.center.name)
            end
            
            -- Check for special attributes
            local special_attrs = CardUtils.get_card_attributes(card)
            if #special_attrs > 0 then
                for _, attr in ipairs(special_attrs) do
                    table.insert(special_cards, attr)
                end
            end
        end
        
        -- Show suit distribution
        table.insert(context_parts, "\nSuit Distribution:")
        for suit, count in pairs(suit_counts) do
            if count > 0 then
                table.insert(context_parts, "  " .. suit .. ": " .. count .. " cards")
            end
        end
        
        -- Show enhancements if any
        if #enhanced_cards > 0 then
            -- Count enhancement types
            local enhancement_counts = {}
            for _, enhancement in ipairs(enhanced_cards) do
                enhancement_counts[enhancement] = (enhancement_counts[enhancement] or 0) + 1
            end
            
            table.insert(context_parts, "\nEnhanced Cards:")
            for enhancement, count in pairs(enhancement_counts) do
                table.insert(context_parts, "  " .. enhancement .. ": " .. count)
            end
        end
        
        -- Show special attributes if any
        if #special_cards > 0 then
            -- Count special types
            local special_counts = {}
            for _, special in ipairs(special_cards) do
                special_counts[special] = (special_counts[special] or 0) + 1
            end
            
            table.insert(context_parts, "\nSpecial Cards:")
            for special, count in pairs(special_counts) do
                table.insert(context_parts, "  " .. special .. ": " .. count)
            end
        end
    end
    
    local context_message = table.concat(context_parts, "\n")
    if sendWebSocketMessage then
        sendWebSocketMessage(context_message, true)
    end
end

local function view_deck_executor(params)
    -- First, try to open the deck UI
    local deck_opened = false
    
    -- Try to find and click the deck button/area to open deck view
    local deck_button = nil
    
    -- Look for deck UI elements by ID
    if G.buttons then
        local deck_button_ids = {
            'deck_button',
            'view_deck',
            'deck',
            'your_deck'
        }
        
        for _, button_id in ipairs(deck_button_ids) do
            deck_button = G.buttons:get_UIE_by_ID(button_id)
            if deck_button then
                break
            end
        end
    end
    
    -- If not found by ID, try to find deck area visually
    if not deck_button and G.deck then
        -- Try to click on the deck area directly
        if G.deck.click then
            G.deck:click()
            deck_opened = true
        elseif G.deck.definition and G.deck.definition.click then
            G.deck.definition:click()
            deck_opened = true
        end
    end
    
    -- Try clicking the found button
    if not deck_opened and deck_button and deck_button.click then
        deck_button:click()
        deck_opened = true
    end
    
    -- Fallback: try G.FUNCS
    if not deck_opened and G.FUNCS then
        local deck_funcs = {'view_deck', 'your_deck', 'deck_view'}
        for _, func_name in ipairs(deck_funcs) do
            if G.FUNCS[func_name] then
                G.FUNCS[func_name]()
                deck_opened = true
                break
            end
        end
    end
    
    -- Wait a moment for UI to open, then send context
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 0.3, -- Small delay to let UI open
        func = function()
            view_deck_send_context()
            return true
        end
    }))
    
    if deck_opened then
        return true, "Opened deck view - context will follow"
    else
        return false, "Could not open deck view"
    end
end

local function create_view_deck_action()
    -- Only available during gameplay states when deck exists
    local valid_states = {
        G.STATES.SELECTING_HAND,
        G.STATES.SHOP,
        G.STATES.BLIND_SELECT
    }
    
    local is_valid_state = false
    for _, state in ipairs(valid_states) do
        if G.STATE == state then
            is_valid_state = true
            break
        end
    end
    
    if not is_valid_state or not G.deck then
        return nil
    end
    
    return {
        name = "view_deck",
        definition = {
            name = "view_deck",
            description = "Open deck view UI and provide context about deck composition for viewers",
            parameters = {}
        },
        executor = view_deck_executor
    }
end

return create_view_deck_action