-- Select From Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_from_pack_executor(params)
    local card_indices = params.card_indices
    if not card_indices or #card_indices == 0 then
        return false, "card_indices is required"
    end

    if not G.pack_cards then
        return false, "No pack cards available"
    end

    local cards_to_select = {}
    for _, idx in ipairs(card_indices) do
        if G.pack_cards.cards[idx] then
            table.insert(cards_to_select, G.pack_cards.cards[idx])
        end
    end

    if #cards_to_select > 0 then
        for _, card in ipairs(cards_to_select) do
            -- First click the card to select it
            if card.click then
                card:click()
            end

            -- Then use the card with Event Manager
            G.E_MANAGER:add_event(Event({
                trigger = "after",
                delay = 0.1,
                func = function()
                    CardUtils.use_card(card)
                    return true
                end
            }))
        end
        return true, "Selecting pack cards: " .. table.concat(card_indices, ", ")
    end

    return false, "No valid cards found at specified indices"
end

local function create_select_from_pack_action()
    -- Only available when pack cards are present
    if G.pack_cards and G.pack_cards.cards then
        local max_cards = G.GAME.pack_choices
        if max_cards > 0 then
            return {
                name = "select_from_pack",
                definition = {
                    name = "select_from_pack",
                    description = "Select cards from an opened pack (1-" .. max_cards .. ")",
                    schema = {
                        type = "object",
                        properties = {
                            card_indices = {
                                type = "array",
                                items = {
                                    type = "integer",
                                    minimum = 1,
                                    maximum = max_cards
                                },
                                minLength = 1,
                                maxLength = max_cards,
                            }
                        },
                        required = {"card_indices"}
                    }
                },
                executor = select_from_pack_executor
            }
        end
    end

    return nil
end

return create_select_from_pack_action