-- Select Specific Cards Action
-- Allows selecting specific cards by index, clearing other selections first
-- This is useful for targeted actions like select_from_pack_targeted

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_specific_cards_by_indices(indices)
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return false, "No cards in hand"
    end
    if CardUtils.hand_locked() then
        return false, "A hand is being scored; wait for it to finish"
    end

    -- First, clear all current selections using the proper CardArea method
    for i = #G.hand.highlighted, 1, -1 do
        local card = G.hand.highlighted[i]
        if card then
            G.hand:remove_from_highlighted(card)
        end
    end

    return CardUtils.highlight_hand_cards(indices)
end

local function create_select_specific_cards_action()
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return nil
    end

    local max_cards = #G.hand.cards

    return {
        name = "select_specific_cards",
        definition = {
            name = "select_specific_cards",
            description = "Select specific cards by their indices in hand (1-" .. max_cards .. "), clearing other selections first. Useful for targeting specific cards.",
            schema = {
                type = "object",
                properties = {
                    indices = {
                        type = "array",
                        items = {
                            type = "integer",
                            minimum = 1,
                            maximum = max_cards
                        },
                        minLength = 1,
                        maxLength = max_cards,
                    }
                },
                required = {"indices"}
            }
        },
        executor = function(params)
            if not params.indices or type(params.indices) ~= "table" then
                return false, "Invalid indices parameter"
            end
            return select_specific_cards_by_indices(params.indices)
        end
    }
end

return create_select_specific_cards_action