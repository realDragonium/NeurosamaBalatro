-- Cash Out Action

local function cash_out_executor(params)
    if G.FUNCS.cash_out then
        G.FUNCS.cash_out({config={}})
        return true, "Successfully cashed out!"
    end
    return false, "Cash out didn't work"
end

local function create_cash_out_action()
    return {
        name = "cash_out",
        definition = {
            name = "cash_out",
            description = "Cash out and end the blind",
            parameters = {}
        },
        executor = cash_out_executor
    }
end

return create_cash_out_action