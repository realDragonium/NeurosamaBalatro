-- Buy Card Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function buy_card_executor(params)
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
            -- First click the card to select it
            if card.click then
                card:click()
            end

            -- Then use the card (find and click appropriate button)
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    CardUtils.use_card(card)
                    return true
                end
            }))
            return true, "Buying card at index " .. card_index
        else
            return false, "Not enough money to buy card (costs $" .. card.cost .. ")"
        end
    end

    return false, "Card not found at index " .. card_index
end

local function create_buy_card_action()
    -- Only available in shop with available cards
    if G.STATE == G.STATES.SHOP and G.shop_jokers and G.shop_jokers.cards then
        local max_cards = #G.shop_jokers.cards
        for i, card in ipairs(G.shop_jokers.cards) do
            if card and G.GAME.dollars >= card.cost then
                return {
                    name = "buy_card",
                    definition = {
                        name = "buy_card",
                        description = "Buy a card (joker or consumable) from the shop (1-" .. max_cards .. ")",
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
                    executor = buy_card_executor
                }
            end
        end
    end

    return nil
end

return create_buy_card_action