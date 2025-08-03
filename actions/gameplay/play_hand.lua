-- Play Hand Action

local function play_hand()
    if G.STATE ~= G.STATES.SELECTING_HAND then
        return false
    end
    if not G.GAME or not G.GAME.current_round or not G.GAME.current_round.hands_left or G.GAME.current_round.hands_left <= 0 then
        return false
    end
    if not G.hand or not G.hand.cards then
        return false
    end

    -- Ensure we have cards highlighted
    if not G.hand.highlighted or #G.hand.highlighted == 0 then
        return false
    end


    local play_button = G.buttons:get_UIE_by_ID('play_button')
    if play_button and play_button.click then
        play_button:click()
        return true
    end

    return false
end

local function create_play_hand_action()
    -- Check if player can play hand (has selected cards and plays left)
    local plays_left = G.GAME and G.GAME.current_round and G.GAME.current_round.hands_left or 0

    if plays_left <= 0 then
        return nil -- No plays left
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
        name = "play_hand",
        definition = {
            name = "play_hand",
            description = "Play selected cards (" .. selected_count .. " cards, " .. plays_left .. " plays left)",
            parameters = {}
        },
        executor = function(params)
            return play_hand()
        end
    }
end

return create_play_hand_action