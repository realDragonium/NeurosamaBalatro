-- Message Processor Module
-- Handles processing incoming messages from Neuro

local MessageProcessor = {}

local json = assert(SMODS.load_file("utils/json.lua"))()
local WebSocketHandler = assert(SMODS.load_file("neuro/communication/websocket_handler.lua"))()
local ActionRefresh = assert(SMODS.load_file("neuro/discovery/action_refresh.lua"))()

-- Process incoming message from Neuro
function MessageProcessor.process_message(api_handler, payload)
    local msg = json.decode(payload)
    if not msg then
        sendErrorMessage("Failed to decode message: " .. payload, "APIHandler")
        return
    end

    sendInfoMessage("Received from Neuro: " .. payload, "APIHandler")

    if msg.command == "action" then
        -- Defer action handling to avoid blocking the game loop
        MessageProcessor.handle_action(api_handler, msg)
    elseif msg.command == "query" then
        -- Handle query request using discovery manager
        MessageProcessor.handle_query(api_handler, msg)
    elseif msg.command == "actions/reregister_all" then
        -- Handle reregister_all request using discovery manager
        MessageProcessor.handle_reregister_all(api_handler, msg)
    end
end

-- Handle query request
function MessageProcessor.handle_query(api_handler, msg)
    sendInfoMessage("Processing query request", "MessageProcessor")

    -- Send full context for query
    api_handler:send_full_context_update()
end

-- Handle reregister_all request
function MessageProcessor.handle_reregister_all(api_handler, msg)
    sendInfoMessage("Processing reregister_all request", "MessageProcessor")

    -- Just reregister whatever actions are currently in the registry
    api_handler.action_registry:reregister_all()
end

-- Handle action execution
function MessageProcessor.handle_action(api_handler, msg)
    if not msg.data or not msg.data.name then
        WebSocketHandler.send_action_result(api_handler, msg.data and msg.data.id, false, "Invalid action message")
        return
    end

    local action_name = msg.data.name
    local action_data = {}

    -- Parse action data if provided
    if msg.data.data and type(msg.data.data) == "string" then
        local ok, parsed = pcall(json.decode, msg.data.data)
        if ok and parsed then
            action_data = parsed
        end
    end

    sendInfoMessage("Executing action: " .. action_name .. " with data: " .. json.encode(action_data), "APIHandler")

    -- Execute the action
    local success, message = api_handler:execute_action(action_name, action_data)

    -- Send result
    WebSocketHandler.send_action_result(api_handler, msg.data.id, success, message)

    -- After action execution, schedule action refresh to update available actions
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 1.0,
        blocking = false,
        func = function()
            ActionRefresh.refresh_actions()
            return true
        end
    }))
end

return MessageProcessor