-- Buy Card Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

-- Helper function to find and click the buy button (not buy-and-use)
local function buy_card_only(card)
    -- Look for the regular buy button (not buy-and-use)
    local buy_button = card.children.buy_button and card.children.buy_button.definition
    
    if buy_button then
        CardUtils.push_button(buy_button)
        return true
    end
    
    -- Fallback: try to find any button that just buys without using
    if card.children then
        for child_name, child in pairs(card.children) do
            if child and child.definition and child.definition.config then
                local config = child.definition.config
                -- Look for buy buttons that don't auto-use
                if config.button and (config.button == "buy_card" or config.button:match("buy")) then
                    -- Avoid buy_and_use buttons
                    if not config.button:match("use") and not config.button:match("and") then
                        CardUtils.push_button(child.definition)
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

local function buy_card_executor(params)
    local card_index = params.card_index
    if not card_index then
        return false, "card_index parameter is required"
    end

    if G.STATE ~= G.STATES.SHOP then
        return false, "Not in shop state"
    end

    if G.shop_jokers and G.shop_jokers.cards[card_index] then
        local card = G.shop_jokers.cards[card_index]
        if G.GAME.dollars >= card.cost then
            -- First click the card to select it
            if card.click then
                card:click()
            end

            -- Buy the card without using it
            G.E_MANAGER:add_event(Event({
                trigger = 'after',
                delay = 0.1,
                func = function()
                    local success = buy_card_only(card)
                    if not success then
                        -- Fallback: if no buy-only button found, just click the card
                        -- This should add it to collection without using
                        if card.click then
                            card:click()
                        end
                    end
                    return true
                end
            }))
            return true, "Buying card at index " .. card_index .. " (will be added to collection)"
        else
            return false, "Not enough money to buy card (costs $" .. card.cost .. ")"
        end
    end

    return false, "Card not found at index " .. card_index
end

local function create_buy_card_action()
    -- Only available in shop with available cards
    if G.STATE == G.STATES.SHOP and G.shop_jokers and G.shop_jokers.cards then
        local max_cards = #G.shop_jokers.cards
        for i, card in ipairs(G.shop_jokers.cards) do
            if card and G.GAME.dollars >= card.cost then
                return {
                    name = "buy_card",
                    definition = {
                        name = "buy_card",
                        description = "Buy a card (joker or consumable) from the shop and add it to your collection WITHOUT using it immediately (1-" .. max_cards .. ")",
                        schema = {
                            type = "object",
                            properties = {
                                card_index = {
                                    type = "integer",
                                    minimum = 1,
                                    maximum = max_cards,
                                }
                            },
                            required = {"card_index"}
                        }
                    },
                    executor = buy_card_executor
                }
            end
        end
    end

    return nil
end

return create_buy_card_action