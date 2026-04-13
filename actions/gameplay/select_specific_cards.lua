-- Select Specific Cards Action
-- Allows selecting specific cards by index, clearing other selections first
-- This is useful for targeted actions like select_from_pack_targeted

local function select_specific_cards_by_indices(indices)
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return false, "No cards in hand"
    end

    -- First, clear all current selections using the proper CardArea method
    for i = #G.hand.highlighted, 1, -1 do
        local card = G.hand.highlighted[i]
        if card then
            G.hand:remove_from_highlighted(card)
        end
    end

    -- Then select the specified cards using the proper CardArea method
    local success_count = 0
    for _, index in ipairs(indices) do
        if index >= 1 and index <= #G.hand.cards then
            local card = G.hand.cards[index]
            if card and not card.highlighted then
                G.hand:add_to_highlighted(card)
                success_count = success_count + 1
            end
        end
    end

    return success_count > 0, "Selected " .. success_count .. " cards"
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