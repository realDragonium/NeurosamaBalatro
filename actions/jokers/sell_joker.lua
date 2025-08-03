-- Sell Joker Action

local function sell_joker_executor(params)
    local joker_index = params.joker_index
    if not joker_index then
        return false, "joker_index parameter is required"
    end

    if G.STATE ~= G.STATES.SHOP then
        return false, "Not in shop state"
    end

    if G.jokers and G.jokers.cards[joker_index] then
        local card = G.jokers.cards[joker_index]
        if card.sell_card then
            card:sell_card()
            return true, "Selling joker at index " .. joker_index
        else
            return false, "Joker cannot be sold (no sell_card method)"
        end
    end

    return false, "Joker not found at index " .. joker_index
end

local function create_sell_joker_action()
    if not G.jokers or not G.jokers.cards or #G.jokers.cards == 0 then
        return nill
    end

    local max_jokers = #G.jokers.cards
    return {
        name = "sell_joker",
        definition = {
            name = "sell_joker",
            description = "Sell a joker from your collection",
            schema = {
                type = "object",
                properties = {
                    joker_index = {
                        type = "integer",
                        minimum = 1,
                        maximum = max_jokers,
                    }
                },
                required = {"joker_index"}
            }
        },
        executor = sell_joker_executor
    }

end

return create_sell_joker_action