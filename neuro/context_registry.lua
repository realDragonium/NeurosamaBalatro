-- Context Registry
-- Provides a centralized system for sending context updates via WebSocket

local ContextRegistry = {}
ContextRegistry.__index = ContextRegistry

-- Use global singleton to ensure same instance across all SMODS.load_file() calls
local function get_global_instance()
    return _G._NEURO_CONTEXT_REGISTRY
end

local function set_global_instance(instance)
    _G._NEURO_CONTEXT_REGISTRY = instance
end

-- Load dependencies
local json = assert(SMODS.load_file("utils/json.lua"))()

function ContextRegistry.get_instance()
    local existing = get_global_instance()
    if existing then
        return existing
    end
    
    local instance = ContextRegistry:new()
    set_global_instance(instance)
    return instance
end

function ContextRegistry:new()
    local self = setmetatable({}, ContextRegistry)
    self.websocket_client = nil
    return self
end

-- Set the WebSocket client reference
function ContextRegistry:set_websocket_client(ws_client)
    self.websocket_client = ws_client
    sendInfoMessage("ContextRegistry: WebSocket client set", "ContextRegistry")
end

-- Send context update via WebSocket
function ContextRegistry:send_context_update(context_string, silent)
    -- Wrap everything in pcall to prevent crashes
    local success, result = pcall(function()
        if not self.websocket_client then
            sendWarnMessage("ContextRegistry: No WebSocket client available", "ContextRegistry")
            return false
        end
        
        if not self.websocket_client.connected then
            sendWarnMessage("ContextRegistry: WebSocket not connected", "ContextRegistry")
            return false
        end
        
        -- Create context message
        local message = json.encode({
            command = "context",
            data = { 
                message = context_string, 
                silent = silent or false
            },
            game = "Balatro"
        })
        
        -- Send via WebSocket
        local send_success = self.websocket_client:send_message(message)
        if send_success then
            sendInfoMessage("ContextRegistry: Sent context update", "ContextRegistry")
        else
            sendErrorMessage("ContextRegistry: Failed to send context update", "ContextRegistry")
        end
        
        return send_success
    end)
    
    if not success then
        sendErrorMessage("ContextRegistry: Error sending context update: " .. tostring(result), "ContextRegistry")
        return false
    end
    
    return result
end

return ContextRegistry