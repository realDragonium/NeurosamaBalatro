-- Blind Select Discoverer
-- Handles actions available in blind selection state

-- Load the 2 simplified action creators
local create_play_blind_action = assert(SMODS.load_file("actions/blind_select/play_blind.lua"))()
local create_skip_blind_action = assert(SMODS.load_file("actions/blind_select/skip_blind.lua"))()

local BlindSelectDiscoverer = {}

-- Check if this discoverer applies to current state
function BlindSelectDiscoverer.is_applicable(current_state)
    return current_state == G.STATES.BLIND_SELECT
end

function BlindSelectDiscoverer.discover(current_state)
    local actions = {}

    local play_blind_action = create_play_blind_action()
    if play_blind_action then
        table.insert(actions, play_blind_action)
    end

    local skip_blind_action = create_skip_blind_action()
    if skip_blind_action then
        table.insert(actions, skip_blind_action)
    end

    return actions
end

return BlindSelectDiscoverer
