-- Consumable Utilities
-- Helper functions for working with consumable cards (tarot, planet, spectral)

local ConsumableUtils = {}

-- No hardcoded consumables - we'll detect targeting dynamically

-- Check if a consumable requires card targeting
function ConsumableUtils.requires_targeting(consumable)
    if not consumable or not consumable.config or not consumable.config.center then
        return false, 0
    end
    
    local center_key = consumable.config.center.key
    if G.P_CENTERS and G.P_CENTERS[center_key] and G.P_CENTERS[center_key].config then
        local max_highlighted = G.P_CENTERS[center_key].config.max_highlighted
        if max_highlighted then
            return max_highlighted > 0, max_highlighted
        end
    end
    
    return false, 0
end

-- Get targeting information for a consumable
function ConsumableUtils.get_targeting_info(consumable)
    if not consumable or not consumable.config or not consumable.config.center then
        return nil
    end
    
    local center_key = consumable.config.center.key
    if G.P_CENTERS and G.P_CENTERS[center_key] and G.P_CENTERS[center_key].config then
        local max_highlighted = G.P_CENTERS[center_key].config.max_highlighted
        if max_highlighted then
            return {
                requires_targeting = max_highlighted > 0,
                max_highlighted = max_highlighted
            }
        end
    end
    
    return {
        requires_targeting = false,
        max_highlighted = 0
    }
end

-- Get all consumables that require targeting
function ConsumableUtils.get_targeting_consumables()
    if not G.consumeables or not G.consumeables.cards then
        return {}
    end
    
    local targeting_consumables = {}
    
    for i, consumable in ipairs(G.consumeables.cards) do
        local requires_targeting, max_highlighted = ConsumableUtils.requires_targeting(consumable)
        if requires_targeting then
            table.insert(targeting_consumables, {
                index = i,
                consumable = consumable,
                max_highlighted = max_highlighted,
                name = consumable.config.center.name or "Unknown"
            })
        end
    end
    
    return targeting_consumables
end

-- Get all consumables that don't require targeting (simple use)
function ConsumableUtils.get_simple_consumables()
    if not G.consumeables or not G.consumeables.cards then
        return {}
    end
    
    local simple_consumables = {}
    
    for i, consumable in ipairs(G.consumeables.cards) do
        local requires_targeting, _ = ConsumableUtils.requires_targeting(consumable)
        if not requires_targeting then
            table.insert(simple_consumables, {
                index = i,
                consumable = consumable,
                name = consumable.config.center.name or "Unknown"
            })
        end
    end
    
    return simple_consumables
end

return ConsumableUtils