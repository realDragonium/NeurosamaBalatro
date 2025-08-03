-- Hand Context Builder
-- Handles hand and card information

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
                    if type(desc_template) == "table" then
                        local desc_text = table.concat(desc_template, " ")
                        -- Clean up formatting codes
                        desc_text = desc_text:gsub("{[^}]*}", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        enhancement_desc = (center.name or key) .. " (" .. desc_text .. ")"
                    else
                        local desc_text = tostring(desc_template):gsub("{[^}]*}", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        enhancement_desc = (center.name or key) .. " (" .. desc_text .. ")"
                    end
                end
            end
            
            table.insert(special_attrs, enhancement_desc)
        end
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
                    if type(desc_template) == "table" then
                        local desc_text = table.concat(desc_template, " ")
                        desc_text = desc_text:gsub("{[^}]*}", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        edition_desc = edition_type .. " (" .. desc_text .. ")"
                    else
                        local desc_text = tostring(desc_template):gsub("{[^}]*}", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                        edition_desc = edition_type .. " (" .. desc_text .. ")"
                    end
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
                if type(desc_template) == "table" then
                    local desc_text = table.concat(desc_template, " ")
                    desc_text = desc_text:gsub("{[^}]*}", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                    seal_desc = card.seal .. " Seal (" .. desc_text .. ")"
                else
                    local desc_text = tostring(desc_template):gsub("{[^}]*}", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                    seal_desc = card.seal .. " Seal (" .. desc_text .. ")"
                end
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

-- Get hand evaluation (if available)
function HandContext.get_hand_evaluation()
    local eval = {}
    
    -- Check if there are highlighted cards
    if G.hand and G.hand.highlighted and #G.hand.highlighted > 0 then
        -- Try to get hand evaluation - this might not always be available
        if G.FUNCS and G.FUNCS.get_poker_hand_info then
            local hand_info = G.FUNCS.get_poker_hand_info(G.hand.highlighted)
            if hand_info then
                eval.hand_type = hand_info.type or "Unknown"
                eval.level = hand_info.level or 1
                eval.base_chips = hand_info.chips or 0
                eval.base_mult = hand_info.mult or 0
                eval.scoring_cards = #G.hand.highlighted
            end
        else
            -- Fallback - just count selected cards
            eval.scoring_cards = #G.hand.highlighted
            eval.hand_type = "Unknown"
        end
    end
    
    return eval
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
        
        -- Hand evaluation for selected cards
        local eval = HandContext.get_hand_evaluation()
        if eval.hand_type then
            table.insert(parts, "Selected hand: " .. eval.hand_type)
            if eval.base_chips then
                table.insert(parts, "Base chips: " .. eval.base_chips .. ", Base mult: " .. eval.base_mult)
            end
        end
    else
        table.insert(parts, "Hand: No cards")
    end
    
    return table.concat(parts, "\n")
end

return HandContext