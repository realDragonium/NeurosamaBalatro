-- Select From Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_from_pack_executor(params)
    local max_cards = G.GAME.pack_choices or 1
    
    if not G.pack_cards then
        return false, "No pack cards available"
    end
    
    -- Handle both single index and array of indices
    local card_indices = {}
    if max_cards == 1 then
        -- Single card selection
        local card_index = params.card_index
        if not card_index then
            return false, "card_index is required"
        end
        card_indices = {card_index}
    else
        -- Multiple card selection
        card_indices = params.card_indices
        if not card_indices or #card_indices == 0 then
            return false, "card_indices is required"
        end
    end

    local cards_to_select = {}
    for _, idx in ipairs(card_indices) do
        if G.pack_cards.cards[idx] then
            table.insert(cards_to_select, G.pack_cards.cards[idx])
        end
    end

    if #cards_to_select > 0 then
        -- For multiple card selection, we need to add cards to highlighted selection
        -- and then confirm the selection
        for _, card in ipairs(cards_to_select) do
            -- Add card to highlighted selection (this is the correct way for packs)
            if G.pack_cards and G.pack_cards.add_to_highlighted then
                G.pack_cards:add_to_highlighted(card)
            end
        end
        
        -- After highlighting all cards, we need to confirm the selection
        -- This is typically done by finding and clicking a confirm/use button
        G.E_MANAGER:add_event(Event({
            trigger = "after",
            delay = 0.2, -- Small delay to let highlighting complete
            func = function()
                -- Try to find and click the first highlighted card's use button
                -- The game will handle processing all highlighted cards together
                local first_card = cards_to_select[1]
                if first_card and first_card.children and first_card.children.use_button then
                    local use_button = first_card.children.use_button
                    
                    -- Find the actual button in the use_button UI structure
                    local button = nil
                    if use_button.UIRoot and use_button.UIRoot.children then
                        for _, child in ipairs(use_button.UIRoot.children) do
                            if child.config and child.config.button then
                                button = child
                                break
                            end
                        end
                    end
                    
                    if button and button.click then
                        button:click()
                    elseif use_button.click then
                        use_button:click()
                    end
                end
                return true
            end
        }))
        
        return true, "Selecting pack cards: " .. table.concat(card_indices, ", ")
    end

    return false, "No valid cards found at specified indices"
end

local function create_select_from_pack_action()
    -- Only available when pack cards are present
    if G.pack_cards and G.pack_cards.cards then
        local max_cards = G.GAME.pack_choices or 1
        local total_cards = #G.pack_cards.cards
        if max_cards > 0 then
            if max_cards == 1 then
                -- Single card selection - use simple integer parameter
                return {
                    name = "select_from_pack",
                    definition = {
                        name = "select_from_pack",
                        description = "Select 1 card from the opened pack by index (use card_index: 1-" .. total_cards .. ")",
                        schema = {
                            type = "object",
                            properties = {
                                card_index = {
                                    type = "integer",
                                    minimum = 1,
                                    maximum = total_cards
                                }
                            },
                            required = {"card_index"}
                        }
                    },
                    executor = select_from_pack_executor
                }
            else
                -- Multiple card selection - use array parameter
                return {
                    name = "select_from_pack",
                    definition = {
                        name = "select_from_pack",
                        description = "Select up to " .. max_cards .. " cards from the opened pack by indices (use card_indices: [1-" .. total_cards .. "])",
                        schema = {
                            type = "object",
                            properties = {
                                card_indices = {
                                    type = "array",
                                    items = {
                                        type = "integer",
                                        minimum = 1,
                                        maximum = total_cards
                                    },
                                    minItems = 1,
                                    maxItems = max_cards,
                                }
                            },
                            required = {"card_indices"}
                        }
                    },
                    executor = select_from_pack_executor
                }
            end
        end
    end

    return nil
end

return create_select_from_pack_action