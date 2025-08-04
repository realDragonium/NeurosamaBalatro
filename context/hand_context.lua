-- Hand Context Builder
-- Handles hand and card information

local CardUtils = SMODS.load_file("context/card_utils.lua")()
local HandContext = {}

-- Build card description string
function HandContext.build_card_string(card, index)
    if not card then return nil end

    local rank = "Unknown"
    local suit = "Unknown"
    local selected = card.highlighted or false

    -- Get rank and suit
    if card.base then
        rank = card.base.value or rank
        suit = card.base.suit or suit
    end

    -- Convert rank/suit to readable names
    if rank and G.localization and G.localization.misc and G.localization.misc.ranks then
        rank = G.localization.misc.ranks[rank] or rank
    end
    if suit and G.localization and G.localization.misc and G.localization.misc.suits_plural then
        suit = G.localization.misc.suits_plural[suit] or suit
    end

    local desc = rank .. " of " .. suit
    if selected then
        desc = desc .. " [SELECTED]"
    end

    -- Check for special attributes
    local special_attrs = {}

    -- Check for enhancements
    if card.config and card.config.center and card.config.center.key then
        local center = card.config.center
        local key = center.key
        if key ~= "c_base" then -- Skip base cards
            local enhancement_desc = center.name or key

            -- Try to get dynamic description from localization
            if G.localization and G.localization.descriptions and G.localization.descriptions[center.set] and G.localization.descriptions[center.set][key] then
                local desc_template = G.localization.descriptions[center.set][key].text
                if desc_template then
                    local desc_text = CardUtils.clean_text(desc_template)
                    enhancement_desc = (center.name or key) .. " (" .. desc_text .. ")"
                end
            end

            table.insert(special_attrs, enhancement_desc)
        end
    end

    -- Check for bonus effects (chips, mult, etc.)
    local bonus_effects = {}
    if card.ability then
        -- Check for bonus chips
        if card.ability.bonus and card.ability.bonus > 0 then
            table.insert(bonus_effects, "+" .. card.ability.bonus .. " Chips")
        end
        
        -- Check for bonus mult
        if card.ability.mult and card.ability.mult > 0 then
            table.insert(bonus_effects, "+" .. card.ability.mult .. " Mult")
        end
        
        -- Check for x_mult
        if card.ability.x_mult and card.ability.x_mult > 1 then
            table.insert(bonus_effects, "X" .. card.ability.x_mult .. " Mult")
        end
        
        -- Check for h_mult (hand mult)
        if card.ability.h_mult and card.ability.h_mult > 0 then
            table.insert(bonus_effects, "+" .. card.ability.h_mult .. " Hand Mult")
        end
        
        -- Check for h_x_mult (hand x mult)
        if card.ability.h_x_mult and card.ability.h_x_mult > 1 then
            table.insert(bonus_effects, "X" .. card.ability.h_x_mult .. " Hand Mult")
        end
        
        -- Check for p_dollars (passive money generation)
        if card.ability.p_dollars and card.ability.p_dollars > 0 then
            table.insert(bonus_effects, "+$" .. card.ability.p_dollars .. " per round")
        end
        
        -- Check for t_chips and t_mult (triggered effects)
        if card.ability.t_chips and card.ability.t_chips > 0 then
            table.insert(bonus_effects, "+" .. card.ability.t_chips .. " Chips when triggered")
        end
        if card.ability.t_mult and card.ability.t_mult > 0 then
            table.insert(bonus_effects, "+" .. card.ability.t_mult .. " Mult when triggered")
        end
    end
    
    -- Add bonus effects to special attributes
    if #bonus_effects > 0 then
        table.insert(special_attrs, "Bonus (" .. table.concat(bonus_effects, ", ") .. ")")
    end

    -- Check for editions
    if card.edition then
        for edition_type, _ in pairs(card.edition) do
            local edition_key = "e_" .. edition_type
            local edition_desc = edition_type

            -- Try to get description from localization
            if G.localization and G.localization.descriptions and G.localization.descriptions.Edition and G.localization.descriptions.Edition[edition_key] then
                local desc_template = G.localization.descriptions.Edition[edition_key].text
                if desc_template then
                    local desc_text = CardUtils.clean_text(desc_template)
                    edition_desc = edition_type .. " (" .. desc_text .. ")"
                end
            elseif G.P_CENTERS and G.P_CENTERS[edition_key] and G.P_CENTERS[edition_key].name then
                edition_desc = G.P_CENTERS[edition_key].name
            end

            table.insert(special_attrs, edition_desc)
        end
    end

    -- Check for seals
    if card.seal then
        local seal_key = string.lower(card.seal) .. "_seal"
        local seal_desc = card.seal .. " Seal"

        -- Try to get description from localization
        if G.localization and G.localization.descriptions and G.localization.descriptions.Other and G.localization.descriptions.Other[seal_key] then
            local desc_template = G.localization.descriptions.Other[seal_key].text
            if desc_template then
                local desc_text = CardUtils.clean_text(desc_template)
                seal_desc = card.seal .. " Seal (" .. desc_text .. ")"
            end
        elseif G.P_SEALS and G.P_SEALS[seal_key] and G.P_SEALS[seal_key].name then
            seal_desc = G.P_SEALS[seal_key].name
        end

        table.insert(special_attrs, seal_desc)
    end

    -- Check for debuffed status
    if card.debuff then
        table.insert(special_attrs, "DEBUFFED")
    end

    -- Add special attributes to description
    if #special_attrs > 0 then
        desc = desc .. " [" .. table.concat(special_attrs, ", ") .. "]"
    end

    return "  " .. index .. ". " .. desc
end


-- Build hand context string
function HandContext.build_context_string()
    local parts = {}

    -- Hand size and basic info
    if G.hand and G.hand.cards and #G.hand.cards > 0 then
        table.insert(parts, "Hand: " .. #G.hand.cards .. " cards")

        -- List cards with selections
        table.insert(parts, "Cards:")
        for i, card in ipairs(G.hand.cards) do
            local card_desc = HandContext.build_card_string(card, i)
            if card_desc then
                table.insert(parts, card_desc)
            end
        end

    else
        table.insert(parts, "Hand: No cards")
    end

    return table.concat(parts, "\n")
end

return HandContext