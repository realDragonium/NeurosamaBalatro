-- Skip Pack Action

local CardUtils = SMODS.load_file("utils/card_utils.lua")()

local function skip_pack_executor(params)
    -- Skipping a pack that is already closing ends it twice and leaves the game without a state.
    if not (G.pack_cards and G.pack_cards.cards) or not CardUtils.game_allows('can_skip_booster') then
        return false, "The pack is already closing"
    end
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