-- End Game Detector
-- Detects game loss and win overlays and provides appropriate actions

local EndgameDetector = {}

-- Check if there's currently a game over state active
function EndgameDetector.has_active_game_over()
    -- Check if we're in game over state (like balatrobot does)
    -- Don't wait for UI to be created, as state change is sufficient
    return G.STATE == G.STATES.GAME_OVER
end

-- Check if there's currently a win overlay active
function EndgameDetector.has_active_win_overlay()
    -- Check for the specific win overlay ID from create_UIBox_win
    if G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
        local overlay_id = G.OVERLAY_MENU.definition.config and G.OVERLAY_MENU.definition.config.id
        if overlay_id == 'you_win_UI' then
            return true
        end
    end
    
    return false
end

-- Get information about the current endgame state
function EndgameDetector.get_endgame_info()
    local info = nil
    
    if EndgameDetector.has_active_game_over() then
        info = {
            type = "game_over",
            name = "Game Over",
            state = "loss",
            dismissible = true,
            actions_available = {"restart_run", "go_to_menu"}
        }
        
        -- Extract basic game details from game state
        info.details = {
            final_ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or "Unknown",
            final_score = G.GAME and G.GAME.chips or 0,
            reason = "Game Over"
        }
        
    elseif EndgameDetector.has_active_win_overlay() then
        info = {
            type = "win_overlay", 
            name = "Victory",
            state = "win",
            dismissible = true,
            actions_available = {"continue_run", "restart_run", "go_to_menu"}
        }
        
        -- Try to extract win details from overlay
        if G.OVERLAY_MENU and G.OVERLAY_MENU.definition then
            info.details = EndgameDetector.extract_win_details(G.OVERLAY_MENU.definition)
        end
    end
    
    return info
end

-- Extract details from game over UI
function EndgameDetector.extract_game_over_details(definition)
    local details = {
        final_ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or "Unknown",
        final_score = G.GAME and G.GAME.chips or 0,
        reason = "Unknown"
    }
    
    -- Try to extract more specific loss reason from UI
    local function traverse_ui(node, depth)
        if not node or depth > 10 then return end
        
        if type(node) == "table" then
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    -- Look for defeat reasons
                    if text:match("[Dd]efeated") or text:match("[Ll]ost") then
                        details.reason = text
                    end
                elseif type(text) == "table" then
                    for _, text_line in ipairs(text) do
                        if type(text_line) == "string" and (text_line:match("[Dd]efeated") or text_line:match("[Ll]ost")) then
                            details.reason = text_line
                        end
                    end
                end
            end
            
            -- Traverse child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    traverse_ui(child, depth + 1)
                end
            end
            
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    traverse_ui(v, depth + 1)
                end
            end
        end
    end
    
    traverse_ui(definition, 0)
    return details
end

-- Extract details from win overlay
function EndgameDetector.extract_win_details(definition)
    local details = {
        final_ante = G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante or "Unknown",
        final_score = G.GAME and G.GAME.chips or 0,
        achievement = "Victory"
    }
    
    -- Try to extract win-specific details
    local function traverse_ui(node, depth)
        if not node or depth > 10 then return end
        
        if type(node) == "table" then
            if node.config and node.config.text then
                local text = node.config.text
                if type(text) == "string" then
                    if text:match("[Cc]ongratulations") or text:match("[Vv]ictory") then
                        details.achievement = text
                    end
                elseif type(text) == "table" then
                    for _, text_line in ipairs(text) do
                        if type(text_line) == "string" and 
                           (text_line:match("[Cc]ongratulations") or text_line:match("[Vv]ictory")) then
                            details.achievement = text_line
                        end
                    end
                end
            end
            
            -- Traverse child nodes
            if node.nodes then
                for _, child in ipairs(node.nodes) do
                    traverse_ui(child, depth + 1)
                end
            end
            
            for k, v in pairs(node) do
                if type(tonumber(k)) == "number" and type(v) == "table" then
                    traverse_ui(v, depth + 1)
                end
            end
        end
    end
    
    traverse_ui(definition, 0)
    return details
end

-- Build context string for endgame overlay
function EndgameDetector.build_endgame_context()
    local endgame_info = EndgameDetector.get_endgame_info()
    if not endgame_info then
        return ""
    end
    
    local context_parts = {}
    
    if endgame_info.state == "loss" then
        table.insert(context_parts, "💀 GAME OVER:")
        
        -- Add detailed game over information from G.GAME
        if G.GAME then
            -- Progression info
            local ante = G.GAME.round_resets and G.GAME.round_resets.ante or "Unknown"
            local round = G.GAME.round or "Unknown"
            table.insert(context_parts, "Furthest Ante: " .. ante)
            table.insert(context_parts, "Furthest Round: " .. round)
            
            -- Defeated by information
            if G.GAME.blind and G.GAME.blind.config and G.GAME.blind.config.blind then
                local blind_name = G.GAME.blind.config.blind.name or "Unknown Blind"
                table.insert(context_parts, "Defeated By: " .. blind_name)
            end
            
            -- Score statistics from round_scores if available
            if G.GAME.round_scores then
                if G.GAME.round_scores.hand and G.GAME.round_scores.hand.amt then
                    table.insert(context_parts, "Best Hand Score: " .. G.GAME.round_scores.hand.amt)
                end
                if G.GAME.round_scores.cards_played and G.GAME.round_scores.cards_played.amt then
                    table.insert(context_parts, "Cards Played: " .. G.GAME.round_scores.cards_played.amt)
                end
                if G.GAME.round_scores.cards_discarded and G.GAME.round_scores.cards_discarded.amt then
                    table.insert(context_parts, "Cards Discarded: " .. G.GAME.round_scores.cards_discarded.amt)
                end
                if G.GAME.round_scores.cards_purchased and G.GAME.round_scores.cards_purchased.amt then
                    table.insert(context_parts, "Cards Purchased: " .. G.GAME.round_scores.cards_purchased.amt)
                end
                if G.GAME.round_scores.times_rerolled and G.GAME.round_scores.times_rerolled.amt then
                    table.insert(context_parts, "Times Rerolled: " .. G.GAME.round_scores.times_rerolled.amt)
                end
                if G.GAME.round_scores.new_collection and G.GAME.round_scores.new_collection.amt then
                    table.insert(context_parts, "New Discoveries: " .. G.GAME.round_scores.new_collection.amt)
                end
            end
            
            -- Seed information
            if G.GAME.pseudorandom and G.GAME.pseudorandom.seed then
                table.insert(context_parts, "Seed: " .. G.GAME.pseudorandom.seed)
            end
        end
        
    elseif endgame_info.state == "win" then
        table.insert(context_parts, "🎉 YOU WIN!")
        
        -- Add detailed win information matching the win screen
        if G.GAME then
            -- Progression info
            local ante = G.GAME.round_resets and G.GAME.round_resets.ante or "Unknown"
            local round = G.GAME.round or "Unknown"
            table.insert(context_parts, "Furthest Ante: " .. ante)
            table.insert(context_parts, "Furthest Round: " .. round)
            
            -- Score statistics from round_scores (same as win screen)
            if G.GAME.round_scores then
                if G.GAME.round_scores.hand and G.GAME.round_scores.hand.amt then
                    table.insert(context_parts, "Best Hand Score: " .. G.GAME.round_scores.hand.amt)
                end
                if G.GAME.round_scores.cards_played and G.GAME.round_scores.cards_played.amt then
                    table.insert(context_parts, "Cards Played: " .. G.GAME.round_scores.cards_played.amt)
                end
                if G.GAME.round_scores.cards_discarded and G.GAME.round_scores.cards_discarded.amt then
                    table.insert(context_parts, "Cards Discarded: " .. G.GAME.round_scores.cards_discarded.amt)
                end
                if G.GAME.round_scores.cards_purchased and G.GAME.round_scores.cards_purchased.amt then
                    table.insert(context_parts, "Cards Purchased: " .. G.GAME.round_scores.cards_purchased.amt)
                end
                if G.GAME.round_scores.times_rerolled and G.GAME.round_scores.times_rerolled.amt then
                    table.insert(context_parts, "Times Rerolled: " .. G.GAME.round_scores.times_rerolled.amt)
                end
                if G.GAME.round_scores.new_collection and G.GAME.round_scores.new_collection.amt then
                    table.insert(context_parts, "New Discoveries: " .. G.GAME.round_scores.new_collection.amt)
                end
            end
            
            -- Seed information
            if G.GAME.pseudorandom and G.GAME.pseudorandom.seed then
                table.insert(context_parts, "Seed: " .. G.GAME.pseudorandom.seed)
            end
        end
        
        if endgame_info.details and endgame_info.details.achievement ~= "Victory" then
            table.insert(context_parts, "Achievement: " .. endgame_info.details.achievement)
        end
    end
    
    return table.concat(context_parts, "\n")
end

return EndgameDetector