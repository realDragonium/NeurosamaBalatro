-- Go to Menu Action
-- Returns to main menu from game over or win state

local EndgameDetector = assert(SMODS.load_file("context/endgame_detector.lua"))()

local function go_to_menu_executor(params)
    -- Can go to menu if we're in game over state or have a win overlay
    if not (EndgameDetector.has_active_game_over() or EndgameDetector.has_active_win_overlay()) then
        return false, "Cannot go to menu - not in endgame state"
    end
    
    -- Find and click the actual menu button
    local menu_button = G.buttons:get_UIE_by_ID('go_to_menu')
    
    if menu_button and menu_button.click then
        menu_button:click()
        return true, "Clicked menu button"
    end
    
    return false, "Failed to find menu button"
end

local function create_go_to_menu_action()
    -- Can go to menu if we're in game over state or have a win overlay
    if not (EndgameDetector.has_active_game_over() or EndgameDetector.has_active_win_overlay()) then
        return nil
    end
    
    return {
        name = "go_to_menu",
        definition = {
            name = "go_to_menu",
            description = "Return to main menu",
            parameters = {}
        },
        executor = go_to_menu_executor
    }
end

return create_go_to_menu_action