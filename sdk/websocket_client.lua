local WebSocketClient = {}
WebSocketClient.__index = WebSocketClient

-- Connection states for non-blocking state machine
local STATE = {
    DISCONNECTED = "disconnected",
    CONNECTING = "connecting",       -- TCP connect in progress
    SENDING_HANDSHAKE = "sending_handshake",
    AWAITING_HANDSHAKE = "awaiting_handshake",
    CONNECTED = "connected",
}

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
        outgoing_queue = {},
        receive_buffer = "",
        Settings = Settings,
        connection_failed = false,
        -- Non-blocking state machine
        state = STATE.DISCONNECTED,
        handshake_response = "",
        handshake_start_time = 0,
        connect_start_time = 0,
        last_reconnect_attempt = nil,
        -- Send buffer for partial sends
        send_buffer = "",
        send_offset = 0,
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

    local response_lower = response:lower()
    if not response_lower:match("upgrade: websocket") and not response_lower:match("upgrade:websocket") then
        return false, "Missing websocket upgrade"
    end
    if not response_lower:match("connection: upgrade") and not response_lower:match("connection:upgrade") then
        return false, "Missing connection upgrade"
    end

    return true, nil
end

-- Start a non-blocking connection attempt
function WebSocketClient:connect()
    if self.state ~= STATE.DISCONNECTED then
        return true -- Already connecting or connected
    end

    sendInfoMessage("Attempting to connect to " .. self.host .. ":" .. self.port, "WebSocketClient")

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

    -- Set to non-blocking BEFORE connect - this makes connect() return immediately
    self.sock:settimeout(0)
    self.connect_start_time = love.timer.getTime()

    local result, err = self.sock:connect(self.host, self.port)

    if result then
        -- Connected immediately (rare but possible for localhost)
        self.state = STATE.SENDING_HANDSHAKE
        self:_begin_handshake()
    elseif err == "timeout" or err == "Operation already in progress" then
        -- Connection in progress (expected for non-blocking)
        self.state = STATE.CONNECTING
        sendInfoMessage("Non-blocking connect initiated", "WebSocketClient")
    else
        sendErrorMessage("TCP connection failed: " .. tostring(err), "WebSocketClient")
        self.sock:close()
        self.sock = nil
        return false
    end

    return true
end

-- Begin the WebSocket handshake (called when TCP connect completes)
function WebSocketClient:_begin_handshake()
    local handshake, key = self:create_handshake()
    self.send_buffer = handshake
    self.send_offset = 0
    self.state = STATE.SENDING_HANDSHAKE
    self.handshake_response = ""
    self.handshake_start_time = love.timer.getTime()
end

function WebSocketClient:disconnect(reason)
    reason = reason or "Unknown reason"
    if self.state ~= STATE.DISCONNECTED then
        sendWarnMessage("Disconnecting: " .. reason, "WebSocketClient")
    end

    if self.sock then
        self.sock:close()
        self.sock = nil
    end
    self.connected = false
    self.state = STATE.DISCONNECTED
    self.receive_buffer = ""
    self.handshake_response = ""
    self.send_buffer = ""
    self.send_offset = 0
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

-- Queue a message for sending (non-blocking)
function WebSocketClient:send_message(message)
    if self.state ~= STATE.CONNECTED or not self.sock then
        return false
    end

    local frame = self:create_frame(1, message)
    table.insert(self.outgoing_queue, frame)
    return true
end

-- Flush queued outgoing messages (non-blocking, called from update)
function WebSocketClient:_flush_outgoing()
    if not self.sock or self.state ~= STATE.CONNECTED then return end

    -- If we have a partial send in progress, finish it first
    if #self.send_buffer > 0 then
        local sent, err, last_sent = self.sock:send(self.send_buffer, self.send_offset + 1)
        if sent then
            -- Fully sent
            self.send_buffer = ""
            self.send_offset = 0
        elseif err == "timeout" then
            -- Partially sent
            self.send_offset = last_sent or self.send_offset
            return -- Don't try more messages until this one finishes
        else
            sendErrorMessage("Send error: " .. tostring(err), "WebSocketClient")
            self:disconnect("Send error: " .. tostring(err))
            return
        end
    end

    -- Send queued messages
    while #self.outgoing_queue > 0 do
        local frame = self.outgoing_queue[1]
        local sent, err, last_sent = self.sock:send(frame)

        if sent then
            -- Fully sent, remove from queue
            table.remove(self.outgoing_queue, 1)
        elseif err == "timeout" then
            -- Partially sent - store remainder in send buffer
            local bytes_sent = last_sent or 0
            self.send_buffer = frame
            self.send_offset = bytes_sent
            table.remove(self.outgoing_queue, 1)
            return -- Continue next frame
        else
            sendErrorMessage("Send error: " .. tostring(err), "WebSocketClient")
            self:disconnect("Send error: " .. tostring(err))
            return
        end
    end
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
    if not self.sock or self.state ~= STATE.CONNECTED then
        return {}
    end

    local messages = {}
    local data, err, partial = self.sock:receive("*a")

    if partial and #partial > 0 then
        data = partial
    end

    if data and #data > 0 then
        self.receive_buffer = self.receive_buffer .. data

        while #self.receive_buffer > 0 do
            local frame, remaining = self:parse_frame(self.receive_buffer)
            if not frame then break end

            self.receive_buffer = remaining or ""

            if frame.opcode == 1 then
                table.insert(messages, frame.payload)
            elseif frame.opcode == 8 then
                sendInfoMessage("Received close frame", "WebSocketClient")
                self:disconnect("Received close frame from server")
                break
            elseif frame.opcode == 9 then
                -- Respond to ping with pong immediately (it's non-blocking now)
                self:send_pong(frame.payload)
            elseif frame.opcode == 10 then
                -- Pong received, nothing to do
            end
        end
    elseif err and err ~= "timeout" then
        sendErrorMessage("Receive error: " .. tostring(err), "WebSocketClient")
        self:disconnect("Receive error: " .. tostring(err))
    end

    return messages
end

function WebSocketClient:send_ping()
    if self.state ~= STATE.CONNECTED or not self.sock then return false end
    local frame = self:create_frame(9, "")
    table.insert(self.outgoing_queue, frame)
    return true
end

function WebSocketClient:send_pong(payload)
    if self.state ~= STATE.CONNECTED or not self.sock then return false end
    local frame = self:create_frame(10, payload or "")
    -- Insert pong at front of queue (high priority)
    table.insert(self.outgoing_queue, 1, frame)
    return true
end

-- Main update - non-blocking state machine
function WebSocketClient:update()
    local socket = socket or (package.loaded.socket) or (_G.socket)

    if self.state == STATE.CONNECTING then
        -- Check if TCP connect completed using socket.select
        local _, writable = socket.select(nil, {self.sock}, 0)
        if writable and #writable > 0 then
            -- Connected! Start handshake
            sendInfoMessage("TCP connection established", "WebSocketClient")
            self:_begin_handshake()
        elseif love.timer.getTime() - self.connect_start_time > self.Settings.CONNECTION_TIMEOUT then
            sendErrorMessage("Connection timeout", "WebSocketClient")
            self:disconnect("Connection timeout")
        end
        return
    end

    if self.state == STATE.SENDING_HANDSHAKE then
        -- Try to send handshake data (non-blocking)
        local sent, err, last_sent = self.sock:send(self.send_buffer, self.send_offset + 1)
        if sent then
            -- Handshake fully sent
            self.send_buffer = ""
            self.send_offset = 0
            self.state = STATE.AWAITING_HANDSHAKE
            sendInfoMessage("WebSocket handshake sent", "WebSocketClient")
        elseif err == "timeout" then
            -- Partially sent
            self.send_offset = last_sent or self.send_offset
        else
            sendErrorMessage("Handshake send error: " .. tostring(err), "WebSocketClient")
            self:disconnect("Handshake send error: " .. tostring(err))
        end
        return
    end

    if self.state == STATE.AWAITING_HANDSHAKE then
        local data, err, partial = self.sock:receive("*a")
        if partial and #partial > 0 then
            data = partial
        end

        if data and #data > 0 then
            self.handshake_response = self.handshake_response .. data
        elseif err and err ~= "timeout" then
            sendErrorMessage("Handshake receive error: " .. tostring(err), "WebSocketClient")
            self:disconnect("Handshake receive error: " .. tostring(err))
            return
        end

        -- Check if we have complete response
        local header_end = self.handshake_response:find("\r\n\r\n")
        if header_end then
            local handshake_only = self.handshake_response:sub(1, header_end + 3)
            local valid, parse_err = self:parse_handshake_response(handshake_only)

            if valid then
                self.connected = true
                self.state = STATE.CONNECTED
                self.reconnect_attempts = 0
                self.last_ping = love.timer.getTime()
                sendInfoMessage("WebSocket connected!", "WebSocketClient")

                -- Buffer any extra data after handshake
                local extra_data = self.handshake_response:sub(header_end + 4)
                if #extra_data > 0 then
                    self.receive_buffer = extra_data
                end
            else
                sendErrorMessage("Handshake validation failed: " .. parse_err, "WebSocketClient")
                self:disconnect("Handshake validation failed: " .. parse_err)
            end
        elseif love.timer.getTime() - self.handshake_start_time > self.Settings.CONNECTION_TIMEOUT then
            sendErrorMessage("Handshake timeout", "WebSocketClient")
            self:disconnect("Handshake timeout")
        end
        return
    end

    -- Handle reconnection
    if self.state == STATE.DISCONNECTED and self.Settings.AUTO_RECONNECT and not self.connection_failed then
        local should_reconnect = self.Settings.MAX_RECONNECT_ATTEMPTS == -1
            or self.reconnect_attempts < self.Settings.MAX_RECONNECT_ATTEMPTS

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
                    sendWarnMessage("Max reconnection attempts reached", "WebSocketClient")
                    self.connection_failed = true
                end
            end
        end
    end

    -- Connected state: flush outgoing messages and send periodic pings
    if self.state == STATE.CONNECTED then
        self:_flush_outgoing()

        local now = love.timer.getTime()
        if now - self.last_ping > 30 then
            self:send_ping()
            self.last_ping = now
        end
    end
end

function WebSocketClient:is_connected()
    return self.state == STATE.CONNECTED
end

return WebSocketClient
