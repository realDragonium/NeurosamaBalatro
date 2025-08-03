-- Sort Hand Action

local function sort_hand(new_order)
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return false, "No cards in hand"
    end
    
    local current_cards = G.hand.cards
    local num_cards = #current_cards
    
    -- Validate new_order array
    if not new_order or type(new_order) ~= "table" or #new_order ~= num_cards then
        return false, "Invalid order array: must contain exactly " .. num_cards .. " indices"
    end
    
    -- Check that all indices are valid and unique
    local seen = {}
    for _, index in ipairs(new_order) do
        if type(index) ~= "number" or index < 1 or index > num_cards then
            return false, "Invalid index: " .. tostring(index) .. " (must be 1-" .. num_cards .. ")"
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
    G.hand.cards = new_cards
    
    return true, "Hand reordered successfully"
end

local function create_sort_hand_action()
    -- Check if hand has cards to sort
    if not G.hand or not G.hand.cards or #G.hand.cards == 0 then
        return nil
    end
    
    local num_cards = #G.hand.cards
    
    return {
        name = "sort_hand",
        definition = {
            name = "sort_hand",
            description = "Reorder hand cards according to specified indices. Provide an array of exactly " .. num_cards .. " indices (1-" .. num_cards .. "). Example: [3,1,2] moves 3rd card to 1st position",
            schema = {
                type = "object",
                properties = {
                    new_order = {
                        type = "array",
                        items = {
                            type = "integer",
                            minimum = 1,
                            maximum = num_cards
                        },
                        minLength = num_cards,
                        maxLength = num_cards
                    }
                },
                required = {"new_order"}
            }
        },
        executor = function(params)
            return sort_hand(params.new_order)
        end
    }
end

return create_sort_hand_action