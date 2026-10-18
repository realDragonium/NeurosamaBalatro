-- Select Multiple Cards From Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_multiple_from_pack_executor(params)
    if not G.pack_cards then
        return false, "No pack cards available"
    end
    
    local card_indices = params.card_indices
    if not card_indices or type(card_indices) ~= "table" or #card_indices == 0 then
        return false, "card_indices array is required and must not be empty"
    end
    
    local max_cards = G.GAME.pack_choices or 1
    local original_pack_size = G.GAME.pack_size or #G.pack_cards.cards
    local cards_already_selected = original_pack_size - max_cards
    local is_first_selection = cards_already_selected == 0
    
    -- Determine how many cards can be processed in this call
    local max_to_process
    if is_first_selection and max_cards >= 2 then
        -- First selection: can process up to 2 cards
        max_to_process = math.min(2, #card_indices, max_cards)
    else
        -- Subsequent selections: only process 1 card
        max_to_process = 1
    end
    
    if #card_indices > max_to_process then
        return false, "Can only select " .. max_to_process .. " cards in this action call"
    end
    
    -- Validate all card indices
    for _, idx in ipairs(card_indices) do
        if not G.pack_cards.cards[idx] then
            return false, "Invalid card index: " .. idx
        end
    end
    
    -- Check for duplicates
    local seen = {}
    for _, idx in ipairs(card_indices) do
        if seen[idx] then
            return false, "Duplicate card index: " .. idx
        end
        seen[idx] = true
    end
    
    for _, idx in ipairs(card_indices) do
        local card = G.pack_cards.cards[idx]
        if CardUtils.hand_targets(card) then
            return false, CardUtils.card_name(card) .. " needs target cards from your hand; use select_from_pack_targeted"
        end
        if not CardUtils.can_use_now(card) then
            return false, CardUtils.card_name(card) .. " can't be used right now"
        end
    end

    -- Process each selected card with staggered timing
    local function select_card_with_delay(card_index, delay_offset)
        local selected_card = G.pack_cards.cards[card_index]
        
        G.E_MANAGER:add_event(Event({
            trigger = "after",
            delay = 0.1 + (0.15 * delay_offset),
            func = function()
                -- Add to highlighted selection
                if G.pack_cards and G.pack_cards.add_to_highlighted then
                    G.pack_cards:add_to_highlighted(selected_card)
                end

                -- Call G.FUNCS.use_card directly with a mock element referencing the card
                if G.FUNCS and G.FUNCS.use_card then
                    G.FUNCS.use_card({config = {ref_table = selected_card, button = 'use_card'}})
                end
                return true
            end
        }))
    end
    
    -- Select all cards with staggered timing
    for i, card_index in ipairs(card_indices) do
        select_card_with_delay(card_index, i - 1)
    end
    
    return true, "Selected pack cards at indices: " .. table.concat(card_indices, ", ")
end

local function create_select_multiple_from_pack_action()
    -- Only available when pack cards are present and multiple selections are possible
    if not G.pack_cards or not G.pack_cards.cards then
        return nil
    end
    
    local max_cards = G.GAME.pack_choices or 1
    local total_cards = #G.pack_cards.cards
    
    -- Enhanced pack choice detection - check multiple sources
    if not max_cards or max_cards <= 1 then
        -- Try alternative sources for pack choice information
        if SMODS and SMODS.OPENED_BOOSTER then
            if SMODS.OPENED_BOOSTER.config and SMODS.OPENED_BOOSTER.config.center then
                local center = SMODS.OPENED_BOOSTER.config.center
                -- Check for choose property in the pack center
                if center.config and center.config.choose then
                    max_cards = center.config.choose
                elseif center.choose then
                    max_cards = center.choose
                end
            end
        end
        
        -- Check G.pack_cards.config if it exists
        if (not max_cards or max_cards <= 1) and G.pack_cards and G.pack_cards.config then
            if G.pack_cards.config.choose then
                max_cards = G.pack_cards.config.choose
            elseif G.pack_cards.config.card_limit then
                max_cards = G.pack_cards.config.card_limit
            end
        end
        
        -- If still not found, check G.GAME.pack_choices again (might be nil vs 0)
        if not max_cards or max_cards <= 0 then
            max_cards = G.GAME.pack_choices or 1
        end
    end
    
    -- Special case: Spectral packs typically only allow 1 selection
    -- Check current game state to determine pack type
    local current_state = G.STATE
    if current_state == G.STATES.SPECTRAL_PACK then
        -- Spectral packs usually only allow 1 selection, but double-check
        if max_cards <= 1 then
            return nil  -- Don't offer multiple selection for single-choice spectral packs
        end
    end
    
    -- Fallback for pack size detection
    if total_cards == 0 then
        if SMODS and SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config and 
           SMODS.OPENED_BOOSTER.config.center and SMODS.OPENED_BOOSTER.config.center.config and
           SMODS.OPENED_BOOSTER.config.center.config.extra then
            total_cards = SMODS.OPENED_BOOSTER.config.center.config.extra
        elseif G.GAME and G.GAME.pack_size then
            total_cards = G.GAME.pack_size
        else
            total_cards = 3
        end
    end
    
    -- Only create this action if multiple selections are actually possible
    -- Be more strict - must allow selecting at least 2 cards
    -- DEBUG: max_cards should be >= 2 for multiple selection to be available
    if total_cards <= 0 or max_cards < 2 then
        return nil
    end
    
    -- Calculate selection context
    local original_pack_size = G.GAME.pack_size or total_cards
    local cards_already_selected = original_pack_size - max_cards
    local is_first_selection = cards_already_selected == 0
    local cards_remaining = max_cards
    
    if cards_remaining <= 1 then
        return nil -- Not applicable for single card remaining
    end
    
    -- Determine max cards for this action call
    local max_this_call
    if is_first_selection and cards_remaining >= 2 then
        max_this_call = math.min(2, cards_remaining)
    else
        max_this_call = 1
    end
    
    -- Don't create this action if we can only select 1 card
    if max_this_call <= 1 then
        return nil
    end
    
    return {
        name = "select_multiple_from_pack",
        definition = {
            name = "select_multiple_from_pack",
            description = "Select multiple cards from the opened pack. You can select up to " .. max_this_call .. " cards (" .. cards_remaining .. " total remaining). Provide an array of card indices.",
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
                        minItems = 2,
                        maxItems = max_this_call,
                        description = "Array of card indices to select"
                    }
                },
                required = {"card_indices"}
            }
        },
        executor = select_multiple_from_pack_executor
    }
end

return create_select_multiple_from_pack_action