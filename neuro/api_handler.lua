-- API handler for Neuro SDK commands
-- Focuses on dynamic action registration/unregistration based on game state

local APIHandler = {}
APIHandler.__index = APIHandler

-- Load all modules
local json = assert(SMODS.load_file("utils/json.lua"))()
local ActionRegistry = assert(SMODS.load_file("neuro/action_registry.lua"))()

-- Communication modules
local WebSocketHandler = assert(SMODS.load_file("neuro/communication/websocket_handler.lua"))()
local MessageProcessor = assert(SMODS.load_file("neuro/communication/message_processor.lua"))()

-- Context modules
local ContextBuilder = assert(SMODS.load_file("context/context_builder.lua"))()
local ContextUpdater = assert(SMODS.load_file("context/context_updater.lua"))()



function APIHandler:new()
    local self = setmetatable({}, APIHandler)

    self.ws = nil
    self.game_name = "Balatro"
    self.waiting_for_action = false
    self.action_queue = {}
    self.last_tab_clicked = nil  -- Track which tab was last clicked

    -- Get action registry instance
    self.action_registry = ActionRegistry.get_instance()
    self.action_registry:set_api_handler(self)

    return self
end

function APIHandler:set_websocket(ws)
    self.ws = ws
end


-- Execute specific action
function APIHandler:execute_action(action_name, params)
    sendInfoMessage("Executing action: " .. action_name, "APIHandler")

    -- Get action from registry
    local action = self.action_registry:get_definition(action_name)
    if not action then
        return false, "Unknown action: " .. action_name
    end

    -- Check if the action has an executor function
    local executor = self.action_registry:get_executor(action_name)
    if not executor then
        return false, "No executor function for action: " .. action_name
    end

    -- Execute the action using the stored executor function
    local success, message = executor(params or {})
    return success, message or (success and "Action completed" or "Action failed")
end

-- Send message to Neuro (delegate to WebSocketHandler)
function APIHandler:send_message(msg)
    return WebSocketHandler.send_message(self, msg)
end

-- Send startup command
function APIHandler:send_startup()
    return WebSocketHandler.send_startup(self)
end

-- Send context update
function APIHandler:send_context(message, silent)
    return WebSocketHandler.send_context(self, message, silent)
end

-- Process incoming message from Neuro
function APIHandler:process_message(payload)
    return MessageProcessor.process_message(self, payload)
end

-- Get current game state context
function APIHandler:get_state_context()
    local context = {
        game_state = G.STATE,
        state_name = self:get_state_name(G.STATE),
        timestamp = love.timer.getTime()
    }

    -- Add state-specific context data
    if G.STATE == G.STATES.SELECTING_HAND then
        context.hand_size = G.hand and #G.hand.cards or 0
        context.plays_left = G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left or 0
        context.discards_left = G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left or 0
        context.target_score = G.GAME and G.GAME.blind and G.GAME.blind.chips or 0
        context.current_score = G.GAME and G.GAME.chips or 0
    elseif G.STATE == G.STATES.SHOP then
        context.money = G.GAME and G.GAME.dollars or 0
        context.reroll_cost = G.GAME and G.GAME.current_round and G.GAME.current_round.reroll_cost or 0
    elseif G.STATE == G.STATES.BLIND_SELECT then
        context.ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or 0
        context.round = G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_states or {}
    end

    return context
end

-- Helper to get human-readable state name
function APIHandler:get_state_name(state)
    if not G.STATES then return "UNKNOWN" end

    for name, state_value in pairs(G.STATES) do
        if state_value == state then
            return name
        end
    end
    return "UNKNOWN"
end

-- Build context message for current state
function APIHandler:build_state_context()
    return ContextBuilder.build_context()
end

-- Send context update to Neuro
function APIHandler:send_context_update()
    local context_message = self:build_state_context()
    return self:send_context(context_message, false)
end

-- Send targeted context update based on state change
function APIHandler:send_state_context_update(previous_state)
    return ContextUpdater.send_state_context_update(self, G.STATE, previous_state)
end


-- Send full context (for queries, startup, etc.)
function APIHandler:send_full_context_update()
    return ContextUpdater.send_full_context_update(self)
end


return APIHandler
