local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_cards_by_indices(indices)
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return false, "No cards in hand"
    end
    if CardUtils.hand_locked() then
        return false, "A hand is being scored; wait for it to finish"
    end
    return CardUtils.highlight_hand_cards(indices)
end

local function create_select_cards_action()
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return nil
    end

    -- Check if there are any unselected cards
    local has_unselected = false
    for _, card in ipairs(G.hand.cards) do
        if not card.highlighted then
            has_unselected = true
            break
        end
    end

    if not has_unselected then
        return nil -- No cards available to select
    end

    local max_cards = #G.hand.cards

    return {
        name = "select_cards",
        definition = {
            name = "select_cards",
            description = "Select cards by their indices in hand (1-" .. max_cards .. ")",
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
                return false, "indices must be a list of hand positions"
            end
            return select_cards_by_indices(params.indices)
        end
    }
end

return create_select_cards_action