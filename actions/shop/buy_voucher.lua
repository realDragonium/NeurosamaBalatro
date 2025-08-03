-- Buy Voucher Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function buy_voucher_executor(params)
    local voucher_index = params.voucher_index
    if not voucher_index then
        return false, "voucher_index parameter is required"
    end

    if G.STATE ~= G.STATES.SHOP then
        return false, "Not in shop state"
    end

    if G.shop_vouchers and G.shop_vouchers.cards[voucher_index] then
        local card = G.shop_vouchers.cards[voucher_index]
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
            return true, "Buying voucher at index " .. voucher_index
        else
            return false, "Not enough money to buy voucher (costs $" .. card.cost .. ")"
        end
    end

    return false, "Voucher not found at index " .. voucher_index
end

local function create_buy_voucher_action()
    -- Only available in shop with available vouchers
    if G.STATE == G.STATES.SHOP and G.shop_vouchers and G.shop_vouchers.cards then
        local max_vouchers = #G.shop_vouchers.cards
        for i, card in ipairs(G.shop_vouchers.cards) do
            if card and G.GAME.dollars >= card.cost then
                return {
                    name = "buy_voucher",
                    definition = {
                        name = "buy_voucher",
                        description = "Buy a voucher from the shop",
                        schema = {
                            type = "object",
                            properties = {
                                voucher_index = {
                                    type = "integer",
                                    minimum = 1,
                                    maximum = max_vouchers,
                                }
                            },
                            required = {"voucher_index"}
                        }
                    },
                    executor = buy_voucher_executor
                }
            end
        end
    end

    return nil
end

return create_buy_voucher_action