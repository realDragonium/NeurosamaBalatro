local function use_consumable(index)
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

    if not consumable.ability or consumable.ability.consumeable_used then
        return false, "Consumable already used or not usable"
    end

    -- Use the game's function to use consumable
    if consumable.use_card then
        consumable:use_card()
        return true, "Consumable used successfully"
    elseif G.FUNCS and G.FUNCS.use_card then
        G.FUNCS.use_card({config = {ref_table = consumable}})
        return true, "Consumable used successfully"
    end

    return false, "Unable to use consumable"
end

local function create_use_consumable_action()
    -- Only add action if we have consumables
    if not G.consumeables or not G.consumeables.cards or #G.consumeables.cards == 0 then
        return nil
    end

    local num_consumables = #G.consumeables.cards

    return {
        name = "use_consumable",
        definition = {
            name = "use_consumable",
            description = "Use a consumable at the specified index (1-" .. num_consumables .. ")",
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
            return use_consumable(params.consumable_index)
        end
    }
end

return create_use_consumable_action