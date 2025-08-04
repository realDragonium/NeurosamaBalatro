-- Context Builder
-- Orchestrates all context modules to build complete game context

local ContextBuilder = {}

-- Load all context modules
local BlindContext = assert(SMODS.load_file("context/blind_context.lua"))()
local GameContext = assert(SMODS.load_file("context/game_context.lua"))()
local HandContext = assert(SMODS.load_file("context/hand_context.lua"))()
local JokersContext = assert(SMODS.load_file("context/jokers_context.lua"))()
local ConsumablesContext = assert(SMODS.load_file("context/consumables_context.lua"))()
local ShopContext = assert(SMODS.load_file("context/shop_context.lua"))()
local MenuContext = assert(SMODS.load_file("context/menu_context.lua"))()
local PackContext = assert(SMODS.load_file("context/pack_context.lua"))()

-- Build complete context string for current game state
function ContextBuilder.build_context()
    local context_parts = {}

    -- Basic game state info
    local state_name = ContextBuilder.get_state_name(G.STATE)
    table.insert(context_parts, "Game State: " .. state_name)

    -- Add basic game context (money, ante, round, etc.)
    local game_context = GameContext.build_context_string()
    if game_context and game_context ~= "" then
        table.insert(context_parts, game_context)
    end

    -- Add blind context (available in multiple states)
    local blind_context = BlindContext.build_context_string()
    if blind_context and blind_context ~= "" then
        table.insert(context_parts, blind_context)
    end

    -- Add hand context (for gameplay states)
    if G.STATE == G.STATES.SELECTING_HAND then
        local hand_context = HandContext.build_context_string()
        if hand_context and hand_context ~= "" then
            table.insert(context_parts, hand_context)
        end
    end

    -- Add jokers context (for most states)
    if G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.SHOP then
        local jokers_context = JokersContext.build_context_string()
        if jokers_context and jokers_context ~= "" then
            table.insert(context_parts, jokers_context)
        end

        local consumables_context = ConsumablesContext.build_context_string()
        if consumables_context and consumables_context ~= "" then
            table.insert(context_parts, consumables_context)
        end
    end

    -- Add shop context (for shop state only)
    local shop_context = ShopContext.build_context_string()
    if shop_context and shop_context ~= "" then
        table.insert(context_parts, shop_context)
    end

    -- Add pack context (for pack opening states)
    local pack_context = PackContext.build_context_string()
    if pack_context and pack_context ~= "" then
        table.insert(context_parts, pack_context)
    end

    -- Add menu context (for menu states only)
    local menu_context = MenuContext.build_context_string()
    if menu_context and menu_context ~= "" then
        table.insert(context_parts, menu_context)
    end

    return table.concat(context_parts, "\n")
end

-- Helper to get human-readable state name
function ContextBuilder.get_state_name(state)
    if not G.STATES then return "UNKNOWN" end

    for name, state_value in pairs(G.STATES) do
        if state_value == state then
            return name
        end
    end
    return "UNKNOWN"
end


return ContextBuilder