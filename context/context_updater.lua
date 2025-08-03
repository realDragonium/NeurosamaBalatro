-- Context Updater
-- Sends targeted context updates based on state changes and discoverer patterns

local ContextUpdater = {}

-- Load context modules
local BlindContext = assert(SMODS.load_file("context/blind_context.lua"))()
local GameContext = assert(SMODS.load_file("context/game_context.lua"))()
local HandContext = assert(SMODS.load_file("context/hand_context.lua"))()
local JokersContext = assert(SMODS.load_file("context/jokers_context.lua"))()
local ShopContext = assert(SMODS.load_file("context/shop_context.lua"))()
local MenuContext = assert(SMODS.load_file("context/menu_context.lua"))()

-- Send specific context update based on what changed
function ContextUpdater.send_state_context_update(api_handler, state, previous_state)
    if not api_handler then return end

    local context_parts = {}

    -- State-specific context updates
    if state == G.STATES.BLIND_SELECT then
        -- Include game context for blind select
        local game_context = GameContext.build_context_string()
        if game_context and game_context ~= "" then
            table.insert(context_parts, game_context)
        end

        local blind_context = BlindContext.build_context_string()
        if blind_context and blind_context ~= "" then
            table.insert(context_parts, blind_context)
        end

    elseif state == G.STATES.SHOP then
        -- Include game context for shop
        local game_context = GameContext.build_context_string()
        if game_context and game_context ~= "" then
            table.insert(context_parts, game_context)
        end

        local shop_context = ShopContext.build_context_string()
        if shop_context and shop_context ~= "" then
            table.insert(context_parts, shop_context)
        end

        -- Include jokers context in shop
        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end

    elseif state == G.STATES.SELECTING_HAND then
        -- Include game context for gameplay
        local game_context = GameContext.build_context_string()
        if game_context and game_context ~= "" then
            table.insert(context_parts, game_context)
        end

        local hand_context = HandContext.build_context_string()
        if hand_context and hand_context ~= "" then
            table.insert(context_parts, hand_context)
        end

        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end

        local blind_context = BlindContext.build_context_string()
        if blind_context and blind_context ~= "" then
            table.insert(context_parts, blind_context)
        end

    elseif state == G.STATES.MENU or state == G.STATES.MAIN_MENU then
        -- Always indicate we're in the main menu
        table.insert(context_parts, "In Main Menu")

        local menu_context = MenuContext.build_context_string()
        if menu_context and menu_context ~= "" then
            table.insert(context_parts, menu_context)
        end

        -- Only include game context if we're in the Continue tab of the overlay
        if G.OVERLAY_MENU and G.SETTINGS and G.SETTINGS.current_setup == "Continue" then
            local game_context = GameContext.build_context_string()
            if game_context and game_context ~= "" then
                table.insert(context_parts, game_context)
            end
        end
    end

    if #context_parts > 0 then
        local context_message = table.concat(context_parts, "\n")
        api_handler:send_context(context_message, false)
    end
end


-- Send full context (for initial connections, queries, etc.)
function ContextUpdater.send_full_context_update(api_handler)
    if not api_handler then return end

    local context_parts = {}
    local state_name = api_handler:get_state_name(G.STATE)
    table.insert(context_parts, "Game State: " .. state_name)

    -- Add all relevant contexts
    local game_context = GameContext.build_context_string()
    if game_context and game_context ~= "" then
        table.insert(context_parts, game_context)
    end

    local blind_context = BlindContext.build_context_string()
    if blind_context and blind_context ~= "" then
        table.insert(context_parts, blind_context)
    end

    if G.STATE == G.STATES.SELECTING_HAND then
        local hand_context = HandContext.build_context_string()
        if hand_context and hand_context ~= "" then
            table.insert(context_parts, hand_context)
        end
    end

    if G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.SHOP then
        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end
    end

    local shop_context = ShopContext.build_context_string()
    if shop_context and shop_context ~= "" then
        table.insert(context_parts, shop_context)
    end

    local menu_context = MenuContext.build_context_string()
    if menu_context and menu_context ~= "" then
        table.insert(context_parts, menu_context)
    end

    if #context_parts > 0 then
        local context_message = table.concat(context_parts, "\n")
        api_handler:send_context(context_message, false)
    end
end

return ContextUpdater