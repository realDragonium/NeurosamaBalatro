-- Gameplay Discoverer
-- Handles actions available during hand selection and card gameplay

-- Load individual action creators
local create_play_hand_action = assert(SMODS.load_file("actions/gameplay/play_hand.lua"))()
local create_discard_cards_action = assert(SMODS.load_file("actions/gameplay/discard_cards.lua"))()
local create_sort_hand_action = assert(SMODS.load_file("actions/gameplay/sort_hand.lua"))()
local create_select_card_action = assert(SMODS.load_file("actions/gameplay/select_cards_action.lua"))()
local create_sort_jokers_actions = assert(SMODS.load_file("actions/jokers/sort_joker.lua"))()
local create_sell_joker_actions = assert(SMODS.load_file("actions/jokers/sell_joker.lua"))()
local create_use_consumable_action = assert(SMODS.load_file("actions/consumables/use_consumable.lua"))()
local create_use_consumable_targeted_action = assert(SMODS.load_file("actions/consumables/use_consumable_targeted.lua"))()
local create_sell_consumable_action = assert(SMODS.load_file("actions/consumables/sell_consumable.lua"))()
local create_deselect_cards_action = assert(SMODS.load_file("actions/gameplay/deselect_cards.lua"))()

local GameplayDiscoverer = {}

-- Check if this discoverer applies to current state
function GameplayDiscoverer.is_applicable(current_state)
    return current_state == G.STATES.SELECTING_HAND or
           current_state == G.STATES.DRAW_TO_HAND
end

function GameplayDiscoverer.discover(current_state)
    local actions = {}

    -- Basic actions
    local play_action = create_play_hand_action()
    if play_action then
        table.insert(actions, play_action)
    end

    local discard_action = create_discard_cards_action()
    if discard_action then
        table.insert(actions, discard_action)
    end

    local sort_action = create_sort_hand_action()
    if sort_action then
        table.insert(actions, sort_action)
    end

    local select_action = create_select_card_action()
    if select_action then
        table.insert(actions, select_action)
    end

    local deselect_action = create_deselect_cards_action()
    if deselect_action then
        table.insert(actions, deselect_action)
    end

    local sort_jokers_action = create_sort_jokers_actions()
    if sort_jokers_action then
        table.insert(actions, sort_jokers_action)
    end

    local sell_jokers_action = create_sell_joker_actions()
    if sell_jokers_action then
        table.insert(actions, sell_jokers_action)
    end

    local use_consumable_action = create_use_consumable_action()
    if use_consumable_action then
        table.insert(actions, use_consumable_action)
    end

    local use_consumable_targeted_action = create_use_consumable_targeted_action()
    if use_consumable_targeted_action then
        table.insert(actions, use_consumable_targeted_action)
    end

    local sell_consumable_action = create_sell_consumable_action()
    if sell_consumable_action then
        table.insert(actions, sell_consumable_action)
    end

    return actions
end

return GameplayDiscoverer
