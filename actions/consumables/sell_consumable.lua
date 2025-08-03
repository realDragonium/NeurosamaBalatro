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

    -- Use the game's sell function
    if consumable.sell_card then
        consumable:sell_card()
        return true, "Consumable sold successfully"
    elseif G.FUNCS and G.FUNCS.sell_card then
        G.FUNCS.sell_card({config = {ref_table = consumable}})
        return true, "Consumable sold successfully"
    end

    return false, "Unable to sell consumable"
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