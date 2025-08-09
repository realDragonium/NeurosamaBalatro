-- Continue Run Action
-- Continues the run after a win (if possible, like after beating ante 8)

local EndgameDetector = assert(SMODS.load_file("context/endgame_detector.lua"))()

local function continue_run_executor(params)
    -- Can continue if we have a win overlay (not game over)
    if not (EndgameDetector.has_active_win_overlay() and not EndgameDetector.has_active_game_over()) then
        return false, "Cannot continue run - not in win state or run cannot be continued"
    end

    -- Find and click the actual continue button
    local continue_button_ids = {
        'continue_button',     -- Standard continue button
        'endless_button',      -- Endless mode button
        'keep_playing',        -- Alternative button ID
        'continue_run_button'  -- Another alternative
    }
    
    local continue_button = nil
    for _, button_id in ipairs(continue_button_ids) do
        if G.buttons then
            continue_button = G.buttons:get_UIE_by_ID(button_id)
            if continue_button then
                break
            end
        end
    end
    
    -- If no button found by ID, try searching through overlay menu
    if not continue_button and G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
        local function find_continue_button(node)
            if not node then return nil end
            
            -- Check if this node is a continue button
            if node.config and node.config.button then
                local button_func = node.config.button
                if button_func == 'continue_run' or button_func == 'endless_mode' or button_func == 'keep_playing' then
                    return node
                end
            end
            
            -- Check child nodes recursively
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    local found_button = find_continue_button(child)
                    if found_button then return found_button end
                end
            end
            
            return nil
        end
        
        continue_button = find_continue_button(G.OVERLAY_MENU.definition)
    end

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