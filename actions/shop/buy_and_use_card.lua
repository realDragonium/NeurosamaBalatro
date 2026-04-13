-- Buy and Use Card Action
-- Explicitly buys a card and immediately uses it (for consumables)

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function buy_and_use_card_executor(params)
    local card_index = params.card_index
    if not card_index then
        return false, "card_index parameter is required"
    end

    if G.STATE ~= G.STATES.SHOP then
        return false, "Not in shop state"
    end

    if G.shop_jokers and G.shop_jokers.cards[card_index] then
        local card = G.shop_jokers.cards[card_index]
        if G.GAME.dollars >= card.cost then
            -- Check if this is a consumable that can be used immediately
            local is_consumable = false
            
            -- Check multiple ways to identify consumables
            if card.ability and card.ability.consumeable then
                is_consumable = true
            elseif card.config and card.config.center and card.config.center.consumeable then
                is_consumable = true
            end
            
            if not is_consumable then
                local card_type = "Unknown"
                if card.config and card.config.center then
                    card_type = card.config.center.set or card_type
                end
                return false, "Card at index " .. card_index .. " (" .. card_type .. ") is not a consumable and cannot be used immediately"
            end

            -- First click the card to select it
            if card.click then
                card:click()
            end

            -- Buy and use the card using the original CardUtils.use_card function
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    CardUtils.use_card(card)
                    return true
                end
            }))
            return true, "Buying and using card at index " .. card_index
        else
            return false, "Not enough money to buy card (costs $" .. card.cost .. ")"
        end
    end

    return false, "Card not found at index " .. card_index
end

local function create_buy_and_use_card_action()
    -- Only available in shop with available consumable cards
    if G.STATE == G.STATES.SHOP and G.shop_jokers and G.shop_jokers.cards then
        local max_cards = #G.shop_jokers.cards
        local has_affordable_consumable = false
        
        for i, card in ipairs(G.shop_jokers.cards) do
            if card and G.GAME.dollars >= card.cost then
                -- Check if this is a consumable using multiple approaches
                local is_consumable = false
                
                if card.ability and card.ability.consumeable then
                    is_consumable = true
                elseif card.config and card.config.center and card.config.center.consumeable then
                    is_consumable = true
                end
                
                if is_consumable then
                    has_affordable_consumable = true
                    break
                end
            end
        end
        
        if has_affordable_consumable then
            return {
                name = "buy_and_use_card",
                definition = {
                    name = "buy_and_use_card",
                    description = "Buy a consumable card from the shop and immediately use it (only works with Tarot, Planet, and Spectral cards). Check cards 1-" .. max_cards .. " for consumables.",
                    schema = {
                        type = "object",
                        properties = {
                            card_index = {
                                type = "integer",
                                minimum = 1,
                                maximum = max_cards,
                            }
                        },
                        required = {"card_index"}
                    }
                },
                executor = buy_and_use_card_executor
            }
        end
    end

    return nil
end

return create_buy_and_use_card_action