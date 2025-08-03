-- Skip Pack Action

local function skip_pack_executor(params)
    if G.FUNCS.skip_booster then
        G.FUNCS.skip_booster()
        return true, "Skipped pack selection"
    end
    return false, "Skip booster function not available"
end

local function create_skip_pack_action()
    -- Only available when pack cards are present
    if G.pack_cards and G.pack_cards.cards then
        return {
            name = "skip_pack",
            definition = {
                name = "skip_pack",
                description = "Skip selecting from the current pack",
                parameters = {}
            },
            executor = skip_pack_executor
        }
    end

    return nil
end

return create_skip_pack_action