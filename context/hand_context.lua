-- Hand Context Builder
-- Handles hand and card information

local CardUtils = SMODS.load_file("context/card_utils.lua")()
local HandContext = {}

-- Get poker hand levels information
function HandContext.get_poker_hand_levels()
    local hand_levels = {}
    
    if G.GAME and G.GAME.hands then
        -- Get visible poker hands and their levels
        for hand_name, hand_data in pairs(G.GAME.hands) do
            -- Check if this hand type is visible/unlocked (using SMODS function if available)
            local is_visible = true
            if SMODS and SMODS.is_poker_hand_visible then
                is_visible = SMODS.is_poker_hand_visible(hand_name)
            end
            
            if is_visible and hand_data.level and hand_data.level > 0 then
                -- Get localized hand name
                local display_name = hand_name
                if G.localization and G.localization.misc and G.localization.misc.poker_hands then
                    display_name = G.localization.misc.poker_hands[hand_name] or hand_name
                end
                
                table.insert(hand_levels, {
                    name = display_name,
                    level = hand_data.level,
                    chips = hand_data.chips or 0,
                    mult = hand_data.mult or 0,
                    played = hand_data.played or 0
                })
            end
        end
        
        -- Sort by level descending, then by name
        table.sort(hand_levels, function(a, b)
            if a.level == b.level then
                return a.name < b.name
            end
            return a.level > b.level
        end)
    end
    
    return hand_levels
end

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