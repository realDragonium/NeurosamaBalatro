-- Switch to Continue Tab Action

local function switch_to_continue_executor(params)
    -- Find and click the Continue tab button
    if G.OVERLAY_MENU then
        local continue_label = localize('b_continue')
        local tab_button_id = 'tab_but_' .. continue_label
        local tab_button = G.OVERLAY_MENU:get_UIE_by_ID(tab_button_id)
        
        if tab_button and tab_button.click then
            tab_button:click()
            return true, "Switched to Continue tab"
        end
        
        return false, "Continue tab button not found (ID: " .. tab_button_id .. ")"
    end
    return false, "Overlay menu not active"
end

local function create_switch_to_continue_action()
    -- Only available when overlay is active, continue tab exists, and not already on Continue tab
    if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup ~= 'Continue' and G.SAVED_GAME then
        return {
            name = "switch_to_continue",
            definition = {
                name = "switch_to_continue",
                description = "Switch to Continue tab",
                parameters = {}
            },
            executor = switch_to_continue_executor
        }
    end
    
    return nil
end

return create_switch_to_continue_action