-- Endgame Action Discoverer
-- Discovers endgame actions (restart_run, go_to_menu, continue_run) when in game over or win states

local EndgameDiscoverer = {}

-- Load endgame action creators
local create_restart_run_action = assert(SMODS.load_file("actions/endgame/restart_run.lua"))()
local create_go_to_menu_action = assert(SMODS.load_file("actions/endgame/go_to_menu.lua"))()
local create_continue_run_action = assert(SMODS.load_file("actions/endgame/continue_run.lua"))()

-- Check if this discoverer applies to current state
function EndgameDiscoverer.is_applicable(current_state)
    -- Always check for endgame states - they have their own internal state checks
    return current_state == G.STATES.GAME_OVER or (G.OVERLAY_MENU ~= nil)
end

function EndgameDiscoverer.discover(state)
    local actions = {}
    
    -- Use action creators like other discoverers
    local restart_action = create_restart_run_action()
    if restart_action then
        table.insert(actions, restart_action)
    end
    
    local menu_action = create_go_to_menu_action()
    if menu_action then
        table.insert(actions, menu_action)
    end
    
    local continue_action = create_continue_run_action()
    if continue_action then
        table.insert(actions, continue_action)
    end
    
    return actions
end

return EndgameDiscoverer