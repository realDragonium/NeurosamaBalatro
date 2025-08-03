-- Global action refresh function
-- Calls discoverers directly without DiscoveryManager

local ActionRegistry = assert(SMODS.load_file("neuro/action_registry.lua"))()

-- Load discoverers
local GameplayDiscoverer = assert(SMODS.load_file("neuro/discovery/discoverers/gameplay_discoverer.lua"))()
local ShopDiscoverer = assert(SMODS.load_file("neuro/discovery/discoverers/shop_discoverer.lua"))()
local MenuDiscoverer = assert(SMODS.load_file("neuro/discovery/discoverers/menu_discoverer.lua"))()
local BlindSelectDiscoverer = assert(SMODS.load_file("neuro/discovery/discoverers/blind_select_discoverer.lua"))()
local RoundEvalDiscoverer = assert(SMODS.load_file("neuro/discovery/discoverers/round_eval_discoverer.lua"))()
local PackDiscoverer = assert(SMODS.load_file("neuro/discovery/discoverers/pack_discoverer.lua"))()

local ActionRefresh = {}

-- Helper function to get action names from action list
local function get_action_names(actions)
    local names = {}
    for _, action in ipairs(actions) do
        if action and action.name then
            table.insert(names, action.name)
        end
    end
    table.sort(names)
    return names
end

-- Helper function to compare two sorted arrays
local function arrays_equal(arr1, arr2)
    if #arr1 ~= #arr2 then
        return false
    end
    for i = 1, #arr1 do
        if arr1[i] ~= arr2[i] then
            return false
        end
    end
    return true
end

-- Simple action refresh function - collects actions from discoverers and compares
function ActionRefresh.refresh_actions()
    local action_registry = ActionRegistry.get_instance()
    if not action_registry then
        sendErrorMessage("Action registry not available", "ActionRefresh")
        return
    end

    -- Ensure API handler is set (fix for nil api_handler issue)
    if not action_registry.api_handler and _G.NeuroMod and _G.NeuroMod.api_handler then
        sendInfoMessage("Fixing missing API handler in ActionRegistry", "ActionRefresh")
        action_registry:set_api_handler(_G.NeuroMod.api_handler)
    end

    -- Defer the heavy action discovery work to avoid blocking main thread
    G.E_MANAGER:add_event(Event({
        trigger = "immediate",
        blocking = false,
        func = function()
            local current_state = G.STATE

            -- Collect all actions from discoverers
            local all_discovered_actions = {}

            -- Call each discoverer and collect actions
            if GameplayDiscoverer.is_applicable(current_state) then
                local actions = GameplayDiscoverer.discover(current_state)
                if actions then
                    for _, action in ipairs(actions) do
                        table.insert(all_discovered_actions, action)
                    end
                end
            end

            if ShopDiscoverer.is_applicable(current_state) then
                local actions = ShopDiscoverer.discover(current_state)
                if actions then
                    for _, action in ipairs(actions) do
                        table.insert(all_discovered_actions, action)
                    end
                end
            end

            if MenuDiscoverer.is_applicable(current_state) then
                local actions = MenuDiscoverer.discover(current_state)
                if actions then
                    for _, action in ipairs(actions) do
                        table.insert(all_discovered_actions, action)
                    end
                end
            end

            if BlindSelectDiscoverer.is_applicable(current_state) then
                local actions = BlindSelectDiscoverer.discover(current_state)
                if actions then
                    for _, action in ipairs(actions) do
                        table.insert(all_discovered_actions, action)
                    end
                end
            end

            if RoundEvalDiscoverer.is_applicable(current_state) then
                local actions = RoundEvalDiscoverer.discover(current_state)
                if actions then
                    for _, action in ipairs(actions) do
                        table.insert(all_discovered_actions, action)
                    end
                end
            end

            -- Pack discoverer for pack opening actions
            local pack_actions = PackDiscoverer.discover(current_state)
            if pack_actions then
                for _, action in ipairs(pack_actions) do
                    table.insert(all_discovered_actions, action)
                end
            end

            -- Get current and discovered action names for comparison
            local current_action_names = action_registry:get_all()
            table.sort(current_action_names)

            local discovered_action_names = get_action_names(all_discovered_actions)

            -- Compare action sets
            if not arrays_equal(current_action_names, discovered_action_names) then
                -- Clear existing actions
                action_registry:clear()

                -- Add all discovered actions using add_multiple for better performance
                action_registry:add_multiple(all_discovered_actions)
            end

            return true
        end
    }))
end

return ActionRefresh