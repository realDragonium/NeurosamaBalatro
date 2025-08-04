-- Consumables Context Builder
-- Handles consumable card information (tarot, planet, spectral cards)

local ConsumableUtils = SMODS.load_file("utils/consumable_utils.lua")()
local CardUtils = SMODS.load_file("context/card_utils.lua")()
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

    -- Use CardUtils for consistent description reading
    description = CardUtils.get_consumable_effect(consumable)

    local consumable_desc = "  " .. index .. ". " .. name
    if set ~= "Unknown" then
        consumable_desc = consumable_desc .. " (" .. set .. ")"
    end
    
    -- Add targeting information
    local targeting_info = ConsumableUtils.get_targeting_info(consumable)
    if targeting_info and targeting_info.requires_targeting then
        consumable_desc = consumable_desc .. " [Targets: " .. targeting_info.max_highlighted .. " cards]"
    end
    
    if description and description ~= "" then
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