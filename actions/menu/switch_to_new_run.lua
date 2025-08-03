-- Switch to New Run Tab Action

local function switch_to_new_run_executor(params)
    -- Find and click the New Run tab button
    if G.OVERLAY_MENU then
        local new_run_label = localize('b_new_run')
        local tab_button_id = 'tab_but_' .. new_run_label
        local tab_button = G.OVERLAY_MENU:get_UIE_by_ID(tab_button_id)
        
        if tab_button and tab_button.click then
            tab_button:click()
            return true, "Switched to New Run tab"
        end
        
        return false, "New Run tab button not found (ID: " .. tab_button_id .. ")"
    end
    return false, "Overlay menu not active"
end

local function create_switch_to_new_run_action()
    -- Only available when overlay is active and not already on New Run tab
    if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup ~= 'New Run' then
        return {
            name = "switch_to_new_run",
            definition = {
                name = "switch_to_new_run",
                description = "Switch to New Run tab",
                parameters = {}
            },
            executor = switch_to_new_run_executor
        }
    end
    
    return nil
end

return create_switch_to_new_run_action