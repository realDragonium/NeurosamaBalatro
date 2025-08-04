-- Game Context Builder
-- Handles basic game state information like money, ante, round, etc.

local CardUtils = SMODS.load_file("context/card_utils.lua")()
local GameContext = {}

-- Get basic game information
function GameContext.get_basic_info()
    local info = {}

    if G.GAME then
        info.money = G.GAME.dollars or 0
        info.ante = G.GAME.round_resets and G.GAME.round_resets.ante or 1
        info.round = G.GAME.round or 1
        info.current_score = G.GAME.chips or 0
    end

    return info
end

-- Get round-specific information
function GameContext.get_round_info()
    local info = {}

    if G.GAME and G.GAME.current_round then
        info.hands_left = G.GAME.current_round.hands_left or 0
        info.discards_left = G.GAME.current_round.discards_left or 0
        info.reroll_cost = G.GAME.current_round.reroll_cost or 5
    end

    return info
end

-- Get deck information
function GameContext.get_deck_info()
    local info = {}

    if G.deck then
        info.cards_in_deck = #G.deck.cards or 0
    end

    if G.GAME and G.GAME.selected_back then
        info.deck_name = G.GAME.selected_back.name or "Unknown Deck"
    end

    return info
end

-- Build basic game context string
function GameContext.build_context_string()
    local parts = {}
    local basic = nil

    -- Only show game context in gameplay states
    if G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT then
        -- Basic game info
        basic = GameContext.get_basic_info()
        if basic.money then
            table.insert(parts, "Money: $" .. basic.money)
        end
        if basic.ante then
            table.insert(parts, "Ante: " .. basic.ante)
        end
        if basic.round then
            table.insert(parts, "Round: " .. basic.round)
        end
    end

    -- Round info (for gameplay states)
    if G.STATE == G.STATES.SELECTING_HAND then
        local round_info = GameContext.get_round_info()
        if round_info.hands_left then
            table.insert(parts, "Hands left: " .. round_info.hands_left)
        end
        if round_info.discards_left then
            table.insert(parts, "Discards left: " .. round_info.discards_left)
        end
        -- Get basic info if not already retrieved
        if not basic then
            basic = GameContext.get_basic_info()
        end
        if basic.current_score then
            table.insert(parts, "Current score: " .. basic.current_score .. " chips")
        end
    end

    -- Shop-specific info
    if G.STATE == G.STATES.SHOP then
        local round_info = GameContext.get_round_info()
        if round_info.reroll_cost then
            table.insert(parts, "Reroll cost: $" .. round_info.reroll_cost)
        end
    end

    -- Current tags (show in all gameplay states)
    if G.STATE == G.STATES.SELECTING_HAND or G.STATE == G.STATES.SHOP or G.STATE == G.STATES.BLIND_SELECT then
        local current_tags = GameContext.get_current_tags()
        if #current_tags > 0 then
            table.insert(parts, "\nCurrent Tags:")
            for _, tag in ipairs(current_tags) do
                local tag_text = "- " .. tag.name
                if tag.effect then
                    tag_text = tag_text .. " (" .. tag.effect .. ")"
                end
                table.insert(parts, tag_text)
            end
        end
    end

    return table.concat(parts, "\n")
end

-- Get current tags information  
function GameContext.get_current_tags()
    return CardUtils.get_current_tags()
end


return GameContext