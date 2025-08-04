-- Card Utilities
-- Shared utilities for processing card descriptions (Tags, Jokers, etc.) across context modules

local CardUtils = {}

-- Helper function to extract text from UI nodes
function CardUtils.extract_text_from_ui_nodes(ui_node)
    local text_parts = {}
    
    local function traverse_node(node, depth)
        if not node then return end
        depth = depth or 0
        
        -- Check if this node has text
        if node.config and node.config.text then
            if type(node.config.text) == "string" then
                table.insert(text_parts, node.config.text)
            elseif type(node.config.text) == "table" then
                for _, text_line in ipairs(node.config.text) do
                    if type(text_line) == "string" then
                        table.insert(text_parts, text_line)
                    end
                end
            end
        end
        
        -- Recursively check child nodes
        if node.nodes then
            for _, child in ipairs(node.nodes) do
                traverse_node(child, depth + 1)
            end
        end
        
        -- Handle the numbered sub-tables structure that tags use
        if type(node) == "table" and depth < 5 then
            for k, v in pairs(node) do
                if type(v) == "table" then
                    -- Check for numbered keys or common UI structure keys
                    if type(tonumber(k)) == "number" or k == "info" or k == "main" then
                        traverse_node(v, depth + 1)
                    end
                end
            end
        end
    end
    
    traverse_node(ui_node)
    
    if #text_parts == 0 then
        return ""
    end
    
    local result = table.concat(text_parts, " ")
    -- Clean up formatting tags and normalize whitespace
    result = result:gsub("{[^}]*}", "")
    result = result:gsub("%s+", " ")
    result = result:gsub("^%s+", ""):gsub("%s+$", "")
    
    return result
end

-- Get tag effect description using the game's UI generation system
-- Get blind effect using collection_loc_vars like the game does
function CardUtils.get_blind_effect(blind_key)
    if not blind_key or not G.P_BLINDS or not G.P_BLINDS[blind_key] then
        return ""
    end
    
    local blind_center = G.P_BLINDS[blind_key]
    if not blind_center then
        return ""
    end
    
    -- Use the same approach as generate_card_ui for blinds
    local coll_loc_vars = (blind_center.collection_loc_vars and type(blind_center.collection_loc_vars) == 'function' and blind_center:collection_loc_vars()) or {}
    local loc_vars = coll_loc_vars.vars or blind_center.vars
    
    -- Get description from localization
    if G.localization and G.localization.descriptions and G.localization.descriptions.Blind then
        local blind_desc = G.localization.descriptions.Blind[coll_loc_vars.key or blind_center.key]
        if blind_desc and blind_desc.text then
            local desc_text = ""
            if type(blind_desc.text) == "table" then
                desc_text = table.concat(blind_desc.text, " ")
            else
                desc_text = tostring(blind_desc.text)
            end
            
            -- Replace variables if available
            if loc_vars and type(loc_vars) == "table" then
                for i, v in ipairs(loc_vars) do
                    if type(v) == "number" then
                        desc_text = desc_text:gsub("#" .. i .. "#", tostring(v))
                    elseif type(v) == "string" then
                        desc_text = desc_text:gsub("#" .. i .. "#", v)
                    end
                end
            end
            
            -- Clean up formatting codes
            desc_text = desc_text:gsub("{[^}]*}", "")
            desc_text = desc_text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            
            return desc_text
        end
    end
    
    return ""
end

-- Get consumable effect using generate_card_ui
function CardUtils.get_consumable_effect(consumable)
    if not consumable or not consumable.config or not consumable.config.center then
        return ""
    end
    
    local center = consumable.config.center
    if not center or not generate_card_ui then
        return ""
    end
    
    -- Use generate_card_ui for consumables
    local ui_table = generate_card_ui(center, nil, nil, center.set, nil, false, nil, nil, consumable)
    if ui_table then
        local effect = CardUtils.extract_text_from_ui_nodes(ui_table)
        -- Clean up formatting codes
        effect = effect:gsub("{[^}]*}", "")
        effect = effect:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        return effect
    end
    
    return ""
end

function CardUtils.get_tag_effect(tag_key)
    if not tag_key or not G.P_TAGS or not G.P_TAGS[tag_key] or not generate_card_ui or not Tag then
        return ""
    end
    
    local temp_tag = Tag(tag_key)
    if not temp_tag then
        return ""
    end
    
    -- Get loc_vars using Tag:get_uibox_table like the game does
    local loc_vars = temp_tag:get_uibox_table(nil, true)  -- vars_only = true
    
    -- Generate UI using the game's function
    local ui_table = generate_card_ui(G.P_TAGS[tag_key], nil, loc_vars, 'Tag', nil, false, nil, nil, temp_tag)
    if not ui_table then
        return ""
    end
    
    local tag_effect = CardUtils.extract_text_from_ui_nodes(ui_table)
    if tag_effect == "" then
        return ""
    end
    
    -- Clean up formatting codes
    tag_effect = tag_effect:gsub("{[^}]*}", "")
    tag_effect = tag_effect:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    
    return tag_effect
end

-- Format tag effect with name and side explanations
function CardUtils.format_tag_display(tag_name, tag_effect)
    if tag_effect == "" then
        return tag_name
    end
    
    -- Clean up the effect text and format nicely
    local cleaned_effect = tag_effect:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- For tag descriptions, try to identify the core action vs contextual info
    -- The UI structure is: [Main Box] + [Side Explanation Boxes]
    local main_effect = cleaned_effect
    local side_explanations = {}
    
    -- Pattern matching for common tag structures
    -- Look for patterns like "[side explanation] [main action]"
    local context_pattern = "^(.+)%s+(Gives a free .+)$"
    local context_match, main_match = cleaned_effect:match(context_pattern)
    
    if context_match and main_match then
        main_effect = main_match
        -- Extract the item name from main_match (e.g., "Mega Celestial Pack" from "Gives a free Mega Celestial Pack")
        local item_name = main_match:match("Gives a free (.+)$")
        if item_name then
            table.insert(side_explanations, "- " .. item_name .. ": " .. context_match)
        end
    else
        -- Try other common patterns
        -- Pattern for "action (details)" where we want to keep it together
        if cleaned_effect:match("^[^%(]+%([^%)]+%)$") then
            -- Keep as-is for patterns like "Doubles your money (Max of $40)"
            main_effect = cleaned_effect
        end
    end
    
    -- Format: Tag Name (Main Effect) + Side explanations as bullet points
    local formatted_effect = tag_name .. " (" .. main_effect .. ")"
    if #side_explanations > 0 then
        formatted_effect = formatted_effect .. " " .. table.concat(side_explanations, " ")
    end
    
    return formatted_effect
end

-- Get current tags information (shared implementation)
function CardUtils.get_current_tags()
    local current_tags = {}
    
    if G.GAME and G.GAME.tags then
        for i, tag in ipairs(G.GAME.tags) do
            if tag then
                local tag_info = {
                    name = tag.name or "Unknown Tag"
                }
                
                -- Get tag key from multiple possible sources
                local tag_key = nil
                if tag.config and tag.config.type then
                    tag_key = tag.config.type
                elseif tag.ability and tag.ability.type then
                    tag_key = tag.ability.type
                elseif tag.config and tag.config.id then
                    tag_key = tag.config.id
                elseif tag.key then
                    tag_key = tag.key
                end
                
                if tag_key then
                    local tag_effect = CardUtils.get_tag_effect(tag_key)
                    if tag_effect ~= "" then
                        tag_info.effect = tag_effect
                    end
                end
                
                table.insert(current_tags, tag_info)
            end
        end
    end
    
    return current_tags
end

-- Get joker effect description using the game's UI generation system
function CardUtils.get_joker_effect(joker_key)
    if not joker_key or not G.P_CENTERS or not G.P_CENTERS[joker_key] or not generate_card_ui then
        return ""
    end
    
    local center = G.P_CENTERS[joker_key]
    if not center then
        return ""
    end
    
    -- Create a minimal fake joker card similar to how generate_card_ui does it
    local fake_ability = {}
    if type(center.config) == "table" then
        for k, v in pairs(center.config) do
            fake_ability[k] = v
        end
    end
    fake_ability.set = 'Joker'
    fake_ability.name = center.name
    fake_ability.x_mult = center.config and (center.config.Xmult or center.config.x_mult)
    
    local fake_joker = { 
        ability = fake_ability, 
        config = { center = center },
        bypass_lock = true
    }
    
    -- Get loc_vars using Card.generate_UIBox_ability_table
    local specific_vars = nil
    local success, result = pcall(Card.generate_UIBox_ability_table, fake_joker, true)
    if success and type(result) == "table" then
        specific_vars = result
    end
    
    if not specific_vars then
        return ""
    end
    
    -- Generate UI using the game's function
    local ui_table = generate_card_ui(center, nil, specific_vars, 'Joker', nil, false, nil, nil, fake_joker)
    if not ui_table then
        return ""
    end
    
    local joker_effect = CardUtils.extract_text_from_ui_nodes(ui_table)
    if joker_effect == "" then
        return ""
    end
    
    -- Clean up formatting codes
    joker_effect = joker_effect:gsub("{[^}]*}", "")
    joker_effect = joker_effect:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    
    return joker_effect
end

return CardUtils