-- Blind Context Builder
-- Handles building context information for blinds

local CardUtils = SMODS.load_file("context/card_utils.lua")()
local BlindContext = {}


-- Get current blind information
function BlindContext.get_current_blind()
    local blind_info = {}

    -- Current blind (when playing)
    if G.GAME and G.GAME.blind then
        blind_info.name = G.GAME.blind.name or "Unknown"
        blind_info.chips = G.GAME.blind.chips or 0
        blind_info.chips_text = G.GAME.blind.chips_text or number_format(blind_info.chips)
        blind_info.type = G.GAME.blind.config and G.GAME.blind.config.blind and G.GAME.blind.config.blind.key or "Unknown"

        -- Add boss blind effect if it's a boss blind
        if G.GAME.blind.config and G.GAME.blind.config.blind and G.GAME.blind.config.blind.boss then
            local blind_key = G.GAME.blind.config.blind.key
            blind_info.effect = CardUtils.get_blind_effect(blind_key)
        else
            blind_info.effect = "No special effect"
        end
    elseif G.STATE == G.STATES.BLIND_SELECT and G.GAME and G.GAME.blind_on_deck then
        -- When in blind select, show info about the selected blind
        local blind_choices = BlindContext.get_blind_choices()
        for _, choice in ipairs(blind_choices) do
            if choice.selected then
                blind_info.name = choice.name
                blind_info.chips = choice.chips
                blind_info.chips_text = choice.chips_text
                blind_info.type = choice.type
                blind_info.effect = choice.effect
                break
            end
        end
    end

    return blind_info
end

-- Get available blind choices (for blind select state)
function BlindContext.get_blind_choices()
    local choices = {}

    if G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices then
        -- Process blinds in the correct order: Small, Big, Boss
        local blind_order = {"Small", "Big", "Boss"}

        for _, blind_type in ipairs(blind_order) do
            local blind_config = G.GAME.round_resets.blind_choices[blind_type]
            if blind_config then
                -- Calculate chips properly since blind_config.chips might not be set
                local blind_ante = G.GAME.round_resets.blind_ante or G.GAME.round_resets.ante or 1
                local base_chips = get_blind_amount(blind_ante)

                local blind_mult = 1
                if blind_type == "Small" then
                    blind_mult = 1
                elseif blind_type == "Big" then
                    blind_mult = 1.5
                elseif blind_type == "Boss" then
                    blind_mult = 2
                end

                local ante_scaling = (G.GAME.starting_params and G.GAME.starting_params.ante_scaling) or 1
                local calculated_chips = math.floor(base_chips * blind_mult * ante_scaling)

                local choice = {
                    type = blind_type,
                    name = blind_config.name or blind_type,
                    chips = calculated_chips,
                    chips_text = number_format(calculated_chips)
                }

                -- Add boss blind effect
                if blind_type == "Boss" or blind_config.boss then
                    choice.is_boss = true
                    
                    -- For boss blinds, we need to determine which boss blind this ante
                    -- The game determines boss blinds based on ante - let's try to get it
                    local boss_blind_key = nil
                    
                    -- Try to get the boss blind from the game's boss blind selection logic
                    if G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante then
                        local ante = G.GAME.round_resets.ante
                        -- Try to find boss blind key by looking at G.P_BLINDS for boss blinds
                        if G.P_BLINDS then
                            for key, blind_data in pairs(G.P_BLINDS) do
                                if blind_data.boss and blind_data.boss.ante and blind_data.boss.ante == ante then
                                    boss_blind_key = key
                                    break
                                elseif blind_data.boss and not blind_data.boss.ante then
                                    -- Some boss blinds might not have ante restrictions
                                    boss_blind_key = key
                                end
                            end
                        end
                    end
                    
                    if boss_blind_key then
                        choice.effect = CardUtils.get_blind_effect(boss_blind_key)
                        -- Also update the name if we found a specific boss blind
                        if G.P_BLINDS[boss_blind_key] and G.P_BLINDS[boss_blind_key].name then
                            choice.name = G.P_BLINDS[boss_blind_key].name
                        end
                    else
                        choice.effect = "Boss blind effect"
                    end
                    
                    -- Use the actual boss blind name if available
                    if blind_config.name and blind_config.name ~= "Boss" then
                        choice.name = blind_config.name
                    end
                else
                    choice.effect = "No special effect"
                    choice.is_boss = false
                end

                -- Get skip reward (tag) with effect description
                if G.GAME.round_resets.blind_tags and G.GAME.round_resets.blind_tags[blind_type] then
                    local tag_key = G.GAME.round_resets.blind_tags[blind_type]
                    if G.P_TAGS and G.P_TAGS[tag_key] then
                        local tag_name = G.P_TAGS[tag_key].name or tag_key
                        local tag_effect = CardUtils.get_tag_effect(tag_key)

                        if tag_effect ~= "" then
                            choice.skip_reward = CardUtils.format_tag_display(tag_name, tag_effect)
                        else
                            choice.skip_reward = tag_name
                        end
                    end
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

-- Get current tags information
function BlindContext.get_current_tags()
    return CardUtils.get_current_tags()
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
                    choice_text = choice_text .. " [CURRENT]"
                end

                if choice.is_boss then
                    choice_text = choice_text .. " [BOSS: " .. choice.effect .. "]"
                end

                -- Add skip reward if available (boss blinds can't be skipped)
                if choice.skip_reward and not choice.is_boss then
                    choice_text = choice_text .. " [Skip reward: " .. choice.skip_reward .. "]"
                elseif choice.is_boss then
                    choice_text = choice_text .. " [Cannot skip]"
                end

                table.insert(context_parts, choice_text)
            end
        end
    end

    -- Current tags
    local current_tags = BlindContext.get_current_tags()
    if #current_tags > 0 then
        table.insert(context_parts, "\nCurrent Tags:")
        for _, tag in ipairs(current_tags) do
            local tag_text = "- " .. tag.name
            if tag.effect then
                tag_text = tag_text .. " (" .. tag.effect .. ")"
            end
            table.insert(context_parts, tag_text)
        end
    end

    return table.concat(context_parts, "\n")
end

return BlindContext