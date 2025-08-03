-- Menu Discoverer
-- Handles actions available in main menu states

-- Load individual action creators
local create_press_play_action = assert(SMODS.load_file("actions/menu/press_play.lua"))()
local create_continue_run_action = assert(SMODS.load_file("actions/menu/continue_run.lua"))()
local create_start_run_action = assert(SMODS.load_file("actions/menu/start_run.lua"))()
local create_select_deck_action = assert(SMODS.load_file("actions/menu/select_deck.lua"))()
local create_select_stake_action = assert(SMODS.load_file("actions/menu/select_stake.lua"))()

-- Load information actions
local create_view_available_decks_action = assert(SMODS.load_file("actions/menu/view_available_decks.lua"))()
local create_view_available_stakes_action = assert(SMODS.load_file("actions/menu/view_available_stakes.lua"))()

-- Load tab switching actions
local create_switch_to_new_run_action = assert(SMODS.load_file("actions/menu/switch_to_new_run.lua"))()
local create_switch_to_continue_action = assert(SMODS.load_file("actions/menu/switch_to_continue.lua"))()
local create_switch_to_challenges_action = assert(SMODS.load_file("actions/menu/switch_to_challenges.lua"))()

local MenuDiscoverer = {}

-- Check if this discoverer applies to current state
function MenuDiscoverer.is_applicable(current_state)
    return current_state == G.STATES.MAIN_MENU or
           current_state == G.STATES.MENU
end

function MenuDiscoverer.discover(current_state)
    local actions = {}
    -- Check if overlay is active and which setup is current
    if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup then
        -- Always add tab switching actions when overlay is active
        local switch_new_run_action = create_switch_to_new_run_action()
        if switch_new_run_action then
            table.insert(actions, switch_new_run_action)
        end

        local switch_continue_action = create_switch_to_continue_action()
        if switch_continue_action then
            table.insert(actions, switch_continue_action)
        end

        local switch_challenges_action = create_switch_to_challenges_action()
        if switch_challenges_action then
            table.insert(actions, switch_challenges_action)
        end

        -- Tab-specific actions
        if G.SETTINGS.current_setup == 'New Run' then
            -- New Run tab actions
            local start_action = create_start_run_action()
            if start_action then
                table.insert(actions, start_action)
            end

            local select_deck_action = create_select_deck_action()
            if select_deck_action then
                table.insert(actions, select_deck_action)
            end

            local select_stake_action = create_select_stake_action()
            if select_stake_action then
                table.insert(actions, select_stake_action)
            end

            -- Information actions
            local view_decks_action = create_view_available_decks_action()
            if view_decks_action then
                table.insert(actions, view_decks_action)
            end

            local view_stakes_action = create_view_available_stakes_action()
            if view_stakes_action then
                table.insert(actions, view_stakes_action)
            end

        elseif G.SETTINGS.current_setup == 'Continue' then
            -- Continue tab actions
            local continue_action = create_continue_run_action()
            if continue_action then
                table.insert(actions, continue_action)
            end
        end
        -- Note: Challenges tab actions would be added here if needed

    else
        -- Main menu (no overlay) - just press_play action
        local play_action = create_press_play_action()
        if play_action then
            table.insert(actions, play_action)
        end
    end
    return actions
end

return MenuDiscoverer