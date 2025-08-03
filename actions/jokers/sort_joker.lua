-- Joker Actions (Simplified)

local function sort_jokers(new_order)
    if not G.jokers or not G.jokers.cards or #G.jokers.cards == 0 then
        return false, "No jokers available"
    end

    local current_cards = G.jokers.cards
    local num_jokers = #current_cards

    -- Validate new_order array
    if not new_order or type(new_order) ~= "table" or #new_order ~= num_jokers then
        return false, "Invalid order array: must contain exactly " .. num_jokers .. " indices"
    end

    -- Check that all indices are valid and unique
    local seen = {}
    for _, index in ipairs(new_order) do
        if type(index) ~= "number" or index < 1 or index > num_jokers then
            return false, "Invalid index: " .. tostring(index) .. " (must be 1-" .. num_jokers .. ")"
        end
        if seen[index] then
            return false, "Duplicate index: " .. index
        end
        seen[index] = true
    end

    -- Create new order by copying cards according to the provided indices
    local new_cards = {}
    for i, old_index in ipairs(new_order) do
        new_cards[i] = current_cards[old_index]
    end

    -- Replace the cards array
    G.jokers.cards = new_cards

    return true, "Jokers reordered successfully"
end

local function create_sort_joker_actions()
    if not G.jokers or not G.jokers.cards or #G.jokers.cards == 0 then
        return nill
    end

    local num_jokers = #G.jokers.cards

    return {
        name = "sort_jokers",
        definition = {
            name = "sort_jokers",
            description = "Reorder jokers according to specified indices. Provide an array of exactly " .. num_jokers .. " indices (1-" .. num_jokers .. "). Example: [3,1,2] moves 3rd joker to 1st position",
            schema = {
                type = "object",
                properties = {
                    new_order = {
                        type = "array",
                        items = {
                            type = "integer",
                            minimum = 1,
                            maximum = num_jokers
                        },
                        minLength = num_jokers,
                        maxLength = num_jokers
                    }
                },
                required = {"new_order"}
            }
        },
        executor = function(params)
            return sort_jokers(params.new_order)
        end
    }
end

return create_sort_joker_actions
