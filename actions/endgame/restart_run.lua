-- Restart Run Action
-- Starts a new run after game over or win

local EndgameDetector = assert(SMODS.load_file("context/endgame_detector.lua"))()

local function restart_run_executor(params)
    -- Can restart if we're in game over state or have a win overlay
    if not (EndgameDetector.has_active_game_over() or EndgameDetector.has_active_win_overlay()) then
        return false, "Cannot restart run - not in endgame state"
    end
    
    -- Find and click the actual restart button
    local restart_button = G.buttons:get_UIE_by_ID('from_game_over')
    
    if restart_button and restart_button.click then
        restart_button:click()
        return true, "Clicked restart button"
    end
    
    return false, "Failed to find restart button"
end

local function create_restart_run_action()
    -- Can restart if we're in game over state or have a win overlay
    if not (EndgameDetector.has_active_game_over() or EndgameDetector.has_active_win_overlay()) then
        return nil
    end
    
    return {
        name = "restart_run",
        definition = {
            name = "restart_run",
            description = "Start a new run with the same deck and stake",
            parameters = {}
        },
        executor = restart_run_executor
    }
end

return create_restart_run_action