local WebSocketClient = {}
WebSocketClient.__index = WebSocketClient

-- Bitwise XOR fallback for Lua without bitwise operators
local function bxor(a, b)
    local result = 0
    local bit_a, bit_b, bit_result
    local shift = 1

    while a > 0 or b > 0 do
        bit_a = a % 2
        bit_b = b % 2
        bit_result = (bit_a + bit_b) % 2
        result = result + bit_result * shift

        a = math.floor(a / 2)
        b = math.floor(b / 2)
        shift = shift * 2
    end

    return result
end

function WebSocketClient:new(Settings)
    local client = {
        sock = nil,
        connected = false,
        host = Settings.WEBSOCKET_HOST,
        port = Settings.WEBSOCKET_PORT,
        path = Settings.WEBSOCKET_PATH,
        reconnect_attempts = 0,
        last_ping = 0,
        message_queue = {},
        receive_buffer = "",
        Settings = Settings,
        connection_failed = false
    }
    setmetatable(client, WebSocketClient)
    return client
end

function WebSocketClient:generate_key()
    local key = ""
    for i = 1, 16 do
        key = key .. string.char(math.random(0, 255))
    end
    return love.data.encode("string", "base64", key)
end

function WebSocketClient:create_handshake()
    local key = self:generate_key()
    local handshake = string.format(
        "GET %s HTTP/1.1\r\n" ..
        "Host: %s:%d\r\n" ..
        "Upgrade: websocket\r\n" ..
        "Connection: Upgrade\r\n" ..
        "Sec-WebSocket-Key: %s\r\n" ..
        "Sec-WebSocket-Version: 13\r\n" ..
        "\r\n",
        self.path, self.host, self.port, key
    )
    return handshake, key
end

function WebSocketClient:parse_handshake_response(response)
    if not response:match("HTTP/1.1 101") then
        return false, "Invalid HTTP response"
    end

    -- Convert to lowercase for case-insensitive matching
    local response_lower = response:lower()

    if not response_lower:match("upgrade: websocket") and not response_lower:match("upgrade:websocket") then
        return false, "Missing websocket upgrade"
    end

    if not response_lower:match("connection: upgrade") and not response_lower:match("connection:upgrade") then
        return false, "Missing connection upgrade"
    end

    return true, nil
end

function WebSocketClient:connect()
    if self.connected then
        sendWarnMessage("Already connected to WebSocket", "WebSocketClient")
        return true
    end

    sendInfoMessage("Attempting to connect to " .. self.host .. ":" .. self.port, "WebSocketClient")

    -- Check if socket is available (LuaSocket)
    local socket = socket or (package.loaded.socket) or (_G.socket)
    if not socket then
        sendErrorMessage("LuaSocket not available", "WebSocketClient")
        return false
    end

    self.sock = socket.tcp()
    if not self.sock then
        sendErrorMessage("Failed to create TCP socket", "WebSocketClient")
        return false
    end

    -- Set timeout for initial connection
    self.sock:settimeout(self.Settings.CONNECTION_TIMEOUT)

    -- Wrap connection attempt in pcall to catch any errors
    local success, result = pcall(function()
        return self.sock:connect(self.host, self.port)
    end)

    if not success then
        sendErrorMessage("TCP connection error: " .. tostring(result), "WebSocketClient")
        self.sock:close()
        self.sock = nil
        return false
    end

    if not result then
        sendErrorMessage("TCP connection failed: Connection refused or timeout", "WebSocketClient")
        self.sock:close()
        self.sock = nil
        return false
    end

    sendInfoMessage("TCP connection established, sending WebSocket handshake", "WebSocketClient")

    local handshake, key = self:create_handshake()
    sendDebugMessage("Sending handshake:\n" .. handshake:gsub("\r", "\\r"):gsub("\n", "\\n"), "WebSocketClient")

    local sent, err = self.sock:send(handshake)
    if not sent then
        sendErrorMessage("Failed to send handshake: " .. tostring(err), "WebSocketClient")
        self:disconnect("Failed to send handshake: " .. tostring(err))
        return false
    end

    sendInfoMessage("Handshake sent successfully (" .. sent .. " bytes)", "WebSocketClient")

    -- Set socket to non-blocking mode immediately
    self.sock:settimeout(0)

    -- Store handshake state
    self.handshaking = true
    self.handshake_response = ""
    self.handshake_start_time = love.timer.getTime()

    sendInfoMessage("WebSocket handshake initiated", "WebSocketClient")
    return true
end

function WebSocketClient:disconnect(reason)
    reason = reason or "Unknown reason"
    sendWarnMessage("WebSocket disconnecting - Reason: " .. reason, "WebSocketClient")

    if self.sock then
        self.sock:close()
        self.sock = nil
    end
    self.connected = false
    self.handshaking = false
    self.receive_buffer = ""
    self.handshake_response = ""
    sendInfoMessage("WebSocket disconnected", "WebSocketClient")
end

function WebSocketClient:create_frame(opcode, payload)
    local payload_len = #payload
    local frame = string.char(0x80 + opcode)

    if payload_len < 126 then
        frame = frame .. string.char(0x80 + payload_len)
    elseif payload_len < 65536 then
        frame = frame .. string.char(0x80 + 126)
        frame = frame .. string.char(math.floor(payload_len / 256))
        frame = frame .. string.char(payload_len % 256)
    else
        frame = frame .. string.char(0x80 + 127)
        for i = 7, 0, -1 do
            frame = frame .. string.char(math.floor(payload_len / (2^(8*i))) % 256)
        end
    end

    local mask = {}
    for i = 1, 4 do
        mask[i] = math.random(0, 255)
        frame = frame .. string.char(mask[i])
    end

    local masked_payload = ""
    for i = 1, payload_len do
        local byte = string.byte(payload, i)
        local mask_byte = mask[((i - 1) % 4) + 1]
        local xor_result = bit and bit.bxor and bit.bxor(byte, mask_byte) or bxor(byte, mask_byte)
        masked_payload = masked_payload .. string.char(xor_result)
    end

    return frame .. masked_payload
end

function WebSocketClient:send_message(message)
    if not self.connected or not self.sock then
        sendWarnMessage("Cannot send message: not connected (connected=" .. tostring(self.connected) .. ", sock=" .. tostring(self.sock ~= nil) .. ")", "WebSocketClient")
        return false
    end

    local frame = self:create_frame(1, message)
    sendDebugMessage("Created frame of " .. #frame .. " bytes for message of " .. #message .. " bytes", "WebSocketClient")

    local sent, err = self.sock:send(frame)

    if not sent then
        sendErrorMessage("Failed to send message: " .. tostring(err), "WebSocketClient")
        self:disconnect("Failed to send message: " .. tostring(err))
        return false
    end

    sendInfoMessage("Sent WebSocket frame with message: " .. message, "WebSocketClient")
    return true
end

function WebSocketClient:parse_frame(data)
    if #data < 2 then return nil, data end

    local pos = 1
    local first_byte = string.byte(data, pos)
    local fin = bit and bit.band and bit.band(first_byte, 0x80) ~= 0 or (first_byte >= 128)
    local opcode = bit and bit.band and bit.band(first_byte, 0x0F) or (first_byte % 16)
    pos = pos + 1

    local second_byte = string.byte(data, pos)
    local masked = bit and bit.band and bit.band(second_byte, 0x80) ~= 0 or (second_byte >= 128)
    local payload_len = bit and bit.band and bit.band(second_byte, 0x7F) or (second_byte % 128)
    pos = pos + 1

    if payload_len == 126 then
        if #data < pos + 1 then return nil, data end
        payload_len = string.byte(data, pos) * 256 + string.byte(data, pos + 1)
        pos = pos + 2
    elseif payload_len == 127 then
        if #data < pos + 7 then return nil, data end
        payload_len = 0
        for i = 0, 7 do
            payload_len = payload_len + (string.byte(data, pos + i) * (2^(8 * (7 - i))))
        end
        pos = pos + 8
    end

    if masked then
        if #data < pos + 3 then return nil, data end
        pos = pos + 4
    end

    if #data < pos + payload_len - 1 then return nil, data end

    local payload = data:sub(pos, pos + payload_len - 1)
    local remaining = data:sub(pos + payload_len)

    return {
        fin = fin,
        opcode = opcode,
        payload = payload
    }, remaining
end

function WebSocketClient:receive_messages()
    -- Allow receiving during handshake phase too
    if not self.sock then
        sendDebugMessage("Cannot receive - no socket", "WebSocketClient")
        return {}
    end

    -- Only process WebSocket frames if we're connected (post-handshake)
    if not self.connected then
        return {}
    end

    local messages = {}
    local data, err, partial = self.sock:receive("*a")

    -- Handle partial data
    if partial and #partial > 0 then
        data = partial
    end

    if data and #data > 0 then
        -- sendDebugMessage("Raw data received (" .. #data .. " bytes): " .. string.sub(data:gsub("\r", "\\r"):gsub("\n", "\\n"), 1, 200), "WebSocketClient")
        self.receive_buffer = self.receive_buffer .. data

        -- sendDebugMessage("Buffer size: " .. #self.receive_buffer .. " bytes", "WebSocketClient")

        while #self.receive_buffer > 0 do
            local frame, remaining = self:parse_frame(self.receive_buffer)
            if not frame then
                if #self.receive_buffer > 2 then
                    sendDebugMessage("No complete frame yet, buffer: " .. string.sub(self.receive_buffer:gsub("\r", "\\r"):gsub("\n", "\\n"), 1, 100), "WebSocketClient")
                end
                break
            end

            self.receive_buffer = remaining or ""

            -- sendDebugMessage("Parsed frame - opcode: " .. frame.opcode .. ", payload length: " .. #frame.payload, "WebSocketClient")

            if frame.opcode == 1 then
                table.insert(messages, frame.payload)
                -- Always log received messages during testing
                sendInfoMessage("Received WebSocket message: " .. frame.payload, "WebSocketClient")
            elseif frame.opcode == 8 then
                sendInfoMessage("Received close frame", "WebSocketClient")
                self:disconnect("Received close frame from server")
                break
            elseif frame.opcode == 9 then
                -- sendInfoMessage("Received ping, deferring pong response", "WebSocketClient")
                -- Defer pong response to next frame to avoid blocking game loop
                local payload = frame.payload
                local ws_client = self
                G.E_MANAGER:add_event(Event({
                    trigger = "immediate",
                    func = function()
                        ws_client:send_pong(payload)
                        return true
                    end
                }))
            elseif frame.opcode == 10 then
                -- sendInfoMessage("Received pong", "WebSocketClient")
            else
                sendInfoMessage("Received unknown opcode: " .. frame.opcode, "WebSocketClient")
            end
        end
    elseif err and err ~= "timeout" then
        sendErrorMessage("Receive error: " .. tostring(err), "WebSocketClient")
        self:disconnect("Receive error: " .. tostring(err))
    end

    return messages
end

function WebSocketClient:send_ping()
    if not self.connected or not self.sock then return false end
    local frame = self:create_frame(9, "")

    -- Use pcall to prevent game freezes from blocking send operations
    local success, result = pcall(function()
        return self.sock:send(frame)
    end)

    if not success then
        sendWarnMessage("Ping send failed: " .. tostring(result), "WebSocketClient")
        return false
    end

    return result ~= nil
end

function WebSocketClient:send_pong(payload)
    if not self.connected or not self.sock then return false end
    local frame = self:create_frame(10, payload or "")

    -- Use pcall to prevent game freezes from blocking send operations
    local success, result = pcall(function()
        return self.sock:send(frame)
    end)

    if not success then
        sendWarnMessage("Pong send failed: " .. tostring(result), "WebSocketClient")
        return false
    end

    return result ~= nil
end

function WebSocketClient:update()
    -- Handle handshake completion
    if self.handshaking and self.sock then
        local data, err, partial = self.sock:receive("*a")

        -- Handle partial data
        if partial and #partial > 0 then
            data = partial
        end

        if data and #data > 0 then
            self.handshake_response = self.handshake_response .. data
            sendDebugMessage("Handshake data received: " .. #data .. " bytes, total: " .. #self.handshake_response, "WebSocketClient")
        elseif err and err ~= "timeout" then
            sendErrorMessage("Handshake receive error: " .. tostring(err), "WebSocketClient")
            self:disconnect("Handshake receive error: " .. tostring(err))
            return
        end

        -- Check if we have complete response
        local header_end = self.handshake_response:find("\r\n\r\n")
        if header_end then
            sendInfoMessage("Complete handshake response received", "WebSocketClient")

            -- Extract just the handshake response
            local handshake_only = self.handshake_response:sub(1, header_end + 3)
            sendDebugMessage("Server handshake response:\n" .. handshake_only:gsub("\r", "\\r"):gsub("\n", "\\n"), "WebSocketClient")
            local valid, err = self:parse_handshake_response(handshake_only)

            if valid then
                self.connected = true
                self.handshaking = false
                self.reconnect_attempts = 0
                self.last_ping = love.timer.getTime()
                sendInfoMessage("WebSocket handshake completed successfully", "WebSocketClient")

                -- Check if there's data after the handshake (Randy might have sent messages immediately)
                local extra_data = self.handshake_response:sub(header_end + 4)
                if #extra_data > 0 then
                    sendInfoMessage("Found " .. #extra_data .. " bytes after handshake - buffering for processing", "WebSocketClient")
                    self.receive_buffer = extra_data
                end
            else
                sendErrorMessage("Handshake validation failed: " .. err, "WebSocketClient")
                self:disconnect("Handshake validation failed: " .. err)
            end
        elseif love.timer.getTime() - self.handshake_start_time > self.Settings.CONNECTION_TIMEOUT then
            sendErrorMessage("Handshake timeout - received " .. #self.handshake_response .. " bytes", "WebSocketClient")
            if #self.handshake_response > 0 then
                sendDebugMessage("Partial response: " .. self.handshake_response:gsub("\r", "\\r"):gsub("\n", "\\n"), "WebSocketClient")
            end
            self:disconnect("Handshake timeout after " .. self.Settings.CONNECTION_TIMEOUT .. " seconds")
        end
        return
    end

    -- Handle reconnection (infinite if MAX_RECONNECT_ATTEMPTS is -1)
    if not self.connected and self.Settings.AUTO_RECONNECT and not self.connection_failed then
        local should_reconnect = false

        if self.Settings.MAX_RECONNECT_ATTEMPTS == -1 then
            -- Infinite reconnection
            should_reconnect = true
        elseif self.reconnect_attempts < self.Settings.MAX_RECONNECT_ATTEMPTS then
            -- Limited reconnection
            should_reconnect = true
        end

        if should_reconnect then
            local now = love.timer.getTime()
            if not self.last_reconnect_attempt or
               now - self.last_reconnect_attempt > self.Settings.RECONNECT_DELAY then
                self.last_reconnect_attempt = now
                self.reconnect_attempts = self.reconnect_attempts + 1

                if self.Settings.MAX_RECONNECT_ATTEMPTS == -1 then
                    sendInfoMessage("Reconnection attempt " .. self.reconnect_attempts .. " (infinite mode)", "WebSocketClient")
                else
                    sendInfoMessage("Reconnection attempt " .. self.reconnect_attempts .. "/" .. self.Settings.MAX_RECONNECT_ATTEMPTS, "WebSocketClient")
                end

                local success = self:connect()
                if not success and self.Settings.MAX_RECONNECT_ATTEMPTS ~= -1 and self.reconnect_attempts >= self.Settings.MAX_RECONNECT_ATTEMPTS then
                    sendWarnMessage("Max reconnection attempts reached - giving up", "WebSocketClient")
                    self.connection_failed = true
                end
            end
        end
    end

    -- Send periodic pings (deferred to avoid blocking)
    if self.connected then
        local now = love.timer.getTime()
        if now - self.last_ping > 30 then
            -- Defer ping sending to next frame
            local ws_client = self
            G.E_MANAGER:add_event(Event({
                trigger = "immediate",
                func = function()
                    ws_client:send_ping()
                    return true
                end
            }))
            self.last_ping = now
        end
    end
end

function WebSocketClient:is_connected()
    return self.connected and not self.handshaking
end

return WebSocketClient