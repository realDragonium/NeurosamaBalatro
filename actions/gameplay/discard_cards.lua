-- Discard Cards Action

local function discard_cards()
    if G.STATE ~= G.STATES.SELECTING_HAND then
        return false
    end
    if not G.GAME or not G.GAME.current_round or not G.GAME.current_round.discards_left or G.GAME.current_round.discards_left <= 0 then
        return false
    end
    if not G.hand or not G.hand.cards then
        return false
    end

    -- Ensure we have cards highlighted
    if not G.hand.highlighted or #G.hand.highlighted == 0 then
        return false
    end

    local discard_button = G.buttons:get_UIE_by_ID('discard_button')
    if discard_button and discard_button.click then
        discard_button:click()
        return true
    end

    return false
end

local function create_discard_cards_action()
    -- Check if player can discard (has discards left)
    local discards_left = G.GAME and G.GAME.current_round and G.GAME.current_round.discards_left or 0

    if discards_left <= 0 then
        return nil -- No discards left
    end

    -- Check if any cards are selected
    local selected_count = 0
    if G.hand and G.hand.highlighted then
        selected_count = #G.hand.highlighted
    end

    if selected_count == 0 then
        return nil -- No cards selected
    end

    return {
        name = "discard_cards",
        definition = {
            name = "discard_cards",
            description = "Discard selected cards (" .. selected_count .. " cards, " .. discards_left .. " discards left)",
            parameters = {}
        },
        executor = function(params)
            return discard_cards()
        end
    }
end

return create_discard_cards_action