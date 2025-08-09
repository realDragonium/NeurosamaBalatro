-- Go to Menu Action
-- Returns to main menu from game over or win state

local EndgameDetector = assert(SMODS.load_file("context/endgame_detector.lua"))()

local function go_to_menu_executor(params)
    -- Can go to menu if we're in game over state or have a win overlay
    if not (EndgameDetector.has_active_game_over() or EndgameDetector.has_active_win_overlay()) then
        return false, "Cannot go to menu - not in endgame state"
    end
    
    -- Find and click the actual menu button
    local menu_button_ids = {
        'go_to_menu',          -- Standard menu button
        'main_menu_button',    -- Alternative button ID
        'menu_button',         -- Generic menu button
        'return_to_menu'       -- Another alternative
    }
    
    local menu_button = nil
    for _, button_id in ipairs(menu_button_ids) do
        if G.buttons then
            menu_button = G.buttons:get_UIE_by_ID(button_id)
            if menu_button then
                break
            end
        end
    end
    
    -- If no button found by ID, try searching through overlay menu
    if not menu_button and G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
        local function find_menu_button(node)
            if not node then return nil end
            
            -- Check if this node is a menu button
            if node.config and node.config.button then
                local button_func = node.config.button
                if button_func == 'go_to_menu' or button_func == 'main_menu' or button_func == 'return_to_menu' then
                    return node
                end
            end
            
            -- Check child nodes recursively
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    local found_button = find_menu_button(child)
                    if found_button then return found_button end
                end
            end
            
            return nil
        end
        
        menu_button = find_menu_button(G.OVERLAY_MENU.definition)
    end
    
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