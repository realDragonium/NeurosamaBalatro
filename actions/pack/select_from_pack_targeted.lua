-- Select From Pack with Targeting Action
-- Handles consumable cards from packs that require targeting hand cards (like some Tarot cards)

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_from_pack_targeted_executor(params)
    if not G.pack_cards or not G.pack_cards.cards then
        return false, "No pack cards available"
    end
    
    local card_index = params.card_index
    if not card_index or card_index < 1 or card_index > #G.pack_cards.cards then
        return false, "Invalid card_index: " .. tostring(card_index)
    end
    
    local pack_card = G.pack_cards.cards[card_index]
    if not pack_card then
        return false, "No pack card found at index " .. card_index
    end
    
    -- Check if this card requires targeting
    local requires_targeting = false
    local max_highlighted = nil
    
    if pack_card.config and pack_card.config.center then
        local center = pack_card.config.center
        
        -- Check if it's a consumable that needs targeting
        if center.use and center.config then
            max_highlighted = center.config.max_highlighted
            requires_targeting = max_highlighted and max_highlighted > 0
        end
    end
    
    -- If targeting is required, validate target cards
    if requires_targeting and params.target_card_indices then
        if not G.hand or not G.hand.cards then
            return false, "No hand cards available for targeting"
        end
        
        local target_indices = params.target_card_indices
        if #target_indices > max_highlighted then
            return false, "Too many target cards. Max allowed: " .. max_highlighted
        end
        
        -- Validate all target indices
        for _, idx in ipairs(target_indices) do
            if not G.hand.cards[idx] then
                return false, "Invalid hand card index: " .. idx
            end
        end
        
        -- First, clear any existing selections using the proper CardArea method
        for i = #G.hand.highlighted, 1, -1 do
            G.hand:remove_from_highlighted(G.hand.highlighted[i])
        end

        -- Then select target cards using the proper CardArea method
        for _, idx in ipairs(target_indices) do
            local target_card = G.hand.cards[idx]
            if target_card and not target_card.highlighted then
                G.hand:add_to_highlighted(target_card)
            end
        end
    end
    
    -- Use the card with proper delay (after targeting is set up)
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 0.2,
        func = function()
            -- Add to highlighted selection in pack
            if G.pack_cards and G.pack_cards.add_to_highlighted then
                G.pack_cards:add_to_highlighted(pack_card)
            end

            -- Call G.FUNCS.use_card directly
            if G.FUNCS and G.FUNCS.use_card then
                G.FUNCS.use_card({config = {ref_table = pack_card, button = 'use_card'}})
            end
            return true
        end
    }))
    
    local result_msg = "Selected pack card at index " .. card_index
    if requires_targeting and params.target_card_indices then
        result_msg = result_msg .. " targeting " .. #params.target_card_indices .. " hand cards"
    end
    
    return true, result_msg
end

local function create_select_from_pack_targeted_action()
    -- Only available when pack cards are present
    if not G.pack_cards or not G.pack_cards.cards or #G.pack_cards.cards == 0 then
        return nil
    end
    
    local total_cards = #G.pack_cards.cards
    local max_hand_cards = G.hand and G.hand.cards and #G.hand.cards or 0
    
    -- Check if any pack card might need targeting
    local has_targeting_cards = false
    for _, card in ipairs(G.pack_cards.cards) do
        if card.config and card.config.center and card.config.center.config then
            local max_highlighted = card.config.center.config.max_highlighted
            if max_highlighted and max_highlighted > 0 then
                has_targeting_cards = true
                break
            end
        end
    end
    
    -- Only provide this action if there are targeting cards and hand cards available
    if not has_targeting_cards or max_hand_cards == 0 then
        return nil
    end
    
    return {
        name = "select_from_pack_targeted",
        definition = {
            name = "select_from_pack_targeted",
            description = "Select a card from pack with optional hand card targeting (for Tarot cards)",
            schema = {
                type = "object",
                properties = {
                    card_index = {
                        type = "integer",
                        minimum = 1,
                        maximum = total_cards
                    },
                    target_card_indices = {
                        type = "array",
                        items = {
                            type = "integer",
                            minimum = 1,
                            maximum = max_hand_cards
                        },
                        minItems = 0,
                        maxItems = max_hand_cards
                    }
                },
                required = {"card_index"}
            }
        },
        executor = select_from_pack_targeted_executor
    }
end

return create_select_from_pack_targeted_action