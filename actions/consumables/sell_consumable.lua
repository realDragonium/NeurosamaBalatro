local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function sell_consumable(index)
    if not G.consumeables or not G.consumeables.cards or #G.consumeables.cards == 0 then
        return false, "No consumables available"
    end

    if not index or type(index) ~= "number" or index < 1 or index > #G.consumeables.cards then
        return false, "Invalid consumable index: " .. tostring(index)
    end

    local consumable = G.consumeables.cards[index]
    if not consumable then
        return false, "No consumable found at index " .. index
    end

    if CardUtils.sell(consumable) then
        return true, "Consumable sold successfully"
    end
    return false, CardUtils.sell_refusal(consumable)
end

local function create_sell_consumable_action()
    -- Only add action if we have consumables
    if not G.consumeables or not G.consumeables.cards or #G.consumeables.cards == 0 then
        return nil
    end

    local num_consumables = #G.consumeables.cards

    return {
        name = "sell_consumable",
        definition = {
            name = "sell_consumable",
            description = "Sell a consumable at the specified index (1-" .. num_consumables .. ")",
            schema = {
                type = "object",
                properties = {
                    consumable_index = {
                        type = "integer",
                        minimum = 1,
                        maximum = num_consumables
                    }
                },
                required = {"consumable_index"}
            }
        },
        executor = function(params)
            return sell_consumable(params.consumable_index)
        end
    }
end

return create_sell_consumable_action