-- Reroll Shop Action

local function reroll_shop_executor(params)
    if G.STATE == G.STATES.SHOP then
        local reroll_cost = G.GAME.current_round.reroll_cost or 5
        if G.GAME.current_round.free_rerolls and G.GAME.current_round.free_rerolls > 0 then
            reroll_cost = 0
        end

        if G.GAME.dollars >= reroll_cost then
            G.FUNCS.reroll_shop()
            return true, "Rerolled shop items"
        else
            return false, "Not enough money to reroll shop"
        end
    end
    return false, "Not in shop state"
end

local function create_reroll_shop_action()
    -- Check if player can afford reroll
    local reroll_cost = G.GAME and G.GAME.current_round and G.GAME.current_round.reroll_cost or 5
    local money = G.GAME and G.GAME.dollars or 0

    -- Check for free rerolls
    if G.GAME and G.GAME.current_round and G.GAME.current_round.free_rerolls and G.GAME.current_round.free_rerolls > 0 then
        reroll_cost = 0
    end

    if money < reroll_cost then
        return nil -- Can't afford reroll
    end

    local cost_text = reroll_cost > 0 and ("costs $" .. reroll_cost) or "free"

    return {
        name = "reroll_shop",
        definition = {
            name = "reroll_shop",
            description = "Reroll shop items (" .. cost_text .. ")",
            parameters = {}
        },
        executor = reroll_shop_executor
    }
end

return create_reroll_shop_action