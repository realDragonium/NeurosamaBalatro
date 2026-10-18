-- End Shop Action

local function end_shop_executor(params)
    -- The game locks the shop while leaving it; a second toggle_shop crashes on the removed shop.
    if G.CONTROLLER.locks.toggle_shop then
        return false, "Already leaving the shop"
    end
    if G.STATE == G.STATES.SHOP and G.FUNCS.toggle_shop then
        G.FUNCS.toggle_shop()
        return true, "Ended shop and proceeded to next round"
    end
    return false, "Not in shop state or toggle_shop not available"
end

local function create_end_shop_action()
    return {
        name = "end_shop",
        definition = {
            name = "end_shop",
            description = "End shop and proceed to next round",
            parameters = {}
        },
        executor = end_shop_executor
    }
end

return create_end_shop_action