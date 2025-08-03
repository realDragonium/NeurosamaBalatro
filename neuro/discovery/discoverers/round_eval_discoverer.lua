-- Round Eval Discoverer
-- Handles actions available during round evaluation (cash out, etc.)

-- Load individual action creators
local create_cash_out_action = assert(SMODS.load_file("actions/round_eval/cash_out.lua"))()

local RoundEvalDiscoverer = {}

-- Check if this discoverer applies to current state
function RoundEvalDiscoverer.is_applicable(current_state)
    -- Cash out and other round eval actions are available during round evaluation
    return current_state == G.STATES.ROUND_EVAL
end

function RoundEvalDiscoverer.discover(current_state)
    local actions = {}

    -- Cash out action (only available after ante 1)
    local cash_out_action = create_cash_out_action()
    if cash_out_action then
        table.insert(actions, cash_out_action)
    end

    return actions
end

return RoundEvalDiscoverer
