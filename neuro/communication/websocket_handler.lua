-- WebSocket Handler Module
-- Handles sending messages to Neuro through WebSocket

local WebSocketHandler = {}

local json = assert(SMODS.load_file("utils/json.lua"))()

-- Send message to Neuro
function WebSocketHandler.send_message(api_handler, msg)
    if not api_handler.ws then
        -- [MOCK] Would send message
        return true
    end

    msg.game = api_handler.game_name
    local json_str = json.encode(msg)

    if api_handler.ws.send_message then 
        return api_handler.ws:send_message(json_str) 
    else 
        return api_handler.ws:send(json_str) 
    end
end

-- Send startup command
function WebSocketHandler.send_startup(api_handler)
    return WebSocketHandler.send_message(api_handler, {
        command = "startup"
    })
end

-- Send context update
function WebSocketHandler.send_context(api_handler, message, silent)
    return WebSocketHandler.send_message(api_handler, {
        command = "context",
        data = {
            message = message,
            silent = silent or false
        }
    })
end

-- Send action result
function WebSocketHandler.send_action_result(api_handler, id, success, message)
    return WebSocketHandler.send_message(api_handler, {
        command = "action/result",
        data = {
            id = id,
            success = success,
            message = message or ""
        }
    })
end

return WebSocketHandler