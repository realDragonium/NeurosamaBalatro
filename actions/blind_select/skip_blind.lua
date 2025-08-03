-- Skip Blind Action

local function skip_blind_executor(params)
    -- Skip the currently selected blind
    -- Check if we're in the blind selection state
    if not G.GAME or not G.GAME.blind_on_deck then
        sendWarnMessage("No blind on deck", "SkipBlind")
        return false, "No blind selected"
    end

    -- Can't skip boss blind
    if G.GAME.blind_on_deck == "Boss" then
        sendWarnMessage("Cannot skip boss blind", "SkipBlind")
        return false, "Cannot skip boss blind"
    end

    -- Check if blind_select_opts exists
    if not G.blind_select_opts then
        sendWarnMessage("No blind select options available", "SkipBlind")
        return false, "Blind selection not available"
    end

    local blind_key = string.lower(G.GAME.blind_on_deck)
    local blind_option = G.blind_select_opts[blind_key]

    if not blind_option then
        sendWarnMessage("Blind option not found for: " .. blind_key, "SkipBlind")
        return false, "Blind option not found"
    end

    -- Skip the blind
    local e = {
        UIBox = blind_option
    }
    
    if G.FUNCS.skip_blind then
        G.FUNCS.skip_blind(e)
        sendInfoMessage("Skipping blind: " .. G.GAME.blind_on_deck, "SkipBlind")
        return true, "Skipping blind"
    end

    return false, "skip_blind function not available"
end

local function create_skip_blind_action()
    -- Only available when not on Boss blind
    if G.GAME and G.GAME.blind_on_deck and G.GAME.blind_on_deck ~= "Boss" then
        return {
            name = "skip_blind",
            definition = {
                name = "skip_blind",
                description = "Skip the current blind",
                parameters = {}
            },
            executor = skip_blind_executor
        }
    end
    
    return nil
end

return create_skip_blind_action