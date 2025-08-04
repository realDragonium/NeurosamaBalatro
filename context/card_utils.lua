-- Card Utilities
-- Shared utilities for processing card descriptions (Tags, Jokers, etc.) across context modules

local CardUtils = {}

-- Centralized text cleaning function for all UI text processing
function CardUtils.clean_text(text)
    if not text or text == "" then
        return ""
    end

    -- Convert to string if it's a table (join with spaces)
    if type(text) == "table" then
        text = table.concat(text, " ")
    else
        text = tostring(text)
    end

    -- Remove formatting codes like {C:red}, {X:mult}, etc.
    text = text:gsub("{[^}]*}", "")

    -- Normalize whitespace - collapse multiple spaces into single spaces
    text = text:gsub("%s+", " ")

    -- Trim leading and trailing whitespace
    text = text:gsub("^%s+", ""):gsub("%s+$", "")

    return text
end

-- Helper function to extract text from UI nodes with better formatting
function CardUtils.extract_text_from_ui_nodes(ui_node)
    local text_parts = {}
    local structure_info = {}  -- Track which parts are headers vs descriptions

    local function traverse_node(node, depth, parent_type)
        if not node then return end
        depth = depth or 0
        parent_type = parent_type or "unknown"

        -- Check if this node has text
        if node.config and node.config.text then
            local text_content = nil
            if type(node.config.text) == "string" then
                text_content = node.config.text
            elseif type(node.config.text) == "table" then
                text_content = table.concat(node.config.text, " ")
            end

            if text_content and text_content ~= "" then
                -- Clean formatting tags first
                text_content = CardUtils.clean_text(text_content)

                if text_content ~= "" then
                    -- Try to identify the type of content based on node structure
                    local content_type = "description"
                    if node.config.id and (node.config.id == "name" or string.find(node.config.id, "name")) then
                        content_type = "name"
                    elseif depth == 0 or (parent_type == "main" and depth <= 2) then
                        content_type = "header"
                    elseif node.config.colour and node.config.colour[4] and node.config.colour[4] < 1 then
                        content_type = "subtitle"  -- Often used for effect descriptions
                    end

                    table.insert(text_parts, {
                        text = text_content,
                        type = content_type,
                        depth = depth
                    })
                end
            end
        end

        -- Recursively check child nodes
        if node.nodes then
            for _, child in ipairs(node.nodes) do
                traverse_node(child, depth + 1, parent_type)
            end
        end

        -- Handle the numbered sub-tables structure that tags use
        if type(node) == "table" and depth < 5 then
            for k, v in pairs(node) do
                if type(v) == "table" then
                    -- Check for numbered keys or common UI structure keys
                    local node_type = parent_type
                    if k == "info" or k == "main" then
                        node_type = k
                    elseif type(tonumber(k)) == "number" then
                        node_type = "indexed"
                    end

                    if type(tonumber(k)) == "number" or k == "info" or k == "main" then
                        traverse_node(v, depth + 1, node_type)
                    end
                end
            end
        end
    end

    traverse_node(ui_node)

    if #text_parts == 0 then
        return ""
    end

    -- Smart formatting based on content types
    local formatted_parts = {}
    local current_name = nil
    local descriptions = {}

    for i, part in ipairs(text_parts) do
        if part.type == "name" or part.type == "header" then
            -- This is likely the main name/title
            if not current_name then
                current_name = part.text
            end
        else
            -- This is description content
            table.insert(descriptions, part.text)
        end
    end

    -- Build final result
    local result = ""
    if current_name then
        result = current_name
        if #descriptions > 0 then
            -- Join descriptions without adding periods - let the original text formatting determine punctuation
            local desc_text = CardUtils.clean_text(table.concat(descriptions, " "))
            if desc_text ~= "" then
                result = result .. " (" .. desc_text .. ")"
            end
        end
    else
        -- No clear name found, just join all parts
        local all_text = {}
        for _, part in ipairs(text_parts) do
            table.insert(all_text, part.text)
        end
        result = table.concat(all_text, " ")
        result = result:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    end

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
            desc_text = CardUtils.clean_text(desc_text)

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
        effect = CardUtils.clean_text(effect)
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
    tag_effect = CardUtils.clean_text(tag_effect)

    return tag_effect
end

-- Format tag effect with name and side explanations
function CardUtils.format_tag_display(tag_name, tag_effect)
    if tag_effect == "" then
        return tag_name
    end

    -- Clean up the effect text and format nicely
    local cleaned_effect = CardUtils.clean_text(tag_effect)

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
    if not joker_key or not G.P_CENTERS or not G.P_CENTERS[joker_key] then
        return ""
    end

    local center = G.P_CENTERS[joker_key]
    if not center then
        return ""
    end

    -- Use generate_card_ui like the game does for detailed tooltips
    if not generate_card_ui then
        return ""
    end

    -- Create the full UI table structure like the game does in create_UIBox_detailed_tooltip
    local full_UI_table = {
        main = {},
        info = {},
        type = {},
        name = 'done',
        badges = {}
    }

    -- Generate UI using the game's function with proper structure
    local success, desc = pcall(generate_card_ui, center, full_UI_table, nil, center.set, nil)
    if not success or not desc then
        return ""
    end


    -- Extract text from the info section (like the game does)
    local joker_effect = ""
    if desc.info and desc.info[1] then
        joker_effect = CardUtils.extract_text_from_ui_nodes(desc.info[1])
    end

    -- If no info, try main section
    if joker_effect == "" and desc.main then
        joker_effect = CardUtils.extract_text_from_ui_nodes(desc.main)
    end

    if joker_effect == "" then
        return ""
    end

    -- Clean up formatting codes
    joker_effect = CardUtils.clean_text(joker_effect)

    return joker_effect
end

return CardUtils