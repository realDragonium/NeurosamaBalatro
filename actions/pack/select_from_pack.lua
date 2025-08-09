-- Select From Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_from_pack_executor(params)
    local max_cards = G.GAME.pack_choices or 1
    
    if not G.pack_cards then
        return false, "No pack cards available"
    end
    
    -- Determine which cards to select
    local card_indices_to_process = {}
    
    -- Calculate selection context
    local original_pack_size = G.GAME.pack_size or #G.pack_cards.cards
    local cards_already_selected = original_pack_size - max_cards
    local is_first_selection = cards_already_selected == 0
    
    if max_cards == 1 then
        -- Single card selection
        local card_index = params.card_index
        if not card_index then
            return false, "card_index is required"
        end
        table.insert(card_indices_to_process, card_index)
    else
        -- Multiple card selection logic
        if params.card_indices and #params.card_indices > 0 then
            -- Array provided - process based on selection rules
            if is_first_selection and max_cards >= 2 then
                -- First selection: can process up to 2 cards
                local max_to_process = math.min(2, #params.card_indices, max_cards)
                for i = 1, max_to_process do
                    table.insert(card_indices_to_process, params.card_indices[i])
                end
            else
                -- Subsequent selections: only process 1 card
                table.insert(card_indices_to_process, params.card_indices[1])
            end
        elseif params.card_index then
            -- Single index provided
            table.insert(card_indices_to_process, params.card_index)
        else
            return false, "card_index or card_indices is required"
        end
    end

    -- Validate all card indices
    for _, idx in ipairs(card_indices_to_process) do
        if not G.pack_cards.cards[idx] then
            return false, "Invalid card index: " .. idx
        end
    end
    
    -- Process each selected card with appropriate delays
    local function select_card_with_delay(card_index, delay_offset)
        local selected_card = G.pack_cards.cards[card_index]
        
        G.E_MANAGER:add_event(Event({
            trigger = "after",
            delay = 0.1 + (0.15 * delay_offset), -- Staggered timing for multiple cards
            func = function()
                -- Add to highlighted selection
                if G.pack_cards and G.pack_cards.add_to_highlighted then
                    G.pack_cards:add_to_highlighted(selected_card)
                end
                
                -- Find and click the use button
                local button = nil
                if selected_card.children and selected_card.children.use_button and 
                   selected_card.children.use_button.UIRoot and selected_card.children.use_button.UIRoot.children then
                    for _, child in ipairs(selected_card.children.use_button.UIRoot.children) do
                        if child.config and child.config.button then
                            button = child
                            break
                        end
                    end
                end
                
                if button and button.click then
                    button:click()
                end
                return true
            end
        }))
    end
    
    -- Select all cards with staggered timing
    for i, card_index in ipairs(card_indices_to_process) do
        select_card_with_delay(card_index, i - 1)
    end
    
    local message
    if #card_indices_to_process == 1 then
        message = "Selected pack card at index: " .. card_indices_to_process[1]
    else
        message = "Selected pack cards at indices: " .. table.concat(card_indices_to_process, ", ")
    end
    
    return true, message
end

local function create_select_from_pack_action()
    -- Only available when pack cards are present
    if G.pack_cards and G.pack_cards.cards then
        local max_cards = G.GAME.pack_choices or 1
        local total_cards = #G.pack_cards.cards
        
        -- Fallback: if pack cards array is empty but we're in a pack state, 
        -- try to get the expected pack size from game data
        if total_cards == 0 then
            -- Try to get pack size from SMODS.OPENED_BOOSTER
            if SMODS and SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config and 
               SMODS.OPENED_BOOSTER.config.center and SMODS.OPENED_BOOSTER.config.center.config and
               SMODS.OPENED_BOOSTER.config.center.config.extra then
                total_cards = SMODS.OPENED_BOOSTER.config.center.config.extra
            -- Fallback to G.GAME.pack_size
            elseif G.GAME and G.GAME.pack_size then
                total_cards = G.GAME.pack_size
            -- Final fallback for common pack sizes
            else
                total_cards = 3 -- Most common pack size
            end
        end
        
        -- Safety check: if still no cards detected, don't create action
        if total_cards <= 0 then
            return nil
        end
        
        -- Calculate how many cards have already been selected
        -- We can determine this by checking how many cards are no longer in the pack
        -- or by looking at pack_choices remaining vs original pack size
        local original_pack_size = G.GAME.pack_size or total_cards
        local cards_already_selected = original_pack_size - max_cards
        local cards_remaining = max_cards
        
        -- Additional safety check
        if cards_remaining <= 0 then
            return nil
        end
        
        if cards_remaining > 0 then
            -- Determine how many cards can be selected in this action call
            local cards_this_call = 1 -- Default to 1 card per call
            
            -- Special case: if this is the first selection and we can select 2+ cards,
            -- allow selecting up to 2 cards (but still process only the first one)
            if cards_already_selected == 0 and cards_remaining >= 2 then
                cards_this_call = math.min(2, cards_remaining)
            end
            
            local description
            local schema
            
            if cards_remaining == 1 then
                -- Only 1 card can be selected (either single card pack or last selection)
                description = "Select the final card from the opened pack (1 remaining, use card_index: 1-" .. total_cards .. ")"
                schema = {
                    type = "object",
                    properties = {
                        card_index = {
                            type = "integer",
                            minimum = 1,
                            maximum = total_cards
                        }
                    },
                    required = {"card_index"}
                }
            elseif cards_already_selected == 0 and cards_remaining >= 2 then
                -- First selection and multiple cards allowed - can select up to 2
                description = "Select cards from the opened pack. You can select up to " .. cards_this_call .. " cards in this action (" .. cards_remaining .. " total remaining). Use card_indices array for multiple cards or card_index for single card."
                schema = {
                    type = "object",
                    properties = {
                        card_indices = {
                            type = "array",
                            items = {
                                type = "integer",
                                minimum = 1,
                                maximum = total_cards
                            },
                            minItems = 1,
                            maxItems = cards_this_call,
                            description = "Array of card indices to select (recommended for multiple cards)"
                        },
                        card_index = {
                            type = "integer",
                            minimum = 1,
                            maximum = total_cards,
                            description = "Single card index to select (alternative to card_indices)"
                        }
                    },
                    anyOf = {
                        {required = {"card_indices"}},
                        {required = {"card_index"}}
                    }
                }
            else
                -- Subsequent selections - only 1 card at a time
                description = "Select 1 more card from the opened pack (" .. cards_remaining .. " remaining, use card_index: 1-" .. total_cards .. ")"
                schema = {
                    type = "object",
                    properties = {
                        card_index = {
                            type = "integer",
                            minimum = 1,
                            maximum = total_cards
                        }
                    },
                    required = {"card_index"}
                }
            end
            
            return {
                name = "select_from_pack",
                definition = {
                    name = "select_from_pack",
                    description = description,
                    schema = schema
                },
                executor = select_from_pack_executor
            }
        end
    end

    return nil
end

return create_select_from_pack_action