-- Restart Run Action
-- Starts a new run after game over or win

local EndgameDetector = assert(SMODS.load_file("context/endgame_detector.lua"))()

local function restart_run_executor(params)
    -- Can restart if we're in game over state or have a win overlay
    if not (EndgameDetector.has_active_game_over() or EndgameDetector.has_active_win_overlay()) then
        return false, "Cannot restart run - not in endgame state"
    end
    
    -- Find and click the actual restart button
    local restart_button_ids = {
        'from_game_over',      -- Game over screen
        'from_game_won',       -- Win screen 
        'new_run_button',      -- Alternative button ID
        'restart_button'       -- Generic restart button
    }
    
    local restart_button = nil
    for _, button_id in ipairs(restart_button_ids) do
        if G.buttons then
            restart_button = G.buttons:get_UIE_by_ID(button_id)
            if restart_button then
                break
            end
        end
    end
    
    -- If no button found by ID, try searching through overlay menu
    if not restart_button and G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
        local function find_restart_button(node)
            if not node then return nil end
            
            -- Check if this node is a restart button
            if node.config and node.config.button then
                local button_func = node.config.button
                if button_func == 'start_new_run' or button_func == 'new_run' or button_func == 'restart_run' then
                    return node
                end
            end
            
            -- Check child nodes recursively
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    local found_button = find_restart_button(child)
                    if found_button then return found_button end
                end
            end
            
            return nil
        end
        
        restart_button = find_restart_button(G.OVERLAY_MENU.definition)
    end
    
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