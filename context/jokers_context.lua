-- Jokers Context Builder
-- Handles joker card information

local JokersContext = {}

-- Build joker description string
function JokersContext.build_joker_string(joker, index)
    if not joker then return nil end

    local name = "Unknown Joker"
    local description = "No description"
    local sell_value = nil

    -- Get joker name and basic description
    if joker.config and joker.config.center then
        name = joker.config.center.name or name
        description = joker.config.center.text or description
    end

    -- Get sell value
    if joker.sell_cost then
        sell_value = joker.sell_cost
    end

    -- Try to get description using the same logic as generate_card_ui for jokers
    if joker.config and joker.config.center then
        local center = joker.config.center

        -- Get specific_vars using the same logic as generate_card_ui
        local specific_vars = nil
        local success, result = pcall(Card.generate_UIBox_ability_table, joker, true)
        if success then
            if type(result) == "table" then
                specific_vars = result
            else
                -- Some jokers return a string or other type - use empty table for localization
                specific_vars = {}
            end
        end

        -- If that failed, try the fake card approach from generate_card_ui
        if not specific_vars and center.config then
            local fake_ability = {}
            if type(center.config) == "table" then
                for k, v in pairs(center.config) do
                    fake_ability[k] = v
                end
            end
            fake_ability.set = 'Joker'
            fake_ability.name = center.name
            fake_ability.x_mult = center.config.Xmult or center.config.x_mult

            if fake_ability.name == 'To Do List' then
                fake_ability.to_do_poker_hand = "High Card" -- fallback
            end

            local fake_card = { ability = fake_ability, config = { center = center }, bypass_lock = true}
            local fake_success, fake_result = pcall(Card.generate_UIBox_ability_table, fake_card, true)
            if fake_success then
                specific_vars = fake_result
            end
        end

        -- Now use localize to get the description text - but we need to find how to get text without UI nodes
        if specific_vars then
            -- Try a simple approach - look up the localization directly
            if G.localization and G.localization.descriptions and G.localization.descriptions[center.set] and G.localization.descriptions[center.set][center.key] then
                local desc_template = G.localization.descriptions[center.set][center.key].text
                if desc_template then
                    if type(desc_template) == "table" then
                        description = table.concat(desc_template, " ")
                    else
                        description = tostring(desc_template)
                    end

                    -- Replace variables in the description
                    if type(specific_vars) == "table" then
                        local i = 1
                        for k, v in pairs(specific_vars) do
                            if type(v) == "number" then
                                description = description:gsub("#" .. i .. "#", tostring(v))
                                i = i + 1
                            elseif type(v) == "string" then
                                description = description:gsub("#" .. i .. "#", v)
                                i = i + 1
                            end
                        end
                    end

                    -- Clean up formatting codes while preserving readability
                    description = description:gsub("{[^}]*}", "")
                    -- Clean up any multiple spaces and trim
                    description = description:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
                end
            end
        end
    end

    -- Check for special attributes (editions, seals, stickers, etc.)
    local special_attrs = {}

    -- Check for editions
    if joker.edition then
        if joker.edition.foil then
            table.insert(special_attrs, "Foil")
        end
        if joker.edition.holo then
            table.insert(special_attrs, "Holographic")
        end
        if joker.edition.polychrome then
            table.insert(special_attrs, "Polychrome")
        end
        if joker.edition.negative then
            table.insert(special_attrs, "Negative")
        end
    end

    -- Check for seals
    if joker.seal then
        if joker.seal == "Red" then
            table.insert(special_attrs, "Red Seal")
        elseif joker.seal == "Blue" then
            table.insert(special_attrs, "Blue Seal")
        elseif joker.seal == "Gold" then
            table.insert(special_attrs, "Gold Seal")
        elseif joker.seal == "Purple" then
            table.insert(special_attrs, "Purple Seal")
        end
    end

    -- Check for special states
    if joker.ability and joker.ability.eternal then
        table.insert(special_attrs, "Eternal")
    end
    if joker.ability and joker.ability.perishable then
        table.insert(special_attrs, "Perishable")
    end
    if joker.pinned then
        table.insert(special_attrs, "Pinned")
    end

    local joker_desc = "  " .. index .. ". " .. name
    if description ~= "No description" then
        joker_desc = joker_desc .. " - " .. description
    end
    if #special_attrs > 0 then
        joker_desc = joker_desc .. " [" .. table.concat(special_attrs, ", ") .. "]"
    end
    if sell_value then
        joker_desc = joker_desc .. " [Sell: $" .. sell_value .. "]"
    end

    return joker_desc
end

-- Build jokers context string
function JokersContext.build_context_string()
    local parts = {}

    -- Jokers section
    if G.jokers and G.jokers.cards and #G.jokers.cards > 0 then
        table.insert(parts, "Jokers (" .. #G.jokers.cards .. "):")
        for i, joker in ipairs(G.jokers.cards) do
            local joker_desc = JokersContext.build_joker_string(joker, i)
            if joker_desc then
                table.insert(parts, joker_desc)
            end
        end
    else
        table.insert(parts, "Jokers: None")
    end

    return table.concat(parts, "\n")
end

return JokersContext