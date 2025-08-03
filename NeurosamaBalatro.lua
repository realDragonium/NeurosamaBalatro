--- STEAMODDED HEADER
--- MOD_NAME: Neuro-sama Balatro API
--- MOD_ID: neuro_balatro_ai
--- PREFIX: neuro_api
--- MOD_AUTHOR: [realDragonium]
--- MOD_DESCRIPTION: Integrates Neuro-sama SDK to allow VTuber autonomous Balatro gameplay via WebSocket connection
--- VERSION: 0.2.0


local NeuroMod = {
    initialized = false,
    connected = false,
    ws = nil,
    api_handler = nil,
    action_registry = nil,
    last_update = 0,
    startup_sent = false,
    debug_logging = true,
    last_logged_state_num = nil,
    last_logged_state_name = nil,
    game_update_hooked = false
}

local Settings = assert(SMODS.load_file("config/settings.lua"))()
local json = assert(SMODS.load_file("utils/json.lua"))()

local WebSocketClient = assert(SMODS.load_file("sdk/websocket_client.lua"))()
local APIHandler = assert(SMODS.load_file("neuro/api_handler.lua"))()
local ActionRegistry = assert(SMODS.load_file("neuro/action_registry.lua"))()
local ActionRefresh = assert(SMODS.load_file("neuro/discovery/action_refresh.lua"))()
local ContextRefresh = assert(SMODS.load_file("context/context_refresh.lua"))()
local SelectionMonitor = assert(SMODS.load_file("context/selection_monitor.lua"))()
local ContextRegistry = assert(SMODS.load_file("neuro/context_registry.lua"))()


local function connect_to_neuro()
    NeuroMod.ws = WebSocketClient:new(Settings)
    local success = NeuroMod.ws:connect()
    if not success then
        sendErrorMessage("Failed to initiate WebSocket connection", "NeuroMod")
    end

    NeuroMod.api_handler = APIHandler:new()
    sendInfoMessage("Creating APIHandler instance", "NeuroMod")
    NeuroMod.api_handler:set_websocket(NeuroMod.ws)

    -- Initialize ContextRegistry with WebSocket client
    local context_registry = ContextRegistry.get_instance()
    context_registry:set_websocket_client(NeuroMod.ws)
    sendInfoMessage("ContextRegistry initialized with WebSocket client", "NeuroMod")

    return true
end

local function process_socket_messages()
    if not NeuroMod.ws then return end

    NeuroMod.ws:update()

    local is_connected = NeuroMod.ws:is_connected()

    if is_connected and not NeuroMod.connected then
        NeuroMod.connected = true
        sendInfoMessage("WebSocket connection established", "NeuroMod")

        if not NeuroMod.startup_sent and NeuroMod.api_handler then
            sendInfoMessage("Sending startup command to Neuro SDK", "NeuroMod")
            NeuroMod.api_handler:send_startup()
            NeuroMod.startup_sent = true

        end
    elseif not is_connected and NeuroMod.connected then
        NeuroMod.connected = false
        sendWarnMessage("WebSocket disconnected - running in offline mode", "NeuroMod")
    end

    if NeuroMod.connected then
        local messages = NeuroMod.ws:receive_messages()
        for _, message in ipairs(messages) do
            if #message > 0 and NeuroMod.api_handler then
                NeuroMod.api_handler:process_message(message)
            end
        end
    end
end

local function hook_game_state_logging()
    if NeuroMod.game_update_hooked then return end

    local original_game_update = Game.update
    function Game:update(dt)
        original_game_update(self, dt)

        -- Log state changes (compare numbers, not strings)
        if G.STATE ~= NeuroMod.last_logged_state_num then
            local previous_state = NeuroMod.last_logged_state_num
            local state_name = "UNKNOWN"
            for name, state in pairs(G.STATES or {}) do
                if state == G.STATE then
                    state_name = name
                    break
                end
            end

            sendInfoMessage("Game state changed: " .. (NeuroMod.last_logged_state_name and "from " .. NeuroMod.last_logged_state_name or "initial") .. " to " .. state_name .. " (" .. tostring(G.STATE) .. ")", "GameState")

            -- Send targeted context update for state change
            if NeuroMod.api_handler then
                NeuroMod.api_handler:send_state_context_update(previous_state)
            end

            NeuroMod.last_logged_state_num = G.STATE
            NeuroMod.last_logged_state_name = state_name
        end
    end

    NeuroMod.game_update_hooked = true
    sendInfoMessage("Game state logging enabled", "NeuroMod")
end

local function hook_button_id_log_on_click()
    -- Hook UIElement:click to log button clicks
    if not NeuroMod.ui_click_hooked then
        local original_click = UIElement.click
        function UIElement:click()
            -- Log the click with element information
            local element_id = self.config and self.config.id
            local button_id = self.config and self.config.button
            local button_uie_id = self.config and self.config.button_UIE and self.config.button_UIE.id

            local log_parts = {}
            if element_id then
                table.insert(log_parts, "element_id=" .. tostring(element_id))
            end
            if button_id then
                table.insert(log_parts, "button=" .. tostring(button_id))
            end
            if button_uie_id then
                table.insert(log_parts, "button_UIE_id=" .. tostring(button_uie_id))
            end

            local log_msg = "UIElement clicked"
            if #log_parts > 0 then
                log_msg = log_msg .. ": " .. table.concat(log_parts, ", ")
            end

            sendInfoMessage(log_msg, "UIClick")

            -- Call original click function
            return original_click(self)
        end
        NeuroMod.ui_click_hooked = true
        sendInfoMessage("UI click logging enabled", "NeuroMod")
    end
end

local function update_neuro_mod()
    if not NeuroMod.initialized then
        NeuroMod.initialized = true
        connect_to_neuro()
        ActionRefresh.refresh_actions()
        ContextRefresh.refresh_context()
        hook_game_state_logging()
        hook_button_id_log_on_click()
        -- Install selection monitoring hooks
        SelectionMonitor.install_hooks()
    end

    process_socket_messages()

    -- Periodic action and context refresh (less frequent now that we have UI detection)
    local current_time = love.timer.getTime()
    if not NeuroMod.last_refresh_time then
        NeuroMod.last_refresh_time = current_time
    end

    if current_time - NeuroMod.last_refresh_time > 2.0 then -- Every 2 seconds
        ActionRefresh.refresh_actions()
        ContextRefresh.refresh_context()
        -- Check and reinstall selection hooks if needed
        SelectionMonitor.check_and_reinstall()
        NeuroMod.last_refresh_time = current_time
    end
end



if love and love.update then
    local original_update = love.update
    love.update = function(dt)
        original_update(dt)
        update_neuro_mod()
    end
else
    sendErrorMessage("love.update not available - mod cannot run!", "NeuroMod")
end

_G.NeuroMod = NeuroMod

-- Set up global sendWebSocketMessage function for actions
function sendWebSocketMessage(message, type)
    local context_registry = ContextRegistry.get_instance()
    return context_registry:send_context_update(message, false)
end
_G.sendWebSocketMessage = sendWebSocketMessage

sendInfoMessage("Neuro-sama Balatro mod loaded (v0.2.0)", "NeuroMod")
