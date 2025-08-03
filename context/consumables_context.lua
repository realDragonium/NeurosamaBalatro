-- Consumables Context Builder
-- Handles consumable card information (tarot, planet, spectral cards)

local ConsumablesContext = {}

-- Build consumable description string
function ConsumablesContext.build_consumable_string(consumable, index)
    if not consumable then return nil end

    local name = "Unknown Consumable"
    local description = "No description"
    local set = "Unknown"

    -- Get consumable name, set, and basic description
    if consumable.config and consumable.config.center then
        local center = consumable.config.center
        name = center.name or name
        description = center.text or description
        set = center.set or set
    end

    -- Try to get description using the same logic as jokers_context
    if consumable.config and consumable.config.center then
        local center = consumable.config.center

        -- Get specific_vars using the same logic as generate_card_ui
        local specific_vars = nil
        local success, result = pcall(Card.generate_UIBox_ability_table, consumable, true)
        if success then
            specific_vars = result
        end

        -- If that failed, try the fake card approach from generate_card_ui
        if not specific_vars and center.config then
            local fake_ability = {}
            if type(center.config) == "table" then
                for k, v in pairs(center.config) do
                    fake_ability[k] = v
                end
            end
            fake_ability.set = center.set
            fake_ability.name = center.name

            local fake_card = { ability = fake_ability, config = { center = center }, bypass_lock = true}
            local fake_success, fake_result = pcall(Card.generate_UIBox_ability_table, fake_card, true)
            if fake_success then
                specific_vars = fake_result
            end
        end

        -- Now use localize to get the description text - look up the localization directly
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

    local consumable_desc = "  " .. index .. ". " .. name
    if set ~= "Unknown" then
        consumable_desc = consumable_desc .. " (" .. set .. ")"
    end
    if description ~= "No description" then
        consumable_desc = consumable_desc .. " - " .. description
    end

    return consumable_desc
end

-- Build consumables context string
function ConsumablesContext.build_context_string()
    local parts = {}

    -- Consumables section
    if G.consumeables and G.consumeables.cards and #G.consumeables.cards > 0 then
        table.insert(parts, "Consumables (" .. #G.consumeables.cards .. "):")
        for i, consumable in ipairs(G.consumeables.cards) do
            local consumable_desc = ConsumablesContext.build_consumable_string(consumable, i)
            if consumable_desc then
                table.insert(parts, consumable_desc)
            end
        end
    else
        table.insert(parts, "Consumables: None")
    end

    return table.concat(parts, "\n")
end

return ConsumablesContext