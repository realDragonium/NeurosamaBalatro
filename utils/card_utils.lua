-- Card Utility Functions
-- Shared utilities for card interactions in shop actions

local CardUtils = {}

-- Helper function to push a button using G.FUNCS (based on balatrobot)
function CardUtils.push_button(button)
    if button and button.config and button.config.button then
        G.FUNCS[button.config.button](button)
    end
end

-- Helper function to find and click the appropriate button on a card
function CardUtils.use_card(card)
    if not card then return false end

    -- Based on balatrobot's usecard function
    local use_button = card.children.use_button and card.children.use_button.definition
    if use_button and use_button.config and use_button.config.button == nil then
        -- Special handling for use buttons with nodes
        local node_index = card.ability and card.ability.consumeable and 2 or 1
        local button_node = use_button.nodes and use_button.nodes[node_index]

        if card.area and card.area.config and card.area.config.type == 'joker' then
            -- Special path for jokers
            button_node = use_button.nodes[1].nodes[1].nodes[1].nodes[1]
        end

        if button_node then
            CardUtils.push_button(button_node)
            return true
        end
        return false
    end

    -- Try buy_and_use_button first, then buy_button (get definitions)
    local buy_and_use_button = card.children.buy_and_use_button and card.children.buy_and_use_button.definition
    local buy_button = card.children.buy_button and card.children.buy_button.definition

    if buy_and_use_button then
        CardUtils.push_button(buy_and_use_button)
        return true
    elseif buy_button then
        CardUtils.push_button(buy_button)
        return true
    end

    return false
end

return CardUtils