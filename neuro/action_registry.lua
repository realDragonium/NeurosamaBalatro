-- Dynamic Action Registry for managing available actions
-- Any part of the code can add/remove actions as needed

local ActionRegistry = {}
ActionRegistry.__index = ActionRegistry

-- Use global singleton to ensure same instance across all SMODS.load_file() calls
local function get_global_instance()
    return _G._NEURO_ACTION_REGISTRY
end

local function set_global_instance(instance)
    _G._NEURO_ACTION_REGISTRY = instance
end

-- Instance counter for debugging
local instance_id = 0

function ActionRegistry:new()
    local existing = get_global_instance()
    if existing then
        sendInfoMessage("Returning existing global ActionRegistry instance " .. existing.id, "ActionRegistry")
        return existing
    end

    instance_id = instance_id + 1
    local self = setmetatable({}, ActionRegistry)
    self.actions = {}  -- Current available actions
    self.executors = {}  -- Action execution functions
    self.api_handler = nil  -- Reference to API handler for syncing
    self.id = instance_id
    self.created_at = love.timer.getTime()

    set_global_instance(self)
    sendInfoMessage("Created new global ActionRegistry instance " .. self.id, "ActionRegistry")

    return self
end

-- Set the API handler reference
function ActionRegistry:set_api_handler(api_handler)
    self.api_handler = api_handler
    sendInfoMessage("API handler set on ActionRegistry instance " .. self.id, "ActionRegistry")
end


-- Add multiple actions at once
function ActionRegistry:add_multiple(action_list)
    local to_register = {}
    local pending_actions = {}

    -- First, prepare actions to register but don't store them yet
    for _, action in ipairs(action_list) do
        if action.name and action.definition and action.executor and not self.actions[action.name] then
            table.insert(to_register, action.definition)
            table.insert(pending_actions, action)
        end
    end

    -- Only store actions if we can send them to the websocket
    if #to_register > 0 and self.api_handler then
        local success, error_msg = pcall(function()
            self.api_handler:send_message({
                command = "actions/register",
                data = {
                    actions = to_register
                }
            })
        end)

        if success then
            -- Only store actions locally if websocket send succeeded
            for _, action in ipairs(pending_actions) do
                self.actions[action.name] = action.definition
                self.executors[action.name] = action.executor
            end

            local names = {}
            for _, action in ipairs(to_register) do
                table.insert(names, action.name)
            end
            -- sendInfoMessage("Registered actions: " .. table.concat(names, ", "), "ActionRegistry")
        -- else
        --     sendWarnMessage("Failed to send actions to websocket: " .. tostring(error_msg), "ActionRegistry")
        --     sendWarnMessage("Actions not stored locally due to websocket failure", "ActionRegistry")
        end
    elseif #to_register > 0 then
        sendWarnMessage("API handler not available, actions not stored: " .. #to_register .. " actions", "ActionRegistry")
    end
end


-- Remove multiple actions
function ActionRegistry:remove_multiple(names)
    local to_unregister = {}

    for _, name in ipairs(names) do
        if self.actions[name] then
            self.actions[name] = nil
            self.executors[name] = nil
            table.insert(to_unregister, name)
        end
    end

    -- Send all unregistrations at once
    if #to_unregister > 0 and self.api_handler then
        self.api_handler:send_message({
            command = "actions/unregister",
            data = {
                action_names = to_unregister
            }
        })
        sendInfoMessage("Unregistered " .. #to_unregister .. " actions: " .. table.concat(to_unregister, ", ") .. " (remaining: " .. self:count() .. ")", "ActionRegistry")
    end
end


-- Clear all actions
function ActionRegistry:clear()
    local all_names = {}
    for name, _ in pairs(self.actions) do
        table.insert(all_names, name)
    end

    sendInfoMessage("Clearing all actions from registry instance " .. self.id .. " (" .. #all_names .. " actions)", "ActionRegistry")

    if #all_names > 0 then
        self:remove_multiple(all_names)
    end

    -- Also clear executors
    self.executors = {}
end

-- Get all current actions as a list
function ActionRegistry:get_all()
    local action_list = {}
    for name, _ in pairs(self.actions) do
        table.insert(action_list, name)
    end
    return action_list
end

-- Count of actions
function ActionRegistry:count()
    local count = 0
    for _ in pairs(self.actions) do
        count = count + 1
    end
    return count
end

-- Get action definition
function ActionRegistry:get_definition(name)
    local action = self.actions[name]
    if not action then
        sendWarnMessage("Action '" .. name .. "' not found in registry instance " .. self.id .. ". Available actions: " .. table.concat(self:get_all(), ", "), "ActionRegistry")
        sendWarnMessage("Registry instance " .. self.id .. " has " .. self:count() .. " actions", "ActionRegistry")
    else
        sendInfoMessage("Found action '" .. name .. "' in registry instance " .. self.id, "ActionRegistry")
    end
    return action
end

-- Get action executor
function ActionRegistry:get_executor(name)
    local executor = self.executors[name]
    if not executor then
        sendWarnMessage("Executor for action '" .. name .. "' not found in registry instance " .. self.id, "ActionRegistry")
    end
    return executor
end

-- Check if action exists
function ActionRegistry:has(name)
    return self.actions[name] ~= nil
end

-- Debug function to list all actions
function ActionRegistry:debug_list_actions()
    sendInfoMessage("=== ActionRegistry Instance " .. self.id .. " Debug ===", "ActionRegistry")
    sendInfoMessage("Total actions: " .. self:count(), "ActionRegistry")
    sendInfoMessage("API handler: " .. (self.api_handler and "SET" or "NULL"), "ActionRegistry")
    sendInfoMessage("Created at: " .. (self.created_at or "unknown"), "ActionRegistry")

    if self:count() > 0 then
        sendInfoMessage("Actions: " .. table.concat(self:get_all(), ", "), "ActionRegistry")
    else
        sendInfoMessage("No actions registered", "ActionRegistry")
    end
    sendInfoMessage("=== End Debug ===", "ActionRegistry")
end

-- Handle reregister_all command - send all current actions
function ActionRegistry:reregister_all()
    if not self.api_handler then
        sendWarnMessage("Cannot reregister actions: API handler not set on instance " .. self.id, "ActionRegistry")
        return
    end

    local all_actions = {}
    for name, definition in pairs(self.actions) do
        table.insert(all_actions, definition)
    end

    if #all_actions > 0 then
        self.api_handler:send_message({
            command = "actions/register",
            data = {
                actions = all_actions
            }
        })

        local names = {}
        for _, action in ipairs(all_actions) do
            table.insert(names, action.name)
        end
        sendInfoMessage("Re-registered all actions from instance " .. self.id .. ": " .. table.concat(names, ", "), "ActionRegistry")
    else
        sendInfoMessage("No actions to re-register in instance " .. self.id, "ActionRegistry")
    end
end

-- Get singleton instance (the main way modules should access the registry)
function ActionRegistry.get_instance()
    local existing = get_global_instance()
    if not existing then
        existing = ActionRegistry:new()
    end
    return existing
end

return ActionRegistry