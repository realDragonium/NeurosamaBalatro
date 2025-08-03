-- Buy Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function buy_pack_executor(params)
    local pack_index = params.pack_index
    if not pack_index then
        return false, "pack_index parameter is required"
    end

    if G.STATE ~= G.STATES.SHOP then
        return false, "Not in shop state"
    end

    if G.shop_booster and G.shop_booster.cards[pack_index] then
        local card = G.shop_booster.cards[pack_index]
        if G.GAME.dollars >= card.cost then
            -- Click the card to select it
            if card.click then
                card:click()
            end

            -- Then use the card
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    CardUtils.use_card(card)
                    return true
                end
            }))
            return true, "Buying pack at index " .. pack_index
        else
            return false, "Not enough money to buy pack (costs $" .. card.cost .. ")"
        end
    end

    return false, "Pack not found at index " .. pack_index
end

local function create_buy_pack_action()
    -- Only available in shop with available packs
    if G.STATE == G.STATES.SHOP and G.shop_booster and G.shop_booster.cards then
        local max_packs = #G.shop_booster.cards
        for i, card in ipairs(G.shop_booster.cards) do
            if card and G.GAME.dollars >= card.cost then
                return {
                    name = "buy_pack",
                    definition = {
                        name = "buy_pack",
                        description = "Buy a booster pack from the shop",
                        schema = {
                            type = "object",
                            properties = {
                                pack_index = {
                                    type = "integer",
                                    minimum = 1,
                                    maximum = max_packs,
                                }
                            },
                            required = {"pack_index"}
                        }
                    },
                    executor = buy_pack_executor
                }
            end
        end
    end

    return nil
end

return create_buy_pack_action