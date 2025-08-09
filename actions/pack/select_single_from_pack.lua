-- Select Single Card From Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function select_single_from_pack_executor(params)
    if not G.pack_cards then
        return false, "No pack cards available"
    end
    
    local card_index = params.card_index
    if not card_index then
        return false, "card_index is required"
    end
    
    if not G.pack_cards.cards[card_index] then
        return false, "Invalid card index: " .. card_index
    end
    
    local selected_card = G.pack_cards.cards[card_index]
    
    G.E_MANAGER:add_event(Event({
        trigger = "after",
        delay = 0.1,
        func = function()
            -- Add to highlighted selection
            if G.pack_cards and G.pack_cards.add_to_highlighted then
                G.pack_cards:add_to_highlighted(selected_card)
            end
            
            -- Find and click the use button
            local button = nil
            if selected_card.children and selected_card.children.use_button and 
               selected_card.children.use_button.UIRoot and selected_card.children.use_button.UIRoot.children then
                for _, child in ipairs(selected_card.children.use_button.UIRoot.children) do
                    if child.config and child.config.button then
                        button = child
                        break
                    end
                end
            end
            
            if button and button.click then
                button:click()
            end
            return true
        end
    }))
    
    return true, "Selected pack card at index: " .. card_index
end

local function create_select_single_from_pack_action()
    -- Only available when pack cards are present
    if not G.pack_cards or not G.pack_cards.cards then
        return nil
    end
    
    local total_cards = #G.pack_cards.cards
    local max_cards = G.GAME.pack_choices or 1
    
    -- Fallback for pack size detection
    if total_cards == 0 then
        if SMODS and SMODS.OPENED_BOOSTER and SMODS.OPENED_BOOSTER.config and 
           SMODS.OPENED_BOOSTER.config.center and SMODS.OPENED_BOOSTER.config.center.config and
           SMODS.OPENED_BOOSTER.config.center.config.extra then
            total_cards = SMODS.OPENED_BOOSTER.config.center.config.extra
        elseif G.GAME and G.GAME.pack_size then
            total_cards = G.GAME.pack_size
        else
            total_cards = 3
        end
    end
    
    if total_cards <= 0 or max_cards <= 0 then
        return nil
    end
    
    return {
        name = "select_single_from_pack",
        definition = {
            name = "select_single_from_pack",
            description = "Select exactly one card from the opened pack. Indices range from 1-" .. total_cards .. ".",
            schema = {
                type = "object",
                properties = {
                    card_index = {
                        type = "integer",
                        minimum = 1,
                        maximum = total_cards,
                        description = "Index of the card to select"
                    }
                },
                required = {"card_index"}
            }
        },
        executor = select_single_from_pack_executor
    }
end

return create_select_single_from_pack_action