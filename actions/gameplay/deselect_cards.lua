local function deselect_cards_by_indices(indices)
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return false
    end

    local success_count = 0
    for _, index in ipairs(indices) do
        if G.hand.cards[index] then
            local card = G.hand.cards[index]
            if card and card.highlighted then
                G.hand:remove_from_highlighted(card)
                success_count = success_count + 1
            end
        end
    end

    return success_count > 0
end

local function create_deselect_cards_action()
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return nil
    end

    -- Check if there are any selected cards
    local has_selected = false
    for _, card in ipairs(G.hand.cards) do
        if card.highlighted then
            has_selected = true
            break
        end
    end

    if not has_selected then
        return nil -- No cards selected to deselect
    end

    local max_cards = #G.hand.cards

    return {
        name = "deselect_cards",
        definition = {
            name = "deselect_cards",
            description = "Deselect cards by their indices in hand (1-" .. max_cards .. ")",
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
                        maxLength = G.hand.config.card_limit
                    }
                },
                required = {"indices"}
            }
        },
        executor = function(params)
            if not params.indices or type(params.indices) ~= "table" then
                return false
            end
            local result = deselect_cards_by_indices(params.indices)

            -- Update hand context after deselection changes
            if result and sendWebSocketMessage then
                local HandContext = require('context/hand_context')
                local context = HandContext.build_context_string()
                sendWebSocketMessage(context, "hand_update")
            end

            return result
        end
    }
end

return create_deselect_cards_action