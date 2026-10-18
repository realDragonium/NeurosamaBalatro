-- Screen elements for Aurora's drawings
-- Reports where cards, jokers, consumables, shop items, HUD counters and buttons
-- sit in the game window, so she can point at one by number. Positions are
-- window client pixels; Brain maps them onto the image of the shared window.

local ScreenElements = {}

local CHECK_SECONDS = 0.5
-- Cards and buttons sit still at their target transform; rounding absorbs
-- sub-pixel jitter so an unchanged screen is not re-sent.
local ROUND_PX = 4

local state = {
    last_check = 0,
    last_sent = nil,
    was_connected = false,
    hwnd = nil,
    hwnd_checked = false,
}

local BUTTON_NAMES = {
    play_cards_from_highlighted = "Play hand",
    discard_cards_from_highlighted = "Discard",
    run_info = "Run info",
    options = "Options",
    toggle_shop = "Next round",
    reroll_shop = "Reroll",
    select_blind = "Select blind",
    skip_blind = "Skip blind",
    sort_hand_value = "Sort by rank",
    sort_hand_suit = "Sort by suit",
    skip_booster = "Skip pack",
    cash_out = "Cash out",
    buy_from_shop = "Buy",
    use_card = "Use",
    sell_card = "Sell",
}

local HUD_COUNTERS = {
    { id = "hand_UI_count", name = function() return "Hands " .. tostring(G.GAME.current_round.hands_left) end },
    { id = "discard_UI_count", name = function() return "Discards " .. tostring(G.GAME.current_round.discards_left) end },
    { id = "dollar_text_UI", name = function() return "Money $" .. tostring(G.GAME.dollars) end },
    { id = "ante_UI_count", name = function() return "Ante " .. tostring(G.GAME.round_resets.ante) end },
    { id = "round_UI_count", name = function() return "Round " .. tostring(G.GAME.round) end },
    { id = "chip_UI_count", name = function() return "Round score " .. tostring(G.GAME.chips) end },
    { id = "hand_chips", name = function() return "Chips" end },
    { id = "hand_mult", name = function() return "Mult" end },
}

local function window_handle()
    if state.hwnd_checked then return state.hwnd end
    state.hwnd_checked = true
    local ok, result = pcall(function()
        local ffi = require("ffi")
        pcall(ffi.cdef, "void* FindWindowA(const char* cls, const char* title);")
        local hwnd = ffi.load("user32").FindWindowA("SDL_app", love.window.getTitle())
        if hwnd == nil then return nil end
        return tonumber(ffi.cast("intptr_t", hwnd))
    end)
    state.hwnd = ok and result or nil
    return state.hwnd
end

local function to_pixels(t)
    local scale = G.TILESIZE * G.TILESCALE
    return (t.x + G.ROOM.T.x) * scale, (t.y + G.ROOM.T.y) * scale, t.w * scale, t.h * scale
end

local function rounded(v)
    return math.floor(v / ROUND_PX + 0.5) * ROUND_PX
end

local function add(list, role, name, node, width, height)
    if not node or not node.T then return end
    local x, y, w, h = to_pixels(node.T)
    if w < 4 or h < 4 or x + w <= 0 or y + h <= 0 or x >= width or y >= height then return end
    table.insert(list, {
        role = role,
        name = string.sub(name, 1, 120),
        x = rounded(x), y = rounded(y), w = rounded(w), h = rounded(h),
    })
end

local function card_name(card)
    if card.facing == "back" then return "face-down card" end
    local name
    local set = card.ability and card.ability.set
    if set == "Default" or set == "Enhanced" then
        name = card.base and card.base.name or "card"
    else
        name = card.ability and card.ability.name or "card"
    end
    if card.highlighted then name = name .. " (selected)" end
    return name
end

local function add_area(list, area, role, width, height, priced)
    if not area or not area.cards then return end
    for _, card in ipairs(area.cards) do
        local name = card_name(card)
        if priced and card.cost then name = name .. " $" .. tostring(card.cost) end
        add(list, role, name, card, width, height)
    end
end

local function node_text(node, parts, depth)
    if not node or depth > 6 then return end
    local config = node.config or {}
    if type(config.text) == "string" and config.text ~= "" then
        table.insert(parts, config.text)
    end
    local object = config.object
    if object and object.strings and object.strings[1] and object.strings[1].string then
        table.insert(parts, tostring(object.strings[1].string))
    end
    for _, child in pairs(node.children or {}) do
        node_text(child, parts, depth + 1)
    end
end

local function emboss_box(node)
    local box = node
    for _ = 1, 4 do
        if not box.parent or not box.parent.config then break end
        box = box.parent
        if box.config.emboss then return box end
    end
    return node
end

local function add_buttons(list, node, width, height, seen, depth)
    if not node or depth > 40 then return end
    if node.states and node.states.visible == false then return end
    local config = node.config or {}
    if config.button and not node.under_overlay and not node.disable_button then
        local parts = {}
        node_text(node, parts, 0)
        local text = table.concat(parts, " "):gsub("%s+", " ")
        local name = BUTTON_NAMES[config.button] or (text ~= "" and text) or config.button
        local key = name .. tostring(node)
        if not seen[key] then
            seen[key] = true
            add(list, "button", name, node, width, height)
        end
    end
    for _, child in pairs(node.children or {}) do
        add_buttons(list, child, width, height, seen, depth + 1)
    end
    local object = config.object
    if object and object.UIRoot then
        add_buttons(list, object.UIRoot, width, height, seen, depth + 1)
    end
end

function ScreenElements.collect()
    if not G or not G.ROOM or not G.TILESCALE then return nil end
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()
    local list = {}

    if G.HUD and G.GAME then
        for _, counter in ipairs(HUD_COUNTERS) do
            local node = G.HUD:get_UIE_by_ID(counter.id)
            if node then
                local ok, name = pcall(counter.name)
                add(list, "counter", ok and name or counter.id, emboss_box(node), width, height)
            end
        end
    end

    local seen = {}
    for _, box in ipairs(G.I and G.I.UIBOX or {}) do
        if box.states and box.states.visible ~= false and box.UIRoot then
            add_buttons(list, box.UIRoot, width, height, seen, 0)
        end
    end

    add_area(list, G.jokers, "joker", width, height, false)
    add_area(list, G.consumeables, "consumable", width, height, false)
    add_area(list, G.shop_jokers, "shop item", width, height, true)
    add_area(list, G.shop_vouchers, "voucher", width, height, true)
    add_area(list, G.shop_booster, "pack", width, height, true)
    add_area(list, G.pack_cards, "pack card", width, height, false)
    add_area(list, G.play, "played card", width, height, false)
    add_area(list, G.hand, "card", width, height, false)
    if G.deck and G.deck.cards and #G.deck.cards > 0 then
        add(list, "deck", "Deck " .. tostring(#G.deck.cards), G.deck, width, height)
    end

    return {
        hwnd = window_handle(),
        width = width,
        height = height,
        elements = list,
    }
end

-- Called every frame; checks twice a second and sends only what changed.
function ScreenElements.update(api_handler, connected)
    if not connected then
        state.was_connected = false
        return
    end
    if not state.was_connected then
        state.was_connected = true
        state.last_sent = nil
    end
    local now = love.timer.getTime()
    if now - state.last_check < CHECK_SECONDS then return end
    state.last_check = now

    local ok, snapshot = pcall(ScreenElements.collect)
    if not ok then
        sendWarnMessage("screen elements failed: " .. tostring(snapshot), "ScreenElements")
        return
    end
    if not snapshot then return end
    local parts = { tostring(snapshot.hwnd), snapshot.width, snapshot.height }
    for _, e in ipairs(snapshot.elements) do
        table.insert(parts, table.concat({ e.role, e.name, e.x, e.y, e.w, e.h }, "|"))
    end
    local signature = table.concat(parts, ";")
    if signature == state.last_sent then return end
    state.last_sent = signature
    api_handler:send_message({ command = "aurora/screen_elements", data = snapshot })
end

return ScreenElements
