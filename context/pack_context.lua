-- Pack Context Builder
-- Handles pack opening states and provides context for different pack types

local CardUtils = SMODS.load_file("context/card_utils.lua")()
local PackContext = {}

-- Map pack states to pack type names
local PACK_STATE_NAMES = {
    [G.STATES.TAROT_PACK] = "Tarot Pack",
    [G.STATES.SPECTRAL_PACK] = "Spectral Pack", 
    [G.STATES.STANDARD_PACK] = "Standard Pack",
    [G.STATES.BUFFOON_PACK] = "Joker Pack",
    [G.STATES.PLANET_PACK] = "Planet Pack"
}

-- Check if currently in any pack opening state or have pack cards (mod fallback)
function PackContext.is_pack_state()
    return PACK_STATE_NAMES[G.STATE] ~= nil or (G.pack_cards and G.pack_cards.cards)
end

-- Get current pack type name
function PackContext.get_pack_type()
    local state_name = PACK_STATE_NAMES[G.STATE]
    if state_name then
        return state_name
    end
    
    -- Fallback: if we have pack cards but unknown state, return generic name
    if G.pack_cards and G.pack_cards.cards then
        return "Pack (Unknown Type)"
    end
    
    return nil
end

-- Get pack cards information
function PackContext.get_pack_cards_info()
    local info = {}
    
    if not G.pack_cards or not G.pack_cards.cards then
        return info
    end
    
    info.total_cards = #G.pack_cards.cards
    info.cards = {}
    
    for i, card in ipairs(G.pack_cards.cards) do
        local card_info = {
            index = i,
            name = card.config and card.config.center and card.config.center.name or "Unknown",
            type = card.ability and card.ability.set or "Unknown"
        }
        
        -- Add specific info based on card type
        if card.ability then
            if card.ability.set == "Joker" then
                card_info.rarity = card.config and card.config.center and card.config.center.rarity or 1
                card_info.effect = CardUtils.get_joker_effect(card.config.center.key)
            elseif card.ability.set == "Tarot" then
                card_info.effect = CardUtils.get_card_effect(card.config.center.key, 'Tarot', G.P_CENTERS, nil)
            elseif card.ability.set == "Planet" then
                card_info.effect = CardUtils.get_card_effect(card.config.center.key, 'Planet', G.P_CENTERS, nil)
            elseif card.ability.set == "Spectral" then
                card_info.effect = CardUtils.get_card_effect(card.config.center.key, 'Spectral', G.P_CENTERS, nil)
            end
        end
        
        table.insert(info.cards, card_info)
    end
    
    return info
end

-- Get pack selection info
function PackContext.get_pack_selection_info()
    local info = {}
    
    if G.GAME then
        info.choices_remaining = G.GAME.pack_choices or 0
        info.max_choices = G.GAME.pack_size or 0
    end
    
    return info
end

-- Build pack context string
function PackContext.build_context_string()
    if not PackContext.is_pack_state() then
        return ""
    end
    
    local parts = {}
    local pack_type = PackContext.get_pack_type()
    
    if pack_type then
        table.insert(parts, "Opening: " .. pack_type)
    end
    
    local selection_info = PackContext.get_pack_selection_info()
    if selection_info.choices_remaining and selection_info.choices_remaining > 0 then
        table.insert(parts, "Choices remaining: " .. selection_info.choices_remaining)
    end
    
    local pack_cards = PackContext.get_pack_cards_info()
    if pack_cards.total_cards and pack_cards.total_cards > 0 then
        table.insert(parts, "Cards available: " .. pack_cards.total_cards)
        table.insert(parts, "\nAvailable cards:")
        
        for _, card in ipairs(pack_cards.cards) do
            local card_text = "- " .. card.name
            if card.type and card.type ~= "Unknown" then
                card_text = card_text .. " (" .. card.type .. ")"
            end
            if card.rarity then
                card_text = card_text .. " [Rarity: " .. card.rarity .. "]"
            end
            if card.effect and card.effect ~= "" then
                card_text = card_text .. ": " .. card.effect
            end
            table.insert(parts, card_text)
        end
    end
    
    return table.concat(parts, "\n")
end

return PackContext