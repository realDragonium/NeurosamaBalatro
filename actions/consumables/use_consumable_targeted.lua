-- Use Consumable with Card Targeting Action
-- Handles consumables that require targeting specific hand cards (like most Tarot cards)

local function use_consumable_targeted(consumable_index, target_card_indices)
    if not G.consumeables or not G.consumeables.cards or #G.consumeables.cards == 0 then
        return false, "No consumables available"
    end

    if not consumable_index or type(consumable_index) ~= "number" or consumable_index < 1 or consumable_index > #G.consumeables.cards then
        return false, "Invalid consumable index: " .. tostring(consumable_index)
    end

    local consumable = G.consumeables.cards[consumable_index]
    if not consumable then
        return false, "No consumable found at index " .. consumable_index
    end

    if not consumable.ability or consumable.ability.consumeable_used then
        return false, "Consumable already used or not usable"
    end

    -- Validate target cards if provided
    if target_card_indices and #target_card_indices > 0 then
        if not G.hand or not G.hand.cards then
            return false, "No hand cards available for targeting"
        end

        for _, idx in ipairs(target_card_indices) do
            if not G.hand.cards[idx] then
                return false, "Invalid hand card index: " .. idx
            end
        end

        -- Check max_highlighted limit if available
        local max_highlighted = nil
        if consumable.config and consumable.config.center and consumable.config.center.config then
            max_highlighted = consumable.config.center.config.max_highlighted
        end
        
        if max_highlighted and #target_card_indices > max_highlighted then
            return false, "Too many target cards. Max allowed: " .. max_highlighted
        end

        -- First, select the target cards
        for _, idx in ipairs(target_card_indices) do
            local card = G.hand.cards[idx]
            if card and card.highlight then
                card:highlight(true) -- Select the card
            elseif card and card.click then
                card:click() -- Alternative selection method
            end
        end
    end

    -- Use the consumable
    if consumable.use_card then
        consumable:use_card()
        return true, "Consumable used on " .. (#target_card_indices or 0) .. " target cards"
    elseif G.FUNCS and G.FUNCS.use_card then
        G.FUNCS.use_card({config = {ref_table = consumable}})
        return true, "Consumable used on " .. (#target_card_indices or 0) .. " target cards"
    end

    return false, "Unable to use consumable"
end

local function create_use_consumable_targeted_action()
    -- Only add action if we have consumables and hand cards
    if not G.consumeables or not G.consumeables.cards or #G.consumeables.cards == 0 then
        return nil
    end

    local num_consumables = #G.consumeables.cards
    local max_hand_cards = G.hand and G.hand.cards and #G.hand.cards or 0

    return {
        name = "use_consumable_targeted",
        definition = {
            name = "use_consumable_targeted",
            description = "Use a consumable with optional card targeting (1-" .. num_consumables .. ")",
            schema = {
                type = "object",
                properties = {
                    consumable_index = {
                        type = "integer",
                        minimum = 1,
                        maximum = num_consumables
                    },
                    target_card_indices = {
                        type = "array",
                        items = {
                            type = "integer",
                            minimum = 1,
                            maximum = max_hand_cards
                        },
                        minItems = 0,
                        maxItems = max_hand_cards
                    }
                },
                required = {"consumable_index"}
            }
        },
        executor = function(params)
            return use_consumable_targeted(params.consumable_index, params.target_card_indices or {})
        end
    }
end

return create_use_consumable_targeted_action