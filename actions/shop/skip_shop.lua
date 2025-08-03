-- Skip Shop Action

local function skip_shop_executor(params)
    if G.STATE == G.STATES.SHOP and G.FUNCS.toggle_shop then
        G.FUNCS.toggle_shop()
        return true, "Skipped shop and proceeded to next round"
    end
    return false, "Not in shop state or toggle_shop not available"
end

local function create_skip_shop_action()
    return {
        name = "skip_shop",
        definition = {
            name = "skip_shop",
            description = "Skip shop and proceed to next round",
            parameters = {}
        },
        executor = skip_shop_executor
    }
end

return create_skip_shop_action