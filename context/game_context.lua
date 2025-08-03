-- Game Context Builder
-- Handles basic game state information like money, ante, round, etc.

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
    
    -- Basic game info
    local basic = GameContext.get_basic_info()
    if basic.money then
        table.insert(parts, "Money: $" .. basic.money)
    end
    if basic.ante then
        table.insert(parts, "Ante: " .. basic.ante)
    end
    if basic.round then
        table.insert(parts, "Round: " .. basic.round)
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
    
    return table.concat(parts, "\n")
end

return GameContext