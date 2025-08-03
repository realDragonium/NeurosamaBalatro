-- Switch to Challenges Tab Action

local function switch_to_challenges_executor(params)
    -- Find and click the Challenges tab button
    if G.OVERLAY_MENU then
        local challenges_label = localize('b_challenges')
        local tab_button_id = 'tab_but_' .. challenges_label
        local tab_button = G.OVERLAY_MENU:get_UIE_by_ID(tab_button_id)

        if tab_button and tab_button.click then
            tab_button:click()
            return true, "Switched to Challenges tab"
        end

        return false, "Challenges tab button not found (ID: " .. tab_button_id .. ")"
    end
    return false, "Overlay menu not active"
end

local function create_switch_to_challenges_action()
    -- Only available when overlay is active and not already on Challenges tab
    if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup ~= 'Challenges' then
        return {
            name = "switch_to_challenges",
            definition = {
                name = "switch_to_challenges",
                description = "Switch to Challenges tab",
                parameters = {}
            },
            executor = switch_to_challenges_executor
        }
    end

    return nil
end

return create_switch_to_challenges_action