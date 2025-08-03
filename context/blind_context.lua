-- Blind Context Builder
-- Handles building context information for blinds

local BlindContext = {}

-- Get current blind information
function BlindContext.get_current_blind()
    local blind_info = {}
    
    -- Current blind (when playing)
    if G.GAME and G.GAME.blind then
        blind_info.name = G.GAME.blind.name or "Unknown"
        blind_info.chips = G.GAME.blind.chips or 0
        blind_info.chips_text = G.GAME.blind.chips_text or tostring(blind_info.chips)
        blind_info.type = G.GAME.blind.config and G.GAME.blind.config.blind and G.GAME.blind.config.blind.key or "Unknown"
        
        -- Add boss blind effect if it's a boss blind
        if G.GAME.blind.config and G.GAME.blind.config.blind and G.GAME.blind.config.blind.boss then
            blind_info.effect = G.GAME.blind.config.blind.name or "Boss effect"
        else
            blind_info.effect = "No special effect"
        end
    end
    
    return blind_info
end

-- Get available blind choices (for blind select state)
function BlindContext.get_blind_choices()
    local choices = {}
    
    if G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices then
        for blind_type, blind_config in pairs(G.GAME.round_resets.blind_choices) do
            if blind_config then
                local choice = {
                    type = blind_type,
                    name = blind_config.name or blind_type,
                    chips = blind_config.chips or 0,
                    chips_text = blind_config.chips_text or tostring(blind_config.chips or 0)
                }
                
                -- Add boss blind effect
                if blind_config.boss then
                    choice.effect = blind_config.name or "Boss effect"
                    choice.is_boss = true
                else
                    choice.effect = "No special effect"
                    choice.is_boss = false
                end
                
                -- Check if this is the currently selected blind
                if G.GAME.blind_on_deck and string.lower(G.GAME.blind_on_deck) == string.lower(blind_type) then
                    choice.selected = true
                else
                    choice.selected = false
                end
                
                table.insert(choices, choice)
            end
        end
    end
    
    return choices
end

-- Build blind context string for current state
function BlindContext.build_context_string()
    local context_parts = {}
    
    -- Current blind info
    local current_blind = BlindContext.get_current_blind()
    if current_blind.name then
        table.insert(context_parts, "Current Blind: " .. current_blind.name)
        table.insert(context_parts, "Required Chips: " .. current_blind.chips_text)
        if current_blind.effect ~= "No special effect" then
            table.insert(context_parts, "Effect: " .. current_blind.effect)
        end
    end
    
    -- Blind choices (for blind select)
    if G.STATE == G.STATES.BLIND_SELECT then
        local choices = BlindContext.get_blind_choices()
        if #choices > 0 then
            table.insert(context_parts, "\nAvailable Blinds:")
            for _, choice in ipairs(choices) do
                local choice_text = "- " .. choice.name .. " (" .. choice.chips_text .. " chips)"
                if choice.selected then
                    choice_text = choice_text .. " [SELECTED]"
                end
                if choice.is_boss then
                    choice_text = choice_text .. " [BOSS: " .. choice.effect .. "]"
                end
                table.insert(context_parts, choice_text)
            end
        end
    end
    
    return table.concat(context_parts, "\n")
end

return BlindContext