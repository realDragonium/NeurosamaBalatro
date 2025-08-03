-- Message Handler for Neuro SDK
-- Handles incoming and outgoing messages between the game and Neuro

local MessageHandler = {}
MessageHandler.__index = MessageHandler

local json = SMODS.load_file("utils/json.lua")()

function MessageHandler:new(game_name)
    local self = setmetatable({}, MessageHandler)

    self.game_name = game_name or "Balatro"
    self.ws = nil
    self.message_callbacks = {}

    return self
end

-- Set WebSocket connection
function MessageHandler:set_websocket(ws)
    self.ws = ws
end

-- Register a callback for a specific command
function MessageHandler:on(command, callback)
    if not self.message_callbacks[command] then
        self.message_callbacks[command] = {}
    end
    table.insert(self.message_callbacks[command], callback)
end

-- Send a message to Neuro
function MessageHandler:send(msg)
    if not self.ws then
        sendWarnMessage("No WebSocket connection available", "MessageHandler")
        return false
    end

    -- Add game name to all outgoing messages
    msg.game = self.game_name

    local json_str = json.encode(msg)

    if self.ws.send_message then 
        return self.ws:send_message(json_str) 
    else 
        return self.ws:send(json_str) 
    end
end

-- Process incoming message
function MessageHandler:process_message(payload)
    local msg = json.decode(payload)
    if not msg then
        sendErrorMessage("Failed to decode message: " .. payload, "MessageHandler")
        return
    end

    sendInfoMessage("Received: " .. payload, "MessageHandler")

    -- Find and execute callbacks for this command
    local callbacks = self.message_callbacks[msg.command]
    if callbacks then
        for _, callback in ipairs(callbacks) do
            local success, error = pcall(callback, msg)
            if not success then
                sendErrorMessage("Error in message callback for " .. msg.command .. ": " .. tostring(error), "MessageHandler")
            end
        end
    else
        sendWarnMessage("No handler for command: " .. tostring(msg.command), "MessageHandler")
    end
end

-- Common message senders
function MessageHandler:send_startup()
    return self:send({
        command = "startup"
    })
end

function MessageHandler:send_context(message, silent)
    return self:send({
        command = "context",
        data = {
            message = message,
            silent = silent or false
        }
    })
end

function MessageHandler:send_action_result(id, success, message)
    return self:send({
        command = "action/result",
        data = {
            id = id,
            success = success,
            message = message or ""
        }
    })
end

function MessageHandler:send_actions_register(actions)
    return self:send({
        command = "actions/register",
        data = {
            actions = actions
        }
    })
end

function MessageHandler:send_actions_unregister(action_names)
    return self:send({
        command = "actions/unregister",
        data = {
            action_names = action_names
        }
    })
end

return MessageHandler