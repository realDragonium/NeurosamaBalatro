-- Select Single Card From Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_single_from_pack_executor(params)
    if not G.pack_cards then
        return false, "No pack cards available"
    end
    
    local card_index = params.card_index
    if not card_index then
        return false, "card_index is required"
    end
    
    if not G.pack_cards.cards[card_index] then
        return false, "Invalid card index: " .. card_index
    end
    
    local selected_card = G.pack_cards.cards[card_index]

    -- Using a targeted consumable with nothing highlighted crashes the game.
    local center = selected_card.config and selected_card.config.center
    local max_highlighted = center and center.config and center.config.max_highlighted
    if max_highlighted and max_highlighted > 0 then
        return false, (center.name or "This card") .. " needs 1-" .. max_highlighted
            .. " target cards from your hand; use select_from_pack_targeted with target_card_indices"
    end

    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 0.1,
        func = function()
            -- Add to highlighted selection
            if G.pack_cards and G.pack_cards.add_to_highlighted then
                G.pack_cards:add_to_highlighted(selected_card)
            end

            -- Call G.FUNCS.use_card directly with a mock element referencing the card
            -- This is the same function the game's Use/Select button calls
            if G.FUNCS and G.FUNCS.use_card then
                G.FUNCS.use_card({config = {ref_table = selected_card, button = 'use_card'}})
            end
            return true
        end
    }))
    
    return true, "Selected pack card at index: " .. card_index
end

local function create_select_single_from_pack_action()
    -- Only available when pack cards are present
    if not G.pack_cards or not G.pack_cards.cards then
        return nil
    end
    
    local total_cards = #G.pack_cards.cards
    local max_cards = G.GAME.pack_choices or 1
    
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
    
    if total_cards <= 0 or max_cards <= 0 then
        return nil
    end
    
    return {
        name = "select_single_from_pack",
        definition = {
            name = "select_single_from_pack",
            description = "Select exactly one card from the opened pack. Indices range from 1-" .. total_cards .. ".",
            schema = {
                type = "object",
                properties = {
                    card_index = {
                        type = "integer",
                        minimum = 1,
                        maximum = total_cards,
                        description = "Index of the card to select"
                    }
                },
                required = {"card_index"}
            }
        },
        executor = select_single_from_pack_executor
    }
end

return create_select_single_from_pack_action