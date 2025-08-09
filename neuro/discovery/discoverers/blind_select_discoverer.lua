-- Blind Select Discoverer
-- Handles actions available in blind selection state

-- Load the action creators
local create_play_blind_action = assert(SMODS.load_file("actions/blind_select/play_blind.lua"))()
local create_skip_blind_action = assert(SMODS.load_file("actions/blind_select/skip_blind.lua"))()

-- Load joker actions
local create_sell_joker_action = assert(SMODS.load_file("actions/jokers/sell_joker.lua"))()
local create_sort_joker_action = assert(SMODS.load_file("actions/jokers/sort_joker.lua"))()

-- Load menu/view actions
local create_view_deck_action = assert(SMODS.load_file("actions/menu/view_deck.lua"))()
local create_view_poker_hands_action = assert(SMODS.load_file("actions/menu/view_poker_hands.lua"))()

local BlindSelectDiscoverer = {}

-- Check if this discoverer applies to current state
function BlindSelectDiscoverer.is_applicable(current_state)
    return current_state == G.STATES.BLIND_SELECT
end

function BlindSelectDiscoverer.discover(current_state)
    local actions = {}

    -- Core blind selection actions
    local play_blind_action = create_play_blind_action()
    if play_blind_action then
        table.insert(actions, play_blind_action)
    end

    local skip_blind_action = create_skip_blind_action()
    if skip_blind_action then
        table.insert(actions, skip_blind_action)
    end

    -- Joker management actions
    local sell_joker_action = create_sell_joker_action()
    if sell_joker_action then
        table.insert(actions, sell_joker_action)
    end

    local sort_joker_action = create_sort_joker_action()
    if sort_joker_action then
        table.insert(actions, sort_joker_action)
    end

    -- View/information actions
    local view_deck_action = create_view_deck_action()
    if view_deck_action then
        table.insert(actions, view_deck_action)
    end

    local view_poker_hands_action = create_view_poker_hands_action()
    if view_poker_hands_action then
        table.insert(actions, view_poker_hands_action)
    end

    return actions
end

return BlindSelectDiscoverer
