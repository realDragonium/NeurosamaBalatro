-- Play Blind Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function play_blind_executor(params)
    -- Play the currently selected blind
    -- Check if we're in the blind selection state
    if not G.GAME or not G.GAME.blind_on_deck then
        sendWarnMessage("No blind on deck", "PlayBlind")
        return false, "No blind selected"
    end

    -- Check if blind_select_opts exists
    if not G.blind_select_opts then
        sendWarnMessage("No blind select options available", "PlayBlind")
        return false, "Blind selection not available"
    end

    local blind_key = string.lower(G.GAME.blind_on_deck)
    local blind_option = G.blind_select_opts[blind_key]

    if not blind_option then
        sendWarnMessage("Blind option not found for: " .. blind_key, "PlayBlind")
        return false, "Blind option not found"
    end

    -- G.blind_select_opts outlives the screen; the button only works once the screen has settled.
    if G.blind_select and CardUtils.press(blind_option:get_UIE_by_ID('select_blind_button')) then
        sendInfoMessage("Playing blind: " .. G.GAME.blind_on_deck, "PlayBlind")
        return true, "Playing blind"
    end

    return false, CardUtils.BUSY_MESSAGE
end

local function create_play_blind_action()
    -- Always available when in blind selection state
    if G.GAME and G.GAME.blind_on_deck then
        return {
            name = "play_blind",
            definition = {
                name = "play_blind",
                description = "Play the current blind",
                parameters = {}
            },
            executor = play_blind_executor
        }
    end

    return nil
end

return create_play_blind_action