-- Jokers Context Builder
-- Handles joker card information

local CardUtils = SMODS.load_file("context/card_utils.lua")()
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

    -- Get description using our new joker effect function
    if joker.config and joker.config.center and joker.config.center.key then
        local joker_effect = CardUtils.get_joker_effect(joker.config.center.key)
        if joker_effect ~= "" then
            description = joker_effect
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