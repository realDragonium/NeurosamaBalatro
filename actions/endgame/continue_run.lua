-- Continue Run Action
-- Continues the run after a win (if possible, like after beating ante 8)

local EndgameDetector = assert(SMODS.load_file("context/endgame_detector.lua"))()

local function continue_run_executor(params)
    -- Can continue if we have a win overlay (not game over)
    if not (EndgameDetector.has_active_win_overlay() and not EndgameDetector.has_active_game_over()) then
        return false, "Cannot continue run - not in win state or run cannot be continued"
    end

    local continue_button = G.buttons:get_UIE_by_ID('continue_button')


    if continue_button and continue_button.click then
        continue_button:click()
        return true, "Clicked continue button"
    end

    return false, "Failed to find continue button"
end

local function create_continue_run_action()
    -- Can continue if we have a win overlay (not game over)
    if not (EndgameDetector.has_active_win_overlay() and not EndgameDetector.has_active_game_over()) then
        return nil
    end

    return {
        name = "continue_run",
        definition = {
            name = "continue_run",
            description = "Continue the run to higher antes (endless mode)",
            parameters = {}
        },
        executor = continue_run_executor
    }
end

return create_continue_run_action