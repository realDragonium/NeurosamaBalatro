-- Use Consumable with Card Targeting Action
-- Handles consumables that require targeting specific hand cards (like most Tarot cards)

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

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
    if CardUtils.busy() then
        return false, CardUtils.BUSY_MESSAGE
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

        local max_highlighted = CardUtils.hand_targets(consumable)
        if max_highlighted and #target_card_indices > max_highlighted then
            return false, "Too many target cards. Max allowed: " .. max_highlighted
        end

        -- First, clear existing selections
        for i = #G.hand.highlighted, 1, -1 do
            G.hand:remove_from_highlighted(G.hand.highlighted[i])
        end

        -- Then select the target cards using the proper CardArea method
        for _, idx in ipairs(target_card_indices) do
            local card = G.hand.cards[idx]
            if card and not card.highlighted then
                G.hand:add_to_highlighted(card)
            end
        end
    end

    if not CardUtils.can_use_now(consumable) then
        for i = #G.hand.highlighted, 1, -1 do
            G.hand:remove_from_highlighted(G.hand.highlighted[i])
        end
        return false, CardUtils.card_name(consumable) .. " can't be used with these targets right now"
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