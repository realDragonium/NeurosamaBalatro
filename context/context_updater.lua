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
local ConsumablesContext = assert(SMODS.load_file("context/consumables_context.lua"))()
local PackContext = assert(SMODS.load_file("context/pack_context.lua"))()
local ScorePreview = assert(SMODS.load_file("context/score_preview.lua"))()

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

        -- Include jokers and consumables context so Neuro knows what it has
        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end

        local consumables_context = ConsumablesContext.build_context_string()
        if consumables_context and consumables_context ~= "" then
            table.insert(context_parts, consumables_context)
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

        -- Include jokers and consumables context in shop
        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end

        local consumables_context = ConsumablesContext.build_context_string()
        if consumables_context and consumables_context ~= "" then
            table.insert(context_parts, consumables_context)
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

        local consumables_context = ConsumablesContext.build_context_string()
        if consumables_context and consumables_context ~= "" then
            table.insert(context_parts, consumables_context)
        end

        local blind_context = BlindContext.build_context_string()
        if blind_context and blind_context ~= "" then
            table.insert(context_parts, blind_context)
        end

    elseif state == G.STATES.TAROT_PACK or 
           state == G.STATES.SPECTRAL_PACK or 
           state == G.STATES.STANDARD_PACK or 
           state == G.STATES.BUFFOON_PACK or 
           state == G.STATES.PLANET_PACK then
        -- Pack opening states
        local pack_context = PackContext.build_context_string()
        if pack_context and pack_context ~= "" then
            table.insert(context_parts, pack_context)
        end

        -- Include game context for pack states
        local game_context = GameContext.build_context_string()
        if game_context and game_context ~= "" then
            table.insert(context_parts, game_context)
        end

    elseif state == G.STATES.ROUND_EVAL then
        -- Round evaluation - show game context so Neuro knows earnings/score
        local game_context = GameContext.build_context_string()
        if game_context and game_context ~= "" then
            table.insert(context_parts, game_context)
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
        -- Only on full updates (queries): scoring every candidate play is too
        -- heavy for the update sent on each card click.
        local preview_ok, preview = pcall(ScorePreview.build_context_string)
        if preview_ok and preview ~= "" then
            table.insert(context_parts, preview)
        elseif not preview_ok then
            sendWarnMessage("Score preview failed: " .. tostring(preview), "ContextUpdater")
        end
    end

    if G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT then
        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end

        local consumables_context = ConsumablesContext.build_context_string()
        if consumables_context and consumables_context ~= "" then
            table.insert(context_parts, consumables_context)
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

    local pack_context = PackContext.build_context_string()
    if pack_context and pack_context ~= "" then
        table.insert(context_parts, pack_context)
    end

    if #context_parts > 0 then
        local context_message = table.concat(context_parts, "\n")
        api_handler:send_context(context_message, false)
    end
end

return ContextUpdater