-- Shop Discoverer
-- Handles actions available in shop state

-- Load individual action creators
local create_end_shop_action = assert(SMODS.load_file("actions/shop/end_shop.lua"))()
local create_reroll_shop_action = assert(SMODS.load_file("actions/shop/reroll_shop.lua"))()
local create_buy_card_action = assert(SMODS.load_file("actions/shop/buy_card.lua"))()
local create_buy_voucher_action = assert(SMODS.load_file("actions/shop/buy_voucher.lua"))()
local create_buy_pack_action = assert(SMODS.load_file("actions/shop/buy_pack.lua"))()

local ShopDiscoverer = {}

-- Check if this discoverer applies to current state
function ShopDiscoverer.is_applicable(current_state)
    return current_state == G.STATES.SHOP
end

function ShopDiscoverer.discover(current_state)
    local actions = {}

    -- Basic shop actions
    local skip_action = create_end_shop_action()
    if skip_action then
        table.insert(actions, skip_action)
    end

    local reroll_action = create_reroll_shop_action()
    if reroll_action then
        table.insert(actions, reroll_action)
    end

    -- Purchase actions
    local buy_card_action = create_buy_card_action()
    if buy_card_action then
        table.insert(actions, buy_card_action)
    end

    local buy_voucher_action = create_buy_voucher_action()
    if buy_voucher_action then
        table.insert(actions, buy_voucher_action)
    end

    local buy_pack_action = create_buy_pack_action()
    if buy_pack_action then
        table.insert(actions, buy_pack_action)
    end

    return actions
end

return ShopDiscoverer