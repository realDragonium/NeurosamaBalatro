-- Play Hand Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function play_hand()
    if G.STATE ~= G.STATES.SELECTING_HAND then
        return false, "Not choosing a hand right now"
    end
    if not G.GAME or not G.GAME.current_round or not G.GAME.current_round.hands_left or G.GAME.current_round.hands_left <= 0 then
        return false, "No hands left"
    end
    if not G.hand or not G.hand.cards then
        return false, "No hand"
    end

    -- Ensure we have cards highlighted
    if not G.hand.highlighted or #G.hand.highlighted == 0 then
        return false, "No cards selected; select cards first"
    end

    local limit = math.max(G.GAME.starting_params.play_limit, 1)
    if #G.hand.highlighted > limit then
        return false, "Too many cards selected; you can play at most " .. limit
    end

    if CardUtils.press(G.buttons and G.buttons:get_UIE_by_ID('play_button')) then
        return true, "Playing " .. #G.hand.highlighted .. " cards"
    end
    -- The boss blind keeps Play disabled while it is being revealed.
    if G.GAME.blind and G.GAME.blind.block_play then
        return false, "The boss blind is still being revealed; try again in a moment"
    end
    return false, CardUtils.BUSY_MESSAGE
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