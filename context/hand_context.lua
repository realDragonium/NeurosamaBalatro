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

    -- Get all special attributes using shared CardUtils function
    local special_attrs = CardUtils.get_card_attributes(card)

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