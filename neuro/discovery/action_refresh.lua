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

-- Collect all available actions from discoverers
local function discover_all_actions(current_state)
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

    return all_discovered_actions
end

-- Compare current actions with discovered actions and return differences
local function calculate_action_differences(action_registry, discovered_actions)
    local current_actions = {}  -- name -> true
    local new_actions = {}      -- name -> action object
    
    -- Build current actions set
    local current_action_names = action_registry:get_all()
    for _, name in ipairs(current_action_names) do
        current_actions[name] = true
    end
    
    -- Build new actions set
    for _, action in ipairs(discovered_actions) do
        if action.name and action.definition and action.executor then
            new_actions[action.name] = action
        end
    end
    
    -- Find actions to remove (exist in current but not in new)
    local to_remove = {}
    for name, _ in pairs(current_actions) do
        if not new_actions[name] then
            table.insert(to_remove, name)
        end
    end
    
    -- Find actions to add (exist in new but not in current)
    local to_add = {}
    for name, action in pairs(new_actions) do
        if not current_actions[name] then
            table.insert(to_add, action)
        end
    end
    
    return to_add, to_remove
end

-- Apply action updates to the registry
local function apply_action_updates(action_registry, to_add, to_remove)
    if #to_remove == 0 and #to_add == 0 then
        return false -- No changes
    end
    
    -- Remove actions that are no longer available
    if #to_remove > 0 then
        action_registry:remove_multiple(to_remove)
    end
    
    -- Add new actions
    if #to_add > 0 then
        action_registry:add_multiple(to_add)
    end
    
    sendInfoMessage("Action refresh: +" .. #to_add .. " actions, -" .. #to_remove .. " actions (total: " .. action_registry:count() .. ")", "ActionRefresh")
    return true -- Changes applied
end

-- Main action refresh function
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

            -- Discover all available actions
            local discovered_actions = discover_all_actions(current_state)
            
            -- Calculate what needs to be added/removed
            local to_add, to_remove = calculate_action_differences(action_registry, discovered_actions)
            
            -- Apply the updates
            apply_action_updates(action_registry, to_add, to_remove)

            return true
        end
    }))
end

return ActionRefresh